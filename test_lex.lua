-- LuaTree lexer tests.


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
local pretty = require(PATH .. "test_pretty")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local stringWalk = require(PATH .. "lib.string_walk")


local cli_verbosity
for i = 0, #arg do
	if arg[i] == "--verbosity" then
		cli_verbosity = tonumber(arg[i + 1])
		if not cli_verbosity then
			error("invalid verbosity value")
		end
	end
end


local self = errTest.new("Lexer tests", cli_verbosity)


-- [===[
self:registerJob("lex.name, lex.space", function(self)

	do
		self:print(4, "[+] lex.name shouldn't match reserved keywords.")
		local W = lex.newLexer("function", "5.1", false)
		local t = lex.name(W)
		self:isNil(t, nil)

		self:lf(3)
	end


	do
		self:print(4, "[+] lexing a simple name")
		local W = lex.newLexer("foo", "5.1", false)
		local t = lex.name(W)
		self:isType(t, "table")
		self:isEqual(t.id, "name")
		self:isEqual(t.text, "foo")

		self:lf(3)
	end


	-- Spaces and comments are automatically attached to nodes as delimiters.
	-- The root token catches opening delimiters before the first bit of real
	-- code.
	do
		self:print(4, "[+] lexing whitespace")
		local W = lex.newLexer(" \t\r\v\n", "5.1", false)
		local root = W.t[1]
		self:isType(root, "table")
		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "space")
		self:isEqual(root.delim[1].text, " \t\r\v\n")

		self:lf(3)
	end


	do
		self:print(4, "[+] lexing names separated by whitespace")
		local W = lex.newLexer(" foo\tbar ", "5.1", false)
		local root = W.t[1]
		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "space")
		self:isEqual(root.delim[1].text, " ")

		local t1 = lex.name(W)
		self:isEqual(t1.id, "name")
		self:isEqual(t1.text, "foo")
		self:isEqual(t1.delim[1].id, "space")
		self:isEqual(t1.delim[1].text, "\t")

		local t2 = lex.name(W)
		self:isEqual(t2.id, "name")
		self:isEqual(t2.text, "bar")
		self:isEqual(t2.delim[1].id, "space")
		self:isEqual(t2.delim[1].text, " ")

		self:lf(3)
	end


	do
		self:print(4, "[+] lexing LuaJIT Unicode names")
		local W = lex.newLexer("foöbaró ¡Æøſㇱㇹ㈅꠲꠹𐅀𐅁𐅅 \128\129\130\131\132", "5.1", true)
		local t1 = lex.name(W)
		self:isEqual(t1.id, "name")
		self:isEqual(t1.text, "foöbaró")

		local t2 = lex.name(W)
		self:isEqual(t2.id, "name")
		self:isEqual(t2.text, "¡Æøſㇱㇹ㈅꠲꠹𐅀𐅁𐅅")

		local t3 = lex.name(W)
		self:isEqual(t3.id, "name")
		self:isEqual(t3.text, "\128\129\130\131\132")

		self:lf(3)
	end
end
)
--]===]


-- [===[
self:registerJob("lex.symbol", function(self)

	do
		local W = lex.newLexer("-...+..#.", "5.1", false)
		local t

		t = lex.symbol(W)
		self:isEqual(t.id, "-")
		self:isEqual(t.text, "-")

		t = lex.symbol(W, "...")
		self:isEqual(t.id, "...")
		self:isEqual(t.text, "...")

		t = lex.symbol(W)
		self:isEqual(t.id, "+")
		self:isEqual(t.text, "+")

		t = lex.symbol(W)
		self:isEqual(t.id, "..")
		self:isEqual(t.text, "..")

		t = lex.symbol(W)
		self:isEqual(t.id, "#")
		self:isEqual(t.text, "#")

		t = lex.symbol(W)
		self:isEqual(t.id, ".")
		self:isEqual(t.text, ".")

		self:lf(3)
	end
end
)
--]===]


-- [===[
self:registerJob("lex.keyword", function(self)

	do
		self:print(4, "[+] Don't recognize parts of names as keywords")
		local W = lex.newLexer("notto", "5.1", false)
		local t = lex.symbol(W)
		self:isEqual(t, nil)

		self:lf(3)
	end


	do
		local W = lex.newLexer("do until not repeat end", "5.1", false)
		local t

		t = lex.keyword(W)
		self:isEqual(t.id, "do")
		self:isEqual(t.text, "do")

		t = lex.keyword(W)
		self:isEqual(t.id, "until")
		self:isEqual(t.text, "until")

		t = lex.keyword(W)
		self:isEqual(t.id, "not")
		self:isEqual(t.text, "not")

		t = lex.keyword(W)
		self:isEqual(t.id, "repeat")
		self:isEqual(t.text, "repeat")

		t = lex.keyword(W)
		self:isEqual(t.id, "end")
		self:isEqual(t.text, "end")

		self:lf(3)
	end
end
)
--]===]


