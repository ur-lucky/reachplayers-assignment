--Services
const Players = game:GetService("Players")

--Imports
const CampaignConfig = require("../../shared/constants/campaign")
const DialogueController = require("../controllers/DialogueController")
const GridRoute = require("../../shared/libraries/GridRoute")
const IsGuid = require("../../shared/utils/funcs/isGuid")
const Janitor = require("../../shared/Packages/Janitor")
const MissionTypes = require("../../shared/types/Mission")
const Network = require("../../shared/network")
const PivotCharacter = require("../../shared/utils/funcs/pivotCharacter")
const SoftwareEngineerConfig = require("../../shared/constants/missions/SoftwareEngineer")
const TaggedInstance = require("../../shared/libraries/TaggedInstance")
const Tags = require("../../shared/constants/tags")

--Types
type Direction = MissionTypes.Direction
type GridPosition = MissionTypes.GridPosition
type JanitorObject = typeof(Janitor.new())
type Response = MissionTypes.Response
type RouteBoard = MissionTypes.RouteBoard
type SoftwareEngineerStartPayload = MissionTypes.SoftwareEngineerStartPayload

type MissionState = {
	active: boolean,
	board: RouteBoard?,
	busy: boolean,
	cells: { [string]: TextLabel },
	commands: { Direction },
	exiting: boolean,
	generation: number,
	gui: ScreenGui,
	janitor: JanitorObject,
	office: Model,
	requestGeneration: number,
	requestJanitor: JanitorObject,
	returnCFrame: CFrame,
	round: number,
	runner: GridPosition?,
	seeds: { number }?,
	sessionGuid: string,
	totalRounds: number,
}

type Request = () -> Network.ResponsePromise

--Declarations
const Assets = script.Parent.Parent.Parent.assets
const ControllerJanitor = Janitor.new()
const DirectionGlyphs: { [Direction]: string } = {
	down = "↓",
	left = "←",
	right = "→",
	up = "↑",
}
const StartJanitor = Janitor.new()

local ActiveMission: MissionState? = nil
local BeginSeedRequest: (MissionState) -> ()
local Generation = 0

--Private Methods
const function Invoke(
	state: MissionState,
	request: Request,
	requestGeneration: number,
	handler: (boolean, unknown) -> ()
)
	const requestPromise = request()
	state.requestJanitor:Add(function()
		requestPromise:cancel()
	end, true, "Request")
	const timeoutThread = task.delay(8, function()
		if state.active and state.requestGeneration == requestGeneration then
			state.requestGeneration += 1
			requestPromise:cancel()
			handler(false, nil)
		end
	end)
	state.requestJanitor:Add(function()
		if coroutine.status(timeoutThread) ~= "dead" then
			task.cancel(timeoutThread)
		end
	end, true, "Timeout")
	requestPromise:andThen(function(result: unknown)
		if state.active and state.requestGeneration == requestGeneration then
			state.requestGeneration += 1
			handler(true, result)
		end
	end, function()
		if state.active and state.requestGeneration == requestGeneration then
			state.requestGeneration += 1
			handler(false, nil)
		end
	end)
end

const function SetButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.45
end

