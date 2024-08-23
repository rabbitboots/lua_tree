**NOTE:** This is a beta.

# LuaTree

An unfinished Lua source parser. Currently targets PUC-Lua 5.1 and LuaJIT 2.1.3.

PUC-Lua 5.2, 5.3 and 5.4 are planned, and a small amount of work has been done, but they have not been tested at all.

See the test files for some examples.


# lua_parse API

## parse.parse

Parses a Lua source string, converting it to a tree of nodes.

`local root = parse.parse(str, lua_ver, jit)`

* `str`: The input string.

* `lua_ver`: The Lua version, in string form: `5.1`, `5.2`, `5.3` or `5.4`. The version affects lexing and parsing.

* `jit`: `true` to treat `5.1` strings as LuaJIT code, `false` otherwise. (When enabled, `lua_ver` *must* be `5.1`.)

**Returns:** A tree of nodes based on the source input.


## parse.parseFile

A wrapper for `parse.parse()` that loads a file from disk.

`local root = parse.parseFile(path, lua_ver, jit)`

* `path`: File path of the input source code.

* `lua_ver`: The Lua version, in string form: `5.1`, `5.2`, `5.3` or `5.4`. The version affects lexing and parsing.

* `jit`: `true` to treat `5.1` strings as LuaJIT code, `false` otherwise. (When enabled, `lua_ver` *must* be `5.1`.)

**Returns:** A tree of nodes based on the source input.

**Notes:** This is provided for convenience when working from the command line. When working from a host application that has its own way of loading files as strings (like in LÖVE's `love.filesystem`), use those functions instead.


# lua_lex API

**TODO**


# lua_out API

**TODO!**


# Notes

## Character Classes

* In Lua, string character classes are determined by the current locale. This affects which characters are designated as alphanumeric, as whitespace, etc.


## Differences from the eBNF

[Section 8](https://www.lua.org/manual/5.1/manual.html#8) of the Lua Reference Manual provides the language syntax in eBNF form. (There are slight differences in 5.2, 5.3 and 5.4.) LuaTree mostly follows the grammar productions, with the following exceptions.

### chunk

**chunk** is merged with **block**.


### var, prefixexp, functioncall

**var**, **prefixexp** and **functioncall** are constructed using the same internal function. The reason is that **var** and **prefixexp** include each other in their productions.

The internal function that handles **var**, **prefixexp** and **functioncall** assembles nodes from the following token layout:

`(Name | '(' exp ')') ('.' Name | '[' exp ']' | ':' Name args | args)*`

The resulting node is a function if its last child is **args**.


# References

* Lua Reference Manuals: [5.1](https://www.lua.org/manual/5.1/manual.html), [5.2](https://www.lua.org/manual/5.2/manual.html), [5.3](https://www.lua.org/manual/5.3/manual.html), [5.4](https://www.lua.org/manual/5.4/manual.html)

* [LuaJIT extensions](http://luajit.org/extensions.html)

* Libraries referenced and examined while developing LuaTree:

  * [ReFreezed/DumbLuaParser](https://github.com/ReFreezed/DumbLuaParser)

  * [stravant/LuaMinify](https://github.com/stravant/LuaMinify)

  * [2dengine/sstrict.lua](https://github.com/2dengine/sstrict.lua). (See also the linked [LÖVE forum thread](https://love2d.org/forums/viewtopic.php?f=5&t=90074) for many tips on parsing Lua source code.)

  * [fab13n/metalua](https://github.com/fab13n/metalua)


# License (MIT)

```
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
```
