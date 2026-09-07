--Types
export type Direction = "down" | "left" | "right" | "up"

export type GridPosition = {
	row: number,
	column: number,
}

export type RouteBoard = {
	size: number,
	start: GridPosition,
	goal: GridPosition,
	blocked: { [string]: boolean },
}

export type RouteFailureReason = "blocked" | "incomplete" | "out_of_bounds"

export type RouteEvaluation = {
	completedSteps: number,
	reachedGoal: boolean,
	failureReason: RouteFailureReason?,
}

export type SeedList = { number }

export type PublicDialogue = {
	npcGuid: string,
	conversationId: string,
	active: boolean,
}

export type SoftwareEngineerStartPayload = {
	sessionGuid: string,
	officeCFrame: CFrame,
	round: number,
	totalRounds: number,
}

export type TeachingMissionPayload = {
	sessionGuid: string,
	classroomCFrame: CFrame,
	studentCFrames: { [string]: CFrame },
	dialogues: { PublicDialogue },
	total: number,
}

export type Response = {
	ok: boolean,
	code: string?,
	error: string?,
	campaignSessionGuid: string?,
	profession: string?,
	softwareEngineerStartToken: string?,
	teachingStartToken: string?,
	payload: TeachingMissionPayload?,
	softwareEngineerPayload: SoftwareEngineerStartPayload?,
	seeds: SeedList?,
	round: number?,
	totalRounds: number?,
	completedSteps: number?,
	commands: { Direction }?,
	failureReason: RouteFailureReason?,
	progress: number?,
	total: number?,
	correct: boolean?,
	missionCompleted: boolean?,
	alreadyCompleted: boolean?,
	reward: string?,
}

return {}
