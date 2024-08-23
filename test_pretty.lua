-- This is not a test, but rather a pretty-printer for other test files.


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


local pretty = {}


local function _indent(_d)
	io.write(string.rep("  ", _d))
end


local function _commentQuote(temp, level, open)
	if type(level) == "number" then
		local qq = open and "[" or "]"
		table.insert(temp, qq)
		table.insert(temp, string.rep("=", level))
		table.insert(temp, qq)

	elseif level ~= false then
		print("level |" .. tostring(level) .. "|")
		error("invalid comment state.")
	end
end


local function _concatDelims(delims)
	if delims then
		local temp = {}
		for i, t in ipairs(delims) do
			if t.id == "comment" then
				table.insert(temp, "--")
				_commentQuote(temp, t.level, true)
			end
			if t.text and #t.text > 0 then
				table.insert(temp, t.text)
			end
			if t.id == "comment" then
				_commentQuote(temp, t.level, false)
			end
		end
		if #temp > 0 then
			return table.concat(temp)
		end
	end
end


function pretty.print(n, _d)
	if type(n) ~= "table" then error("expected table, got " .. type(n)) end

	_d = _d or 0
	_indent(_d); io.write("• " .. n.id)
	if n.text then
		io.write(" ¨" .. n.text .. "¨")
	end
	local str_delim = _concatDelims(n.delim)
	if str_delim then
		io.write(" |" .. str_delim .. "|")
	end
	io.write("\n")
	if n.children and #n.children > 0 then
		for i, c in ipairs(n.children) do
			pretty.print(c, _d + 1)
		end
	end
end


function pretty.tokens(toks)
	if type(toks) ~= "table" then error("expected table, got " .. type(toks)) end

	for i, t in ipairs(toks) do
		io.write(i .. "/" .. #toks .. "\t" .. t.id .. " ¨" ..  t.text .. "¨")
		local str_delim = _concatDelims(t.delim)
		if str_delim then
			io.write(" |" .. str_delim .. "|")
		end
		io.write("\n")
	end
end


return pretty
