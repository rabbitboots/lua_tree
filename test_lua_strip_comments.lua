-- Comment stripping test.


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
local lOut = require(PATH .. "lua_out")
local parse = require(PATH .. "lua_parse")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local stringWalk = require(PATH .. "string_walk")


local hex = string.char


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


local self = errTest.new("Parser early work", cli_verbosity)


local function _commentLoop(parent)
	local did_delete
	for j = #parent.delim, 1, -1 do
		local delim = parent.delim[j]
		if delim.id == "comment" then
			if not delim.text:find("SPDX-License-Identifier:", 1, true) then
				print("DELETING: " .. lOut.concat(delim))
				table.remove(parent.delim, j)
				did_delete = true
			end
		end
	end
	if did_delete and #parent.delim == 0 then
		table.insert(parent.delim, {id="space", text=" "})
	end
	for i, node in ipairs(parent.children) do
		_commentLoop(node)
	end
end


-- [===[
self:registerJob("remove comments from lua_parse.lua", function(self)

	do
		local s = _loadWrapper("lua_parse.lua")
		local root = parse.parse(s, "5.1", false)

		_commentLoop(root)

		print("\n\n")

		lOut.print(root)
	end
end
)
--]===]


self:runJobs()
