--Imports
const NpcConstants = require("../constants/npc")

--Types
export type Androgyny = "Masculine" | "Feminine"

export type Outfit = {
	Androgyny: Androgyny,
	hair: (number | boolean)?,
	bodyColor: (Color3 | { number } | boolean)?,
	classic_shirt: (number | boolean)?,
	classic_pants: (number | boolean)?,
	accessories: { number }?,
}

export type Pools<T> = {
	FEMININE: { T }?,
	MASCULINE: { T }?,
	UNISEX: { T }?,
}

--Declarations
const RandomGenerator = Random.new()

--Private Methods
const function GetRandomValue<T>(pools: Pools<T>, androgyny: Androgyny): T
	const androgynyPool = if androgyny == "Masculine" then pools.MASCULINE or {} else pools.FEMININE or {}
	const unisexPool = pools.UNISEX or {}
	const optionCount = #androgynyPool + #unisexPool
	assert(optionCount > 0, "NPC appearance pool cannot be empty")

	const selectedIndex = RandomGenerator:NextInteger(1, optionCount)
	if selectedIndex <= #androgynyPool then
		return androgynyPool[selectedIndex]
	end
	return unisexPool[selectedIndex - #androgynyPool]
end

--Public Methods
const function Randomize(npc: Model, outfit: Outfit?): boolean
	const humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	const descriptionTemplate = npc:FindFirstChildWhichIsA("HumanoidDescription", true)
	local description: HumanoidDescription
	if descriptionTemplate then
		description = descriptionTemplate:Clone()
	else
		const succeeded, appliedDescription = pcall(humanoid.GetAppliedDescription, humanoid)
		if not succeeded then
			return false
		end
		description = appliedDescription
	end

	const outfitOptions = outfit
		or {
			Androgyny = if RandomGenerator:NextInteger(1, 2) == 1 then "Masculine" else "Feminine",
		}
	if outfitOptions.hair ~= false then
		for _, child in description:GetChildren() do
			if child:IsA("AccessoryDescription") and child.AccessoryType == Enum.AccessoryType.Hair then
				child:Destroy()
			end
		end
		description.HairAccessory = tostring(
			if type(outfitOptions.hair) == "number"
				then outfitOptions.hair
				else GetRandomValue(NpcConstants.HAIRS, outfitOptions.Androgyny)
		)
	end
	if outfitOptions.classic_shirt ~= false then
		description.Shirt = if type(outfitOptions.classic_shirt) == "number"
			then outfitOptions.classic_shirt
			else GetRandomValue(NpcConstants.CLASSIC_SHIRTS, outfitOptions.Androgyny)
	end
	if outfitOptions.classic_pants ~= false then
		description.Pants = if type(outfitOptions.classic_pants) == "number"
			then outfitOptions.classic_pants
			else GetRandomValue(NpcConstants.CLASSIC_PANTS, outfitOptions.Androgyny)
	end
	if outfitOptions.bodyColor ~= false then
		const bodyColor = if typeof(outfitOptions.bodyColor) == "Color3"
			then outfitOptions.bodyColor
			else GetRandomValue(NpcConstants.BODY_COLORS, outfitOptions.Androgyny)
		const color = if typeof(bodyColor) == "Color3"
			then bodyColor
			else Color3.fromRGB(bodyColor[1], bodyColor[2], bodyColor[3])
		description.HeadColor = color
		description.LeftArmColor = color
		description.RightArmColor = color
		description.LeftLegColor = color
		description.RightLegColor = color
		description.TorsoColor = color
	end
	if outfitOptions.accessories then
		description.HatAccessory = table.concat(outfitOptions.accessories, ",")
	end

	const succeeded =
		pcall(humanoid.ApplyDescriptionResetAsync, humanoid, description, Enum.AssetTypeVerification.Always)
	description:Destroy()
	return succeeded
end

return {
	randomize = Randomize,
}
