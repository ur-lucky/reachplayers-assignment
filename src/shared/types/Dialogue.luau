--Types
export type Choice = {
	id: string,
	text: string,
	nextPromptId: string?,
}

export type ChoiceHandler = (choiceId: string) -> ()

export type Prompt = {
	id: string,
	text: string,
	choices: { Choice },
}

export type Conversation = {
	id: string,
	initialPromptId: string,
	prompts: { [string]: Prompt },
}

export type EndReason = "completed" | "closed" | "distance" | "replaced"

export type ConversationResult = {
	conversationId: string,
	answers: { [string]: string },
	reason: EndReason,
}

export type ConversationHandler = (result: ConversationResult) -> ()

export type ConversationOptions = {
	title: string,
	origin: Instance?,
	maxDistance: number?,
}

return {}
