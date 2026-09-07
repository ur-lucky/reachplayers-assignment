--Services
const RunService = game:GetService("RunService")

--Declarations
const Campaign = script.Parent.Parent

--Private Methods
const function WaitForRuntime()
	while true do
		const expectedDescendantCount = Campaign:GetAttribute("expectedDescendantCount")
		if
			Campaign:GetAttribute("ready") == true
			and type(expectedDescendantCount) == "number"
			and #Campaign:GetDescendants() >= expectedDescendantCount
		then
			return
		end

		RunService.Heartbeat:Wait()
	end
end

--Init
WaitForRuntime()
const Client = Campaign:WaitForChild("client")
const Shared = Campaign:WaitForChild("shared")
const Libraries = Shared:WaitForChild("libraries")
const Engine = require(Libraries:WaitForChild("Engine"))
Engine.loadSingletons(Client:WaitForChild("controllers"))
Engine.launch()
