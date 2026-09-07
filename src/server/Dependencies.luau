--Types
export type Dependencies = {
	assets: Folder,
	root: Folder,
	shared: Folder,
}

--Declarations
const RuntimeRoot = script.Parent:FindFirstChild("runtimeRoot")
assert(RuntimeRoot and RuntimeRoot:IsA("ObjectValue"), "Campaign server runtimeRoot is missing")

--Public Methods
const function Get(): Dependencies
	const root = RuntimeRoot.Value
	assert(root and root:IsA("Folder"), "Campaign replicated runtime root is unavailable")
	const assets = root:FindFirstChild("assets")
	const shared = root:FindFirstChild("shared")
	assert(assets and assets:IsA("Folder"), "Campaign assets are unavailable")
	assert(shared and shared:IsA("Folder"), "Campaign shared modules are unavailable")

	return {
		assets = assets,
		root = root,
		shared = shared,
	}
end

return {
	get = Get,
}
