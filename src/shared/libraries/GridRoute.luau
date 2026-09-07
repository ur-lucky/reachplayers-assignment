--Imports
const MissionTypes = require("../types/Mission")
const SoftwareEngineerConfig = require("../constants/missions/SoftwareEngineer")
const TableUtil = require("./TableUtil")

--Types
type Direction = MissionTypes.Direction
type GridPosition = MissionTypes.GridPosition
type RouteBoard = MissionTypes.RouteBoard
type RouteEvaluation = MissionTypes.RouteEvaluation

--Declarations
const DirectionOffsets: { [Direction]: GridPosition } = {
	down = { row = 1, column = 0 },
	left = { row = 0, column = -1 },
	right = { row = 0, column = 1 },
	up = { row = -1, column = 0 },
}

--Private Methods
const function CellKey(row: number, column: number): string
	return `{row}:{column}`
end

const function BuildGuaranteedPath(
	size: number,
	startRow: number,
	goalRow: number,
	random: Random
): { [string]: boolean }
	const path = { [CellKey(startRow, 1)] = true }
	local row = startRow
	local column = 1

	while column < size or row ~= goalRow do
		const choices: { GridPosition } = {}
		if column < size then
			table.insert(choices, { row = row, column = column + 1 })
		end
		if row < goalRow then
			table.insert(choices, { row = row + 1, column = column })
		elseif row > goalRow then
			table.insert(choices, { row = row - 1, column = column })
		end

		const nextPosition = choices[random:NextInteger(1, #choices)]
		row = nextPosition.row
		column = nextPosition.column
		path[CellKey(row, column)] = true
	end

	return path
end

const function IsReachable(board: RouteBoard): boolean
	const queue: { GridPosition } = { board.start }
	const visited = { [CellKey(board.start.row, board.start.column)] = true }
	local queueIndex = 1

	while queueIndex <= #queue do
		const position = queue[queueIndex]
		queueIndex += 1
		if position.row == board.goal.row and position.column == board.goal.column then
			return true
		end

		for _, offset in DirectionOffsets do
			const row = position.row + offset.row
			const column = position.column + offset.column
			const key = CellKey(row, column)
			if
				row >= 1
				and row <= board.size
				and column >= 1
				and column <= board.size
				and not board.blocked[key]
				and not visited[key]
			then
				visited[key] = true
				table.insert(queue, { row = row, column = column })
			end
		end
	end

	return false
end

--Public Methods
const function GetDirectionOffset(direction: Direction): GridPosition
	return DirectionOffsets[direction]
end

const function IsDirection(value: unknown): boolean
	return type(value) == "string" and DirectionOffsets[value :: Direction] ~= nil
end

const function Generate(seed: number, round: number): RouteBoard
	const roundConfig = SoftwareEngineerConfig.rounds[round]
	assert(roundConfig, `Invalid software engineer round {round}`)

	const random = Random.new(seed)
	const size = roundConfig.size
	const startRow = random:NextInteger(1, size)
	const goalRow = random:NextInteger(1, size)
	const guaranteedPath = BuildGuaranteedPath(size, startRow, goalRow, random)
	const candidates: { GridPosition } = {}

	for row = 1, size do
		for column = 1, size do
			if not guaranteedPath[CellKey(row, column)] then
				table.insert(candidates, { row = row, column = column })
			end
		end
	end
	TableUtil.shuffle(candidates, random)

	const blocked: { [string]: boolean } = {}
	const obstacleCount = math.min(math.round(size * size * roundConfig.obstacleDensity), #candidates)
	for obstacleIndex = 1, obstacleCount do
		const position = candidates[obstacleIndex]
		blocked[CellKey(position.row, position.column)] = true
	end

	const board: RouteBoard = {
		size = size,
		start = { row = startRow, column = 1 },
		goal = { row = goalRow, column = size },
		blocked = blocked,
	}
	assert(IsReachable(board), "Generated route board is not solvable")
	return board
end

const function Evaluate(board: RouteBoard, commands: { Direction }): RouteEvaluation
	local row = board.start.row
	local column = board.start.column

	for commandIndex, command in commands do
		const offset = DirectionOffsets[command]
		const nextRow = row + offset.row
		const nextColumn = column + offset.column
		if nextRow < 1 or nextRow > board.size or nextColumn < 1 or nextColumn > board.size then
			return {
				completedSteps = commandIndex - 1,
				reachedGoal = false,
				failureReason = "out_of_bounds",
			}
		end
		if board.blocked[CellKey(nextRow, nextColumn)] then
			return {
				completedSteps = commandIndex - 1,
				reachedGoal = false,
				failureReason = "blocked",
			}
		end

		row = nextRow
		column = nextColumn
		if row == board.goal.row and column == board.goal.column then
			return { completedSteps = commandIndex, reachedGoal = true }
		end
	end

	return {
		completedSteps = #commands,
		reachedGoal = false,
		failureReason = "incomplete",
	}
end

return {
	cellKey = CellKey,
	evaluate = Evaluate,
	generate = Generate,
	getDirectionOffset = GetDirectionOffset,
	isDirection = IsDirection,
}