const function SetControlsEnabled(state: MissionState, enabled: boolean)
	const side = state.gui.Backdrop.Panel.Side
	for _, button in
		{
			side.Controls.Up,
			side.Controls.Down,
			side.Controls.Left,
			side.Controls.Right,
			side.Undo,
			side.Reset,
		}
	do
		SetButtonEnabled(button, enabled)
	end
	SetButtonEnabled(side.Go, enabled and #state.commands > 0)
end

const function UpdateCommandQueue(state: MissionState)
	const glyphs: { string } = {}
	for _, command in state.commands do
		table.insert(glyphs, DirectionGlyphs[command])
	end
	const queue = state.gui.Backdrop.Panel.Side.CommandQueue
	queue.Text = if #glyphs > 0 then table.concat(glyphs, " ") else "No commands"
	queue.TextColor3 = if #glyphs > 0 then Color3.fromRGB(245, 247, 255) else Color3.fromRGB(151, 163, 184)
	if not state.busy and state.board then
		SetControlsEnabled(state, true)
	end
end

const function PaintCell(state: MissionState, row: number, column: number, runner: boolean)
	const board = state.board
	const cell = state.cells[GridRoute.cellKey(row, column)]
	if not board or not cell then
		return
	end

	if runner then
		cell.BackgroundColor3 = Color3.fromRGB(81, 157, 255)
		cell.Text = "●"
		cell.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif row == board.start.row and column == board.start.column then
		cell.BackgroundColor3 = Color3.fromRGB(67, 187, 132)
		cell.Text = "S"
		cell.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif row == board.goal.row and column == board.goal.column then
		cell.BackgroundColor3 = Color3.fromRGB(184, 41, 41)
		cell.Text = "E"
		cell.TextColor3 = Color3.fromRGB(34, 44, 67)
	elseif board.blocked[GridRoute.cellKey(row, column)] then
		cell.BackgroundColor3 = Color3.fromRGB(17, 23, 38)
		cell.Text = ""
	else
		cell.BackgroundColor3 = Color3.fromRGB(72, 86, 116)
		cell.Text = ""
	end
end

const function SetRunner(state: MissionState, position: GridPosition)
	const previous = state.runner
	if previous then
		PaintCell(state, previous.row, previous.column, false)
	end
	state.runner = { row = position.row, column = position.column }
	PaintCell(state, position.row, position.column, true)
end

const function RenderBoard(state: MissionState, board: RouteBoard)
	state.board = board
	state.runner = nil
	table.clear(state.cells)
	const grid = state.gui.Backdrop.Panel.BoardHolder.Grid
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	const layout = grid.Layout
	layout.FillDirectionMaxCells = board.size
	layout.CellSize = UDim2.new(1 / board.size, -4, 1 / board.size, -4)
	for row = 1, board.size do
		for column = 1, board.size do
			const key = GridRoute.cellKey(row, column)
			const cell = Instance.new("TextLabel")
			cell.Name = key
			cell.BackgroundColor3 = Color3.fromRGB(72, 86, 116)
			cell.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Bold)
			cell.LayoutOrder = (row - 1) * board.size + column
			cell.Text = ""
			cell.TextColor3 = Color3.fromRGB(255, 255, 255)
			cell.TextScaled = true
			cell.Parent = grid
			const corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = cell
			state.cells[key] = cell
			PaintCell(state, row, column, false)
		end
	end
	SetRunner(state, board.start)
end

const function ResetRoute(state: MissionState)
	table.clear(state.commands)
	UpdateCommandQueue(state)
	const board = state.board
	if board then
		SetRunner(state, board.start)
	end
end

const function ValidateSeeds(value: unknown): { number }?
	if type(value) ~= "table" or #value ~= #SoftwareEngineerConfig.rounds then
		return nil
	end

	const source = value :: { unknown }
	const seeds: { number } = {}
	for seedIndex = 1, #SoftwareEngineerConfig.rounds do
		const seed = source[seedIndex]
		if type(seed) ~= "number" or seed % 1 ~= 0 or seed < 1 or seed > 2 ^ 30 then
			return nil
		end
		table.insert(seeds, seed)
	end
	return seeds
end

const function ShowSeedError(state: MissionState)
	state.busy = false
	state.gui.Backdrop.Panel.BoardHolder.LoadingOverlay.Visible = false
	state.gui.Backdrop.Panel.Status.Text = "The puzzle seeds could not be loaded."
	state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(239, 128, 128)
	state.gui.Backdrop.Panel.Side.Retry.Visible = true
	SetControlsEnabled(state, false)
end

const function StartLoadingBoards(state: MissionState, requestGeneration: number)
	const loadingRandom = Random.new()
	const loadingThread = task.spawn(function()
		while state.active and state.requestGeneration == requestGeneration do
			RenderBoard(state, GridRoute.generate(loadingRandom:NextInteger(1, 2 ^ 30), 1))
			task.wait(0.12)
		end
	end)
	state.requestJanitor:Add(function()
		if coroutine.status(loadingThread) ~= "dead" then
			task.cancel(loadingThread)
		end
	end, true, "Loading")
end

