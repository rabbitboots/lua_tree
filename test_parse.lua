-- Various parser tests.
-- This is incomplete: while the jobs may complete without raising errors,
-- many of them are missing any kind of validation on the returned data.


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


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.strict")


local lex = require(PATH .. "lua_lex")
local parse = require(PATH .. "lua_parse")
local pretty = require(PATH .. "test_pretty")


local errTest = require(PATH .. "test.err_test.err_test")
local inspect = require(PATH .. "test.inspect.inspect")


local cli_verbosity
for i = 0, #arg do
	if arg[i] == "--verbosity" then
		cli_verbosity = tonumber(arg[i + 1])
		if not cli_verbosity then
			error("invalid verbosity value")
		end
	end
end


local function _loadWrapper(path)
	local f = io.open(path, "r")
	if not f then
		error("unable to open path: " .. tostring(path))
	end
	local s = f:read(_VERSION == "5.1" and "a" or "*a")
	f:close()
	return s
end


local sym = parse.sym


local self = errTest.new("Parser early work")


local function _setup(str, lua_ver, jit)
	local W = lex.lex(str, lua_ver, jit)
	local P = parse.newParser(W)
	return P
end


-- [===[
self:registerJob("sym.name", function(self)

	do
		local P = _setup("foo", "5.1", false)
		local t = sym.name(P)
		print(inspect(t))
		self:isEqual(t.id, "name")
		self:isEqual(t.text, "foo")
	end


	-- Spaces and comments are automatically attached to tokens during the lexer pass.
	do
		local P = _setup(" \t\r\v\n", "5.1", false)
		local root = P.root
		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "space")
		self:isEqual(root.delim[1].text, " \t\r\v\n")
	end
end
)
--]===]


-- [===[
self:registerJob("sym.other", function(self)
	do
		local P = _setup("-...not", "5.1", false)

		local t

		t = sym.other(P, "-")
		self:isEqual(t.id, "-")
		self:isEqual(t.text, "-")

		t = sym.other(P, "...")
		self:isEqual(t.id, "...")
		self:isEqual(t.text, "...")

		t = sym.other(P, "not")
		print(inspect(t))
		self:isEqual(t.id, "not")
		self:isEqual(t.text, "not")
	end
end
)
--]===]


-- [===[
self:registerJob("sym.string", function(self)

	do
		local P = _setup("\"foobar\"", "5.1", false)
		local t

		t = sym.string(P)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foobar")
		self:isEqual(t.quote, "\"")
	end
end
)
--]===]


-- [===[
self:registerJob("sym.comment", function(self)

	do
		local P = _setup("--", "5.1", false)
		local root = P.root

		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "comment")
		self:isEqual(root.delim[1].text, "")
		self:isEqual(root.delim[1].level, false)
	end
end
)
--]===]


-- [===[
self:registerJob("sym.number", function(self)

	do
		local P = _setup("1", "5.1", false)
		local t = sym.number(P)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "1")
	end
end
)
--]===]


-- [===[
self:registerJob("sym.unop()", function(self)

	do
		local P = _setup("-", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.unop, P)
		self:isEqual(t.id, "unop")
		self:isEqual(t.text, "-")
	end


	do
		local P = _setup("not", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.unop, P)
		self:isEqual(t.id, "unop")
		self:isEqual(t.text, "not")
	end


	do
		-- The leading space prevents this string from being treated as an ignore-line
		-- by the lexer.
		local P = _setup(" #", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.unop, P)
		self:isEqual(t.id, "unop")
		self:isEqual(t.text, "#")
	end


	do
		self:print(4, "[+] Not a unop")
		local P = _setup("zoot", "5.1", false)

		local t = sym.unop(P)
		self:isType(t, "nil")
	end
end
)
--]===]


-- [===[
self:registerJob("sym.binop()", function(self)

	do
		local P = _setup("-", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.binop, P)
		self:isEqual(t.id, "binop")
		self:isEqual(t.text, "-")
	end


	do
		local P = _setup("and", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.binop, P)
		self:isEqual(t.id, "binop")
		self:isEqual(t.text, "and")
	end


	do
		local P = _setup("<=", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.binop, P)
		self:isEqual(t.id, "binop")
		self:isEqual(t.text, "<=")
	end


	do
		self:print(4, "[+] Not a binop")
		local P = _setup("zoot", "5.1", false)

		local t = sym.binop(P)
		self:isType(t, "nil")
	end
end
)
--]===]


