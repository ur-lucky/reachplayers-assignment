--Services
const CollectionService = game:GetService("CollectionService")
const KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
const Players = game:GetService("Players")

--Imports
const CampaignConfig = require("../../shared/constants/campaign")
const DialogueController = require("../controllers/DialogueController")
const DialogueTypes = require("../../shared/types/Dialogue")
const IsGuid = require("../../shared/utils/funcs/isGuid")
const Janitor = require("../../shared/Packages/Janitor")
const MissionTypes = require("../../shared/types/Mission")
const Network = require("../../shared/network")
const NPC = require("../../shared/libraries/NPC")
const NpcConstants = require("../../shared/constants/npc")
const PivotCharacter = require("../../shared/utils/funcs/pivotCharacter")
const TableUtil = require("../../shared/libraries/TableUtil")
const TaggedInstance = require("../../shared/libraries/TaggedInstance")
const Tags = require("../../shared/constants/tags")
const TeacherConfig = require("../../shared/constants/missions/Teacher")
const TeacherConversations = require("../../shared/constants/conversations/Teacher")

--Types
type Conversation = DialogueTypes.Conversation
type ConversationResult = DialogueTypes.ConversationResult
type JanitorObject = typeof(Janitor.new())
type PublicDialogue = MissionTypes.PublicDialogue
type QuestionDefinition = TeacherConversations.QuestionDefinition
type Response = MissionTypes.Response
type TeachingMissionPayload = MissionTypes.TeachingMissionPayload

type DialogueBinding = {
	dialogue: PublicDialogue,
	busy: boolean,
	issueTrack: AnimationTrack?,
	name: string,
	prompt: ProximityPrompt,
}

type MissionState = {
	active: boolean,
	answerPending: boolean,
	exiting: boolean,
	generation: number,
	returnCFrame: CFrame,
	sessionGuid: string,
	progress: number,
	total: number,
	janitor: JanitorObject,
	classroomJanitor: JanitorObject,
	bindings: { [string]: DialogueBinding },
	progressLabel: TextLabel,
}

type RequestHandler = (succeeded: boolean, result: unknown) -> ()
type Request = () -> Network.ResponsePromise

--Declarations
const Assets = script.Parent.Parent.Parent.assets
const ControllerJanitor = Janitor.new()
const StartJanitor = Janitor.new()

local ActiveMission: MissionState? = nil
local Generation = 0

--Private Methods
const function FlattenPools<T>(pools: NPC.Pools<T>): { T }
	const values: { T } = {}
	for _, pool in { pools.FEMININE, pools.MASCULINE, pools.UNISEX } do
		if pool then
			for _, value in pool do
				table.insert(values, value)
			end
		end
	end
	return values
end

const function GetConversation(conversationId: string): QuestionDefinition?
	for _, conversation in TeacherConversations do
		if conversation.id == conversationId then
			return conversation
		end
	end
	return nil
end

const function Invoke(request: Request, owner: JanitorObject, generation: number, handler: RequestHandler)
	const requestPromise = request()
	owner:Add(function()
		requestPromise:cancel()
	end)
	requestPromise:andThen(function(result: unknown)
		if generation == Generation then
			handler(true, result)
		end
	end, function()
		if generation == Generation then
			handler(false, nil)
		end
	end)
end

const function ValidatePayload(value: unknown): TeachingMissionPayload?
	if type(value) ~= "table" then
		return nil
	end
	const payload = value :: { [string]: unknown }
	if not IsGuid(payload.sessionGuid) or typeof(payload.classroomCFrame) ~= "CFrame" then
		return nil
	end
	if
		payload.total ~= TeacherConfig.studentCount
		or type(payload.dialogues) ~= "table"
		or type(payload.studentCFrames) ~= "table"
	then
		return nil
	end
	const dialogues = payload.dialogues :: { unknown }
	const studentCFrames = payload.studentCFrames :: { [string]: unknown }
	if #dialogues ~= TeacherConfig.studentCount then
		return nil
	end

	const conversationIds: { [string]: boolean } = {}
	const npcGuids: { [string]: boolean } = {}
	for _, rawDialogue in dialogues do
		if type(rawDialogue) ~= "table" then
			return nil
		end
		const dialogue = rawDialogue :: { [string]: unknown }
		if
			not IsGuid(dialogue.npcGuid)
			or type(dialogue.conversationId) ~= "string"
			or type(dialogue.active) ~= "boolean"
		then
			return nil
		end
		const npcGuid = dialogue.npcGuid :: string
		const conversationId = dialogue.conversationId :: string
		if
			npcGuids[npcGuid]
			or conversationIds[conversationId]
			or not GetConversation(conversationId)
			or typeof(studentCFrames[npcGuid]) ~= "CFrame"
		then
			return nil
		end
		npcGuids[npcGuid] = true
		conversationIds[conversationId] = true
	end

	return value :: TeachingMissionPayload
