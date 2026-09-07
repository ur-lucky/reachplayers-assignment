--Imports
const DialogueTypes = require("../../types/Dialogue")

--Declarations
const Career: DialogueTypes.Conversation = {
	id = "career",
	initialPromptId = "challenge",
	prompts = {
		challenge = {
			id = "challenge",
			text = "Which challenge sounds more satisfying?",
			choices = {
				{
					id = "challenge_a",
					text = "Untangling a tricky problem",
					nextPromptId = "outcome",
				},
				{
					id = "challenge_b",
					text = "Helping someone understand an idea",
					nextPromptId = "outcome",
				},
			},
		},
		outcome = {
			id = "outcome",
			text = "At the end of a good day, what would make you proudest?",
			choices = {
				{ id = "outcome_a", text = "I built something that works" },
				{ id = "outcome_b", text = "I helped someone grow in confidence" },
			},
		},
	},
}

return Career
