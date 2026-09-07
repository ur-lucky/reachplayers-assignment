--Services
const CollectionService = game:GetService("CollectionService")
const HttpService = game:GetService("HttpService")

--Imports
const Dependencies = require("../Dependencies").get()
const AllowRateLimit = require(Dependencies.shared.utils.funcs.allowRateLimit)
const AnalyticsService = require("../services/AnalyticsService")
const CampaignService = require("../services/CampaignService")
const IsGuid = require(Dependencies.shared.utils.funcs.isGuid)
const Janitor = require(Dependencies.shared.Packages.Janitor)
const MissionRuntime = require("../libraries/MissionRuntime")
const MissionTypes = require(Dependencies.shared.types.Mission)
const Network = require(Dependencies.shared.network)
const TableUtil = require(Dependencies.shared.libraries.TableUtil)
const Tags = require(Dependencies.shared.constants.tags)
const TeacherConfig = require(Dependencies.shared.constants.missions.Teacher)
const TeacherConversations = require(Dependencies.shared.constants.conversations.Teacher)
const TeacherKeys = require("./TeacherKeys")
const TrackMissionEvent = require("../utils/funcs/trackMission")

--Types
type JanitorObject = typeof(Janitor.new())
type Response = MissionTypes.Response
type PublicDialogue = MissionTypes.PublicDialogue
type TeachingMissionPayload = MissionTypes.TeachingMissionPayload
type QuestionDefinition = TeacherConversations.QuestionDefinition

type AnswerRecord = {
	conversationId: string,
	correctChoiceId: string,
	validChoiceIds: { [string]: boolean },
	completed: boolean,
	active: boolean,
	availableAt: number,
	attempts: number,
	questionViewedAt: number?,
}

type TeachingSession = {
	campaignSessionGuid: string?,
	sessionGuid: string,
	entered: boolean,
	answersByNpcGuid: { [string]: AnswerRecord },
	progress: number,
	total: number,
	startedAt: number,
	completing: boolean,
	classroomCFrame: CFrame,
	studentCFrames: { [string]: CFrame },
	invalidActionsRecorded: { [string]: boolean },
}

type PlayerState = {
	janitor: JanitorObject,
	missionJanitor: JanitorObject?,
	session: TeachingSession?,
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
const ReservedClassroomCells: { [number]: boolean } = {}

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
	session: TeachingSession,
	properties: AnalyticsService.Properties?
)
	TrackMissionEvent(player, eventName, session, TeacherConfig, properties)
end

const function TrackInvalid(player: Player, state: PlayerState?, code: string, questionId: string?)
	const session = if state then state.session else nil
	if not session or session.invalidActionsRecorded[code] then
		return
	end
	session.invalidActionsRecorded[code] = true
	const properties: AnalyticsService.Properties = { rejectionCode = code }
	if questionId then
		properties.questionId = questionId
	end
	TrackMission(player, "mission_invalid_action", session, properties)
end

const function IsNearStudentLocation(player: Player, session: TeachingSession, npcGuid: string): boolean
	const studentCFrame = session.studentCFrames[npcGuid]
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return studentCFrame ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and (root.Position - studentCFrame.Position).Magnitude <= 13
end

const function BuildPayload(classroomCFrame: CFrame): (TeachingMissionPayload?, { [string]: AnswerRecord }?)
	const classroom = Assets.models:FindFirstChild("Classroom")
	if not classroom or not classroom:IsA("Model") then
		return nil, nil
	end
	const locations: { CFrame } = {}
	const templatePivot = classroom:GetPivot()
	for _, location in classroom:QueryDescendants("MeshPart") do
		if CollectionService:HasTag(location, Tags.TEACHER_NPC_LOCATION) then
			const attachment = location:FindFirstChildWhichIsA("Attachment")
			if attachment then
				table.insert(locations, classroomCFrame * templatePivot:ToObjectSpace(attachment.WorldCFrame))
			end
		end
	end
	if #locations < TeacherConfig.studentCount then
		return nil, nil
	end
	const random = Random.new()
	TableUtil.shuffle(locations, random)
	const selectedQuestions = TableUtil.shuffled(TeacherConversations, random)
	const dialogues: { PublicDialogue } = {}
	const answersByNpcGuid: { [string]: AnswerRecord } = {}
	const studentCFrames: { [string]: CFrame } = {}
	const sessionGuid = HttpService:GenerateGUID(false)

	for questionIndex = 1, TeacherConfig.studentCount do
		const question: QuestionDefinition = selectedQuestions[questionIndex]
		const npcGuid = HttpService:GenerateGUID(false)
		studentCFrames[npcGuid] = locations[questionIndex]
		const validChoiceIds: { [string]: boolean } = {}

		for _, choice in question.choices do
			validChoiceIds[choice.id] = true
		end

		const correctChoiceId = TeacherKeys[question.id]
		assert(correctChoiceId and validChoiceIds[correctChoiceId], `Question "{question.id}" has no correct answer`)
		table.insert(dialogues, {
			npcGuid = npcGuid,
			conversationId = question.id,
			active = questionIndex <= TeacherConfig.activeStudentCount,
		})
		answersByNpcGuid[npcGuid] = {
			conversationId = question.id,
			correctChoiceId = correctChoiceId,
			validChoiceIds = validChoiceIds,
			completed = false,
			active = questionIndex <= TeacherConfig.activeStudentCount,
			availableAt = 0,
			attempts = 0,
			questionViewedAt = nil,
		}
	end

	return {
		sessionGuid = sessionGuid,
		classroomCFrame = classroomCFrame,
		studentCFrames = studentCFrames,
		dialogues = dialogues,
		total = TeacherConfig.studentCount,
	},
		answersByNpcGuid
