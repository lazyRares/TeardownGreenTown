function tick()
	if InputPressed("w") or InputPressed("a") or InputPressed("s") or InputPressed("d") then
		SetInt("level.cleared",2)
	end
end