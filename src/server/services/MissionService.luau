--Services
const Players = game:GetService("Players")

--Imports
const AnalyticsService = require("./AnalyticsService")
const CareerKeys = require("../missions/CareerKeys")
const Dependencies = require("../Dependencies").get()
const AllowRateLimit = require(Dependencies.shared.utils.funcs.allowRateLimit)
const CampaignConfig = require(Dependencies.shared.constants.campaign)
const InstanceOrigin = require(Dependencies.shared.libraries.InstanceOrigin)
const IsCampaignEligible = require(Dependencies.shared.utils.funcs.isCampaignEligible)
const Janitor = require(Dependencies.shared.Packages.Janitor)
const MissionRuntime = require("../libraries/MissionRuntime")
const MissionTypes = require(Dependencies.shared.types.Mission)
const Network = require(Dependencies.shared.network)
const SoftwareEngineer = require("../missions/SoftwareEngineer")
const TaggedInstance = require(Dependencies.shared.libraries.TaggedInstance)
const Tags = require(Dependencies.shared.constants.tags)
const Teacher = require("../missions/Teacher")

--Types
type Response = MissionTypes.Response

type CampaignSession = {
	campaignSessionGuid: string,
	impressionRecorded: boolean,
	engagementRecorded: boolean,
	careerCompleted: boolean,
	careerClassified: boolean,
	profession: string?,
	rateWindowStartedAt: number,
	rateCount: number,
}

--Declarations
const Assets = Dependencies.assets
const CampaignSessions: { [Player]: CampaignSession } = {}
const MissionService = {}
const ServiceJanitor = Janitor.new()

--Private Methods
const function FindCampaignPrompt(): ProximityPrompt?
	const booth = Assets.models:FindFirstChild("CampaignBooth")
	if not booth then
		return nil
	end
	return TaggedInstance.findProximityPrompt(booth, Tags.PROMPT, function(prompt: ProximityPrompt)
		return prompt:GetAttribute("DIALOGUE_ID") == "npc"
	end)
end

const function IsNearPrompt(player: Player): boolean
	const prompt = FindCampaignPrompt()
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	const origin = if prompt then prompt.Parent else nil
	const originPosition = if origin then InstanceOrigin.getPosition(origin) else nil
	return prompt ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and originPosition ~= nil
		and (root.Position - originPosition).Magnitude <= prompt.MaxActivationDistance + 3
end

const function GetReceiptSession(player: Player, rawSessionGuid: unknown): CampaignSession?
	const session = CampaignSessions[player]
	if
		not session
		or not AnalyticsService.ownsCampaignSession(player, rawSessionGuid)
		or session.campaignSessionGuid ~= rawSessionGuid
	then
		return nil
	end
	return session
end

const function RequestCampaignSession(player: Player, rawDemo: unknown): Response
	const existingSession = CampaignSessions[player]
	if existingSession then
		return { ok = true, campaignSessionGuid = existingSession.campaignSessionGuid }
	end
	const demo = rawDemo == true and CampaignConfig.DEMO_MODE
	if not demo and not IsCampaignEligible(player, true) then
		return MissionRuntime.failure("campaign_ineligible", "The FindJob campaign is not available in your region.")
	end
	if player.Parent ~= Players then
		return MissionRuntime.failure("player_unavailable", "The player has left the server.")
	end

	const sessionAfterEligibility = CampaignSessions[player]
	if sessionAfterEligibility then
		return { ok = true, campaignSessionGuid = sessionAfterEligibility.campaignSessionGuid }
	end
	const created, rawCampaignSessionGuid = pcall(AnalyticsService.createCampaignSession, player, demo)
	if not created or type(rawCampaignSessionGuid) ~= "string" then
		return MissionRuntime.failure("analytics_unavailable", "Campaign analytics are temporarily unavailable.")
	end
	const campaignSessionGuid = rawCampaignSessionGuid :: string
	CampaignSessions[player] = {
		campaignSessionGuid = campaignSessionGuid,
		impressionRecorded = false,
		engagementRecorded = false,
		careerCompleted = false,
		careerClassified = false,
		profession = nil,
		rateWindowStartedAt = 0,
		rateCount = 0,
	}
	return { ok = true, campaignSessionGuid = campaignSessionGuid }
end

const function RecordCampaignPromptShown(player: Player, rawSessionGuid: unknown)
	const session = GetReceiptSession(player, rawSessionGuid)
	if
		not session
		or session.impressionRecorded
		or not IsNearPrompt(player)
		or not AnalyticsService.canAcceptReceipt(player)
	then
		return
	end
	session.impressionRecorded = true
	AnalyticsService.track(player, "campaign_impression", {
		campaignSessionGuid = session.campaignSessionGuid,
		properties = { stageIndex = 1 },
	})
end

const function RecordCampaignPromptTriggered(player: Player, rawSessionGuid: unknown)
	const session = GetReceiptSession(player, rawSessionGuid)
	if
		not session
		or not session.impressionRecorded
		or session.engagementRecorded
		or not IsNearPrompt(player)
		or not AnalyticsService.canAcceptReceipt(player)
	then
		return
	end
	session.engagementRecorded = true
	AnalyticsService.track(player, "campaign_engaged", {
		campaignSessionGuid = session.campaignSessionGuid,
		properties = { stageIndex = 2 },
	})
end