end

const function ScheduleNextStudent(
	player: Player,
	state: PlayerState,
	session: TeachingSession,
	previousNpcGuid: string
)
	const missionJanitor = state.missionJanitor
	if not missionJanitor then
		return
	end
	const replacementThread = task.delay(TeacherConfig.questionDelaySeconds, function()
		if state.session ~= session or session.completing then
			return
		end

		const waitingNpcGuids: { string } = {}
		const completedNpcGuids: { string } = {}
		const now = os.clock()
		for npcGuid, record in session.answersByNpcGuid do
			if npcGuid ~= previousNpcGuid and not record.active and record.availableAt <= now then
				if record.completed then
					table.insert(completedNpcGuids, npcGuid)
				else
					table.insert(waitingNpcGuids, npcGuid)
				end
			end
		end

		const random = Random.new()
		const changes: { PublicDialogue } = {}
		local nextNpcGuid: string? = nil
		if #waitingNpcGuids > 0 then
			nextNpcGuid = waitingNpcGuids[random:NextInteger(1, #waitingNpcGuids)]
		else
			const previousRecord = session.answersByNpcGuid[previousNpcGuid]
			if not previousRecord.completed and not previousRecord.active and #completedNpcGuids > 0 then
				-- Move the remaining question so even the last retry goes to a different student.
				nextNpcGuid = completedNpcGuids[random:NextInteger(1, #completedNpcGuids)]
				session.answersByNpcGuid[previousNpcGuid] = session.answersByNpcGuid[nextNpcGuid]
				session.answersByNpcGuid[nextNpcGuid] = previousRecord
				table.insert(changes, {
					npcGuid = previousNpcGuid,
					conversationId = session.answersByNpcGuid[previousNpcGuid].conversationId,
					active = false,
				})
			end
		end
		if not nextNpcGuid then
			return
		end

		const nextRecord = session.answersByNpcGuid[nextNpcGuid]
		nextRecord.active = true
		table.insert(changes, {
			npcGuid = nextNpcGuid,
			conversationId = nextRecord.conversationId,
			active = true,
		})
		Network.TeacherStudentsChanged:fire(player, session.sessionGuid, changes)
	end)
	missionJanitor:Add(function()
		if coroutine.status(replacementThread) ~= "dead" then
			task.cancel(replacementThread)
		end
	end)
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
			progress = session.progress,
			durationMs = math.round((os.clock() - session.startedAt) * 1000),
			reason = reason,
		})
	end

	if notifyClient ~= false and reason ~= "completed" and reason ~= "player_left" and reason ~= "unload" then
		Network.TeacherEnded:fire(player, session.sessionGuid, reason)
	end

	state.missionJanitor = nil
	state.janitor:Remove("Mission")
end

--Public Methods
const function IssueToken(player: Player, campaignSessionGuid: string?): string
	const state = GetState(player)
	return MissionRuntime.issueStartToken(state, campaignSessionGuid, 30)
end

const function Request(player: Player, rawStartToken: unknown): Response
	const state = GetState(player)
	if not IsGuid(rawStartToken) or state.startToken ~= rawStartToken then
		TrackInvalid(player, state, "invalid_start_token", nil)
		return Failure("invalid_start_token", "That classroom invitation is invalid or has already been used.")
	end
	const expiresAt = state.startTokenExpiresAt
	if not expiresAt or os.clock() > expiresAt then
		ClearStartToken(state)
		TrackInvalid(player, state, "expired_start_token", nil)
		return Failure("expired_start_token", "That classroom invitation has expired.")
	end

	const campaignSessionGuid = state.startTokenCampaignSessionGuid
	ClearStartToken(state)
	Finish(player, "replaced")
	const character = player.Character
	if not character or not character.Parent then
		return Failure("character_unavailable", "Your character is not ready for the classroom.")
	end

	const classroomCell, classroomCFrame = MissionRuntime.reserveCell(ReservedClassroomCells, 80, 512)
	const payload, answersByNpcGuid = BuildPayload(classroomCFrame)
	if not payload or not answersByNpcGuid then
		ReservedClassroomCells[classroomCell] = nil
		return Failure("classroom_unavailable", "The classroom asset is missing its student locations.")
	end
	const session: TeachingSession = {
		campaignSessionGuid = campaignSessionGuid,
		sessionGuid = payload.sessionGuid,
		entered = false,
		answersByNpcGuid = answersByNpcGuid,
		progress = 0,
		total = payload.total,
		startedAt = os.clock(),
		completing = false,
		classroomCFrame = classroomCFrame,
		studentCFrames = payload.studentCFrames,
		invalidActionsRecorded = {},
	}
	const missionJanitor = Janitor.new()
	state.missionJanitor = missionJanitor
	state.session = session
	state.rateCount = 0
	state.rateWindowStartedAt = 0
	state.janitor:Add(missionJanitor, "Destroy", "Mission")
	missionJanitor:Add(function()
		ReservedClassroomCells[classroomCell] = nil
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
	const timeoutThread = task.delay(TeacherConfig.sessionTimeoutSeconds, function()
		if state.session == session and not session.completing then
			Finish(player, "timeout")
		end
	end)
	missionJanitor:Add(function()
		if coroutine.status(timeoutThread) ~= "dead" then
			task.cancel(timeoutThread)
		end
	end)

	return { ok = true, payload = payload, progress = 0, total = session.total }
end

const function EnterEnvironment(player: Player, rawSessionGuid: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if not session or not IsGuid(rawSessionGuid) or session.sessionGuid ~= rawSessionGuid then
		return Failure("invalid_session", "That classroom session is no longer active.")
	end
	if session.entered then
		return { ok = true }
	end
	session.entered = true
	session.startedAt = os.clock()
	TrackMission(player, "mission_started", session, {
		stageIndex = 5,
		total = session.total,
	})
	return { ok = true }
end

const function QuestionShown(player: Player, rawSessionGuid: unknown, rawNpcGuid: unknown)
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if
		not session
		or not session.entered
		or not IsGuid(rawSessionGuid)
		or session.sessionGuid ~= rawSessionGuid
		or not IsGuid(rawNpcGuid)
	then
		return
	end
	const answerRecord = session.answersByNpcGuid[rawNpcGuid :: string]
	if
		not answerRecord
		or not answerRecord.active
		or answerRecord.completed
		or answerRecord.questionViewedAt ~= nil
		or not AnalyticsService.canAcceptReceipt(player)
		or not IsNearStudentLocation(player, session, rawNpcGuid :: string)
	then
		return
	end

	answerRecord.questionViewedAt = os.clock()
	TrackMission(player, "teacher_question_viewed", session, {
		questionId = answerRecord.conversationId,
		attempt = answerRecord.attempts + 1,
	})
end

const function CompleteConversation(
	player: Player,
	rawSessionGuid: unknown,
	rawNpcGuid: unknown,
	rawChoiceId: unknown
): Response
	const state = PlayerStates[player]
	if not state or not IsGuid(rawSessionGuid) or not IsGuid(rawNpcGuid) or type(rawChoiceId) ~= "string" then
		TrackInvalid(player, state, "malformed_conversation", nil)
		return Failure("malformed_conversation", "The completed conversation was malformed.")
	end
	const session = state.session
	if not session or session.sessionGuid ~= rawSessionGuid then
		TrackInvalid(player, state, "invalid_session", nil)
		return Failure("invalid_session", "That classroom session is no longer active.")
	end
	if not session.entered then
		return Failure("environment_not_ready", "The classroom environment is not ready.")
	end
	if session.completing then
		return Failure("session_completing", "The classroom mission is already finishing.")
	end

	const npcGuid = rawNpcGuid :: string
	const choiceId = rawChoiceId :: string
	const answerRecord = session.answersByNpcGuid[npcGuid]
	if not answerRecord then
		TrackInvalid(player, state, "unknown_npc", nil)
		return Failure("unknown_npc", "That student is not part of this classroom.")
	end
	if not answerRecord.validChoiceIds[choiceId] then
		TrackInvalid(player, state, "answer_not_for_npc", answerRecord.conversationId)
		return Failure("answer_not_for_npc", "That response does not belong to this student.")
	end
	if answerRecord.completed then
		return {
			ok = true,
			correct = true,
			alreadyCompleted = true,
			progress = session.progress,
			total = session.total,
		}
	end
	if not answerRecord.active then
		return Failure("student_not_ready", "That student does not have a question right now.")
	end
	if not IsNearStudentLocation(player, session, npcGuid) then
		TrackInvalid(player, state, "not_near_student", answerRecord.conversationId)
		return Failure("not_near_student", "Move closer to this student before answering.")
	end
	const questionViewedAt = answerRecord.questionViewedAt
	if not AllowRateLimit(state, 12, 2) then
		TrackInvalid(player, state, "rate_limited", nil)
		return Failure("rate_limited", "Please wait a moment before answering again.")
	end

	answerRecord.attempts += 1
	const now = os.clock()
	answerRecord.active = false
	answerRecord.availableAt = now + TeacherConfig.questionDelaySeconds
	answerRecord.questionViewedAt = nil
	const correct = choiceId == answerRecord.correctChoiceId
	if correct then
		answerRecord.completed = true
		session.progress += 1
		session.completing = session.progress == session.total
	end
	Network.TeacherStudentsChanged:fire(player, session.sessionGuid, {
		{
			npcGuid = npcGuid,
			conversationId = answerRecord.conversationId,
			active = false,
		},
	})
	if not session.completing then
		ScheduleNextStudent(player, state, session, npcGuid)
	end

	const answerProperties: AnalyticsService.Properties = {
		questionId = answerRecord.conversationId,
		choiceId = choiceId,
		correct = correct,
		attempt = answerRecord.attempts,
		progress = session.progress,
	}
	if questionViewedAt then
		answerProperties.responseTimeMs = math.round((now - questionViewedAt) * 1000)
	end
	TrackMission(player, "teacher_answered", session, answerProperties)
	if not correct then
		return {
			ok = true,
			correct = false,
			progress = session.progress,
			total = session.total,
		}
	end

	TrackMission(player, "teacher_student_completed", session, {
		questionId = answerRecord.conversationId,
		attempts = answerRecord.attempts,
		progress = session.progress,
	})
	TrackMission(player, "mission_progress", session, {
		progress = session.progress,
		total = session.total,
	})
	if not session.completing then
		return {
			ok = true,
			correct = true,
			progress = session.progress,
			total = session.total,
			missionCompleted = false,
		}
	end

	TrackMission(player, "mission_completed", session, {
		stageIndex = 6,
		progress = session.progress,
		total = session.total,
		durationMs = math.round((os.clock() - session.startedAt) * 1000),
	})
	const rewardGranted, rewardReceipt = CampaignService.grantReward(player, {
		sessionGuid = session.sessionGuid,
		missionId = TeacherConfig.id,
		profession = TeacherConfig.profession,
	})
	TrackMission(player, if rewardGranted then "reward_granted" else "reward_failed", session, {
		stageIndex = 7,
	})
	const response: Response = {
		ok = true,
		correct = true,
		progress = session.progress,
		total = session.total,
		missionCompleted = true,
		reward = if rewardGranted then rewardReceipt else nil,
	}
	Finish(player, "completed")
	return response
end

const function Abandon(player: Player, rawSessionGuid: unknown): Response
	const state = PlayerStates[player]
	const session = if state then state.session else nil
	if not session or not IsGuid(rawSessionGuid) or session.sessionGuid ~= rawSessionGuid then
		TrackInvalid(player, state, "invalid_session", nil)
		return Failure("invalid_session", "That classroom session is no longer active.")
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
	table.clear(ReservedClassroomCells)
end

return {
	abandon = Abandon,
	completeConversation = CompleteConversation,
	enterEnvironment = EnterEnvironment,
	finish = Finish,
	issueToken = IssueToken,
	questionShown = QuestionShown,
	removePlayer = RemovePlayer,
	request = Request,
	reset = Reset,
	shutdown = Shutdown,
}