-- [===[
self:registerJob("sym.fieldsep()", function(self)

	do
		local P = _setup(",", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.fieldsep, P)
		self:isEqual(t.id, "fieldsep")
		self:isEqual(t.text, ",")
	end


	do
		local P = _setup(";", "5.1", false)

		local t = self:expectLuaReturn("expected behavior", sym.fieldsep, P)
		self:isType(t, "table")
		self:isEqual(t.id, "fieldsep")
		self:isEqual(t.text, ";")
	end


	do
		self:print(4, "[+] Not a fieldsep")
		local P = _setup("zoot", "5.1", false)

		local t = sym.fieldsep(P)
		self:isType(t, "nil")
	end
end
)
--]===]


-- [5.2 5] label ::= '::' Name '::'
-- [5.2 3.5] 'goto' Name |
-- [===[
self:registerJob("sym.label52() and sym.goto52()", function(self)

	do
		self:print(4, "[+] 'goto' is not a keyword in PUC-Lua 5.1, and can be used as a variable identifier")
		local P = _setup("goto = 'a'", "5.1", false)

		local t = sym.stat(P)
		self:isEqual(t.id, "statVarEqName")
	end

	do
		local P = _setup("goto = 'a'", "5.2", false)

		local t = self:expectLuaError("'goto' is a keyword in PUC-Lua 5.2, and cannot be used as a variable identifier", sym.goto52, P)
	end


	do
		self:print(4, "[+] 'goto' is not supported in PUC-Lua 5.1")
		local P = _setup("goto lbl", "5.1", false)

		local t = sym.stat(P)
		self:isNil(t)
	end


	do
		self:print(4, "[+] labels are not supported in PUC-Lua 5.1")
		local P = _setup("::lbl::", "5.1", false)

		local t = sym.stat(P)
		self:isNil(t)
	end


	do
		local P = _setup("goto 1e2", "5.2", false)

		local t = self:expectLuaError("unfinished 'goto'", sym.goto52, P)
	end


	do
		local P = _setup("::lbl", "5.2", false)

		local t = self:expectLuaError("unclosed label", sym.label52, P)
	end


	do
		self:print(4, "[+] label declaration")
		local P = _setup("::continue::", "5.2", false)

		local t = sym.label52(P)
		self:isEqual(t.id, "label")
		self:isEqual(t.children[1].id, "::")
		self:isEqual(t.children[2].id, "name")
		self:isEqual(t.children[2].text, "continue")
		self:isEqual(t.children[3].id, "::")
	end


	do
		self:print(4, "[+] goto statement")
		local P = _setup("goto continue", "5.2", false)

		local t = sym.goto52(P)
		self:isEqual(t.id, "goto")
		self:isEqual(t.children[1].id, "goto")
		self:isEqual(t.children[2].id, "name")
		self:isEqual(t.children[2].text, "continue")
	end
end
)
--]===]


-- [8] namelist ::= Name {',' Name}
-- [16] parlist ::= namelist [',' '...'] | '...'
-- [===[
self:registerJob("sym.namelist() (and parlist)", function(self)

	do
		self:print(4, "[+] expected behavior")
		local P = _setup("foo", "5.1", false)

		local n = sym.namelist(P)

		self:isEqual(n.id, "namelist")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "foo")
	end


	do
		local P = _setup("foo, bar", "5.1", false)

		self:print(4, "[+] expected behavior")
		local n = sym.namelist(P)
		self:isEqual(n.id, "namelist")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "foo")

		self:isEqual(n.children[2].id, ",")
		self:isEqual(n.children[2].text, ",")
		self:isEqual(n.children[2].delim[1].id, "space")
		self:isEqual(n.children[2].delim[1].text, " ")

		self:isEqual(n.children[3].id, "name")
		self:isEqual(n.children[3].text, "bar")
	end


	do
		local P = _setup("a, b, ", "5.1", false)

		self:expectLuaError("trailing comma", sym.namelist, P)
	end


	do
		self:print(4, "[+] expected behavior")
		local P = _setup("...", "5.1", false)

		local n = sym.parlist(P)
		self:isEqual(n.id, "parlist")
		self:isEqual(n.children[1].id, "...")
	end


	do
		self:print(4, "[+] expected behavior")
		local P = _setup("a9, _, ...", "5.1", false)

		local n = sym.parlist(P)

		self:isEqual(n.id, "parlist")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "a9")
		self:isEqual(n.children[2].id, ",")
		self:isEqual(n.children[3].id, "name")
		self:isEqual(n.children[3].text, "_")
		self:isEqual(n.children[4].id, ",")
		self:isEqual(n.children[5].id, "...")
	end
end
)
--]===]


