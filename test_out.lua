-- LuaTree output tests.
-- TODO: Coverage of every Lua feature.


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


local lOut = require(PATH .. "lua_out")
local parse = require(PATH .. "lua_parse")


local errTest = require(PATH .. "test.err_test.err_test")


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


local self = errTest.new("Output tests.")


local function _doIt(self, desc, lua_ver, jit, s)
	if type(desc) == "string" then
		self:print(4, desc)
	end

	print("----")
	print(s)
	print("----")
	local tree = parse.parse(s, lua_ver, jit)
	self:isEqual(tree.id, "root")
	local s2 = lOut.concat(tree)
	io.write("string equality check...")
	if s ~= s2 then
		error("output string is not equal to the input. Input:\n" .. s .. "\n\nOutput:\n" .. s2)
	end

	io.write(" good\n\n")
end


-- [===[
self:registerJob("output tests", function(self)

	_doIt(self, "[+] Minimal test", "5.1", false, [[
a = b]])


	_doIt(self, "[+] Multi-line test", "5.1", false, [[
local M = {}
local foo = require("bar")
local a, b, c = 1,2,3
a = b + (c*7      )

return M
]])


	_doIt(self, "[+] label, goto, optional separators", "5.2", false, [[
local M = {}; function foobar(a)
	::top::
	a = a - 1
	if a <= 0 then
		break
	else
		goto top
	end
end; return M
]])


	_doIt(self, "[+] every loop", "5.2", false, [[
for n = 1, 9 do
	print(n)
end

for n = 9, 1, -1 do
	print(n)
end

for k, v in pairs(foo) do
	print(v)
end

for i, v in ipairs(foo) do
	bar(i, v)
end

while true do
	os.exit()
end

local a = 1
repeat
	a = a + 1
until a >= 100
]])


	_doIt(self, "[+] loop nesting", "5.2", false, [[
for a = 1, 3 do
	for b = 6, 4, -1 do
		while g do
			repeat
				break
			until not z
			break
		end
		break
	end
	break
end
]])


	_doIt(self, "[+] comments", "5.2", false, [==============[
--https://gutenberg.org/ebooks/38067
--[[
87. To make a person's face appear luminous in the dark.—Prepare some phosphorized oil,
(as directed 27,) and rub it over the face. This oil, though it appears luminous in the
dark has not power to burn any thing, so that it may be rubbed on the face or hands
without danger; and the appearance thereby produced, is most hideously frightful. All
the parts of the face that have been rubbed, appear to be covered with a luminous bluish
flame, and the mouth and eyes appear as black spots.—The luminous appearance may also be
repeatedly heightened, by the friction of a handkerchief, being rubbed over the luminous
part.
--]]

--[=[
Multi-
line
comment
--]=]

-- NOTE: foo
-- TODO: bar
]==============])

end
)
--]===]


self:runJobs()
