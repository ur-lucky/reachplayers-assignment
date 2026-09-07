--Public Methods
const function PivotCharacter(player: Player, target: unknown): boolean
	if typeof(target) ~= "CFrame" then
		return false
	end
	const character = player.Character
	if not character or not character.Parent then
		return false
	end
	character:PivotTo(target)
	return true
end

return PivotCharacter