-- [5] funcname ::= Name {'.' Name} [':' Name]
-- [===[
self:registerJob("sym.funcname()", function(self)

	do
		self:print(4, "[+] minimal name")
		local P = _setup("n", "5.1", false)

		local n = sym.funcname(P)

		self:isEqual(n.id, "funcname")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "n")
	end


	do
		self:print(4, "[+] names separated by dots")
		local P = _setup("foo.bar.nilbog", "5.1", false)

		local n = sym.funcname(P)
		self:isEqual(n.id, "funcname")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "foo")
		self:isEqual(n.children[2].id, ".")
		self:isEqual(n.children[3].id, "name")
		self:isEqual(n.children[3].text, "bar")
		self:isEqual(n.children[4].id, ".")
		self:isEqual(n.children[5].id, "name")
		self:isEqual(n.children[5].text, "nilbog")
	end


	do
		self:print(4, "[+] names ending with ':name'")
		local P = _setup("foo.bar:bing", "5.1", false)

		local n = sym.funcname(P)
		self:isEqual(n.id, "funcname")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "foo")
		self:isEqual(n.children[2].id, ".")
		self:isEqual(n.children[3].id, "name")
		self:isEqual(n.children[3].text, "bar")
		self:isEqual(n.children[4].id, ":")
		self:isEqual(n.children[5].id, "name")
		self:isEqual(n.children[5].text, "bing")
	end
end)
--]===]


-- (5.4) [4] attnamelist ::=  Name attrib {',' Name attrib}
-- (5.4) [5] attrib ::= ['<' Name '>']
-- [===[
self:registerJob("(Lua 5.4) sym.attnamelist()", function(self)

	do
		self:print(4, "[+] minimal attnamelist")
		local P = _setup("n", "5.4", false)

		local n = sym.attnamelist(P)
		self:isEqual(n.id, "attnamelist")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "n")
	end


	do
		self:print(4, "[+] attnamelist without attributes")
		local P = _setup("foo, bar", "5.4", false)

		local n = sym.attnamelist(P)
		self:isEqual(n.id, "attnamelist")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "foo")
		self:isEqual(n.children[2].id, ",")
		self:isEqual(n.children[3].id, "name")
		self:isEqual(n.children[3].text, "bar")
	end


	do
		self:print(4, "[+] attnamelist expected behavior")
		local P = _setup("foo <const>, bar <close>", "5.4", false)

		local n = sym.attnamelist(P)
		self:isEqual(n.id, "attnamelist")
		self:isEqual(n.children[1].id, "name")
		self:isEqual(n.children[1].text, "foo")

		self:isEqual(n.children[1].children[1].id, "<")
		self:isEqual(n.children[1].children[2].id, "name")
		self:isEqual(n.children[1].children[2].text, "const")
		self:isEqual(n.children[1].children[3].id, ">")

		self:isEqual(n.children[2].id, ",")

		self:isEqual(n.children[3].id, "name")
		self:isEqual(n.children[3].text, "bar")

		self:isEqual(n.children[3].children[1].id, "<")
		self:isEqual(n.children[3].children[2].id, "name")
		self:isEqual(n.children[3].children[2].text, "close")
		self:isEqual(n.children[3].children[3].id, ">")
	end
end)
--]===]


-- [14] function ::= 'function' funcbody
-- [===[
self:registerJob("sym._function()", function(self)

	-- WIP
	do
		self:print(4, "minimal function definition")
		local P = _setup("function() end", "5.1", false)

		local n = sym._function(P)
		pretty.print(n)
		self:isEqual(n.id, "function")
	end


	do
		self:print(4, "function definition")
		local P = _setup("function(a, b, c) a, b, c = c, b, a return c, b, a end", "5.1", false)

		local n = sym._function(P)
		pretty.print(n)
		self:isEqual(n.id, "function")
	end


	do
		local P = _setup("function(a,) end", "5.1", false)

		self:expectLuaError("invalid parlist", sym._function, P)
	end


	do
		local P = _setup("function(a) return return end", "5.1", false)

		self:expectLuaError("multiple laststats", sym._function, P)
	end
end)
--]===]


-- [17] tableconstructor ::= '{' [fieldlist] '}'
-- [18] fieldlist ::= field {fieldsep field} [fieldsep]
-- [19] field ::= '[' exp ']' '=' exp | Name '=' exp | exp
-- [===[
self:registerJob("sym.tableconstructor()", function(self)

	do
		local P = _setup("{,}", "5.1", false)

		local n = self:expectLuaError("separator before field", sym.tableconstructor, P)
	end


	do
		self:print(4, "[+] minimal table constructor")
		local P = _setup("{}", "5.1", false)

		local n = sym.tableconstructor(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] nested constructors")
		local P = _setup("{{{}}}", "5.1", false)

		local n = sym.tableconstructor(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] table constructor array")
		local P = _setup("{a, b, c}", "5.1", false)

		local n = sym.tableconstructor(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] table constructor hash")
		local P = _setup("{a=1, b = 2; c=3}", "5.1", false)

		local n = sym.tableconstructor(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] math assignment")
		local P = _setup("{a=5/10}", "5.1", false)

		local n = sym.tableconstructor(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] bracketed expression")
		local P = _setup("{['a'] = 4}", "5.1", false)

		local n = sym.tableconstructor(P)
		pretty.print(n)
	end
end)
--]===]


