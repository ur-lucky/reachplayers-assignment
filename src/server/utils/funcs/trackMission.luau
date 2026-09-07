--Imports
const AnalyticsService = require("../../services/AnalyticsService")

--Types
export type Definition = {
	id: string,
	profession: string,
}

export type Session = {
	campaignSessionGuid: string?,
	sessionGuid: string,
}

--Public Methods
const function TrackMission(
	player: Player,
	eventName: string,
	session: Session,
	definition: Definition,
	properties: AnalyticsService.Properties?
)
	const campaignSessionGuid = session.campaignSessionGuid
	if not campaignSessionGuid or not AnalyticsService.ownsCampaignSession(player, campaignSessionGuid) then
		return
	end
	AnalyticsService.track(player, eventName, {
		campaignSessionGuid = campaignSessionGuid,
		missionSessionGuid = session.sessionGuid,
		missionId = definition.id,
		profession = definition.profession,
		properties = properties,
	})
end

return TrackMission