BeginSeedRequest = function(state: MissionState)
	state.requestJanitor:Cleanup()
	state.requestGeneration += 1
	const requestGeneration = state.requestGeneration
	state.busy = true
	state.gui.Backdrop.Visible = true
	state.gui.Backdrop.Panel.BoardHolder.LoadingOverlay.BackgroundTransparency = 0.62
	state.gui.Backdrop.Panel.BoardHolder.LoadingOverlay.Visible = true
	state.gui.Backdrop.Panel.Side.Retry.Visible = false
	state.gui.Backdrop.Panel.Status.Text = "Generating routes..."
	state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(151, 163, 184)
	SetControlsEnabled(state, false)
	StartLoadingBoards(state, requestGeneration)

	Invoke(
		state,
		function()
			return Network.SoftwareEngineerSeedsRequest:request(state.sessionGuid)
		end,
		requestGeneration,
		function(succeeded: boolean, rawResult: unknown)
			if not succeeded or type(rawResult) ~= "table" then
				ShowSeedError(state)
				return
			end
			const response = rawResult :: Response
			const seeds = if response.ok then ValidateSeeds(response.seeds) else nil
			if not seeds then
				ShowSeedError(state)
				return
			end

			state.seeds = seeds
			state.busy = false
			state.gui.Backdrop.Panel.BoardHolder.LoadingOverlay.Visible = false
			state.gui.Backdrop.Panel.Status.Text = "Build a route, then press Go."
			state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(151, 163, 184)
			state.gui.Backdrop.Panel.Round.Text = string.format("Puzzle %d/%d", state.round, state.totalRounds)
			state.gui.MissionBar.Progress.Text =
				string.format("Puzzles solved: %d/%d", state.round - 1, state.totalRounds)
			RenderBoard(state, GridRoute.generate(seeds[state.round], state.round))
			ResetRoute(state)
			Network.SoftwareEngineerBoardShown:fire(state.sessionGuid, state.round)
		end
	)
end

const function FailureMessage(reason: MissionTypes.RouteFailureReason?): string
	if reason == "blocked" then
		return "Route hit a blocked cell. Try again."
	elseif reason == "out_of_bounds" then
		return "Route left the board. Try again."
	end
	return "Route did not reach the end. Try again."
end

const function DestroyMission(state: MissionState)
	if ActiveMission == state then
		PivotCharacter(Players.LocalPlayer, state.returnCFrame)
		ActiveMission = nil
	end
	state.janitor:Destroy()
	table.clear(state.cells)
	table.clear(state.commands)
end

const function Stop(notifyServer: boolean)
	Generation += 1
	StartJanitor:Cleanup()
	const state = ActiveMission
	if not state then
		return
	end
	if notifyServer then
		if state.exiting then
			return
		end
		state.exiting = true
		state.active = false
		state.requestGeneration += 1
		SetControlsEnabled(state, false)
		const sessionGuid = state.sessionGuid
		DestroyMission(state)
		Network.SoftwareEngineerAbandon:request(sessionGuid):andThen(function() end, function() end)
		return
	end

	state.active = false
	state.requestGeneration += 1
	DestroyMission(state)
end

const function AnimateAttempt(state: MissionState, commands: { Direction }, completedSteps: number)
	const board = state.board
	if not board then
		return
	end

	local position: GridPosition = { row = board.start.row, column = board.start.column }
	SetRunner(state, position)
	for commandIndex = 1, completedSteps do
		const offset = GridRoute.getDirectionOffset(commands[commandIndex])
		position = {
			row = position.row + offset.row,
			column = position.column + offset.column,
		}
		SetRunner(state, position)
		task.wait(0.15)
	end
end

const function ShowAttemptError(state: MissionState, message: string)
	state.busy = false
	state.gui.Backdrop.Panel.Status.Text = message
	state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(239, 128, 128)
	UpdateCommandQueue(state)
end

