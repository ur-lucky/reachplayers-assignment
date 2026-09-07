--Services
const HttpService = game:GetService("HttpService")

--Imports
const Dependencies = require("../Dependencies").get()
const AllowRateLimit = require(Dependencies.shared.utils.funcs.allowRateLimit)
const AnalyticsService = require("../services/AnalyticsService")
const CampaignService = require("../services/CampaignService")
const GridRoute = require(Dependencies.shared.libraries.GridRoute)
const InstanceOrigin = require(Dependencies.shared.libraries.InstanceOrigin)
const IsGuid = require(Dependencies.shared.utils.funcs.isGuid)
const Janitor = require(Dependencies.shared.Packages.Janitor)
const MissionRuntime = require("../libraries/MissionRuntime")
const MissionTypes = require(Dependencies.shared.types.Mission)
const Network = require(Dependencies.shared.network)
const SoftwareEngineerConfig = require(Dependencies.shared.constants.missions.SoftwareEngineer)
const TaggedInstance = require(Dependencies.shared.libraries.TaggedInstance)
const Tags = require(Dependencies.shared.constants.tags)
const TrackMissionEvent = require("../utils/funcs/trackMission")

--Types
type Direction = MissionTypes.Direction
type JanitorObject = typeof(Janitor.new())
type Response = MissionTypes.Response
type SoftwareEngineerStartPayload = MissionTypes.SoftwareEngineerStartPayload

type SoftwareEngineerSession = {
	campaignSessionGuid: string?,
	sessionGuid: string,
	entered: boolean,
	round: number,
	seeds: { number }?,
	startedAt: number,
	completing: boolean,
	officeCFrame: CFrame,
	laptopViewed: boolean,
	laptopTriggered: boolean,
	boardShownByRound: { [number]: boolean },
	attemptsByRound: { [number]: number },
	resultsByRound: { [number]: Response },
	roundStartedAt: number?,
	lastAttemptAt: number?,
	invalidActionsRecorded: { [string]: boolean },
}

type PlayerState = {
	janitor: JanitorObject,
	missionJanitor: JanitorObject?,
	session: SoftwareEngineerSession?,
	startToken: string?,
	startTokenCampaignSessionGuid: string?,
	startTokenExpiresAt: number?,
	startTokenThread: thread?,
	rateWindowStartedAt: number,
	rateCount: number,
}

--Declarations
const Assets = Dependencies.assets
const ClearStartToken = MissionRuntime.clearStartToken
const Failure = MissionRuntime.failure
const PlayerStates: { [Player]: PlayerState } = {}
const ReservedOfficeCells: { [number]: boolean } = {}

--Private Methods
const function GetState(player: Player): PlayerState
	const existingState = PlayerStates[player]
	if existingState then
		return existingState
	end

	const state: PlayerState = {
		janitor = Janitor.new(),
		missionJanitor = nil,
		session = nil,
		startToken = nil,
		startTokenCampaignSessionGuid = nil,
		startTokenExpiresAt = nil,
		startTokenThread = nil,
		rateWindowStartedAt = 0,
		rateCount = 0,
	}
	PlayerStates[player] = state
	state.janitor:Add(function()
		ClearStartToken(state)
		PlayerStates[player] = nil
	end)
	return state
end

const function TrackMission(
	player: Player,
	eventName: string,
	session: SoftwareEngineerSession,
	properties: AnalyticsService.Properties?
)
	TrackMissionEvent(player, eventName, session, SoftwareEngineerConfig, properties)
end

const function TrackInvalid(player: Player, state: PlayerState?, code: string)
	const session = if state then state.session else nil
	if not session or session.invalidActionsRecorded[code] then
		return
	end
	session.invalidActionsRecorded[code] = true
	TrackMission(player, "mission_invalid_action", session, { rejectionCode = code })
end

