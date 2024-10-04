-- Lua source parser

--[[
SPDX-License-Identifier: MIT

MIT License

Copyright (c) 2024 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local parse = {}


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


--local interp = require(PATH .. "pile_interp") -- TODO
local _argType = require(PATH .. "pile_arg_check").type


local lex = require(PATH .. "lua_lex")
local shared = require(PATH .. "lua_shared")


--local inspect = require("test.inspect") -- debug
--local pretty = require("test_lua_pretty") -- debug


local void_token = {id="_VOID_", text=""}


local sym = {}
parse.sym = sym


local _mt_node = {}
_mt_node.__index = _mt_node


local function _node(token, ...)
	if type(token.id) ~= "string" then
		error("missing or corrupt 'token.id' field")
	end

	local node = {children={}}
	for k, v in pairs(token) do
		node[k] = v
	end
	node.delim = node.delim or {}
	node.text = node.text or ""

	for i = 1, select("#", ...) do
		table.insert(node.children, select(i, ...))
	end
	return setmetatable(node, _mt_node)
end


local _mt_parser = {}
_mt_parser.__index = _mt_parser


function _mt_parser:error(err)
	local t = self:peek()
	if t.id == "_VOID_" then
		t = self.t[#self.t]
	end
	error("line " .. (t.l or "?") .. ", character " .. (t.c or "?") .. ": " .. err or "(no error message provided)")
end


function _mt_parser:assert(eval, err)
	if not eval then
		self:error(err)
	end
	return eval
end


function _mt_parser:push(node)
	_argType(1, node, "table")

	table.insert(self.stack, node)
	return node
end


function _mt_parser:pop()
	if not self.stack[1] then
		error("attempted to pop an empty stack.")
	end
	return table.remove(self.stack)
end


function _mt_parser:peek(i)
	i = i or 0
	return self.t[self.i + i] or void_token
end


function _mt_parser:seek(i)
	i = i or 1
	self.i = i
end


function _mt_parser:step(i)
	i = i or 1
	self.i = self.i + i
end


function _mt_parser:get(id)
	_argType(1, id, "string")

	local token = self:peek()
	if token.id == id then
		self:step()
		return token
	end
end


function _mt_parser:expect(id)
	local token = self:get(id)
	if not token then
		self:error("expected token '" .. id .. "', got '" .. token.id .. "'")
	end
	return token
end


function _mt_parser:topChild()
	local children = self.stack[#self.stack].children
	if #children == 0 then
		error("no children in top stack object")
	end
	return children[#children]
end


function _mt_parser:inBounds()
	return self.i >= 1 and self.i <= #self.t
end


function _mt_parser:tryPut(n)
	if n then
		table.insert(self.stack[#self.stack].children, n)
		return n
	end
end


function _mt_parser:tryPutReq(n, err)
	n = self:tryPut(n)
	if not n then
		self:error(err)
	end
	return n
end


local function _startCompoundNode(n, id)
	if n then
		return n, _node({id=id}, n)
	end
end


local function _generic(P, id)
	local t = P:get(id)
	return t and _node(t)
end


function sym.name(P) return _generic(P, "name") end
function sym.number(P) return _generic(P, "number") end
function sym.string(P) return _generic(P, "string") end


function sym.other(P, id, id2)
	_argType(2, id, "string")
	_argType(3, id2, "string", "nil")

	local t = P:get(id)

	if t then
		local n = _node(t)
		n.id = id2 or id
		return n
	end
end


local function _getLastLine(P)
	local last_tok = P:peek()
	return last_tok and last_tok.l or false
end

-- (Name | '(' exp ')') ('.' Name | '[' exp ']' | ':' Name args | args)*
-- For [7], [11], [12]
local function _prefixedExpression(P, id)
	local last_line = _getLastLine(P)

	local node, node2 = _startCompoundNode(sym.name(P) or sym.other(P, "("), id)
	if node then
		P:push(node2)

		if node.id == "(" then
			P:tryPutReq(sym.exp(P), "expected expression after '('")
			P:tryPutReq(sym.other(P, ")"), "expected ')' after expression")
			last_line = _getLastLine(P)
		end

		while true do
			if P:tryPut(sym.other(P, "[")) then
				P:tryPutReq(sym.exp(P), "expected expression after '['")
				P:tryPutReq(sym.other(P, "]"), "expected ']' after expression")

			elseif P:tryPut(sym.other(P, ".")) then
				P:tryPutReq(sym.name(P), "expected name after '.'")

			elseif P:tryPut(sym.other(P, ":")) then
				P:tryPutReq(sym.name(P), "expected name after ':'")
				P:tryPutReq(sym.args(P, last_line), "expected function arguments after name")

			elseif P:tryPut(sym.args(P, last_line)) then

			else
				break
			end
			last_line = _getLastLine(P)
		end

		return P:pop()
	end
end


-- for [8], [16]
local function _namelistOrParlist(P, is_parlist)
	if is_parlist then
		local ellipsis = sym.other(P, "...")
		if ellipsis then
			return _node({id="parlist"}, ellipsis)
		end
	end

	local node, node2 = _startCompoundNode(sym.name(P), is_parlist and "parlist" or "namelist")
	if node then
		P:push(node2)

		while P:tryPut(sym.other(P, ",")) do
			if is_parlist and P:tryPut(sym.other(P, "...")) then
				break
			end
			P:tryPutReq(sym.name(P), "expected name after ','")
		end

		return P:pop()
	end
end


-- * Lua source elements with BNR productions *


-- [1] chunk ::= {stat [';']} [laststat [';']]
-- [2] block ::= chunk
function sym.block(P)
	local node2 = _node({id="block"})
	P:push(node2)

	if P.lua_ver == "5.1" and not P.jit then
		while P:tryPut(sym.stat(P)) do
			P:tryPut(sym.other(P, ";"))
		end
		if P:tryPut(sym.laststat(P)) then
			P:tryPut(sym.other(P, ";"))
		end
	else
		while P:tryPut(sym.stat52(P)) do end
		P:tryPut(sym.retstat52(P))
	end

	return P:pop()
end


-- [3.0] stat ::=  varlist '=' explist |
-- [3.1] functioncall |
-- [3.2] 'do' block 'end' |
-- [3.3] 'while' exp 'do' block 'end' |
-- [3.4] 'repeat' block 'until' exp |
-- [3.5] 'if' exp 'then' block {'elseif' exp 'then' block} ['else' block] 'end' |
-- [3.6] 'for' Name '=' exp ',' exp [',' exp] 'do' block 'end' |
-- [3.7] 'for' namelist 'in' explist 'do' block 'end' |
-- [3.8] 'function' funcname funcbody |
-- [3.9] 'local' 'function' Name funcbody |
-- [3.10] 'local' namelist ['=' explist]
function sym.stat(P)
	return sym.statVarEqName(P) -- [3]
	or sym.functioncall(P) -- [3.1]
	or sym.statDo(P) -- [3.2]
	or sym.statWhile(P) -- [3.3]
	or sym.statRepeat(P) -- [3.4]
	or sym.statIf(P) -- [3.5]
	or sym.statFor(P) -- [3.6], [3.7]
	or sym.statFunction(P) -- [3.8]
	or sym.statLocal(P) -- [3.9] [3.10]
end


-- [5.2 3.0] stat ::= ';' |
-- [5.2 3.1] varlist '=' explist |
-- [5.2 3.2] functioncall |
-- [5.2 3.3] label |
-- [5.2 3.4] 'break' |
-- [5.2 3.5] 'goto' Name |
-- [5.2 3.6] 'do' block 'end' |
-- [5.2 3.7] 'while' exp 'do' block 'end' |
-- [5.2 3.8] 'repeat' block 'until' exp |
-- [5.2 3.9] 'if' exp 'then' block {'elseif' exp 'then' block} ['else' block] 'end' |
-- [5.2 3.10] 'for' Name '=' exp ',' exp [',' exp] 'do' block 'end' |
-- [5.2 3.11] 'for' namelist 'in' explist 'do' block 'end' |
-- [5.2 3.12] 'function' funcname funcbody |
-- [5.2 3.13] 'local' function Name funcbody |
-- [5.2 3.14] 'local' namelist ['=' explist]
function sym.stat52(P)
	return sym.other(P, ";") -- [5.2 3.0]
	or sym.statVarEqName(P) -- [3]
	or sym.functioncall(P) -- [3.1]
	or sym.label52(P) -- [5.2 3.3]
	or sym.other(P, "break") -- [5.2 3.4]
	or sym.goto52(P) -- [5.2 3.5]
	or sym.statDo(P) -- [5.2 3.6]
	or sym.statWhile(P) -- [3.3]
	or sym.statRepeat(P) -- [3.4]
	or sym.statIf(P) -- [3.5]
	or sym.statFor(P) -- [3.6], [3.7]
	or sym.statFunction(P) -- [3.8]
	or sym.statLocal(P) -- [3.9] [3.10]
end


-- [5.2 5] label ::= '::' Name '::'
function sym.label52(P)
	local node, node2 = _startCompoundNode(sym.other(P, "::"), "label")
	if node then
		P:push(node2)

		P:tryPutReq(sym.name(P), "expected Name after '::' for label")
		P:tryPutReq(sym.other(P, "::"), "expected '::' after Name for label")

		return P:pop()
	end
end


-- [5.2 3.5] 'goto' Name |
function sym.goto52(P)
	local node, node2 = _startCompoundNode(sym.other(P, "goto"), "goto")
	if node then
		P:push(node2)

		P:tryPutReq(sym.name(P), "expected Name after 'goto'")

		return P:pop()
	end
end


-- [5.2 4] retstat ::= 'return' [explist] [';']
function sym.retstat52(P)
	local node, node2 = _startCompoundNode(sym.other(P, "return"), "retstat")
	if node then
		P:push(node2)

		P:tryPut(sym.explist(P))
		P:tryPut(sym.other(P, ";"))

		return P:pop()
	end
end


-- [3.0] stat ::=  varlist '=' explist |
function sym.statVarEqName(P)
	local i = P.i
	local node, node2 = _startCompoundNode(sym.varlist(P), "statVarEqName")
	if node then
		local ok

		P:push(node2)

		if P:tryPut(sym.other(P, "=")) then
			P:tryPutReq(sym.explist(P), "expected list of expressions after '='")
			ok = true
		end

		P:pop()

		if ok then
			return node2
		end
	end
	P:seek(i)
end


-- [3.2] 'do' block 'end' |
function sym.statDo(P)
	local node, node2 = _startCompoundNode(sym.other(P, "do"), "statDo")
	if node then
		P:push(node2)

		P:tryPut(sym.block(P))
		P:tryPutReq(sym.other(P, "end"), "expected 'end' to close block")

		return P:pop()
	end
end


-- [3.3] 'while' exp 'do' block 'end' |
function sym.statWhile(P)
	local node, node2 = _startCompoundNode(sym.other(P, "while"), "statWhile")
	if node then
		P:push(node2)

		P:tryPutReq(sym.exp(P), "expected expression for 'while' loop")
		P:tryPutReq(sym.other(P, "do"), "expected 'do' after expression")
		P:tryPut(sym.block(P))
		P:tryPutReq(sym.other(P, "end"), "expected 'end' to close block")

		return P:pop()
	end
end


-- [3.4] 'repeat' block 'until' exp |
function sym.statRepeat(P)
	local node, node2 = _startCompoundNode(sym.other(P, "repeat"), "statRepeat")
	if node then
		P:push(node2)

		P:tryPut(sym.block(P))
		P:tryPutReq(sym.other(P, "until"), "expected 'until' to close block")
		P:tryPutReq(sym.exp(P), "expected expression for 'repeat' loop")

		return P:pop()
	end
end


-- [3.5] 'if' exp 'then' block {'elseif' exp 'then' block} ['else' block] 'end' |
function sym.statIf(P)
	local node, node2 = _startCompoundNode(sym.other(P, "if"), "statIf")
	if node then
		P:push(node2)

		P:tryPutReq(sym.exp(P), "expected expression after 'if'")
		P:tryPutReq(sym.other(P, "then"), "expected 'then' after expression")
		P:tryPut(sym.block(P))

		while P:tryPut(sym.other(P, "elseif")) do
			P:tryPutReq(sym.exp(P), "expected expression after 'elseif'")
			P:tryPutReq(sym.other(P, "then"), "expected 'then' after expression")
			P:tryPut(sym.block(P))
		end

		if P:tryPut(sym.other(P, "else")) then
			P:tryPut(sym.block(P))
		end

		P:tryPutReq(sym.other(P, "end"), "expected 'end' to close if statement")

		return P:pop()
	end
end


-- [3.6] 'for' Name '=' exp ',' exp [',' exp] 'do' block 'end' |
-- [3.7] 'for' namelist 'in' explist 'do' block 'end' |
function sym.statFor(P)
	local node, node2 = _startCompoundNode(sym.other(P, "for"), "statFor")
	if node then
		P:push(node2)

		P:tryPutReq(sym.namelist(P), "expected name(s) after 'for'")
		local tok = P:peek()
		P:step(1)

		-- [3.6]
		if tok.id == "=" then
			P:tryPut(_node(tok))
			P:tryPutReq(sym.exp(P), "expected expression after '='")
			P:tryPutReq(sym.other(P, ","), "expected ',' after expression")
			P:tryPutReq(sym.exp(P), "expected expression after ','")
			if P:tryPut(sym.other(P, ",")) then
				P:tryPutReq(sym.exp(P), "expected expression after ','")
			end

		-- [3.7]
		elseif tok.id == "in" then
			P:tryPut(_node(tok))
			P:tryPutReq(sym.explist(P), "expected list of expressions after 'in'")

		else
			P:error("expected 'in' or '=' after namelist in 'for' loop")
		end

		P:tryPutReq(sym.other(P, "do"), "expected 'do' after expression")
		P:tryPut(sym.block(P))
		P:tryPutReq(sym.other(P, "end"), "expected 'end' to close 'for' loop")

		return P:pop()
	end
end


-- For [3.8], [3.9]
local function _functionNameBody(P)
	P:tryPutReq(sym.funcname(P), "expected name after 'function'")
	P:tryPutReq(sym.funcbody(P), "expected function body after name")
end


-- [3.8] 'function' funcname funcbody |
function sym.statFunction(P)
	local node, node2 = _startCompoundNode(sym.other(P, "function"), "statFunction")
	if node then
		P:push(node)

		_functionNameBody(P)

		return P:pop()
	end
end


-- [3.9] 'local' 'function' Name funcbody |
-- [3.10] 'local' namelist ['=' explist]
function sym.statLocal(P)
	local node, node2 = _startCompoundNode(sym.other(P, "local"), "stat")
	if node then
		P:push(node2)
		if P:tryPut(sym.other(P, "function")) then
			_functionNameBody(P)
		else
			P:tryPutReq(sym.namelist(P), "expected name(s) after 'local'")
			if P:tryPut(sym.other(P, "=")) then
				P:tryPutReq(sym.explist(P), "expected expression(s) after '='")
			end
		end

		return P:pop()
	end
end


-- [4] laststat ::= 'return' [explist] | 'break'
function sym.laststat(P)
	local node, node2 = _startCompoundNode(sym.other(P, "break") or sym.other(P, "return"), "laststat")
	if node then
		P:push(node2)

		if node.text == "return" then
			P:tryPut(sym.explist(P))
		end

		return P:pop()
	end
end


-- [5] funcname ::= Name {'.' Name} [':' Name]
function sym.funcname(P)
	local node, node2 = _startCompoundNode(sym.name(P), "funcname")
	if node then
		P:push(node2)

		while P:tryPut(sym.other(P, ".")) do
			P:tryPutReq(sym.name(P), "expected name after '.'")
		end

		if P:tryPut(sym.other(P, ":")) then
			P:tryPutReq(sym.name(P), "expected name after ':")
		end

		return P:pop()
	end
end


-- [6] varlist ::= var {',' var}
function sym.varlist(P)
	local node, node2 = _startCompoundNode(sym.var(P), "varlist")
	if node then
		P:push(node2)

		while P:tryPut(sym.other(P, ",")) do
			P:tryPutReq(sym.var(P), "expected variable after ','")
		end

		return P:pop()
	end
end


-- [7]* var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name
-- For [6]
function sym.var(P)
	local i = P.i
	local node = _prefixedExpression(P, "var")
	if node and #node.children > 0 and node.children[#node.children].id ~= "args" then
		return node
	end
	P:seek(i)
end


-- [8] namelist ::= Name {',' Name}
function sym.namelist(P)
	return _namelistOrParlist(P)
end


-- [9] explist ::= {exp ','} exp
function sym.explist(P)
	local node, node2 = _startCompoundNode(sym.exp(P), "explist")
	if node then
		P:push(node2)

		while P:tryPut(sym.other(P, ",")) do
			P:tryPutReq(sym.exp(P), "expected expression after ','")
		end

		return P:pop()
	end
end


-- For [10]
local function _expSet(P)
	return sym.other(P, "nil")
	or sym.other(P, "false", "boolean")
	or sym.other(P, "true", "boolean")
	or sym.number(P)
	or sym.string(P)
	or sym.other(P, "...")
	or sym._function(P)
	or sym.prefixexp(P)
	or sym.tableconstructor(P)
end


-- [10] exp ::=  'nil' | 'false' | 'true' | Number | String | '...' | function |
--               prefixexp | tableconstructor | exp binop exp | unop exp
function sym.exp(P)
	local node, node2 = _startCompoundNode(sym.unop(P) or _expSet(P), "exp")
	if node then
		P:push(node2)

		-- unop exp
		if node.id == "unop" then
			P:tryPutReq(sym.exp(P), "expected expression after unary operator")

		-- exp binop exp
		else
			while P:tryPut(sym.binop(P)) do
				P:tryPutReq(sym.exp(P), "expected expression after binary operator")
			end
		end

		return P:pop()
	end
end


-- [11]* prefixexp ::= var | functioncall | '(' exp ')'
function sym.prefixexp(P)
	return _prefixedExpression(P, "prefixexp")
end


-- [12]* functioncall ::=  prefixexp args | prefixexp ':' Name args
function sym.functioncall(P)
	local i = P.i
	local node = _prefixedExpression(P, "functioncall")
	if node and #node.children > 0 and node.children[#node.children].id == "args" then
		return node
	end
	P:seek(i)
end


-- [13] args ::=  '(' [explist] ')' | tableconstructor | String
function sym.args(P, last_line)
	local node, node2 = _startCompoundNode(sym.other(P, "(") or sym.tableconstructor(P) or sym.string(P), "args")
	if node then
		if node.id == "(" then
			if last_line and node.l ~= last_line then
				P:error("ambiguous syntax")
			end
		end

		P:push(node2)

		if node.id == "(" then
			P:tryPut(sym.explist(P))
			P:tryPutReq(sym.other(P, ")"), "expected ')' after list of expressions")
		end

		return P:pop()
	end
end


-- [14] function ::= 'function' funcbody
function sym._function(P)
	local node, node2 = _startCompoundNode(sym.other(P, "function"), "function")
	if node then
		P:push(node2)

		P:tryPutReq(sym.funcbody(P), "expected function body after 'function'")

		return P:pop()
	end
end


-- [15] funcbody ::= '(' [parlist] ')' block 'end'
function sym.funcbody(P)
	local node, node2 = _startCompoundNode(sym.other(P, "("), "funcbody")
	if node then
		P:push(node2)

		P:tryPut(sym.parlist(P))
		P:tryPutReq(sym.other(P, ")"), "expected ')' after function arguments")
		P:tryPut(sym.block(P))
		P:tryPutReq(sym.other(P, "end"), "expected 'end' after function block")

		return P:pop()
	end
end


-- [16] parlist ::= namelist [',' '...'] | '...'
function sym.parlist(P)
	return _namelistOrParlist(P, true)
end


-- [17] tableconstructor ::= '{' [fieldlist] '}'
function sym.tableconstructor(P)
	local node, node2 = _startCompoundNode(sym.other(P, "{"), "tableconstructor")
	if node then
		P:push(node2)

		P:tryPut(sym.fieldlist(P))
		P:tryPutReq(sym.other(P, "}"), "expected '}' to complete table constructor")

		return P:pop()
	end
end


-- [18] fieldlist ::= field {fieldsep field} [fieldsep]
function sym.fieldlist(P)
	local node, node2 = _startCompoundNode(sym.field(P), "fieldlist")
	if node then
		P:push(node2)

		while P:tryPut(sym.fieldsep(P)) and P:tryPut(sym.field(P)) do end

		return P:pop()
	end
end


-- [19] field ::= '[' exp ']' '=' exp | Name '=' exp | exp
function sym.field(P)
	-- Peek ahead to disambiguate between "Name '=' exp" and "exp" (exp -> prefixexp -> var -> Name)
	local eq = P:peek(1).id == "="

	local node, node2 = _startCompoundNode(sym.other(P, "[") or (eq and sym.name(P)) or sym.exp(P), "field")
	if node then
		P:push(node2)

		if node.id == "[" then
			P:tryPutReq(sym.exp(P), "expected expression after '['")
			P:tryPutReq(sym.other(P, "]"), "expected ']' after expression")
			P:tryPutReq(sym.other(P, "="), "expected '=' after ']'")
			P:tryPutReq(sym.exp(P), "expected expression after '='")

		elseif node.id == "name" then
			P:tryPutReq(sym.other(P, "="), "expected '=' after ']'")
			P:tryPutReq(sym.exp(P), "expected expression after '='")
		end

		return P:pop()
	end
end


-- [20] fieldsep ::= ',' | ';'
function sym.fieldsep(P)
	return sym.other(P, ",", "fieldsep") or sym.other(P, ";", "fieldsep")
end


-- For [21], [22]
local function _arrayLookup(P, arr, id2)
	for _, v in ipairs(arr) do
		local node = sym.other(P, v, id2)
		if node then
			return node
		end
	end
end


-- [21] binop ::= '+' | '-' | '*' | '/' | '^' | '%' | '..' |
--                '<' | '<=' | '>' | '>=' | '==' | '~=' |
--                'and' | 'or'
function sym.binop(P)
	return _arrayLookup(P, shared.binop[P.lua_ver], "binop")
end


-- [22] unop ::= '-' | 'not' | '#'
function sym.unop(P)
	return _arrayLookup(P, shared.unop[P.lua_ver], "unop")
end


-- for (5.4) [5]
local function _attrib(P, node)
	-- 5.4 attrib
	if P.lua_ver == "5.4" then
		P:push(node)

		if P:tryPut(sym.other(P, "<")) then
			P:tryPutReq(sym.name(P), "expected attrib name after '<'")
			P:tryPutReq(sym.other(P, ">"), "expected '>' after attrib name")
		end

		P:pop()
	end
end


-- (5.4) [4] attnamelist ::=  Name attrib {',' Name attrib}
-- (5.4) [5] attrib ::= ['<' Name '>']
function sym.attnamelist(P)
	local node, node2 = _startCompoundNode(sym.name(P), "attnamelist")
	if node then
		_attrib(P, node)

		P:push(node2)

		while P:tryPut(sym.other(P, ",")) do
			local node_x = P:tryPutReq(sym.name(P), "expected name after ','")
			_attrib(P, node_x)
		end

		return P:pop()
	end
end


function parse.newParser(W)
	_argType(1, W, "table")

	-- This is split from parse.parse() to make it easier to
	-- test individual consumer functions.

	if W.t[1].id ~= "root" then
		error("missing root token from lexer pass")
	end

	-- W == output from lex.lex().
	local P = setmetatable({}, _mt_parser)
	P.t = W.t
	P.lua_ver = W.lua_ver
	P.jit = W.jit
	P.i = 1
	P.root = _node(W.t[1])
	P.stack = {P.root}

	P:step()

	return P
end


function parse.parse(str, lua_ver, jit)
	local W = lex.lex(str, lua_ver, jit)
	local P = parse.newParser(W)

	P:tryPut(sym.block(P))

	if P.i < #P.t then
		P:error("parsing failed (failed to reach end of tokens)")
	end

	return P.root
end


function parse.parseFile(path, lua_ver, jit)
	_argType(1, path, "string")
	local f, err = io.open(path, "r")
	if not f then
		error("file open failed: " .. tostring(err))
	end
	local s = f:read(_VERSION == "5.1" and "a" or "*a")
	f:close()
	return parse.parse(s, lua_ver, jit)
end


return parse
