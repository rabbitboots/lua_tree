-- LuaTree shared functions and data.


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


local shared = {}


shared.lang = {
	-- lua_shared.lua
	err_arg_bad_type = "argument #$1: bad type (expected [$2], got $3)",
}
local lang = shared.lang


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local interp = require(PATH .. "pile_interp")
local _argType = require(PATH .. "pile_arg_check").type
local _makeLUT = require(PATH .. "pile_table").makeLUT


-- NOTE: The lexer and parser having JIT assigned implies version 5.1.
shared.versions = _makeLUT({"5.1", "5.2", "5.3", "5.4"})


-- These keywords cannot be used as variable names.
local keywords = {}
shared.keywords = keywords

local keywords_hash = {}
shared.keywords_hash = keywords_hash

keywords["5.1"] = {
	"and", "break", "do", "elseif", "else", "end", "false", "for", "function", "if", "in",
	"local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
keywords_hash["5.1"] = _makeLUT(keywords["5.1"])

keywords["5.2"] = {
	"and", "break", "do", "elseif", "else", "end", "false", "for", "function", "goto", "if", "in",
	"local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
keywords_hash["5.2"] = _makeLUT(keywords["5.2"])

keywords["5.3"] = keywords["5.2"]
keywords_hash["5.3"] = keywords_hash["5.2"]

keywords["5.4"] = keywords["5.2"]
keywords_hash["5.4"] = keywords_hash["5.2"]


shared.binop = {}
local binop = shared.binop

binop["5.1"] = {
	"+", "-", "*", "/", "^", "%", "..",
	"<=", "<", ">=", ">", "==", "~=",
	"and", "or"
}

binop["5.2"] = binop["5.1"]

binop["5.3"] = {
	"+", "-", "*", "//", "/", "^", "%", "..", '&', "|",
	"<<", "<=", "<", ">>", ">=", ">", "==", "~=", "~",
	"and", "or"
}

binop["5.4"] = binop["5.3"]


shared.unop = {}
local unop = shared.unop


unop["5.1"] = {"-", "not", "#"}

unop["5.2"] = unop["5.1"]

unop["5.3"] = {"-", "not", "#", "~"}

unop["5.4"] = unop["5.3"]


return shared