const function IsNearLaptop(player: Player, session: SoftwareEngineerSession): boolean
	const office = Assets.models:FindFirstChild("Office")
	const prompt = if office and office:IsA("Model")
		then TaggedInstance.findProximityPrompt(office, Tags.SOFTWARE_ENGINEER_LAPTOP_PROMPT)
		else nil
	const origin = if prompt then prompt.Parent else nil
	const originCFrame = if origin then InstanceOrigin.getCFrame(origin) else nil
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if
		not office
		or not office:IsA("Model")
		or not prompt
		or not originCFrame
		or not root
		or not root:IsA("BasePart")
	then
		return false
	end
	const offset = office:GetPivot():ToObjectSpace(originCFrame)
	const promptPosition = (session.officeCFrame * offset).Position
	return (root.Position - promptPosition).Magnitude <= prompt.MaxActivationDistance + 3
end

const function GenerateSeeds(): { number }
	const random = Random.new()
	const seeds: { number } = {}
	for _ = 1, #SoftwareEngineerConfig.rounds do
		table.insert(seeds, random:NextInteger(1, 2 ^ 30))
	end
	return seeds
end

const function Finish(player: Player, reason: string, notifyClient: boolean?)
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if not state or not session or not state.missionJanitor then
		return
	end

	state.session = nil
	state.rateCount = 0
	if session.entered and reason ~= "completed" and not session.completing then
		TrackMission(player, "mission_abandoned", session, {
			progress = session.round - 1,
			durationMs = math.round((os.clock() - session.startedAt) * 1000),
			reason = reason,
		})
	end

	if notifyClient ~= false and reason ~= "player_left" and reason ~= "unload" then
		Network.SoftwareEngineerEnded:fire(player, session.sessionGuid, reason)
	end

	state.missionJanitor = nil
	state.janitor:Remove("Mission")
end

const function ParseCommands(rawCommands: unknown): { Direction }?
	if type(rawCommands) ~= "table" or #rawCommands > SoftwareEngineerConfig.maxCommands then
		return nil
	end

	const source = rawCommands :: { [unknown]: unknown }
	local entryCount = 0
	for key, value in source do
		entryCount += 1
		if
			type(key) ~= "number"
			or key % 1 ~= 0
			or key < 1
			or key > #rawCommands
			or type(value) ~= "string"
			or not GridRoute.isDirection(value)
		then
			return nil
		end
	end
	if entryCount ~= #rawCommands then
		return nil
	end

	const commands: { Direction } = {}
	for commandIndex = 1, #rawCommands do
		table.insert(commands, source[commandIndex] :: Direction)
	end
	return commands
end

--Public Methods
const function IssueToken(player: Player, campaignSessionGuid: string?): string
	const state = GetState(player)
	return MissionRuntime.issueStartToken(state, campaignSessionGuid, 30)
end

