--Services
const LocalizationService = game:GetService("LocalizationService")
const RunService = game:GetService("RunService")

--Imports
const CampaignConfig = require("../../constants/campaign")

--Public Methods
const function IsCampaignEligible(player: Player, allowStudio: boolean): boolean
	if allowStudio and RunService:IsStudio() then
		return true
	end
	const succeeded, locale = pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
	return succeeded
		and type(locale) == "string"
		and table.find(CampaignConfig.OPERATING_LOCALES, string.lower(locale)) ~= nil
end

return IsCampaignEligible
