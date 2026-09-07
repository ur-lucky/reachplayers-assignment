--Imports
const CampaignController = require("./CampaignController")
const CareerConversation = require("../../shared/constants/conversations/Career")
const DialogueController = require("./DialogueController")
const DialogueTypes = require("../../shared/types/Dialogue")
const Janitor = require("../../shared/Packages/Janitor")
const MissionTypes = require("../../shared/types/Mission")
const Network = require("../../shared/network")
const Observers = require("../../shared/Packages/Observers")
const Signal = require("../../shared/Packages/Signal")
const Tags = require("../../shared/constants/tags")

--Types
type ConversationResult = DialogueTypes.ConversationResult
type Response = MissionTypes.Response

--Declarations
const CareerClassified = Signal.new() :: Signal.Signal<string, string?>
const ControllerJanitor = Janitor.new()
const RequestJanitor = Janitor.new()
const CareerController = {
	careerClassified = CareerClassified,
}

local RequestGeneration = 0

--Private Methods
const function CancelRequest()
	RequestGeneration += 1
	RequestJanitor:Cleanup()
end

const function ShowCareerError()
	DialogueController.presentMessage(
		"Career Agent",
		"The Career Agent could not continue. Please try again.",
		"Close",
		nil
	)
end

const function RecordCareerResultShown()
	const campaignSessionGuid = CampaignController.getCampaignSessionGuid()
	if campaignSessionGuid then
		Network.CareerResultShown:fire(campaignSessionGuid)
	end
end

const function ProcessCareerResponse(response: Response)
	if not response.ok then
		DialogueController.presentMessage(
			"Career Agent",
			response.error or "The conversation could not continue.",
			"Close",
			nil
		)
		return
	end

	if response.profession == "teaching" and response.teachingStartToken then
		const startToken = response.teachingStartToken
		DialogueController.presentMessage(
			"Your match: Teaching",
			"You enjoy helping people understand ideas. Help ten students work through a question.",
			"Enter classroom",
			function()
				DialogueController.close()
				CareerClassified:Fire("teaching", startToken)
			end
		)
		RecordCareerResultShown()
		return
	end

	if response.profession == "softwareEngineering" and response.softwareEngineerStartToken then
		const startToken = response.softwareEngineerStartToken
		DialogueController.presentMessage(
			"Your match: Software Engineering",
			"You enjoy solving structured problems and building things that work. Program three routes through an office laptop.",
			"Enter office",
			function()
				DialogueController.close()
				CareerClassified:Fire("softwareEngineering", startToken)
			end
		)
		RecordCareerResultShown()
		return
	end

	ShowCareerError()
end

const function FinishConversation(result: ConversationResult)
	if result.reason ~= "completed" then
		return
	end

	CancelRequest()
	const requestGeneration = RequestGeneration
	DialogueController.presentQuestion("Career Agent", "Finding your match...", {}, function() end)
	const requestPromise = Network.CareerComplete:request(CampaignController.getCampaignSessionGuid(), result.answers)
	RequestJanitor:Add(function()
		requestPromise:cancel()
	end)
	requestPromise:andThen(function(rawResponse: unknown)
		if requestGeneration ~= RequestGeneration then
			return
		end
		if type(rawResponse) ~= "table" or type((rawResponse :: { [string]: unknown }).ok) ~= "boolean" then
			ShowCareerError()
			return
		end
		ProcessCareerResponse(rawResponse :: Response)
	end, function()
		if requestGeneration == RequestGeneration then
			ShowCareerError()
		end
	end)
end

const function StartCareerDialogue(prompt: ProximityPrompt)
	CancelRequest()
	DialogueController.presentConversation(CareerConversation, {
		title = "Career Agent",
		origin = prompt.Parent,
		maxDistance = prompt.MaxActivationDistance + 2,
	}, FinishConversation)
end

-- Lifecycle Methods
function CareerController.init()
	ControllerJanitor:Add(CareerClassified)
	ControllerJanitor:Add(Network, "destroy")
	ControllerJanitor:Add(RequestJanitor)
	ControllerJanitor:LinkToInstance(script.Parent.Parent.Parent)
end

function CareerController.start()
	ControllerJanitor:Add(CampaignController.activeChanged:Connect(function(active: boolean)
		if not active then
			CancelRequest()
			DialogueController.close()
		end
	end))
	ControllerJanitor:Add(Observers.observeTag(Tags.PROMPT, function(prompt: ProximityPrompt)
		const promptJanitor = Janitor.new()
		if prompt:GetAttribute("DIALOGUE_ID") == "npc" then
			promptJanitor:Add(prompt.Triggered:Connect(function()
				StartCareerDialogue(prompt)
				const campaignSessionGuid = CampaignController.getCampaignSessionGuid()
				if campaignSessionGuid then
					Network.CampaignPromptTriggered:fire(campaignSessionGuid)
				end
			end))
		end
		return function()
			promptJanitor:Destroy()
		end
	end, { workspace }))
end

return CareerController