end

const function DestroyMission(mission: MissionState)
	if ActiveMission == mission then
		PivotCharacter(Players.LocalPlayer, mission.returnCFrame)
		ActiveMission = nil
		DialogueController.close()
	end
	for _, binding in mission.bindings do
		binding.prompt.Enabled = false
	end
	mission.janitor:Destroy()
	table.clear(mission.bindings)
end

const function Stop(notifyServer: boolean)
	Generation += 1
	StartJanitor:Cleanup()
	const mission = ActiveMission
	if not mission then
		return
	end
	if notifyServer then
		if mission.exiting then
			return
		end
		mission.exiting = true
		mission.active = false
		for _, binding in mission.bindings do
			binding.prompt.Enabled = false
		end
		DialogueController.close()
		const sessionGuid = mission.sessionGuid
		DestroyMission(mission)
		Network.TeacherAbandon:request(sessionGuid):andThen(function() end, function() end)
		return
	end

	mission.active = false
	DestroyMission(mission)
end

const function FindPlayerLocation(classroom: Model): Attachment?
	const taggedAttachment = TaggedInstance.findAttachment(classroom, Tags.TEACHER_PLAYER_LOCATION)
	if taggedAttachment then
		return taggedAttachment
	end

	for _, location in classroom:QueryDescendants("MeshPart") do
		if location:IsA("MeshPart") and CollectionService:HasTag(location, Tags.TEACHER_PLAYER_LOCATION) then
			return location:FindFirstChildWhichIsA("Attachment")
		end
	end
	return nil
end

const function ConfigurePhysics(npc: Model)
	for _, descendant in npc:QueryDescendants("BasePart") do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
	const root = npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
end

const function PlaySittingAnimation(npc: Model, npcJanitor: JanitorObject)
	const humanoid = npc:FindFirstChildOfClass("Humanoid")
	const animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	const animation = npc:FindFirstChild("SitAnim", true)
	if not animator or not animation or not animation:IsA("Animation") then
		return
	end

	const succeeded, track = pcall(animator.LoadAnimation, animator, animation)
	if succeeded then
		track.Looped = true
		track:Play(0.15)
		npcJanitor:Add(function()
			track:Stop(0)
			track:Destroy()
		end)
	end
end