-- [10] exp ::=  'nil' | 'false' | 'true' | Number | String | '...' | function |
--               prefixexp | tableconstructor | exp binop exp | unop exp
-- [===[
self:registerJob("sym.exp()", function(self)

	do
		self:print(4, "[+] nil")
		local P = _setup("nil", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "nil")
		self:isEqual(n.children[1].text, "nil")
	end


	do
		self:print(4, "[+] false")
		local P = _setup("false", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "boolean")
		self:isEqual(n.children[1].text, "false")
	end


	do
		self:print(4, "[+] true")
		local P = _setup("true", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "boolean")
		self:isEqual(n.children[1].text, "true")
	end


	do
		self:print(4, "[+] number")
		local P = _setup("1", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "number")
		self:isEqual(n.children[1].text, "1")
	end


	do
		self:print(4, "[+] string")
		local P = _setup("'foo'", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "string")
		self:isEqual(n.children[1].text, "foo")
		self:isEqual(n.children[1].quote, "'")
	end


	do
		self:print(4, "[+] varargs mark")
		local P = _setup("...", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "...")
	end


	do
		self:print(4, "[+] function")
		local P = _setup("function() end", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "function")
	end


	do
		self:print(4, "[+] minimal prefixexp")
		local P = _setup("f", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "prefixexp")
		self:isEqual(n.children[1].children[1].id, "name")
		self:isEqual(n.children[1].children[1].text, "f")
	end


	do
		self:print(4, "[+] names separated by dots")
		local P = _setup("foo.bar.baz", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "prefixexp")
		self:isEqual(n.children[1].children[1].id, "name")
		self:isEqual(n.children[1].children[1].text, "foo")

		self:isEqual(n.children[1].children[2].id, ".")

		self:isEqual(n.children[1].children[3].id, "name")
		self:isEqual(n.children[1].children[3].text, "bar")

		self:isEqual(n.children[1].children[4].id, ".")

		self:isEqual(n.children[1].children[5].id, "name")
		self:isEqual(n.children[1].children[5].text, "baz")
	end


	do
		self:print(4, "[+] name[exp]")
		local P = _setup("foo[bar]", "5.1", false)

		local n = sym.exp(P)
		self:isEqual(n.id, "exp")
		self:isEqual(n.children[1].id, "prefixexp")
		self:isEqual(n.children[1].children[1].id, "name")
		self:isEqual(n.children[1].children[1].text, "foo")

		self:isEqual(n.children[1].children[2].id, "[")

		self:isEqual(n.children[1].children[3].id, "exp")
		self:isEqual(n.children[1].children[3].children[1].id, "prefixexp")
		self:isEqual(n.children[1].children[3].children[1].children[1].id, "name")
		self:isEqual(n.children[1].children[3].children[1].children[1].text, "bar")

		self:isEqual(n.children[1].children[4].id, "]")
	end


	do
		self:print(4, "[+] (exp)")
		local P = _setup("(foo)", "5.1", false)

		local n = sym.exp(P)
		--pretty.print(n)

		self:isEqual(n.id, "exp")

		self:isEqual(n.children[1].id, "prefixexp")

		self:isEqual(n.children[1].children[1].id, "(")

		self:isEqual(n.children[1].children[2].id, "exp")

		self:isEqual(n.children[1].children[2].children[1].id, "prefixexp")

		self:isEqual(n.children[1].children[2].children[1].children[1].id, "name")
		self:isEqual(n.children[1].children[2].children[1].children[1].text, "foo")

		self:isEqual(n.children[1].children[3].id, ")")
	end


	do
		self:print(4, "[+] tableconstructor")
		local P = _setup("{'one', 'two', 'three'}", "5.1", false)

		local n = sym.exp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] exp binop exp")
		local P = _setup("1 + 2", "5.1", false)

		local n = sym.exp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] exp binop exp binop exp")
		local P = _setup("1 + 2 - 3", "5.1", false)

		local n = sym.exp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] exp binop exp (more)")
		local P = _setup("1 + (2 - 3) / foobar", "5.1", false)

		local n = sym.exp(P)
		pretty.print(n)
	end


	do
		self:print(4, "unop exp")
		local P = _setup("-1", "5.1", false)

		local n = sym.exp(P)
		pretty.print(n)
	end


	do
		self:print(4, "multiple unops")
		-- sym.unop() can't tell the difference between '-' (unary negative) and '--' (start of comment).
		local P = _setup("- - - -1", "5.1", false)

		local n = sym.exp(P)
		pretty.print(n)
	end
end)
--]===]


