--Services
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

--Imports
const DialogueTypes = require("../../shared/types/Dialogue")
const InstanceOrigin = require("../../shared/libraries/InstanceOrigin")
const Janitor = require("../../shared/Packages/Janitor")

--Types
type Choice = DialogueTypes.Choice
type ChoiceHandler = DialogueTypes.ChoiceHandler
type Conversation = DialogueTypes.Conversation
type ConversationHandler = DialogueTypes.ConversationHandler
type ConversationOptions = DialogueTypes.ConversationOptions
type EndReason = DialogueTypes.EndReason
type JanitorObject = typeof(Janitor.new())

type DialogueState = {
	janitor: JanitorObject,
	presentationJanitor: JanitorObject,
	screen: ScreenGui,
	conversation: Conversation?,
	conversationHandler: ConversationHandler?,
	conversationTitle: string?,
	answers: { [string]: string },
}

--Declarations
const Assets = script.Parent.Parent.Parent.assets
const ControllerJanitor = Janitor.new()
const DialogueController = {}

local ActiveGeneration = 0
local ActiveDialogue: DialogueState? = nil

--Private Methods
const function CloseDialogue(reason: EndReason)
	ActiveGeneration += 1
	const dialogue = ActiveDialogue
	if not dialogue then
		return
	end

	ActiveDialogue = nil
	const conversation = dialogue.conversation
	const conversationHandler = dialogue.conversationHandler
	dialogue.conversationHandler = nil
	dialogue.janitor:Destroy()
	if conversation and conversationHandler then
		conversationHandler({
			conversationId = conversation.id,
			answers = dialogue.answers,
			reason = reason,
		})
	end
end

const function StartDialogue(): DialogueState
	CloseDialogue("replaced")
	const janitor = Janitor.new()
	const presentationJanitor = Janitor.new()
	const screen = Assets.gui.campaign.screengui.Campaign:Clone()
	screen.ResetOnSpawn = false
	const dialogue: DialogueState = {
		janitor = janitor,
		presentationJanitor = presentationJanitor,
		screen = screen,
		conversation = nil,
		conversationHandler = nil,
		conversationTitle = nil,
		answers = {},
	}
	ActiveDialogue = dialogue
	janitor:Add(presentationJanitor)
	janitor:Add(screen)
	screen.Parent = Players.LocalPlayer.PlayerGui
	return dialogue
end

const function Present(title: string, prompt: string, choices: { Choice }, onChoice: ChoiceHandler)
	const dialogue = ActiveDialogue or StartDialogue()
	ActiveGeneration += 1
	const generation = ActiveGeneration
	const presentationJanitor = dialogue.presentationJanitor
	const screen = dialogue.screen
	const selectionTemplate = Assets.gui.campaign.templates.DialogueSelection
	const selections = screen.Holder.Selections
	presentationJanitor:Cleanup()

	screen.Holder.Prompt.TextLabel.Text = if title == "" then prompt else `{title}\n{prompt}`
	for choiceIndex, choice in choices do
		const selection = selectionTemplate:Clone()
		const button = selection.Button
		selection.LayoutOrder = choiceIndex
		selection.TextLabel.Text = choice.text
		selection.Parent = selections
		presentationJanitor:Add(selection)
		presentationJanitor:Add(button.Activated:Connect(function()
			if generation ~= ActiveGeneration then
				return
			end
			for _, sibling in selections:GetChildren() do
				const siblingButton = sibling:FindFirstChild("Button")
				if siblingButton and siblingButton:IsA("GuiButton") then
					siblingButton.Active = false
				end
			end
			onChoice(choice.id)
		end))
	end
end

const function PresentConversationPrompt(dialogue: DialogueState, promptId: string)
	const conversation = dialogue.conversation
	const title = dialogue.conversationTitle
	if not conversation or not title then
		return
	end
	const prompt = conversation.prompts[promptId]
	assert(prompt, `Conversation "{conversation.id}" is missing prompt "{promptId}"`)
	Present(title, prompt.text, prompt.choices, function(choiceId: string)
		if ActiveDialogue ~= dialogue then
			return
		end
		local selectedChoice: Choice? = nil
		for _, choice in prompt.choices do
			if choice.id == choiceId then
				selectedChoice = choice
				break
			end
		end
		if not selectedChoice then
			return
		end
		dialogue.answers[prompt.id] = selectedChoice.id
		if selectedChoice.nextPromptId then
			PresentConversationPrompt(dialogue, selectedChoice.nextPromptId)
		else
			CloseDialogue("completed")
		end
	end)
end

const function ShowMessage(title: string, message: string, buttonText: string, onContinue: (() -> ())?)
	Present(title, message, { { id = "continue", text = buttonText } }, function()
		if onContinue then
			onContinue()
		else
			CloseDialogue("completed")
		end
	end)
end

--Public Methods
function DialogueController.close(reason: EndReason?)
	CloseDialogue(reason or "closed")
end

function DialogueController.presentConversation(
	conversation: Conversation,
	options: ConversationOptions,
	onEnded: ConversationHandler
)
	const dialogue = StartDialogue()
	dialogue.conversation = conversation
	dialogue.conversationHandler = onEnded
	dialogue.conversationTitle = options.title

	const origin = options.origin
	if origin then
		const maxDistance = options.maxDistance or 12
		dialogue.janitor:Add(RunService.Heartbeat:Connect(function()
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			const originPosition = if origin.Parent then InstanceOrigin.getPosition(origin) else nil
			if not root or not root:IsA("BasePart") or not originPosition then
				CloseDialogue("distance")
				return
			end
			if (root.Position - originPosition).Magnitude > maxDistance then
				CloseDialogue("distance")
			end
		end))
	end

	PresentConversationPrompt(dialogue, conversation.initialPromptId)
end

function DialogueController.presentMessage(title: string, message: string, buttonText: string, onContinue: (() -> ())?)
	ShowMessage(title, message, buttonText, onContinue)
end

function DialogueController.presentQuestion(title: string, prompt: string, choices: { Choice }, onChoice: ChoiceHandler)
	Present(title, prompt, choices, onChoice)
end

-- Lifecycle Methods
function DialogueController.init()
	ControllerJanitor:Add(function()
		CloseDialogue("closed")
	end)
	ControllerJanitor:LinkToInstance(script.Parent.Parent.Parent)
end

return DialogueController
