--Services
const HttpService = game:GetService("HttpService")

--Imports
const Dependencies = require("../Dependencies").get()
const AllowRateLimit = require(Dependencies.shared.utils.funcs.allowRateLimit)
const CampaignConfig = require(Dependencies.shared.constants.campaign)
const IsGuid = require(Dependencies.shared.utils.funcs.isGuid)

--Types
export type Properties = { [string]: string | number | boolean }
export type Context = {
	campaignSessionGuid: string?,
	missionSessionGuid: string?,
	missionId: string?,
	profession: string?,
	properties: Properties?,
}

type AnalyticsState = {
	campaignSessionGuid: string?,
	demo: boolean,
	rateWindowStartedAt: number,
	rateCount: number,
}

--Declarations
const AllowedEvents: { [string]: boolean } = {
	campaign_engaged = true,
	campaign_impression = true,
	career_classified = true,
	career_completed = true,
	mission_abandoned = true,
	mission_completed = true,
	mission_invalid_action = true,
	mission_progress = true,
	mission_started = true,
	reward_failed = true,
	reward_granted = true,
	software_engineer_game_loaded = true,
	software_engineer_laptop_triggered = true,
	software_engineer_laptop_viewed = true,
	software_engineer_round_completed = true,
	software_engineer_route_attempted = true,
	teacher_answered = true,
	teacher_question_viewed = true,
	teacher_student_completed = true,
}
const AnalyticsService = {}
const PlayerStates: { [Player]: AnalyticsState } = {}

--Private Methods
const function GetState(player: Player): AnalyticsState
	const existingState = PlayerStates[player]
	if existingState then
		return existingState
	end

	const state: AnalyticsState = {
		campaignSessionGuid = nil,
		demo = false,
		rateWindowStartedAt = os.clock(),
		rateCount = 0,
	}
	PlayerStates[player] = state
	return state
end

const function SanitizeProperties(properties: Properties?): Properties
	const safeProperties: Properties = {}
	if type(properties) ~= "table" then
		return safeProperties
	end
	local propertyCount = 0
	for key, value in properties do
		if propertyCount >= 24 then
			break
		end
		const valueType = type(value)
		const validNumber = valueType ~= "number" or (value == value and value ~= math.huge and value ~= -math.huge)
		if
			type(key) == "string"
			and #key <= 32
			and (valueType == "string" or valueType == "number" or valueType == "boolean")
			and validNumber
		then
			safeProperties[key] = if valueType == "string" then string.sub(value :: string, 1, 128) else value
			propertyCount += 1
		end
	end
	return safeProperties
end

const function Emit(player: Player, eventName: string, context: Context?)
	if not AllowedEvents[eventName] then
		return
	end

	const state = GetState(player)
	const eventContext = context or {}
	if eventContext.campaignSessionGuid and eventContext.campaignSessionGuid ~= state.campaignSessionGuid then
		return
	end

	const details: { [string]: string | number | boolean } = SanitizeProperties(eventContext.properties)
	const host = script:FindFirstAncestorOfClass("DataModel") :: DataModel
	details.campaignId = CampaignConfig.ID
	details.demo = state.demo
	details.universeId = host.GameId
	details.placeId = host.PlaceId
	details.serverId = host.JobId
	details.timestampMs = DateTime.now().UnixTimestampMillis
	if eventContext.campaignSessionGuid then
		details.campaignSessionGuid = eventContext.campaignSessionGuid
	end
	if eventContext.missionSessionGuid then
		details.missionSessionGuid = eventContext.missionSessionGuid
	end
	if eventContext.missionId then
		details.missionId = string.sub(eventContext.missionId, 1, 64)
	end
	if eventContext.profession then
		details.profession = string.sub(eventContext.profession, 1, 64)
	end

	print(`[FindJob Analytics] {player.Name} ({player.UserId}) | {eventName} | {HttpService:JSONEncode(details)}`)
end

--Public Methods
function AnalyticsService.createCampaignSession(player: Player, demo: boolean?): string
	const state = GetState(player)
	if not state.campaignSessionGuid then
		state.campaignSessionGuid = HttpService:GenerateGUID(false)
		state.demo = demo == true
	end
	return state.campaignSessionGuid
end

function AnalyticsService.ownsCampaignSession(player: Player, rawSessionGuid: unknown): boolean
	const state = PlayerStates[player]
	return state ~= nil and IsGuid(rawSessionGuid) and state.campaignSessionGuid == rawSessionGuid
end

function AnalyticsService.canAcceptReceipt(player: Player): boolean
	const state = PlayerStates[player]
	if not state then
		return false
	end
	return AllowRateLimit(state, CampaignConfig.RECEIPT_LIMIT, CampaignConfig.RECEIPT_WINDOW_SECONDS)
end

function AnalyticsService.track(player: Player, eventName: string, context: Context?)
	const succeeded = pcall(Emit, player, eventName, context)
	if not succeeded then
		warn("A FindJob analytics event could not be printed")
	end
end

function AnalyticsService.removePlayer(player: Player)
	PlayerStates[player] = nil
end

function AnalyticsService.shutdown()
	table.clear(PlayerStates)
end

return AnalyticsService