const function HandleAttemptResponse(state: MissionState, commands: { Direction }, rawResult: unknown)
	if type(rawResult) ~= "table" then
		ShowAttemptError(state, "The route could not be checked.")
		return
	end
	const response = rawResult :: Response
	if not response.ok then
		ShowAttemptError(state, response.error or "The route could not be checked.")
		return
	end
	const completedSteps = response.completedSteps
	const acceptedCommands = response.commands or commands
	if
		type(completedSteps) ~= "number"
		or completedSteps % 1 ~= 0
		or completedSteps < 0
		or completedSteps > #acceptedCommands
		or type(response.correct) ~= "boolean"
	then
		ShowAttemptError(state, "The server returned an invalid route result.")
		return
	end

	const missionGeneration = state.generation
	task.spawn(function()
		AnimateAttempt(state, acceptedCommands, completedSteps)
		if
			not state.active
			or ActiveMission ~= state
			or state.generation ~= missionGeneration
			or Generation ~= missionGeneration
		then
			return
		end

		if not response.correct then
			state.busy = false
			state.gui.Backdrop.Panel.Status.Text = FailureMessage(response.failureReason)
			state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(239, 128, 128)
			ResetRoute(state)
			return
		end

		if response.missionCompleted then
			const reward = response.reward
			const sessionGuid = state.sessionGuid
			state.exiting = true
			state.active = false
			DestroyMission(state)
			Network.SoftwareEngineerAnimationComplete:request(sessionGuid):andThen(function() end, function() end)
			DialogueController.presentMessage(
				"Routes compiled!",
				if reward
					then `{CampaignConfig.COMPLETION_MESSAGE}\nYou've earned a reward: {reward}!`
					else `{CampaignConfig.COMPLETION_MESSAGE}\nMission complete, but your reward could not be granted.`,
				"Finish",
				nil
			)
			return
		end

		const seeds = state.seeds
		const nextRound = response.round
		if
			not seeds
			or type(nextRound) ~= "number"
			or nextRound % 1 ~= 0
			or nextRound ~= state.round + 1
			or not seeds[nextRound]
		then
			ShowAttemptError(state, "The next puzzle could not be loaded.")
			return
		end

		state.round = nextRound
		state.busy = false
		state.gui.Backdrop.Panel.Status.Text = "Route accepted. Build the next one."
		state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(67, 187, 132)
		state.gui.Backdrop.Panel.Round.Text = string.format("Puzzle %d/%d", state.round, state.totalRounds)
		state.gui.MissionBar.Progress.Text = string.format("Puzzles solved: %d/%d", state.round - 1, state.totalRounds)
		RenderBoard(state, GridRoute.generate(seeds[state.round], state.round))
		ResetRoute(state)
		Network.SoftwareEngineerBoardShown:fire(state.sessionGuid, state.round)
	end)
end

const function BeginAttempt(state: MissionState)
	if state.busy or not state.board or not state.seeds or #state.commands == 0 then
		return
	end

	state.requestJanitor:Cleanup()
	state.requestGeneration += 1
	const requestGeneration = state.requestGeneration
	const commands = table.clone(state.commands)
	state.busy = true
	state.gui.Backdrop.Panel.Status.Text = "Running route..."
	state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(151, 163, 184)
	SetControlsEnabled(state, false)
	Invoke(
		state,
		function()
			return Network.SoftwareEngineerAttempt:request(state.sessionGuid, state.round, commands)
		end,
		requestGeneration,
		function(succeeded: boolean, rawResult: unknown)
			if not succeeded then
				ShowAttemptError(state, "The route could not be checked. Press Go to retry.")
				return
			end
			HandleAttemptResponse(state, commands, rawResult)
		end
	)
end

const function AddCommand(state: MissionState, direction: Direction)
	if state.busy or not state.board then
		return
	end
	if #state.commands >= SoftwareEngineerConfig.maxCommands then
		state.gui.Backdrop.Panel.Status.Text =
			string.format("Routes can contain at most %d commands.", SoftwareEngineerConfig.maxCommands)
		state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(239, 128, 128)
		return
	end

	table.insert(state.commands, direction)
	state.gui.Backdrop.Panel.Status.Text = "Build a route, then press Go."
	state.gui.Backdrop.Panel.Status.TextColor3 = Color3.fromRGB(151, 163, 184)
	UpdateCommandQueue(state)
end

