--Types
export type State = {
	rateCount: number,
	rateWindowStartedAt: number,
}

--Public Methods
const function AllowRateLimit(state: State, limit: number, windowSeconds: number): boolean
	const now = os.clock()
	if now - state.rateWindowStartedAt >= windowSeconds then
		state.rateWindowStartedAt = now
		state.rateCount = 1
		return true
	end
	if state.rateCount >= limit then
		return false
	end
	state.rateCount += 1
	return true
end

return AllowRateLimit