const function Request(player: Player, rawStartToken: unknown): Response
	const state = GetState(player)
	if not IsGuid(rawStartToken) or state.startToken ~= rawStartToken then
		TrackInvalid(player, state, "invalid_start_token")
		return Failure("invalid_start_token", "That office invitation is invalid or has already been used.")
	end
	const expiresAt = state.startTokenExpiresAt
	if not expiresAt or os.clock() > expiresAt then
		ClearStartToken(state)
		TrackInvalid(player, state, "expired_start_token")
		return Failure("expired_start_token", "That office invitation has expired.")
	end

	const campaignSessionGuid = state.startTokenCampaignSessionGuid
	ClearStartToken(state)
	Finish(player, "replaced")
	const character = player.Character
	if not character or not character.Parent then
		return Failure("character_unavailable", "Your character is not ready for the office.")
	end

	const officeCell, officeCFrame = MissionRuntime.reserveCell(ReservedOfficeCells, 80, 640)
	const sessionGuid = HttpService:GenerateGUID(false)
	const session: SoftwareEngineerSession = {
		campaignSessionGuid = campaignSessionGuid,
		sessionGuid = sessionGuid,
		entered = false,
		round = 1,
		seeds = nil,
		startedAt = os.clock(),
		completing = false,
		officeCFrame = officeCFrame,
		laptopViewed = false,
		laptopTriggered = false,
		boardShownByRound = {},
		attemptsByRound = {},
		resultsByRound = {},
		roundStartedAt = nil,
		lastAttemptAt = nil,
		invalidActionsRecorded = {},
	}
	const missionJanitor = Janitor.new()
	state.missionJanitor = missionJanitor
	state.session = session
	state.rateCount = 0
	state.rateWindowStartedAt = 0
	state.janitor:Add(missionJanitor, "Destroy", "Mission")
	missionJanitor:Add(function()
		ReservedOfficeCells[officeCell] = nil
		if state.session == session then
			state.session = nil
		end
	end)
	missionJanitor:Add(player.CharacterRemoving:Connect(function(removingCharacter: Model)
		if removingCharacter == character then
			Finish(player, "character_removed")
		end
	end))
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		missionJanitor:Add(humanoid.Died:Connect(function()
			Finish(player, "character_died")
		end))
	end
	const timeoutThread = task.delay(SoftwareEngineerConfig.sessionTimeoutSeconds, function()
		if state.session == session and not session.completing then
			Finish(player, "timeout")
		end
	end)
	missionJanitor:Add(function()
		if coroutine.status(timeoutThread) ~= "dead" then
			task.cancel(timeoutThread)
		end
	end)

	const payload: SoftwareEngineerStartPayload = {
		sessionGuid = sessionGuid,
		officeCFrame = officeCFrame,
		round = 1,
		totalRounds = #SoftwareEngineerConfig.rounds,
	}
	return { ok = true, softwareEngineerPayload = payload }
end