const function RecordCareerResultShown(player: Player, rawSessionGuid: unknown)
	const session = GetReceiptSession(player, rawSessionGuid)
	if
		not session
		or not session.careerCompleted
		or not session.profession
		or session.careerClassified
		or not AnalyticsService.canAcceptReceipt(player)
	then
		return
	end
	session.careerClassified = true
	AnalyticsService.track(player, "career_classified", {
		campaignSessionGuid = session.campaignSessionGuid,
		profession = session.profession,
		properties = { stageIndex = 4 },
	})
end

const function CompleteCareer(player: Player, rawCampaignSessionGuid: unknown, rawAnswers: unknown): Response
	if type(rawAnswers) ~= "table" then
		return MissionRuntime.failure("invalid_career_answers", "The completed conversation was malformed.")
	end
	const answers = rawAnswers :: { [string]: unknown }
	if type(answers.challenge) ~= "string" or type(answers.outcome) ~= "string" then
		return MissionRuntime.failure(
			"invalid_career_answers",
			"The completed conversation contained an invalid response."
		)
	end
	const firstProfession = CareerKeys.challenge[answers.challenge :: string]
	const secondProfession = CareerKeys.outcome[answers.outcome :: string]
	if not firstProfession or not secondProfession then
		return MissionRuntime.failure(
			"invalid_career_answers",
			"The completed conversation contained an invalid response."
		)
	end

	const campaignSession = GetReceiptSession(player, rawCampaignSessionGuid)
	if not campaignSession then
		return MissionRuntime.failure("invalid_campaign_session", "Load the campaign before speaking to the Career Agent.")
	end
	if not IsNearPrompt(player) then
		return MissionRuntime.failure("not_near_agent", "Move closer to the Career Agent to continue.")
	end
	if not AllowRateLimit(campaignSession, 6, 2) then
		return MissionRuntime.failure("rate_limited", "Please wait a moment before starting another career conversation.")
	end
	const campaignSessionGuid = campaignSession.campaignSessionGuid

	SoftwareEngineer.reset(player, "replaced")
	Teacher.reset(player, "replaced")
	-- A split match follows the player's preferred outcome from the second question.
	const profession = if firstProfession == secondProfession then firstProfession else secondProfession
	const response: Response = { ok = true, profession = profession }
	if profession == "teaching" then
		response.teachingStartToken = Teacher.issueToken(player, campaignSessionGuid)
	elseif profession == "softwareEngineering" then
		response.softwareEngineerStartToken = SoftwareEngineer.issueToken(player, campaignSessionGuid)
	end

	if not campaignSession.careerCompleted then
		campaignSession.careerCompleted = true
		campaignSession.profession = profession
		AnalyticsService.track(player, "career_completed", {
			campaignSessionGuid = campaignSessionGuid,
			profession = profession,
			properties = { stageIndex = 3, challengeAnswer = answers.challenge, outcomeAnswer = answers.outcome },
		})
	end
	return response
end

-- Lifecycle Methods
function MissionService.init()
	Network.CampaignSessionRequest:onRequest(RequestCampaignSession)
	Network.CareerComplete:onRequest(CompleteCareer)
	Network.SoftwareEngineerAbandon:onRequest(SoftwareEngineer.abandon)
	Network.SoftwareEngineerAnimationComplete:onRequest(SoftwareEngineer.completeAnimation)
	Network.SoftwareEngineerAttempt:onRequest(SoftwareEngineer.attempt)
	Network.SoftwareEngineerEnvironmentReady:onRequest(SoftwareEngineer.enterEnvironment)
	Network.SoftwareEngineerRequest:onRequest(SoftwareEngineer.request)
	Network.SoftwareEngineerSeedsRequest:onRequest(SoftwareEngineer.requestSeeds)
	Network.TeacherAbandon:onRequest(Teacher.abandon)
	Network.TeacherRequest:onRequest(Teacher.request)
	Network.TeacherConversationComplete:onRequest(Teacher.completeConversation)
	Network.TeacherEnvironmentReady:onRequest(Teacher.enterEnvironment)
	ServiceJanitor:Add(Network.CampaignPromptShown:connect(RecordCampaignPromptShown))
	ServiceJanitor:Add(Network.CampaignPromptTriggered:connect(RecordCampaignPromptTriggered))
	ServiceJanitor:Add(Network.CareerResultShown:connect(RecordCareerResultShown))
	ServiceJanitor:Add(Network.SoftwareEngineerBoardShown:connect(SoftwareEngineer.boardShown))
	ServiceJanitor:Add(Network.SoftwareEngineerLaptopShown:connect(SoftwareEngineer.laptopShown))
	ServiceJanitor:Add(Network.TeacherQuestionShown:connect(Teacher.questionShown))
	ServiceJanitor:Add(Network, "destroy")
end

function MissionService.start()
	ServiceJanitor:Add(function()
		SoftwareEngineer.shutdown()
		Teacher.shutdown()
		table.clear(CampaignSessions)
		AnalyticsService.shutdown()
	end)
	ServiceJanitor:LinkToInstance(script.Parent.Parent)
	ServiceJanitor:Add(Players.PlayerRemoving:Connect(function(player: Player)
		SoftwareEngineer.removePlayer(player)
		Teacher.removePlayer(player)
		CampaignSessions[player] = nil
		AnalyticsService.removePlayer(player)
	end))
end

return MissionService
