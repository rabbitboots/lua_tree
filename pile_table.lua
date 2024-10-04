-- PILE Table Helpers v1.1.0 (modified)
-- (C) 2024 PILE Contributors
-- License: MIT or MIT-0
-- https://github.com/rabbitboots/pile_base


local M = {}


M.lang = {
	err_dupe = "duplicate values in source table"
}
local lang = M.lang


local ipairs = ipairs


function M.makeLUT(t)
	local lut = {}
	for i, v in ipairs(t) do
		lut[v] = true
	end
	return lut
end


return M