const function PlayIssueAnimation(npc: Model, npcJanitor: JanitorObject, random: Random): AnimationTrack?
	const humanoid = npc:FindFirstChildOfClass("Humanoid")
	const animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	const animations = npc:FindFirstChild("Animations")
	if not animator or not animations then
		return nil
	end

	const animationSources: { Instance } = {}
	for _, animationName in { "Left Arm Raise", "Right Arm Raise" } do
		const animationSource = animations:FindFirstChild(animationName)
		if animationSource and (animationSource:IsA("Animation") or animationSource:IsA("KeyframeSequence")) then
			table.insert(animationSources, animationSource)
		end
	end
	if #animationSources == 0 then
		return nil
	end

	const animationSource = animationSources[random:NextInteger(1, #animationSources)]
	local animation = animationSource
	local temporaryAnimation: Animation? = nil
	if animationSource:IsA("KeyframeSequence") then
		const registered, animationId =
			pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, animationSource)
		if not registered then
			return nil
		end

		temporaryAnimation = Instance.new("Animation")
		temporaryAnimation.AnimationId = animationId
		animation = temporaryAnimation
	end

	const loaded, track = pcall(animator.LoadAnimation, animator, animation :: Animation)
	if temporaryAnimation then
		temporaryAnimation:Destroy()
	end
	if not loaded then
		return nil
	end

	track.Priority = Enum.AnimationPriority.Action
	npcJanitor:Add(function()
		track:Stop(0)
		track:Destroy()
	end)
	return track
end

const function SetIssueAnimationRaised(binding: DialogueBinding, raised: boolean)
	const track = binding.issueTrack
	if not track then
		return
	end

	if raised then
		track:Play(0.15, 1, 0)
	else
		track:Stop(0.15)
	end
end

const function RefreshStudent(binding: DialogueBinding)
	binding.prompt.Enabled = binding.dialogue.active and not binding.busy
	SetIssueAnimationRaised(binding, binding.dialogue.active)
end

const function RandomizeAppearance(mission: MissionState, npc: Model, npcJanitor: JanitorObject)
	const appearanceThread = task.spawn(function()
		NPC.randomize(npc)
		if ActiveMission ~= mission or not mission.active or Generation ~= mission.generation then
			npc:Destroy()
		end
	end)
	npcJanitor:Add(function()
		if coroutine.status(appearanceThread) ~= "dead" then
			task.cancel(appearanceThread)
		end
	end)
end

const function ShowDialogue(mission: MissionState, binding: DialogueBinding)
	if ActiveMission ~= mission or not mission.active or mission.answerPending or not binding.prompt.Enabled then
		return
	end
	const question = GetConversation(binding.dialogue.conversationId)
	if not question then
		return
	end

	binding.busy = true
	binding.prompt.Enabled = false
	const choices: { DialogueTypes.Choice } = {}
	for _, choice in TableUtil.shuffled(question.choices, Random.new()) do
		table.insert(choices, { id = choice.id, text = choice.text })
	end
	const conversation: Conversation = {
		id = question.id,
		initialPromptId = "question",
		prompts = {
			question = {
				id = "question",
				text = question.prompt,
				choices = choices,
			},
		},
	}
	DialogueController.presentConversation(conversation, {
		title = binding.name,
		origin = binding.prompt.Parent,
		maxDistance = binding.prompt.MaxActivationDistance + 2,
	}, function(conversationResult: ConversationResult)
		if ActiveMission ~= mission or not mission.active or mission.generation ~= Generation then
			return
		end
		if conversationResult.reason ~= "completed" then
			binding.busy = false
			RefreshStudent(binding)
			return
		end

		const choiceId = conversationResult.answers.question
		local selectedChoice: TeacherConversations.ChoiceDefinition? = nil
		for _, choice in question.choices do
			if choice.id == choiceId then
				selectedChoice = choice
				break
			end
		end
		if not selectedChoice then
			binding.busy = false
			RefreshStudent(binding)
			return
		end
		const completedChoice = selectedChoice
		mission.answerPending = true

		Invoke(
			function()
				return Network.TeacherConversationComplete:request(
					mission.sessionGuid,
					binding.dialogue.npcGuid,
					choiceId
				)
			end,
			mission.janitor,
			mission.generation,
			function(succeeded: boolean, result: unknown)
				if ActiveMission ~= mission or not mission.active then
					return
				end
				mission.answerPending = false
				binding.busy = false
				RefreshStudent(binding)
				const validResponse = type(result) == "table"
					and type((result :: { [string]: unknown }).ok) == "boolean"
				if not succeeded or not validResponse then
					DialogueController.presentMessage("Teaching", "The answer could not be checked.", "Continue", nil)
					return
				end

				const response = result :: Response
				if not response.ok then
					DialogueController.presentMessage(
						"Teaching",
						response.error or "That response could not be checked.",
						"Continue",
						nil
					)
					return
				end

				mission.progress = response.progress or mission.progress
				mission.progressLabel.Text = `Questions answered: {mission.progress}/{mission.total}`
				if not response.correct then
					DialogueController.presentMessage(
						"",
						completedChoice.retryText or "That response did not address the student's question.",
						"Continue",
						nil
					)
					return
				end

				if response.missionCompleted then
					const reward = response.reward
					Stop(false)
					DialogueController.presentMessage(
						"Class complete!",
						if reward
							then `{CampaignConfig.COMPLETION_MESSAGE}\nYou've earned a reward: {reward}!`
							else `{CampaignConfig.COMPLETION_MESSAGE}\nMission complete, but your reward could not be granted.`,
						"Finish",
						nil
					)
					return
				end

				DialogueController.presentMessage(binding.name, question.successText, "Continue", nil)
			end
		)
	end)
	Network.TeacherQuestionShown:fire(mission.sessionGuid, binding.dialogue.npcGuid)
end

const function CreateNpc(
	mission: MissionState,
	template: Model,
	parent: Instance,
	studentCFrame: CFrame,
	dialogue: PublicDialogue,
	name: string,
	random: Random
)
	const npcJanitor = Janitor.new()
	const npc = template:Clone()
	mission.classroomJanitor:Add(npcJanitor, "Destroy", dialogue.npcGuid)
	npcJanitor:Add(npc)
	npc.Name = `Student_{name}`
	npc:SetAttribute("TeacherNpcGuid", dialogue.npcGuid)
	npc:PivotTo(studentCFrame)
	npc.Parent = parent
	ConfigurePhysics(npc)

	const humanoid = npc:FindFirstChildOfClass("Humanoid")
	const root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		npcJanitor:Destroy()
		return
	end
	humanoid.DisplayName = name
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	PlaySittingAnimation(npc, npcJanitor)
	const issueTrack = PlayIssueAnimation(npc, npcJanitor, random)

	const prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HelpStudent"
	prompt.ActionText = "Help student"
	prompt.ObjectText = name
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = root
	npcJanitor:Add(prompt)
	const binding: DialogueBinding = {
		dialogue = dialogue,
		busy = false,
		issueTrack = issueTrack,
		name = name,
		prompt = prompt,
	}
	mission.bindings[dialogue.npcGuid] = binding
	RefreshStudent(binding)
	npcJanitor:Add(function()
		mission.bindings[dialogue.npcGuid] = nil
	end)
	npcJanitor:Add(prompt.Triggered:Connect(function()
		const npcGuid = npc:GetAttribute("TeacherNpcGuid")
		if type(npcGuid) == "string" then
			const mappedBinding = mission.bindings[npcGuid]
			if mappedBinding then
				ShowDialogue(mission, mappedBinding)
			end
		end
	end))
	RandomizeAppearance(mission, npc, npcJanitor)
end

const function BuildMission(payload: TeachingMissionPayload): (boolean, string?)
	const classroomTemplate = Assets.models:FindFirstChild("Classroom")
	const npcTemplate = Assets.models:FindFirstChild("TeacherStudentTemplate")
	if not classroomTemplate or not classroomTemplate:IsA("Model") then
		return false, "The classroom asset could not be loaded."
	end
	if not npcTemplate or not npcTemplate:IsA("Model") then
		return false, "The student asset could not be loaded."
	end

	const classroom = classroomTemplate:Clone()
	const runtimeFolder = classroom:FindFirstChild("GeneratedStudents")
	const playerLocation = FindPlayerLocation(classroom)
	const character = Players.LocalPlayer.Character
	if not runtimeFolder then
		classroom:Destroy()
		return false, "The classroom asset is missing a required location."
	end
	if not playerLocation then
		classroom:Destroy()
		return false, "The classroom asset is missing its tagged player location."
	end
	if not character or not character.Parent then
		classroom:Destroy()
		return false, "Your character is not ready for the classroom."
	end

	const missionJanitor = Janitor.new()
	const classroomJanitor = Janitor.new()
	const hud = Assets.gui.campaign.screengui.TeachingMission:Clone()
	const mission: MissionState = {
		active = true,
		answerPending = false,
		exiting = false,
		generation = Generation,
		returnCFrame = character:GetPivot(),
		sessionGuid = payload.sessionGuid,
		progress = 0,
		total = payload.total,
		janitor = missionJanitor,
		classroomJanitor = classroomJanitor,
		bindings = {},
		progressLabel = hud.Container.Progress,
	}
	ActiveMission = mission
	mission.progressLabel.Text = `Questions answered: 0/{mission.total}`
	missionJanitor:Add(classroomJanitor)
	classroomJanitor:Add(classroom)
	classroomJanitor:Add(hud)
	classroomJanitor:Add(hud.Container.Leave.Activated:Connect(function()
		Stop(true)
	end))
	classroom:PivotTo(payload.classroomCFrame)
	classroom.Parent = workspace
	hud.Parent = Players.LocalPlayer.PlayerGui

	const random = Random.new()
	const dialogues = TableUtil.shuffled(payload.dialogues, random)
	const names = TableUtil.shuffled(FlattenPools(NpcConstants.NAMES), random)
	for studentIndex = 1, payload.total do
		CreateNpc(
			mission,
			npcTemplate,
			runtimeFolder,
			payload.studentCFrames[dialogues[studentIndex].npcGuid],
			dialogues[studentIndex],
			names[studentIndex],
			random
		)
	end
	if not PivotCharacter(Players.LocalPlayer, playerLocation.WorldCFrame) then
		DestroyMission(mission)
		return false, "Your character could not enter the classroom."
	end
	return true, nil
end

--Public Methods
const function Start(startToken: string)
	Stop(true)
	const generation = Generation
	DialogueController.presentQuestion("Teaching", "Preparing your classroom...", {}, function() end)
	Invoke(
		function()
			return Network.TeacherRequest:request(startToken)
		end,
		StartJanitor,
		generation,
		function(succeeded: boolean, result: unknown)
			DialogueController.close()
			const validResponse = type(result) == "table" and type((result :: { [string]: unknown }).ok) == "boolean"
			if not succeeded or not validResponse then
				DialogueController.presentMessage("Teaching", "The classroom could not be started.", "Close", nil)
				return
			end

			const response = result :: Response
			if not response.ok then
				DialogueController.presentMessage(
					"Teaching",
					response.error or "The classroom could not be started.",
					"Close",
					nil
				)
				return
			end
			const payload = ValidatePayload(response.payload)
			if not payload then
				const rawPayload = response.payload
				if type(rawPayload) == "table" and IsGuid(rawPayload.sessionGuid) then
					Network.TeacherAbandon:request(rawPayload.sessionGuid):andThen(function() end, function() end)
				end
				DialogueController.presentMessage("Teaching", "The classroom returned invalid data.", "Close", nil)
				return
			end

			const started, message = BuildMission(payload)
			if not started then
				Network.TeacherAbandon:request(payload.sessionGuid):andThen(function() end, function() end)
				DialogueController.presentMessage(
					"Teaching",
					message or "The classroom could not be created.",
					"Close",
					nil
				)
				return
			end

			Invoke(
				function()
					return Network.TeacherEnvironmentReady:request(payload.sessionGuid)
				end,
				StartJanitor,
				generation,
				function(environmentReady: boolean, rawReadyResponse: unknown)
					const validReadyResponse = type(rawReadyResponse) == "table"
						and type((rawReadyResponse :: { [string]: unknown }).ok) == "boolean"
					const readyResponse = if validReadyResponse then rawReadyResponse :: Response else nil
					if environmentReady and readyResponse and readyResponse.ok then
						return
					end
					Stop(true)
					DialogueController.presentMessage(
						"Teaching",
						if readyResponse
							then readyResponse.error or "The classroom could not be entered."
							else "The classroom could not be entered.",
						"Close",
						nil
					)
				end
			)
		end
	)
end

const function Init()
	ControllerJanitor:Add(StartJanitor)
	ControllerJanitor:Add(function()
		Stop(false)
	end)
	ControllerJanitor:LinkToInstance(script.Parent.Parent.Parent)
	ControllerJanitor:Add(
		Network.TeacherStudentsChanged:connect(function(sessionGuid: string, dialogues: { PublicDialogue })
			const mission = ActiveMission
			if not mission or not mission.active or mission.sessionGuid ~= sessionGuid then
				return
			end
			for _, dialogue in dialogues do
				const binding = mission.bindings[dialogue.npcGuid]
				if binding then
					binding.dialogue = dialogue
					RefreshStudent(binding)
				end
			end
		end)
	)
	ControllerJanitor:Add(Network.TeacherEnded:connect(function(sessionGuid: string, reason: string)
		const mission = ActiveMission
		if not mission or mission.sessionGuid ~= sessionGuid then
			return
		end
		Stop(false)
		if reason == "timeout" then
			DialogueController.presentMessage(
				"Classroom closed",
				"The classroom session expired. Speak to the Career Agent to begin again.",
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
