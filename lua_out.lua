-- LuaTree output: gets the contents of a node tree as a string.


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


local lOut = {}


local inspect = require(PATH .. "test.inspect")
local shared = require(PATH .. "lua_shared")


local _argType = shared._argType


local function _stringQuote(tmp, quote, open)
	if quote == "'" or quote == "\"" then
		table.insert(tmp, quote)

	elseif type(quote) == "number" then
		local qq = open and "[" or "]"
		table.insert(tmp, qq)
		table.insert(tmp, string.rep("=", quote))
		table.insert(tmp, qq)

	else
		error("string node: invalid quote state.")
	end
end


local function _commentQuote(tmp, level, open)
	if type(level) == "number" then
		local qq = open and "[" or "]"
		table.insert(tmp, qq)
		table.insert(tmp, string.rep("=", level))
		table.insert(tmp, qq)

	elseif level ~= false then
		error("node comment: invalid quote state.")
	end
end


local function _insert(node, tmp)
	if node.id == "comment" then
		table.insert(tmp, "--")
		_commentQuote(tmp, node.level, true)

	elseif node.id == "string" then
		_stringQuote(tmp, node.quote, true)
		if node.lf then
			table.insert(tmp, node.lf)
		end
	end

	if node.text and node.text ~= "" then
		table.insert(tmp, node.text)
	end

	if node.id == "comment" then
		_commentQuote(tmp, node.level, false)

	elseif node.id == "string" then
		_stringQuote(tmp, node.quote, false)
	end
end


local function _combine(tree, tmp)
	_insert(tree, tmp)
	if tree.delim then
		for i, delim in ipairs(tree.delim) do
			_insert(delim, tmp)
		end
	end
	if tree.children then
		for i, child in ipairs(tree.children) do
			_combine(child, tmp)
		end
	end
end


function lOut.concat(tree)
	_argType(1, tree, "table")

	local tmp = {}
	_combine(tree, tmp)
	return table.concat(tmp)
end


function lOut.print(tree)
	_argType(1, tree, "table")

	local tmp = {}
	_combine(tree, tmp)
	print(table.concat(tmp))
end


return lOut
