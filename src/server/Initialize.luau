--Imports
const Dependencies = require("./Dependencies").get()
const Engine = require(Dependencies.shared.libraries.Engine)

--Public Methods
const function Initialize()
	Engine.loadSingletons(script.Parent.services)
	Engine.launch()
end

return {
	initialize = Initialize,
}
