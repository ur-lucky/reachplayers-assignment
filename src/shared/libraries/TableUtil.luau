--Public Methods
const function Shuffle<T>(values: { T }, random: Random)
	for index = #values, 2, -1 do
		const swapIndex = random:NextInteger(1, index)
		values[index], values[swapIndex] = values[swapIndex], values[index]
	end
end

const function Shuffled<T>(values: { T }, random: Random): { T }
	const result = table.clone(values)
	Shuffle(result, random)
	return result
end

return {
	shuffle = Shuffle,
	shuffled = Shuffled,
}