-- [4] laststat ::= 'return' [explist] | 'break'
-- [===[
self:registerJob("sym.laststat()", function(self)

	do
		local P = _setup("return a, ", "5.1", false)

		local n = self:expectLuaError("return with invalid explist", sym.laststat, P)
	end


	do
		local P = _setup("break", "5.1", false)

		local n = self:expectLuaReturn("break", sym.laststat, P)
		pretty.print(n)
		self:isEqual(n.id, "laststat")
		self:isEqual(n.children[1].id, "break")
	end


	do
		local P = _setup("return", "5.1", false)

		local n = self:expectLuaReturn("return (standalone)", sym.laststat, P)
		pretty.print(n)
		self:isEqual(n.id, "laststat")
		self:isEqual(n.children[1].id, "return")
	end


	do
		local P = _setup("return 1, 2, 3", "5.1", false)

		local n = self:expectLuaReturn("return explist", sym.laststat, P)
		pretty.print(n)
		self:isEqual(n.id, "laststat")
		self:isEqual(n.children[1].id, "return")
		self:isEqual(n.children[2].id, "explist")

		self:isEqual(n.children[2].children[1].id, "exp")
		self:isEqual(n.children[2].children[1].children[1].id, "number")
		self:isEqual(n.children[2].children[1].children[1].text, "1")

		self:isEqual(n.children[2].children[2].id, ",")

		self:isEqual(n.children[2].children[3].id, "exp")
		self:isEqual(n.children[2].children[3].children[1].id, "number")
		self:isEqual(n.children[2].children[3].children[1].text, "2")

		self:isEqual(n.children[2].children[4].id, ",")

		self:isEqual(n.children[2].children[5].id, "exp")
		self:isEqual(n.children[2].children[5].children[1].id, "number")
		self:isEqual(n.children[2].children[5].children[1].text, "3")
	end
end)
--]===]


-- [13] args ::=  '(' [explist] ')' | tableconstructor | String
-- [===[
self:registerJob("sym.args()", function(self)

	do
		local P = _setup("(a", "5.1", false)

		local n = self:expectLuaError("incomplete args", sym.args, P)
	end


	do
		local P = _setup("{", "5.1", false)

		local n = self:expectLuaError("incomplete tableconstructor", sym.args, P)
	end


	do
		local P = _setup("(a, )", "5.1", false)

		local n = self:expectLuaError("nothing following comma", sym.args, P)
	end


	do
		local P = _setup("()", "5.1", false)

		local n = self:expectLuaReturn("minimal args list", sym.args, P)
		pretty.print(n)
	end


	do
		local P = _setup("(1.1, 2.2, 3.3)", "5.1", false)

		local n = self:expectLuaReturn("expected behavior (explist)", sym.args, P)
		pretty.print(n)
	end


	do
		local P = _setup("{1.1, 2.2, 3.3;}", "5.1", false)

		local n = self:expectLuaReturn("expected behavior (tableconstructor)", sym.args, P)
		pretty.print(n)
	end


	do
		local P = _setup("'foobar'", "5.1", false)

		local n = self:expectLuaReturn("expected behavior (string)", sym.args, P)
		pretty.print(n)
	end
end)
--]===]



-- [15] funcbody ::= '(' [parlist] ')' block 'end'
-- [===[
self:registerJob("sym.funcbody()", function(self)

	do
		local P = _setup("(a return end", "5.1", false)

		local n = self:expectLuaError("incomplete parentheses", sym.funcbody, P)
	end


	do
		local P = _setup("(a) return", "5.1", false)

		local n = self:expectLuaError("missing closing 'end'", sym.funcbody, P)
	end


	do
		local P = _setup("(a / 5) return", "5.1", false)

		local n = self:expectLuaError("parlist does not hold expressions", sym.funcbody, P)
	end


	do
		local P = _setup("(1, 2) return", "5.1", false)

		local n = self:expectLuaError("parlist does not hold numbers", sym.funcbody, P)
	end


	do
		local P = _setup("('foo') return", "5.1", false)

		local n = self:expectLuaError("parlist does not hold plain strings", sym.funcbody, P)
	end


	do
		self:print(4, "[+] minimal funcbody")
		local P = _setup("()end", "5.1", false)

		local n = sym.funcbody(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] minimal funcbody")
		local P = _setup("(a, b, c) end", "5.1", false)

		local n = sym.funcbody(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] funcbody")
		local P = _setup("(a, b, c) a = b return c end", "5.1", false)

		local n = sym.funcbody(P)
		pretty.print(n)
	end
end)
--]===]