const function BindControls(state: MissionState)
	const side = state.gui.Backdrop.Panel.Side
	state.janitor:Add(side.Controls.Up.Activated:Connect(function()
		AddCommand(state, "up")
	end))
	state.janitor:Add(side.Controls.Down.Activated:Connect(function()
		AddCommand(state, "down")
	end))
	state.janitor:Add(side.Controls.Left.Activated:Connect(function()
		AddCommand(state, "left")
	end))
	state.janitor:Add(side.Controls.Right.Activated:Connect(function()
		AddCommand(state, "right")
	end))
	state.janitor:Add(side.Undo.Activated:Connect(function()
		if not state.busy and #state.commands > 0 then
			table.remove(state.commands)
			UpdateCommandQueue(state)
		end
	end))
	state.janitor:Add(side.Reset.Activated:Connect(function()
		if not state.busy then
			ResetRoute(state)
		end
	end))
	state.janitor:Add(side.Go.Activated:Connect(function()
		BeginAttempt(state)
	end))
	state.janitor:Add(side.Retry.Activated:Connect(function()
		if not state.busy and not state.seeds then
			BeginSeedRequest(state)
		end
	end))
	state.janitor:Add(state.gui.MissionBar.Leave.Activated:Connect(function()
		Stop(true)
	end))
end

const function FindLaptopPrompt(office: Model): ProximityPrompt?
	return TaggedInstance.findProximityPrompt(office, Tags.SOFTWARE_ENGINEER_LAPTOP_PROMPT)
end

const function BuildMission(payload: SoftwareEngineerStartPayload): (boolean, string?)
	const officeTemplate = Assets.models:FindFirstChild("Office")
	const guiTemplate = Assets.gui.campaign.screengui:FindFirstChild("SoftwareEngineerMission")
	if not officeTemplate or not officeTemplate:IsA("Model") then
		return false, "The office asset could not be loaded."
	end
	if not guiTemplate or not guiTemplate:IsA("ScreenGui") then
		return false, "The route compiler interface could not be loaded."
	end

	const office = officeTemplate:Clone()
	const prompt = FindLaptopPrompt(office)
	const playerLocation = TaggedInstance.findAttachment(office, Tags.SOFTWARE_ENGINEER_PLAYER_LOCATION)
	const character = Players.LocalPlayer.Character
	if not prompt or not playerLocation then
		office:Destroy()
		return false, "The office asset is missing a required location or interaction prompt."
	end
	if not character or not character.Parent then
		office:Destroy()
		return false, "Your character is not ready for the office."
	end

	const gui = guiTemplate:Clone()
	const missionJanitor = Janitor.new()
	const requestJanitor = Janitor.new()
	const state: MissionState = {
		active = true,
		board = nil,
		busy = false,
		cells = {},
		commands = {},
		exiting = false,
		generation = Generation,
		gui = gui,
		janitor = missionJanitor,
		office = office,
		requestGeneration = 0,
		requestJanitor = requestJanitor,
		returnCFrame = character:GetPivot(),
		round = payload.round,
		runner = nil,
		seeds = nil,
		sessionGuid = payload.sessionGuid,
		totalRounds = payload.totalRounds,
	}
	ActiveMission = state
	missionJanitor:Add(requestJanitor)
	missionJanitor:Add(office)
	missionJanitor:Add(gui)
	missionJanitor:Add(prompt.PromptShown:Connect(function()
		if state.active and not state.seeds then
			Network.SoftwareEngineerLaptopShown:fire(state.sessionGuid)
		end
	end))
	office:PivotTo(payload.officeCFrame)
	office.Parent = workspace
	gui.Backdrop.Visible = false
	gui.MissionBar.Progress.Text = "Use the laptop to begin"
	gui.Parent = Players.LocalPlayer.PlayerGui
	BindControls(state)

	missionJanitor:Add(
		prompt.Triggered:Connect(function()
			if not state.active or state.busy or state.seeds then
				return
			end
			prompt.Enabled = false
			state.janitor:Remove("Laptop")
			BeginSeedRequest(state)
		end),
		nil,
		"Laptop"
	)
	if not PivotCharacter(Players.LocalPlayer, playerLocation.WorldCFrame) then
		DestroyMission(state)
		return false, "Your character could not enter the office."
	end
	return true
