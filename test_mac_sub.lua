-- LuaTree string substitution macro test.
-- TODO: This is extremely basic, just an example of how nodes can be manipulated.


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


local self = errTest.new("Parser early work")


local function _replaceLoop(self, tbl)
	-- TODO: should probably replace the node with one that is appropriate in context (ie a number node)
	if self.id == "name" and tbl[self.text] then
		self.text = tbl[self.text]
	end
	for i, child in ipairs(self.children) do
		_replaceLoop(child, tbl)
	end
end


-- [===[
self:registerJob("replace name text (GROUND -> 1, WATER -> 2)", function(self)

	do
		local s = _loadWrapper("test/files/mac_sub.lua")
		local root = parse.parse(s, "5.1", false)

		_replaceLoop(root, {GROUND="1", WATER="2"})

		print("\n\n")
		print("old:")
		print(s)
		print("new:")
		lOut.print(root)
	end
end
)
--]===]


self:runJobs()
