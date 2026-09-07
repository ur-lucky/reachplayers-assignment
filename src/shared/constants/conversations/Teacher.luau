--Types
export type ChoiceDefinition = {
	id: string,
	text: string,
	retryText: string?,
}

export type QuestionDefinition = {
	id: string,
	prompt: string,
	choices: { ChoiceDefinition },
	successText: string,
}

--Declarations
const Questions: { QuestionDefinition } = {
	{
		id = "equal_groups",
		prompt = "I got another algebra question wrong. How can I improve if I keep making mistakes?",
		choices = {
			{ id = "choice_7d1", text = "Show me your steps. We'll find where you got stuck and try a similar problem." },
			{
				id = "add_three",
				text = "Memorise the answer to this problem so you'll remember it next time.",
				retryText = "Remembering one answer won't help with different numbers. Help the student understand the steps.",
			},
			{
				id = "memorise",
				text = "Do ten more problems using the same method, then check your answers.",
				retryText = "More practice could repeat the same mistake. First, help the student find what went wrong.",
			},
		},
		successText = "Now I know which step to work on. I'll try another problem using what we checked.",
	},
	{
		id = "fraction_first_mistake",
		prompt = "I got a different answer from my group in maths. How do I check whether my method works?",
		choices = {
			{ id = "choice_4b8", text = "Talk me through your method. We'll check each step against the question." },
			{
				id = "restart",
				text = "Use the group's answer because more people agreed on it.",
				retryText = "Several people can make the same mistake. Check the reasoning, not the number of votes.",
			},
			{
				id = "answer",
				text = "Check only the final answer in the answer key.",
				retryText = "The final answer alone won't show whether the method works. Look at the steps too.",
			},
		},
		successText = "I can explain my steps and check them, even when my answer is different.",
	},
	{
		id = "main_idea",
		prompt = "I understand the events in this article, but how do I find its main idea?",
		choices = {
			{ id = "choice_9f2", text = "Look for what the key details have in common. Sum up the writer's main point in one sentence." },
			{
				id = "first",
				text = "Use the first sentence. It always gives the main idea.",
				retryText = "The opening might be a question or example. Check which idea the whole article supports.",
			},
			{
				id = "longest",
				text = "Pick the most surprising fact and use that as the main idea.",
				retryText = "An interesting fact may be only one detail. The main idea connects the key details.",
			},
		},
		successText = "I'll write one sentence that connects the key details, then check it against the article.",
	},
	{
		id = "spelling_strategy",
		prompt = "I have to present my project, but I'm worried I'll forget what to say. How should I prepare?",
		choices = {
			{ id = "choice_1c6", text = "Make brief notes for each main point and practise aloud. You can pause to check your notes." },
			{
				id = "copy",
				text = "Memorise every word so you won't need a backup plan.",
				retryText = "Forgetting one word could leave the student stuck. Suggest a way to find their place again.",
			},
			{
				id = "guess",
				text = "Put the full script on your slides and read it to the class.",
				retryText = "Crowded slides can be hard to follow. Help the student practise explaining the main points.",
			},
		},
		successText = "I'll practise with short notes so I have something to check if I lose my place.",
	},
	{
		id = "perimeter_area",
		prompt = "For a rectangular garden, when do I use perimeter and when do I use area?",
		choices = {
			{ id = "choice_8a3", text = "Perimeter measures the edge for a fence. Area measures the space inside for grass." },
			{
				id = "swapped",
				text = "Use perimeter for the grass and area for the fence.",
				retryText = "Those are reversed. A fence follows the edge; grass covers the space inside.",
			},
			{
				id = "same",
				text = "Use length times width for both the fence and the grass.",
				retryText = "Length times width gives area. To find perimeter, add the lengths of all four sides.",
			},
		},
		successText = "A fence needs the distance around the garden. Grass needs the area inside, measured in square units.",
	},
	{
		id = "context_clues",
		prompt = "This sentence says, 'Unlike his outgoing sister, Amir was reserved.' What does 'reserved' mean here?",
		choices = {
			{ id = "choice_5e9", text = "It means quiet or private here. 'Unlike' shows a contrast with his outgoing sister." },
			{
				id = "skip",
				text = "It means booked in advance, like a reserved seat.",
				retryText = "That meaning fits a seat, but this sentence describes a person's behaviour.",
			},
			{
				id = "sound",
				text = "It means friendly and talkative, like his sister.",
				retryText = "The word 'unlike' tells us the two people are different in this way.",
			},
		},
		successText = "The contrast helps me choose the meaning that fits the sentence.",
	},
	{
		id = "fair_experiment",
		prompt = "I'm testing whether light affects plant growth. Should I also give each plant a different amount of water?",
		choices = {
			{ id = "choice_2d7", text = "Keep the water and other conditions the same. Change only the light so you can compare its effect." },
			{
				id = "everything",
				text = "Yes. Change the water too, so you can test both things at once.",
				retryText = "If light and water both change, you won't know which caused a difference in growth.",
			},
			{
				id = "favorite",
				text = "Give extra water to any plant that looks smaller during the test.",
				retryText = "Changing the water partway through would make it harder to compare the effect of light.",
			},
		},
		successText = "I'll change the light and keep the other conditions the same to make a fair comparison.",
	},
	{
		id = "measurable_hypothesis",
		prompt = "My science prediction is 'Plants like music.' How can I make it something I can test?",
		choices = {
			{ id = "choice_6f4", text = "Predict a measurable result: plants with music will grow taller in two weeks than plants without it." },
			{
				id = "vague",
				text = "Change it to 'Plants enjoy soft music more than loud music.'",
				retryText = "'Enjoy' still doesn't tell you what to measure. Choose something observable, such as growth.",
			},
			{
				id = "opinion",
				text = "Ask your classmates whether they think plants like music.",
				retryText = "A survey measures classmates' opinions, not how plants respond to music.",
			},
		},
		successText = "Now I have a prediction I can test by measuring growth. The results might support it or show I was wrong.",
	},
	{
		id = "historical_sources",
		prompt = "Two accounts of the same historical event disagree. How do I decide which claims to trust?",
		choices = {
			{ id = "choice_3a8", text = "Compare who wrote them, when and why they wrote, and what evidence supports each claim." },
			{
				id = "older",
				text = "Trust the older account because it was written closer to the event.",
				retryText = "Timing matters, but an early account can still contain mistakes. Check its evidence and viewpoint too.",
			},
			{
				id = "prefer",
				text = "Trust whichever account includes more details.",
				retryText = "Extra detail doesn't guarantee accuracy. Look for evidence that supports those details.",
			},
		},
		successText = "I'll compare the evidence and explain any disagreement I can't settle.",
	},
	{
		id = "manageable_steps",
		prompt = "My history report is due Friday. I've chosen a topic, but I don't know how to start. What should I do first?",
		choices = {
			{ id = "choice_9b5", text = "Check the requirements, write a question your report will answer, and plan time for research and writing." },
			{
				id = "all",
				text = "Write the full report tonight and look for supporting sources later.",
				retryText = "Research should help shape the report. Planning first also leaves time to check and revise it.",
			},
			{
				id = "last",
				text = "Collect as many facts as you can before deciding what the report will answer.",
				retryText = "Without a clear question, it's easy to collect facts you won't use. Give the research a focus.",
			},
		},
		successText = "I'll start with the requirements and a clear question, then set a small task for each day.",
	},
	{
		id = "peer_feedback",
		prompt = "My partner's essay has a clear argument, but one paragraph has no evidence. How can I give useful feedback?",
		choices = {
			{ id = "choice_4e1", text = "Say the argument is clear, then suggest adding an example or source to support that paragraph." },
			{
				id = "vague",
				text = "Say it needs more work, but let your partner figure out where.",
				retryText = "Useful feedback points to a specific part and explains how it could improve.",
			},
			{
				id = "harsh",
				text = "Replace the paragraph with one you write yourself.",
				retryText = "Your partner needs a chance to revise their own work. Offer a suggestion rather than taking over.",
			},
		},
		successText = "I can point out what works and give one clear suggestion without rewriting their essay.",
	},
	{
		id = "group_participation",
		prompt = "Two people in my project group make every decision and talk over me. How can I take part?",
		choices = {
			{ id = "choice_7c6", text = "I'll help your group take turns sharing ideas and agree on a role for each person." },
			{
				id = "loudest",
				text = "Wait for them to finish the planning, then ask for a task.",
				retryText = "That still leaves the student out of decisions. Help everyone have a voice in planning.",
			},
			{
				id = "silent",
				text = "Complete a separate version of the project on your own.",
				retryText = "Separate work doesn't fix the group problem. Start by making participation fair.",
			},
		},
		successText = "Taking turns means I can share an idea, and having a role gives me a clear way to contribute.",
	},
	{
		id = "safe_to_ask",
		prompt = "I don't understand the assignment instructions, but I'm embarrassed to ask in front of everyone. Can you help?",
		choices = {
			{ id = "choice_1f9", text = "Of course. Let's look at them together here. Tell me which part is unclear." },
			{
				id = "easy",
				text = "Ask the question aloud now so the whole class can hear it.",
				retryText = "The student asked for private help. Support them without putting them on the spot.",
			},
			{
				id = "later",
				text = "Read the instructions a few more times before asking for help.",
				retryText = "They already need help understanding the instructions. Find out which part needs explaining.",
			},
		},
		successText = "Thanks. I can show you the part that's confusing without asking in front of the class.",
	},
	{
		id = "test_nerves",
		prompt = "I studied for this test, but the first question has me stuck and nervous. What should I do?",
		choices = {
			{ id = "choice_8d2", text = "Take a short pause, then try a question you recognise. Mark this one to return to later." },
			{
				id = "cram",
				text = "Stay on the first question until you solve it, even if it takes most of the test.",
				retryText = "One hard question can use up time needed for others. Help the student move forward and return later.",
			},
			{
				id = "ignore",
				text = "Rush through the whole test before you forget anything else.",
				retryText = "Rushing can lead to missed instructions. Suggest a pause and a manageable next question.",
			},
		},
		successText = "I'll pause, start with a question I recognise, and leave time to return to this one.",
	},
	{
		id = "missed_lesson",
		prompt = "I missed three days of class. There are notes, homework and a quiz to catch up on. Where should I start?",
		choices = {
			{ id = "choice_5a7", text = "Let's check the deadlines and key lessons, then make a catch-up plan starting with what you need next." },
			{
				id = "everything",
				text = "Finish every missed task tonight before looking at today's lesson.",
				retryText = "Doing everything at once may be too much. Help the student choose priorities and realistic deadlines.",
			},
			{
				id = "skip",
				text = "Start with whichever task is shortest, without checking what the quiz covers.",
				retryText = "The shortest task may not teach what the student needs next. Check the lessons and deadlines first.",
			},
		},
		successText = "Now I know what to study first and when to complete the remaining work.",
	},
	{
		id = "different_format",
		prompt = "I've read the definition of an equation twice, but I still don't understand why both sides must stay equal.",
		choices = {
			{ id = "choice_2e4", text = "Let's draw a balanced scale and work through an example, doing the same thing to both sides." },
			{
				id = "repeat",
				text = "Copy the definition several times until you can repeat it.",
				retryText = "Repeating a definition doesn't show why it works. Try an example the student can follow.",
			},
			{
				id = "blame",
				text = "Memorise the rule now. You don't need to understand why it works.",
				retryText = "The student is asking why. A clear model can connect the rule to its meaning.",
			},
		},
		successText = "The scale helps: if I change one side, I need to make the same change on the other to keep it balanced.",
	},
	{
		id = "working_first_error",
		prompt = "For 2(x + 3) = 10, I wrote 2x + 3 = 10 and got x = 3.5. Where did I go wrong?",
		choices = {
			{ id = "choice_6b9", text = "The 2 multiplies both terms inside the brackets. Start with 2x + 6 = 10, then solve." },
			{
				id = "last",
				text = "Your steps are correct. Just round 3.5 to a whole number.",
				retryText = "Rounding won't fix the equation. Check how the brackets were expanded.",
			},
			{
				id = "redo",
				text = "Subtract 3 from 10 first, then divide the result by 2.",
				retryText = "That uses the incorrect line 2x + 3 = 10. The 3 inside the brackets must also be multiplied by 2.",
			},
		},
		successText = "I missed multiplying the 3 by 2. Now 2x + 6 = 10 gives x = 2, and 2(2 + 3) = 10 checks out.",
	},
	{
		id = "paraphrase_credit",
		prompt = "I want to explain an idea from a website in my essay using my own words. Do I still need to name the source?",
		choices = {
			{ id = "choice_3f1", text = "Yes. Explain the idea in your own words and cite the source so readers know where it came from." },
			{
				id = "synonyms",
				text = "No. Changing a few words makes the idea yours.",
				retryText = "Changing words doesn't make someone else's idea your own. You still need to credit the source.",
			},
			{
				id = "quote",
				text = "No. You only need a source when you copy the exact wording.",
				retryText = "Borrowed ideas need credit too, even when you explain them in your own words.",
			},
		},
		successText = "I'll explain the idea in my own words and include a citation to the website.",
	},
	{
		id = "stuck_time_management",
		prompt = "I've spent 20 minutes on one homework problem and keep repeating the same steps. What should I try next?",
		choices = {
			{ id = "choice_9d6", text = "Mark the step where you get stuck, compare it with a worked example, and ask a specific question if needed." },
			{
				id = "forever",
				text = "Keep repeating the same method until the answer changes.",
				retryText = "Repeating the same steps won't resolve the confusion. Help the student find and check the sticking point.",
			},
			{
				id = "random",
				text = "Copy a worked answer into your homework and move on.",
				retryText = "A worked example helps when you compare and understand its steps. Copying alone skips that learning.",
			},
		},
		successText = "I'll find the exact step I don't understand so I can use an example or ask for help with it.",
	},
	{
		id = "reading_goal",
		prompt = "I planned to read 30 pages each night, but only managed 10. How should I set next week's goal?",
		choices = {
			{ id = "choice_4a2", text = "Check what limited your reading time. Set a realistic daily target and review it at the end of the week." },
			{
				id = "more",
				text = "Raise the target to 60 pages a night to make up for this week.",
				retryText = "A much larger target doesn't address why 30 pages was difficult. Start with the time actually available.",
			},
			{
				id = "perfect",
				text = "Keep the same target and schedule without checking what got in the way.",
				retryText = "If nothing changes, the same problem may happen again. Use this week's experience to adjust the plan.",
			},
		},
		successText = "I'll plan around the time I have, then check whether my new target works after a week.",
	},
}

return Questions
