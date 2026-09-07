--Imports
const NoYield = require("../utils/funcs/noYield")

--Types
export type Singleton = {
	loadOrder: number?,
	init: (() -> ())?,
	start: (() -> ())?,
}

type Module<T> = { name: string, data: T }

--Declarations
const Singletons: { Module<Singleton> } = {}

--Private Methods
const function loadModulesInDirectory(source: Instance)
	const loadedModules = {}
	const moduleScripts = source:QueryDescendants(">ModuleScript, Folder>ModuleScript")

	if source:IsA("ModuleScript") then
		table.insert(moduleScripts, source)
	end

	for _, module in ipairs(moduleScripts) do
		table.insert(loadedModules, { name = module.Name, data = require(module) })
	end

	return loadedModules
end

--Public Methods
const function LoadModules(...: Instance)
	for _, source in { ... } do
		loadModulesInDirectory(source)
	end
end

const function LoadSingletons(source: Instance)
	for _, singleton in ipairs(loadModulesInDirectory(source) :: { Module<Singleton> }) do
		const loadOrder = if typeof(singleton.data.loadOrder) == "number" then singleton.data.loadOrder else math.huge

		singleton.data.loadOrder = loadOrder
		table.insert(Singletons, singleton)
	end

	table.sort(Singletons, function(firstSingleton, secondSingleton)
		return (firstSingleton.data.loadOrder or 0) < (secondSingleton.data.loadOrder or 0)
	end)
end

const function Launch()
	for _, singleton in ipairs(Singletons) do
		const singletonData = singleton.data
		if singletonData.init then
			NoYield(singletonData.init)
		end
	end

	for _, singleton in ipairs(Singletons) do
		const singletonData = singleton.data

		if singletonData.start then
			task.spawn(singletonData.start)
		end
	end
end

return {
	launch = Launch,
	loadModules = LoadModules,
	loadSingletons = LoadSingletons,
}
