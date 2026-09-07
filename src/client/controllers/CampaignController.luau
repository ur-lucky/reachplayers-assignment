--Services
const Players = game:GetService("Players")

--Imports
const DialogueController = require("./DialogueController")
const IsCampaignEligible = require("../../shared/utils/funcs/isCampaignEligible")
const IsGuid = require("../../shared/utils/funcs/isGuid")
const Janitor = require("../../shared/Packages/Janitor")
const MissionTypes = require("../../shared/types/Mission")
const Network = require("../../shared/network")
const Signal = require("../../shared/Packages/Signal")
const TaggedInstance = require("../../shared/libraries/TaggedInstance")
const Tags = require("../../shared/constants/tags")

--Types
type Response = MissionTypes.Response

--Declarations
const ActiveChanged = Signal.new() :: Signal.Signal<boolean>
const Assets = script.Parent.Parent.Parent.assets
const BoothJanitor = Janitor.new()
const ControllerJanitor = Janitor.new()
const CampaignController = {
	activeChanged = ActiveChanged,
	active = false,
	campaignSessionGuid = nil :: string?,
}

local ActivationGeneration = 0
local ActivationPending = false

--Private Methods
const function UpdateRewardLabel(label: TextLabel)
	const tokens = Players.LocalPlayer:GetAttribute("FindJobCareerTokens")
	label.Text = `Career tokens: {if type(tokens) == "number" then tokens else 0}`
end

const function SetActive(active: boolean)
	if CampaignController.active == active then
		return
	end
	CampaignController.active = active
	ActiveChanged:Fire(active)
end

const function FindCareerPrompt(booth: Model): ProximityPrompt?
	return TaggedInstance.findProximityPrompt(booth, Tags.PROMPT, function(prompt: ProximityPrompt)
		return prompt:GetAttribute("DIALOGUE_ID") == "npc"
	end)
end

const function Activate(demo: boolean)
	if CampaignController.active or ActivationPending then
		return
	end
	if CampaignController.campaignSessionGuid then
		SetActive(true)
		return
	end

	ActivationPending = true
	ActivationGeneration += 1
	const activationGeneration = ActivationGeneration
	const requestPromise = Network.CampaignSessionRequest:request(demo):timeout(8)
	ControllerJanitor:Add(function()
		requestPromise:cancel()
	end)
	requestPromise:andThen(function(rawResponse: unknown)
		if activationGeneration ~= ActivationGeneration then
			return
		end
		ActivationPending = false
		if type(rawResponse) == "table" then
			const response = rawResponse :: Response
			if response.ok and IsGuid(response.campaignSessionGuid) then
				CampaignController.campaignSessionGuid = response.campaignSessionGuid
				SetActive(true)
				return
			end
			DialogueController.presentMessage("FindJob", response.error or "The campaign could not be loaded.", "Close", nil)
			return
		end
		DialogueController.presentMessage("FindJob", "The campaign could not be loaded. Please try again.", "Close", nil)
	end, function()
		if activationGeneration == ActivationGeneration then
			ActivationPending = false
			DialogueController.presentMessage("FindJob", "The campaign could not be loaded. Please try again.", "Close", nil)
		end
	end)
end

const function Deactivate()
	ActivationGeneration += 1
	ActivationPending = false
	SetActive(false)
end

--Public Methods
function CampaignController.getCampaignSessionGuid(): string?
	return CampaignController.campaignSessionGuid
end

-- Lifecycle Methods
function CampaignController.init()
	ControllerJanitor:Add(ActiveChanged)
	ControllerJanitor:Add(BoothJanitor)
	ControllerJanitor:LinkToInstance(script.Parent.Parent.Parent)
end

function CampaignController.start()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	ControllerJanitor:Add(ActiveChanged:Connect(function(active: boolean)
		BoothJanitor:Cleanup()
		if active then
			const campaignBooth = Assets.models.CampaignBooth:Clone()
			BoothJanitor:Add(campaignBooth)
			const prompt = FindCareerPrompt(campaignBooth)
			if prompt then
				BoothJanitor:Add(prompt.PromptShown:Connect(function()
					const campaignSessionGuid = CampaignController.getCampaignSessionGuid()
					if campaignSessionGuid then
						Network.CampaignPromptShown:fire(campaignSessionGuid)
					end
				end))
			end
			campaignBooth.Parent = workspace
		end
	end))

	const demoGui = Assets.gui.demo.screengui.DemoGui:Clone()
	demoGui.ResetOnSpawn = false
	const rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name = "CareerTokens"
	rewardLabel.AnchorPoint = Vector2.new(1, 0)
	rewardLabel.Position = UDim2.new(1, -16, 0, 16)
	rewardLabel.Size = UDim2.fromOffset(220, 36)
	rewardLabel.BackgroundColor3 = Color3.fromRGB(25, 33, 49)
	rewardLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rewardLabel.TextSize = 16
	rewardLabel.Parent = demoGui
	UpdateRewardLabel(rewardLabel)
	ControllerJanitor:Add(Players.LocalPlayer:GetAttributeChangedSignal("FindJobCareerTokens"):Connect(function()
		UpdateRewardLabel(rewardLabel)
	end))
	ControllerJanitor:Add(demoGui)
	ControllerJanitor:Add(demoGui.TextButton.Activated:Connect(function()
		if CampaignController.active or ActivationPending then
			Deactivate()
		else
			Activate(true)
		end
	end))
	demoGui.Parent = playerGui
	if IsCampaignEligible(Players.LocalPlayer, false) then
		Activate(false)
	end
end

return CampaignController
