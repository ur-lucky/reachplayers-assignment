--Services
const HttpService = game:GetService("HttpService")

--Imports
const Dependencies = require("../Dependencies").get()
const MissionTypes = require(Dependencies.shared.types.Mission)

--Types
export type StartTokenState = {
	startToken: string?,
	startTokenCampaignSessionGuid: string?,
	startTokenExpiresAt: number?,
	startTokenThread: thread?,
}

--Public Methods
const function ClearStartToken(state: StartTokenState)
	state.startToken = nil
	state.startTokenCampaignSessionGuid = nil
	state.startTokenExpiresAt = nil
	const tokenThread = state.startTokenThread
	state.startTokenThread = nil
	if tokenThread and coroutine.status(tokenThread) ~= "dead" then
		task.cancel(tokenThread)
	end
end

const function Failure(code: string, message: string): MissionTypes.Response
	return { ok = false, code = code, error = message }
end

const function IssueStartToken(state: StartTokenState, campaignSessionGuid: string?, lifetimeSeconds: number): string
	ClearStartToken(state)
	const startToken = HttpService:GenerateGUID(false)
	state.startToken = startToken
	state.startTokenCampaignSessionGuid = campaignSessionGuid
	state.startTokenExpiresAt = os.clock() + lifetimeSeconds
	state.startTokenThread = task.delay(lifetimeSeconds, function()
		if state.startToken == startToken then
			state.startToken = nil
			state.startTokenCampaignSessionGuid = nil
			state.startTokenExpiresAt = nil
			state.startTokenThread = nil
		end
	end)
	return startToken
end

const function ReserveCell(reservations: { [number]: boolean }, spacing: number, height: number): (number, CFrame)
	local cell = 0
	while reservations[cell] do
		cell += 1
	end
	reservations[cell] = true
	return cell, CFrame.new(cell * spacing, height, 0)
end

return {
	clearStartToken = ClearStartToken,
	failure = Failure,
	issueStartToken = IssueStartToken,
	reserveCell = ReserveCell,
}
