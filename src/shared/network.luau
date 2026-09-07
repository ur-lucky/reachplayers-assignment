--Imports
const Remo = require("./Packages/Remo")

--Types
export type ResponsePromise = {
	andThen: (self: ResponsePromise, onFulfilled: (unknown) -> (), onRejected: (unknown) -> ()) -> (),
	cancel: (self: ResponsePromise) -> (),
}

--Declarations
const Network = Remo.createRemotes({
	CareerComplete = Remo.remote().returns(),
	CareerResultShown = Remo.remote(),
	CampaignPromptShown = Remo.remote(),
	CampaignPromptTriggered = Remo.remote(),
	CampaignSessionRequest = Remo.remote().returns(),
	SoftwareEngineerAbandon = Remo.remote().returns(),
	SoftwareEngineerAnimationComplete = Remo.remote().returns(),
	SoftwareEngineerAttempt = Remo.remote().returns(),
	SoftwareEngineerBoardShown = Remo.remote(),
	SoftwareEngineerEnded = Remo.remote(),
	SoftwareEngineerEnvironmentReady = Remo.remote().returns(),
	SoftwareEngineerLaptopShown = Remo.remote(),
	SoftwareEngineerRequest = Remo.remote().returns(),
	SoftwareEngineerSeedsRequest = Remo.remote().returns(),
	TeacherAbandon = Remo.remote().returns(),
	TeacherConversationComplete = Remo.remote().returns(),
	TeacherEnded = Remo.remote(),
	TeacherEnvironmentReady = Remo.remote().returns(),
	TeacherQuestionShown = Remo.remote(),
	TeacherRequest = Remo.remote().returns(),
	TeacherStudentsChanged = Remo.remote(),
})

return Network
