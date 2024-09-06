-- LuaTree lexer.


--[[
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


--local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local lex = {}


local stringWalk = require("lib.string_walk")


--local inspect = require("test.inspect.inspect") -- debug
local shared = require("lua_shared")


local _argType = shared._argType


local symbols = {}
symbols["5.1"] = {
	"#", "%", "(", ")", "*", "+", ",", "-", "...", "..", ".", "/", ":", ";", "<=",
	"<", "==", "=", ">=", ">", "[", "]", "^",  "{", "}", "~="
}
-- also used for LuaJIT
symbols["5.2"] = {
	"#", "%", "(", ")", "*", "+", ",", "-", "...", "..", ".", "/", "::", ":", ";", "<=",
	"<", "==", "=", ">=", ">", "[", "]", "^",  "{", "}", "~="
}
symbols["5.3"] = {
	"#", "%", "(", ")", "*", "+", ",", "-", "...", "..", ".", "//", "/", "::", ":", ";", "<<", "<=",
	"<", "==", "=", ">>", ">=", ">", "[", "]", "^",  "{", "}", "~=", "~", "&", "|"
}
symbols["5.4"] = symbols["5.3"]


local function _luaKeyVer(W)
	return (W.lua_ver == "5.1" and W.jit) and "5.2" or W.lua_ver
end


local function _checkToken(W, t)
	_argType(1, W, "table")
	_argType(2, t, "table")
	if not t.id then error("missing token ID.") end
	if not t.i then error("missing token i (byte position).") end
end


local function _delimLoop(W)
	while lex.ignore(W) or lex.space(W) or lex.comment(W) do end
end


local function _token(W, t)
	_checkToken(W, t)

	t.delim = {}
	table.insert(W.t, t)
	_delimLoop(W)

	return t
end


local function _delim(W, t)
	_checkToken(W, t)

	local last_token = W.t[#W.t]
	if not last_token then
		error("no token to append delimiter tokens to.")
	end

	table.insert(last_token.delim, t)
	return t
end


-- Skip the first line if it begins with '#'.
-- https://www.lua.org/manual/5.1/manual.html#luaL_loadfile
function lex.ignore(W)
	if W.I == 1 then
		local s = W:match("^#[^\n]*\n?")
		if s then
			return _delim(W, {id="ignore", text=s, i=1})
		end
	end
end


function lex.space(W)
	local i = W.I
	local s = W:match("^%s+")
	if s then
		return _delim(W, {id="space", text=s, i=i})
	end
end


function lex.comment(W)
	local i = W.I
	if W:lit("--") then
		-- long comment
		local l1 = W:match("^%[(=*)%[")
		if l1 then
			local s = W:match("(.-)%]" .. l1 ..  "%]")
			if not s then
				W:error("unclosed long comment")
			end
			return _delim(W, {id="comment", level=#l1, text=s, i=i})
		end
		-- short comment
		local s = W:match("^[^\n]*")
		return _delim(W, {id="comment", level=false, text=s, i=i})
	end
end


-- for strings enclosed in single or double quotes
-- [[
local function _getQuoteClose(s, q, i)
	while i <= #s do
		local x = s:find(q, i, true)
		if not x then
			break
		end
		-- skip escaped quotes, but accept things like "\\"
		if s:sub(x - 1, x - 1) ~= "\\" or s:sub(x - 2, x - 1) == "\\\\" then
			return x
		end
		i = x + 1
	end
end
--]]


function lex.string(W)
	local i = W.I
	-- long string
	local l1 = W:match("^%[(=*)%[")
	if l1 then
		-- Lua ignores initial line feeds in long strings. Store this in the field 'lf'.
		local lf = W:match("^\r?\n")
		local s, l2 = W:match("(.-)%]" .. l1 .. "%]")
		if not s then
			W:error("unclosed long string")
		end
		return _token(W, {id="string", text=s, quote=#l1, lf=lf, i=i})
	end
	-- short string
	local q = W:match("^['\"]")
	if q then
		local s
		local x = _getQuoteClose(W.S, q, W.I)
		if x then
			if x - W.I > 0 then
				s = W:bytes(x - W.I)
			else
				s = ""
			end
			W:step(1)
		end
		if not s or s:find("[^\\]\n") then
			W:error("unclosed string")
		end
		return _token(W, {id="string", text=s, quote=q, i=i})
	end
end


function lex.name(W)
	local i = W.I
	local key_hash = shared.keywords_hash[_luaKeyVer(W)]
	local s
	-- LuaJIT accepts non-ASCII bytes for names. In practice, this means you can use
	-- UTF-8 code points greater than U+007F for variable identifiers.
	if W.jit then
		s = W:match("^[%a_\128-\255][%w_\128-\255]*")
	else
		s = W:match("^[%a_][%w_]*")
	end
	if s and not key_hash[s] then
		return _token(W, {id="name", text=s, i=i})
	end
	W:seek(i)
end


function lex.keyword(W)
	local i = W.I
	for _, s in ipairs(shared.keywords[_luaKeyVer(W)]) do
		if W:lit(s) then
			if not W:find("^%a") then
				return _token(W, {id=s, text=s, i=i})
			end
			W:seek(i)
		end
	end
end


function lex.symbol(W)
	local i = W.I
	local sym_id = W.jit and "5.2" or W.lua_ver
	for _, s in ipairs(symbols[sym_id]) do
		if W:lit(s) then
			return _token(W, {id=s, text=s, i=i})
		end
	end
end


local function _numCheckDot(W, int, dot, frac)
	if #int == 0 and #dot > 0 and #frac == 0 then
		W:error("malformed number")
	end
end


local function _numCheckEnd(W, first)
	-- Checks that a number is followed by a valid delimiter.
	local i = W.I
	if not W:isEOS() and not W:lit("--") and not W:match("^[%^%]%}%)%s%-%+%/%*,;]") then
		-- Try to show a bit of the substring that killed the lexer.
		local show_chunk = W.S:match("[%w%.%-%+]+", first)
		W:error("malformed number near '" .. (show_chunk or "(?)") .. "'")
	end
	W:seek(i)
end


local function _numCheckJitSuffix(W, exp, dot, jit)
	if jit then
		-- Imaginary part of complex numbers
		local imag = W:match("^[iI]")
		if imag then
			return imag

		-- 64-bit integers
		elseif not exp and #dot == 0 then
			return W:match("^[Uu]?[Ll][Ll]")
		end
	end
end


function lex.number(W)
	local i = W.I

	-- LuaJIT binary numbers
	if W.jit then
		local bin = W:match("^0[Bb][01]+")
		if bin then
			local jsuf = _numCheckJitSuffix(W, nil, "", W.jit)
			_numCheckEnd(W, i)
			return _token(W, {id="number", text=bin .. (jsuf or ""), i=i})
		end
	end

	-- Non-JIT PUC-Lua 5.1 hex numbers (no fractional parts or binary exponents)
	if W.lua_ver == "5.1" and not W.jit then
		local hex = W:match("^0[Xx]%x+")
		if hex then
			_numCheckEnd(W, i)
			return _token(W, {id="number", text=hex, i=i})
		end
	-- LuaJIT, PUC-Lua 5.2+ hex numbers
	else
		local integ, dot, frac = W:match("^(0[Xx]%x*)(%.?)(%x*)")
		if integ then
			_numCheckDot(W, integ, dot, frac)
			local exp = W:match("^[Pp][%-%+]?[0-9]+")
			local jsuf = _numCheckJitSuffix(W, exp, dot, W.jit)
			_numCheckEnd(W, i)
			return _token(W, {id="number", text=integ .. dot .. frac .. (exp or "") .. (jsuf or ""), i=i})
		end
	end

	-- Decimal numbers
	local integ, dot, frac = W:match("^(%d*)(%.?)(%d*)")
	if #integ > 0 or (#dot > 0 and (#integ > 0 or #frac > 0)) then
		_numCheckDot(W, integ, dot, frac)
		local exp = W:match("^[Ee][%-%+]?[0-9]+")
		local jsuf = _numCheckJitSuffix(W, exp, dot, W.jit)
		_numCheckEnd(W, i)
		return _token(W, {id="number", text=integ .. dot .. frac .. (exp or "") .. (jsuf or ""), i=i})
	end
	W:seek(i)
end


function lex.main(W)
	while lex.string(W)
	or lex.name(W)
	or lex.keyword(W)
	or lex.symbol(W)
	or lex.number(W)
	do
		-- Debug
		--[[
		print()
		local tt = W.t[#W.t]
		print("#tokens", #W.t, tt)
		if type(tt) == "table" then
			print(tt.id, "|" .. tt.text .. "|")
			print("i", tt.i)
			print()
			print("W.I:", W.I)
		end
		--]]
	end
end


function lex.newLexer(str, lua_ver, jit)
	-- This is split from lex.lex() to make it easier to
	-- test individual consumer functions.
	_argType(1, str, "string")
	_argType(2, lua_ver, "string", "nil")
	_argType(3, jit, "string", "boolean", "nil")

	if not shared.versions[lua_ver] then
		error("unsupported Lua version: [" .. lua_ver .. "]")

	elseif jit and lua_ver ~= "5.1" then
		error("when jit mode is active, the Lua version must be 5.1.")
	end

	local W = stringWalk.new(str)
	W.lua_ver = lua_ver
	W.jit = not not jit
	W.t = {}

	-- LuaJIT: If present, skip leading UTF-8 BOM
	if W.jit then
		W:find("^\239\187\191") -- U+FEFF
	end

	_token(W, {id="root", text="", i=1})

	return W
end


local function _setLineCharNum(s, i, j, ln, cn)
	ln, cn = stringWalk.countLineChar(s, i, j, ln, cn)
	return ln, ln, cn, cn, i
end


function lex.lex(str, lua_ver, jit)
	local W = lex.newLexer(str, lua_ver, jit)

	lex.main(W)

	if not W:isEOS() then
		if #W.t > 0 then
			W:error("lexer failed near '" .. W.t[#W.t].id .. "' / '" .. W.t[#W.t].text .. "'")
		else
			W:error("lexer failed at start of chunk.")
		end
	end

	-- Apply line and character numbers to tokens
	local ln, cn, last_i = 1, 1, 1
	for _, t in ipairs(W.t) do
		t.l, ln, t.c, cn, last_i = _setLineCharNum(W.S, t.i, last_i, ln, cn)
		--print("(T) I: " .. t.i .. ", LN: " .. t.l .. ", CN: " .. t.c .. ", id: " .. t.id .. ", text: |" .. t.text .. "|")
		for _, d in ipairs(t.delim) do
			d.l, ln, d.c, cn, last_i = _setLineCharNum(W.S, d.i, last_i, ln, cn)
			--print("(T) I: " .. d.i .. ", (D) LN: " .. d.l .. ", CN: " .. d.c .. ", id: " .. d.id .. ", text: |" .. d.text .. "|")
		end
	end

	return W
end


return lex
