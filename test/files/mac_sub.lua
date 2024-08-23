function groundState(player)
	if player:touching(GROUND) then
		return "grounded"
	elseif player:touching(WATER) then
		return "swimming"
	end
end
