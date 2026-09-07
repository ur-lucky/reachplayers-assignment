--Imports
const Dependencies = require("../Dependencies").get()
const Janitor = require(Dependencies.shared.Packages.Janitor)

--Types
export type RewardContext = {
	sessionGuid: string,
	missionId: string,
	profession: string,
}

export type RewardHandler = (player: Player, context: RewardContext) -> (boolean, string)

--Declarations
const CampaignService = {}
const RewardReceipts: { [string]: string } = {}
const ServiceJanitor = Janitor.new()
local RewardHandler: RewardHandler? = nil

--Private Methods
const function DefaultRewardHandler(player: Player, _context: RewardContext): (boolean, string)
	const currentTokens = player:GetAttribute("FindJobCareerTokens")
	const tokens = if type(currentTokens) == "number" then currentTokens else 0
	player:SetAttribute("FindJobCareerTokens", tokens + 1)
	return true, "Career Explorer Token"
end

--Public Methods
function CampaignService.setRewardHandler(handler: RewardHandler)
	RewardHandler = handler
end

function CampaignService.grantReward(player: Player, context: RewardContext): (boolean, string)
	const existingReceipt = RewardReceipts[context.sessionGuid]
	if existingReceipt then
		return true, existingReceipt
	end

	const succeeded, granted, receipt = pcall(RewardHandler or DefaultRewardHandler, player, context)
	if not succeeded or type(granted) ~= "boolean" or type(receipt) ~= "string" then
		warn("The campaign reward handler failed or returned an invalid result")
		return false, "Reward unavailable"
	end
	if granted then
		RewardReceipts[context.sessionGuid] = receipt
		const receiptThread = task.delay(300, function()
			if RewardReceipts[context.sessionGuid] == receipt then
				RewardReceipts[context.sessionGuid] = nil
			end
		end)
		ServiceJanitor:Add(receiptThread)
	end

	return granted, receipt
end

-- Lifecycle Methods
function CampaignService.init()
	ServiceJanitor:Add(function()
		table.clear(RewardReceipts)
		RewardHandler = DefaultRewardHandler
	end)
	ServiceJanitor:LinkToInstance(script.Parent.Parent)
end

return CampaignService