-- [12] functioncall ::=  prefixexp args | prefixexp ':' Name args
-- [===[
self:registerJob("sym.functioncall()", function(self)

	do
		local P = _setup("a(", "5.1", false)

		local n = self:expectLuaError("unclosed parentheses", sym.functioncall, P)
	end


	do
		local P = _setup("a(a, ,)", "5.1", false)

		local n = self:expectLuaError("missing argument between two commas", sym.functioncall, P)
	end


	do
		self:print(4, "[+] missing args; bail out of node construction")
		local P = _setup("a", "5.1", false)

		local n = sym.functioncall(P)
		self:isNil(n)
	end


	do
		self:print(4, "[+] minimal functioncall")
		local P = _setup("a()", "5.1", false)

		local n = sym.functioncall(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] functioncall")
		local P = _setup("a(a, b, c)", "5.1", false)

		local n = sym.functioncall(P)
		pretty.print(n)
	end
end)
--]===]


-- [11]* prefixexp ::= var | functioncall | '(' exp ')'
-- [===[
self:registerJob("sym.prefixexp()", function(self)

	do
		local P = _setup("(foo", "5.1", false)

		local n = self:expectLuaError("expression with unclosed parentheses", sym.prefixexp, P)
	end


	do
		local P = _setup("foo[bar", "5.1", false)

		local n = self:expectLuaError("expression with unclosed square brackets", sym.prefixexp, P)
	end


	do
		self:print(4, "[+] minimal prefixexp")
		local P = _setup("f", "5.1", false)

		local n = sym.prefixexp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] names separated by dots")
		local P = _setup("foo.bar.baz", "5.1", false)

		local n = sym.prefixexp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] name, expression in square brackets, dot name")
		local P = _setup("foo[bar]baz", "5.1", false)

		local n = sym.prefixexp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] with args")
		local P = _setup("foo(a, b)", "5.1", false)

		local n = sym.prefixexp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] with args (colon syntax); method chaining")
		local P = _setup("foo:bar(a, b):doop()", "5.1", false)

		local n = sym.prefixexp(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] Initial expression in parentheses, plus some whitespace and comments")
		local P = _setup("(foo--[[comment]]) : bar (   ) .\ta--[[]]", "5.1", false)

		local n = sym.prefixexp(P)
		pretty.print(n)
	end
end)
--]===]


-- [9] explist ::= {exp ','} exp
-- [===[
self:registerJob("sym.explist()", function(self)

	do
		local P = _setup("foo,", "5.1", false)

		local n = self:expectLuaError("missing final expression", sym.explist, P)
	end


	do
		self:print(4, "[+] minimal explist")
		local P = _setup("a", "5.1", false)

		local n = sym.explist(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] explist with simple expressions")
		local P = _setup("a, b, c", "5.1", false)

		local n = sym.explist(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] explist with more complex expressions")
		local P = _setup("a + 1, 'e', -(-b), #(c/0.1e7), ({x})", "5.1", false)

		local n = sym.explist(P)
		pretty.print(n)
	end
end)
--]===]


-- [7] var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name
-- [===[
self:registerJob("sym.var()", function(self)

	do
		local P = _setup("foo[bar", "5.1", false)

		local n = self:expectLuaError("unclosed square brackets", sym.var, P)
	end


	do
		local P = _setup("foo.", "5.1", false)

		local n = self:expectLuaError("no name following dot", sym.var, P)
	end


	do
		self:print(4, "[+] minimal var")
		local P = _setup("a", "5.1", false)

		local n = sym.var(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] var with square brackets")
		local P = _setup("foo[bar]", "5.1", false)

		local n = sym.var(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] var with dot")
		local P = _setup("foo.bar", "5.1", false)

		local n = sym.var(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] var with function call")
		local P = _setup("foo(bar, baz)[bop].zoop", "5.1", false)

		local n = sym.var(P)
		pretty.print(n)
	end
end)
--]===]


-- [6] varlist ::= var {',' var}
-- [===[
self:registerJob("sym.varlist()", function(self)

	do
		local P = _setup("foo, ", "5.1", false)

		local n = self:expectLuaError("missing var after comma", sym.varlist, P)
	end


	do
		self:print(4, "[+] minimal varlist")
		local P = _setup("a", "5.1", false)

		local n = sym.varlist(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] varlist with different var forms")
		local P = _setup("foo[bar], baz.bop, mes(jambes).jaunes", "5.1", false)

		local n = sym.varlist(P)
		pretty.print(n)
	end
end)
--]===]


