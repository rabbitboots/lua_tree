-- PILE lut v1.0.0 (modified)
-- (C) 2024 PILE Contributors
-- License: MIT
-- https://github.com/rabbitboots/pile_base


local lut = {}


local ipairs, pairs = ipairs, pairs


lut.lang = {
	err_dupe = "duplicate values in source table"
}
local lang = lut.lang


function lut.make(t)
	local lut = {}
	for i, v in ipairs(t) do
		lut[v] = true
	end
	return lut
end


return lut