-- [===[
self:registerJob("lex.string", function(self)

	do
		local W = lex.newLexer("\"foobar\"'foo'[[foo]][=====[foo]=====][=====[\nfoo\nbar]=====]'foo\\tbar'", "5.1", false)
		local t

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foobar")
		self:isEqual(t.quote, "\"")

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo")
		self:isEqual(t.quote, "'")

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo")
		self:isEqual(t.quote, 0)

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo")
		self:isEqual(t.quote, 5)

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo\nbar")
		self:isEqual(t.lf, "\n")
		self:isEqual(t.quote, 5)

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo\\tbar")
		self:isEqual(t.quote, "'")

		self:lf(3)
	end


	do
		local W = lex.newLexer([["\\"]], "5.1", false)
		local t

		t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "\\\\")
		self:isEqual(t.quote, "\"")

		self:lf(3)
	end


	-- In normal strings, lines ending with '\' are continued on the next line.
	do
		local ex_str = [=====[
'foo\
bar']=====]
		local W = lex.newLexer(ex_str, "5.1", false)
		local t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo\\\nbar")
		self:isEqual(t.quote, "'")

		self:lf(3)
	end


	-- Escaped quotes (')
	do
		local W = lex.newLexer([=====['foo\'bar']=====], "5.1", false)
		local t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo\\'bar")
		self:isEqual(t.quote, "'")

		self:lf(3)
	end


	-- Escaped quotes (")
	do
		local W = lex.newLexer([=====["foo\"bar"]=====], "5.1", false)
		local t = lex.string(W)
		self:isEqual(t.id, "string")
		self:isEqual(t.text, "foo\\\"bar")
		self:isEqual(t.quote, "\"")

		self:lf(3)
	end
end
)
--]===]


-- [===[
self:registerJob("lex.comment", function(self)

	do
		local W = lex.newLexer("--", "5.1", false)
		local root = W.t[1]
		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "comment")
		self:isEqual(root.delim[1].text, "")
		self:isEqual(root.delim[1].level, false)

		self:lf(3)
	end


	do
		local W = lex.newLexer("--foo", "5.1", false)
		local root = W.t[1]
		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "comment")
		self:isEqual(root.delim[1].text, "foo")
		self:isEqual(root.delim[1].level, false)

		self:lf(3)
	end


	do
		local W = lex.newLexer("--[=====[foo\nbar]=====]", "5.1", false)
		local root = W.t[1]
		self:isEqual(root.id, "root")
		self:isEqual(root.delim[1].id, "comment")
		self:isEqual(root.delim[1].text, "foo\nbar")
		self:isEqual(root.delim[1].level, 5)

		self:lf(3)
	end
end
)
--]===]


-- [===[
self:registerJob("lex.number", function(self)

	do
		local W
		W = lex.newLexer("0.0!", "5.1", false)
		self:expectLuaError("Malformed number 1", lex.number, W)

		W = lex.newLexer("0.0.0", "5.1", false)
		self:expectLuaError("Malformed number 2", lex.number, W)

		W = lex.newLexer("0.0e", "5.1", false)
		self:expectLuaError("Malformed number 3", lex.number, W)

		W = lex.newLexer("12ze", "5.1", false)
		self:expectLuaError("Malformed number 4", lex.number, W)

		self:lf(3)
	end


	do
		local W = lex.newLexer("1", "5.1", false)
		local t = lex.number(W)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "1")

		self:lf(3)
	end


	do
		local W = lex.newLexer("0.0--comment", "5.1", false)
		local t = lex.number(W)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "0.0")

		self:lf(3)
	end


	do
		local W = lex.newLexer("0.0 - comment", "5.1", false)
		local t = lex.number(W)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "0.0")

		self:lf(3)
	end


	do
		local W = lex.newLexer("0/0", "5.1", false)
		local t = lex.number(W)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "0")

		self:lf(3)
	end


	do
		local W = lex.newLexer("1e1", "5.1", false)
		local t = lex.number(W)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "1e1")

		self:lf(3)
	end


	do
		self:print(4, "[+] LuaJIT ULL integer")
		local W = lex.newLexer("1ULL", "5.1", true)
		local t = lex.number(W)
		self:isEqual(t.id, "number")
		self:isEqual(t.text, "1ULL")

		self:lf(3)
	end


	do
		self:print(4, "[+] One dot should not be recognized as a number")
		local W = lex.newLexer(".", "5.1", true)
		local t = lex.number(W)
		self:isEqual(t, nil)

		self:lf(3)
	end
end
)
--]===]


self:runJobs()