const function EnterEnvironment(player: Player, rawSessionGuid: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if not session or not IsGuid(rawSessionGuid) or session.sessionGuid ~= rawSessionGuid then
		return Failure("invalid_session", "That software engineering session is no longer active.")
	end
	if session.entered then
		return { ok = true }
	end
	session.entered = true
	session.startedAt = os.clock()
	TrackMission(player, "mission_started", session, {
		stageIndex = 5,
		total = #SoftwareEngineerConfig.rounds,
	})
	return { ok = true }
end

const function LaptopShown(player: Player, rawSessionGuid: unknown)
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if
		not session
		or not session.entered
		or not IsGuid(rawSessionGuid)
		or session.sessionGuid ~= rawSessionGuid
		or session.completing
		or session.laptopViewed
		or not AnalyticsService.canAcceptReceipt(player)
		or not IsNearLaptop(player, session)
	then
		return
	end

	session.laptopViewed = true
	TrackMission(player, "software_engineer_laptop_viewed", session)
end

const function BoardShown(player: Player, rawSessionGuid: unknown, rawRound: unknown)
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if
		not session
		or not session.entered
		or not IsGuid(rawSessionGuid)
		or session.sessionGuid ~= rawSessionGuid
		or session.completing
		or type(rawRound) ~= "number"
		or rawRound % 1 ~= 0
		or rawRound ~= session.round
		or not session.seeds
		or session.boardShownByRound[rawRound]
		or not AnalyticsService.canAcceptReceipt(player)
	then
		return
	end

	const round = rawRound :: number
	const now = os.clock()
	session.boardShownByRound[round] = true
	session.roundStartedAt = now
	session.lastAttemptAt = now
	if round == 1 then
		TrackMission(player, "software_engineer_game_loaded", session, {
			round = round,
			size = SoftwareEngineerConfig.rounds[round].size,
		})
	end
end

const function RequestSeeds(player: Player, rawSessionGuid: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if
		not state
		or not session
		or not session.entered
		or not IsGuid(rawSessionGuid)
		or session.sessionGuid ~= rawSessionGuid
	then
		TrackInvalid(player, state, "invalid_session")
		return Failure("invalid_session", "That software engineering session is no longer active.")
	end
	if not IsNearLaptop(player, session) then
		TrackInvalid(player, state, "not_near_laptop")
		return Failure("not_near_laptop", "Move closer to the office laptop.")
	end
	if not AllowRateLimit(state, 12, 2) then
		TrackInvalid(player, state, "rate_limited")
		return Failure("rate_limited", "Please wait before requesting the puzzles again.")
	end

	if not session.seeds then
		session.seeds = GenerateSeeds()
	end
	if not session.laptopTriggered then
		session.laptopTriggered = true
		TrackMission(player, "software_engineer_laptop_triggered", session)
	end
	return { ok = true, seeds = table.clone(session.seeds), round = session.round }
end

const function Attempt(player: Player, rawSessionGuid: unknown, rawRound: unknown, rawCommands: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	const missionJanitor = if state then state.missionJanitor else nil
	if
		not state
		or not session
		or not missionJanitor
		or not session.entered
		or not IsGuid(rawSessionGuid)
		or session.sessionGuid ~= rawSessionGuid
	then
		TrackInvalid(player, state, "invalid_session")
		return Failure("invalid_session", "That software engineering session is no longer active.")
	end
	if
		type(rawRound) ~= "number"
		or rawRound % 1 ~= 0
		or rawRound < 1
		or rawRound > #SoftwareEngineerConfig.rounds
	then
		TrackInvalid(player, state, "stale_round")
		return Failure("stale_round", "That puzzle is no longer active.")
	end
	if not AllowRateLimit(state, 12, 2) then
		TrackInvalid(player, state, "rate_limited")
		return Failure("rate_limited", "Please wait before running another route.")
	end
	const previousResult = session.resultsByRound[rawRound :: number]
	if previousResult then
		return table.clone(previousResult)
	end
	if session.completing then
		return Failure("session_completing", "The software engineering mission is already finishing.")
	end
	if rawRound ~= session.round then
		TrackInvalid(player, state, "stale_round")
		return Failure("stale_round", "That puzzle is no longer active.")
	end
	if not session.seeds then
		TrackInvalid(player, state, "seeds_unavailable")
		return Failure("seeds_unavailable", "The puzzle seeds have not been requested.")
	end
	const commands = ParseCommands(rawCommands)
	if not commands then
		TrackInvalid(player, state, "invalid_commands")
		return Failure("invalid_commands", "The submitted route was malformed.")
	end

	const round = session.round
	const now = os.clock()
	const roundStartedAt = session.roundStartedAt
	const lastAttemptAt = session.lastAttemptAt
	session.attemptsByRound[round] = (session.attemptsByRound[round] or 0) + 1
	session.lastAttemptAt = now
	const board = GridRoute.generate(session.seeds[round], round)
	const evaluation = GridRoute.evaluate(board, commands)
	const attemptProperties: AnalyticsService.Properties = {
		round = round,
		attempt = session.attemptsByRound[round],
		commandCount = #commands,
		completedSteps = evaluation.completedSteps,
		succeeded = evaluation.reachedGoal,
		result = if evaluation.reachedGoal then "completed" else evaluation.failureReason or "failed",
	}
	if lastAttemptAt then
		attemptProperties.attemptDurationMs = math.round((now - lastAttemptAt) * 1000)
	end
	if evaluation.failureReason then
		attemptProperties.failureReason = evaluation.failureReason
	end
	TrackMission(player, "software_engineer_route_attempted", session, attemptProperties)
	if not evaluation.reachedGoal then
		return {
			ok = true,
			correct = false,
			completedSteps = evaluation.completedSteps,
			failureReason = evaluation.failureReason,
			round = session.round,
			totalRounds = #SoftwareEngineerConfig.rounds,
		}
	end

	const roundProperties: AnalyticsService.Properties = {
		round = round,
		size = SoftwareEngineerConfig.rounds[round].size,
		attempts = session.attemptsByRound[round],
	}
	if roundStartedAt then
		roundProperties.durationMs = math.round((now - roundStartedAt) * 1000)
	end
	TrackMission(player, "software_engineer_round_completed", session, roundProperties)
	session.round += 1
	if session.round <= #SoftwareEngineerConfig.rounds then
		session.roundStartedAt = nil
		session.lastAttemptAt = nil
		TrackMission(player, "mission_progress", session, {
			progress = session.round - 1,
			total = #SoftwareEngineerConfig.rounds,
		})
		const response: Response = {
			ok = true,
			correct = true,
			commands = commands,
			completedSteps = evaluation.completedSteps,
			missionCompleted = false,
			round = session.round,
			totalRounds = #SoftwareEngineerConfig.rounds,
		}
		session.resultsByRound[round] = response
		return table.clone(response)
	end

	session.completing = true
	TrackMission(player, "mission_completed", session, {
		stageIndex = 6,
		progress = #SoftwareEngineerConfig.rounds,
		total = #SoftwareEngineerConfig.rounds,
		durationMs = math.round((os.clock() - session.startedAt) * 1000),
	})
	const rewardGranted, rewardReceipt = CampaignService.grantReward(player, {
		sessionGuid = session.sessionGuid,
		missionId = SoftwareEngineerConfig.id,
		profession = SoftwareEngineerConfig.profession,
	})
	TrackMission(player, if rewardGranted then "reward_granted" else "reward_failed", session, {
		stageIndex = 7,
	})
	const response: Response = {
		ok = true,
		correct = true,
		commands = commands,
		completedSteps = evaluation.completedSteps,
		missionCompleted = true,
		round = #SoftwareEngineerConfig.rounds,
		totalRounds = #SoftwareEngineerConfig.rounds,
		reward = if rewardGranted then rewardReceipt else nil,
	}
	session.resultsByRound[round] = response
	const completionTimeoutThread = task.delay(SoftwareEngineerConfig.completionGraceSeconds, function()
		if state.session == session and session.completing then
			Finish(player, "completed")
		end
	end)
	missionJanitor:Add(function()
		if coroutine.status(completionTimeoutThread) ~= "dead" then
			task.cancel(completionTimeoutThread)
		end
	end)
	return table.clone(response)
end

const function CompleteAnimation(player: Player, rawSessionGuid: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if not session or not IsGuid(rawSessionGuid) or session.sessionGuid ~= rawSessionGuid then
		TrackInvalid(player, state, "invalid_session")
		return Failure("invalid_session", "That software engineering session is no longer active.")
	end
	if not session.completing then
		TrackInvalid(player, state, "premature_animation_completion")
		return Failure("mission_incomplete", "The software engineering mission is not complete.")
	end
	Finish(player, "completed", false)
	return { ok = true }
end

const function Abandon(player: Player, rawSessionGuid: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if not session or not IsGuid(rawSessionGuid) or session.sessionGuid ~= rawSessionGuid then
		TrackInvalid(player, state, "invalid_session")
		return Failure("invalid_session", "That software engineering session is no longer active.")
	end
	Finish(player, "client_abandoned", false)
	return { ok = true }
end

const function RemovePlayer(player: Player)
	const state = PlayerStates[player]
	if not state then
		return
	end
	ClearStartToken(state)
	Finish(player, "player_left")
	state.janitor:Destroy()
end

const function Reset(player: Player, reason: string)
	const state = PlayerStates[player]
	if not state then
		return
	end
	ClearStartToken(state)
	Finish(player, reason)
end

const function Shutdown()
	const players: { Player } = {}
	for player in PlayerStates do
		table.insert(players, player)
	end
	for _, player in players do
		const state = PlayerStates[player]
		ClearStartToken(state)
		Finish(player, "unload")
		state.janitor:Destroy()
	end
	table.clear(ReservedOfficeCells)
end

return {
	abandon = Abandon,
	attempt = Attempt,
	boardShown = BoardShown,
	completeAnimation = CompleteAnimation,
	enterEnvironment = EnterEnvironment,
	issueToken = IssueToken,
	laptopShown = LaptopShown,
	removePlayer = RemovePlayer,
	request = Request,
	requestSeeds = RequestSeeds,
	reset = Reset,
	shutdown = Shutdown,
}
