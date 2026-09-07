--Private Methods
const function resultHandler(callbackThread: thread, succeeded: boolean, ...)
	if not succeeded then
		const message = (...)
		error(debug.traceback(callbackThread, message), 2)
	end

	if coroutine.status(callbackThread) ~= "dead" then
		error(debug.traceback(callbackThread, "Attempted to yield inside changed event!"), 2)
	end

	return ...
end

--Public Methods
const function preventYield<A..., R...>(callback: (A...) -> R..., ...: A...): ...any
	const callbackThread = coroutine.create(callback)

	return resultHandler(callbackThread, coroutine.resume(callbackThread, ...))
end

return preventYield