end

const function ValidatePayload(value: unknown): SoftwareEngineerStartPayload?
	if type(value) ~= "table" then
		return nil
	end
	const payload = value :: { [string]: unknown }
	if
		not IsGuid(payload.sessionGuid)
		or typeof(payload.officeCFrame) ~= "CFrame"
		or payload.round ~= 1
		or payload.totalRounds ~= #SoftwareEngineerConfig.rounds
	then
		return nil
	end
	return value :: SoftwareEngineerStartPayload
end

--Public Methods
const function Start(startToken: string)
	Stop(true)
	const generation = Generation
	DialogueController.presentQuestion("Software Engineering", "Preparing your office...", {}, function() end)
	const requestPromise = Network.SoftwareEngineerRequest:request(startToken)
	StartJanitor:Add(function()
		requestPromise:cancel()
	end)
	requestPromise:andThen(function(rawResult: unknown)
		if generation ~= Generation then
			return
		end
		DialogueController.close()
		if type(rawResult) ~= "table" or type((rawResult :: { [string]: unknown }).ok) ~= "boolean" then
			DialogueController.presentMessage("Software Engineering", "The office could not be prepared.", "Close", nil)
			return
		end

		const response = rawResult :: Response
		if not response.ok then
			DialogueController.presentMessage(
				"Software Engineering",
				response.error or "The office could not be prepared.",
				"Close",
				nil
			)
			return
		end
		const payload = ValidatePayload(response.softwareEngineerPayload)
		if not payload then
			DialogueController.presentMessage("Software Engineering", "The office returned invalid data.", "Close", nil)
			return
		end

		const started, message = BuildMission(payload)
		if not started then
			Network.SoftwareEngineerAbandon:request(payload.sessionGuid):andThen(function() end, function() end)
			DialogueController.presentMessage(
				"Software Engineering",
				message or "The office could not be created.",
				"Close",
				nil
			)
			return
		end

		const state = ActiveMission
		if not state or state.sessionGuid ~= payload.sessionGuid then
			return
		end
		const readyPromise = Network.SoftwareEngineerEnvironmentReady:request(payload.sessionGuid)
		StartJanitor:Add(function()
			readyPromise:cancel()
		end)
		readyPromise:andThen(function(rawReadyResponse: unknown)
			if generation ~= Generation or ActiveMission ~= state then
				return
			end
			const validReadyResponse = type(rawReadyResponse) == "table"
				and type((rawReadyResponse :: { [string]: unknown }).ok) == "boolean"
			const readyResponse = if validReadyResponse then rawReadyResponse :: Response else nil
			if readyResponse and readyResponse.ok then
				return
			end
			Stop(true)
			DialogueController.presentMessage(
				"Software Engineering",
				if readyResponse
					then readyResponse.error or "The office could not be entered."
					else "The office could not be entered.",
				"Close",
				nil
			)
		end, function()
			if generation == Generation and ActiveMission == state then
				Stop(true)
				DialogueController.presentMessage(
					"Software Engineering",
					"The office could not be entered.",
					"Close",
					nil
				)
			end
		end)
	end, function()
		if generation == Generation then
			DialogueController.close()
			DialogueController.presentMessage("Software Engineering", "The office could not be prepared.", "Close", nil)
		end
	end)
end

const function Init()
	ControllerJanitor:Add(StartJanitor)
	ControllerJanitor:Add(function()
		Stop(false)
	end)
	ControllerJanitor:LinkToInstance(script.Parent.Parent.Parent)
	ControllerJanitor:Add(Network.SoftwareEngineerEnded:connect(function(sessionGuid: string, reason: string)
		const state = ActiveMission
		if not state or state.sessionGuid ~= sessionGuid then
			return
		end
		Stop(false)
		if reason == "timeout" then
			DialogueController.presentMessage(
				"Office closed",
				"The software engineering session expired. Speak to the Career Agent to begin again.",
				"Close",
				nil
			)
		end
	end))
end

return {
	init = Init,
	start = Start,
	stop = Stop,
}