--[[
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
--]]


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
-- [===[
self:registerJob("sym.stat()", function(self)

	-- [3.0] stat ::=  varlist '=' explist |
	do
		self:print(4, "[+] ambiguous name; not enough to differentiate between varlist and functioncall")
		local P = _setup("foo", "5.1", false)

		local n = sym.stat(P)
		self:isNil(n)
	end


	do
		local P = _setup("foo = ", "5.1", false)

		local n = self:expectLuaError("missing explist", sym.stat, P)
	end


	do
		self:print(4, "[+] minimal varlist = explist")
		local P = _setup("foo = bar", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] varlist = explist")
		local P = _setup("one, two = 3, 4", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] varlist = explist")
		local P = _setup("one, two(0).x = 3, 4", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.1] functioncall |
	do
		local P = _setup("func, tion()", "5.1", false)

		local n = self:expectLuaError("invalid syntax (mixed functioncall and varlist)", sym.stat, P)
	end


	do
		local P = _setup("func(", "5.1", false)

		local n = self:expectLuaError("functioncall: unclosed args", sym.stat, P)
	end


	do
		self:print(4, "minimal functioncall")
		local P = _setup("f()", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "functioncall with explist")
		local P = _setup("fn(a, b, (123))", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.2] 'do' block 'end' |
	do
		local P = _setup("do", "5.1", false)

		local n = self:expectLuaError("unclosed do statement", sym.stat, P)
	end


	do
		self:print(4, "minimal do statement")
		local P = _setup("do end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "do statement with variable assignment and optional semicolon")
		local P = _setup("do a = 1; end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.3] 'while' exp 'do' block 'end' |
	do
		local P = _setup("while", "5.1", false)

		local n = self:expectLuaError("unfinished while statement (1)", sym.stat, P)
	end


	do
		local P = _setup("while true", "5.1", false)

		local n = self:expectLuaError("unfinished while statement (2)", sym.stat, P)
	end


	do
		local P = _setup("while true do", "5.1", false)

		local n = self:expectLuaError("unfinished while statement (3)", sym.stat, P)
	end


	do
		self:print(4, "minimal while statement")
		local P = _setup("while a do end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.4] 'repeat' block 'until' exp |
	do
		local P = _setup("repeat", "5.1", false)

		local n = self:expectLuaError("unfinished repeat statement (1)", sym.stat, P)
	end


	do
		local P = _setup("repeat until", "5.1", false)

		local n = self:expectLuaError("unfinished repeat statement (2)", sym.stat, P)
	end


	do
		self:print(4, "minimal repeat statement")
		local P = _setup("repeat until false end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "repeat statement")
		local P = _setup("repeat a = b b = c c=d e=f; f=g until false end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.5] 'if' exp 'then' block {'elseif' exp 'then' block} ['else' block] 'end' |
	do
		local P = _setup("if", "5.1", false)

		local n = self:expectLuaError("unfinished 'if' (1)", sym.stat, P)
	end


	do
		local P = _setup("if true", "5.1", false)

		local n = self:expectLuaError("unfinished 'if' (2)", sym.stat, P)
	end


	do
		local P = _setup("if true then", "5.1", false)

		local n = self:expectLuaError("unfinished if statement (3)", sym.stat, P)
	end


	do
		self:print(4, "minimal if statement")
		local P = _setup("if a then end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.6] 'for' Name '=' exp ',' exp [',' exp] 'do' block 'end' |
	do
		local P = _setup("for", "5.1", false)

		local n = self:expectLuaError("unfinished for statement (1)", sym.stat, P)
	end


	do
		local P = _setup("for a", "5.1", false)

		local n = self:expectLuaError("unfinished for statement (2)", sym.stat, P)
	end


	do
		local P = _setup("for a = ", "5.1", false)

		local n = self:expectLuaError("unfinished for statement (3)", sym.stat, P)
	end


	do
		local P = _setup("for a = 1", "5.1", false)

		local n = self:expectLuaError("unfinished for statement (4)", sym.stat, P)
	end


	do
		local P = _setup("for a = 1, 2", "5.1", false)

		local n = self:expectLuaError("unfinished for statement (5)", sym.stat, P)
	end


	do
		local P = _setup("for a = 1, 2 do", "5.1", false)

		local n = self:expectLuaError("unfinished for statement (5)", sym.stat, P)
	end


	do
		self:print(4, "minimal numeric-for statement")
		local P = _setup("for a = 1, 2 do end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "numeric-for with all three conditional numbers and some block content")
		local P = _setup("for a = 10, 1, -1 do foo() bar() end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.7] 'for' namelist 'in' explist 'do' block 'end' |
	do
		local P = _setup("for foo in", "5.1", false)

		local n = self:expectLuaError("unfinished generic for statement (1)", sym.stat, P)
	end


	do
		local P = _setup("for foo in pairs(bar)", "5.1", false)

		local n = self:expectLuaError("unfinished generic for statement (2)", sym.stat, P)
	end


	do
		local P = _setup("for foo in pairs(bar) do", "5.1", false)

		local n = self:expectLuaError("unfinished generic for statement (3)", sym.stat, P)
	end


	do
		self:print(4, "minimal generic for")
		local P = _setup("for a in pairs(b) do end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "generic for with some block content")
		local P = _setup("for a, b, c, d, e, f in notARealGenerator(g, h, i, j, k) do x = y z = x end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.8] 'function' funcname funcbody |
	do
		local P = _setup("function", "5.1", false)

		local n = self:expectLuaError("unfinished named function declaration (1)", sym.stat, P)
	end


	do
		local P = _setup("function hat", "5.1", false)

		local n = self:expectLuaError("unfinished named function declaration (2)", sym.stat, P)
	end


	do
		local P = _setup("function hat(a", "5.1", false)

		local n = self:expectLuaError("unfinished named function declaration (3)", sym.stat, P)
	end


	do
		local P = _setup("function hat(a, b)", "5.1", false)

		local n = self:expectLuaError("unfinished named function declaration (4)", sym.stat, P)
	end


	do
		local P = _setup("function hat(a, b,)", "5.1", false)

		local n = self:expectLuaError("bad args for named function declaration", sym.stat, P)
	end


	do
		self:print(4, "[+] minimal named function declaration")
		local P = _setup("function a() end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] named function declaration with some args and block content")
		local P = _setup("function a(b, c) return c * b end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.9] 'local' 'function' Name funcbody |
	do
		local P = _setup("local function", "5.1", false)

		local n = self:expectLuaError("unfinished local function declaration (1)", sym.stat, P)
	end


	do
		local P = _setup("local function hat", "5.1", false)

		local n = self:expectLuaError("unfinished local function declaration (2)", sym.stat, P)
	end


	do
		local P = _setup("local function hat(a", "5.1", false)

		local n = self:expectLuaError("unfinished local function declaration (3)", sym.stat, P)
	end


	do
		local P = _setup("local function hat(a, b)", "5.1", false)

		local n = self:expectLuaError("unfinished local function declaration (4)", sym.stat, P)
	end


	do
		local P = _setup("local function hat(a, b,)", "5.1", false)

		local n = self:expectLuaError("bad args for local function declaration", sym.stat, P)
	end


	do
		self:print(4, "[+] minimal local function declaration")
		local P = _setup("local function a() end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] local function declaration with some args and block content")
		local P = _setup("local function a(b, c) return c * b end", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	-- [3.10] 'local' namelist ['=' explist]
	do
		local P = _setup("local", "5.1", false)

		local n = self:expectLuaError("unfinished local variable assignment", sym.stat, P)
	end


	do
		local P = _setup("local a = ", "5.1", false)

		local n = self:expectLuaError("unfinished local variable assignment (2)", sym.stat, P)
	end


	do
		local P = _setup("local true = 1", "5.1", false)

		local n = self:expectLuaError("local variables must be names", sym.stat, P)
	end


	do
		self:print(4, "[+] minimal local declaration")
		local P = _setup("local a", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] local declaration")
		local P = _setup("local a, b, c = 4, 5, 6", "5.1", false)

		local n = sym.stat(P)
		pretty.print(n)
	end


	do
		self:print(4, "[+] local variable identifiers must be names (not expressions)")
		local P = _setup("local a.b = 4", "5.1", false)

		local n = sym.stat(P)
		self:isNotEqual(P.i, #P.t + 1)
	end
end)
--]===]


-- [1] chunk ::= {stat [';']} [laststat [';']]
-- [2] block ::= chunk
-- [===[
self:registerJob("sym.block()", function(self)

	-- assuming no errors, sym.block() always returns a block table.
	do
		self:print(4, "[+] empty block")
		local P = _setup("", "5.1", false)

		local n = sym.block(P)
		pretty.print(n)
		self:isEqual(n.id, "block")

	end


	do
		self:print(4, "[+] block with a laststat")
		local P = _setup("return {foo, bar}", "5.1", false)

		local n = sym.block(P)
		pretty.print(n)
		self:isEqual(n.id, "block")
	end
end)
--]===]


-- function parse.newParser(W)
-- function parse.parse(str, lua_ver, jit)
-- [===[
self:registerJob("parse.newParser(), parse.parse()", function(self)

	-- [====[
	do
		self:expectLuaError("parse.newParser() arg 1 bad type", parse.newParser, false)
	end
	--]====]


	-- [====[
	do
		self:expectLuaError("parse.parse() arg 1 bad type", parse.parse, false, "5.1", true)
		self:expectLuaError("parse.parse() arg 2 bad type", parse.parse, "return 1", false, true)
		self:expectLuaError("parse.parse() arg 3 can only be true if arg 2 is '5.1'", parse.parse, "return 1", "5.4", true)
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] minimal parse job")
		local tree = parse.parse("", "5.1", false)

		pretty.print(tree)
		self:isEqual(tree.id, "root")
	end
	--]====]
end)
--]===]


self:runJobs()
