--Services
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Workspace = game:GetService("Workspace")

--Types
type Payload = {
	clientEntry: Script,
	replicatedRoot: Folder,
	runtimeRoot: ObjectValue,
	serverEntry: ModuleScript,
	serverRoot: Folder,
}

--Declarations
const Installer = script.Parent.Parent
local InstalledReplicatedRoot: Folder? = nil
local InstalledServerRoot: Folder? = nil
local TearingDown = false

--Private Methods
const function DisableInstaller(message: string)
	warn(`Campaign installation aborted: {message}`)
	script.Enabled = false
end

const function IsSupportedLocation(): boolean
	return Installer:IsDescendantOf(Workspace)
		or Installer:IsDescendantOf(ReplicatedStorage)
		or Installer:IsDescendantOf(ServerScriptService)
end

const function HasCollision(container: Instance, ignoredInstance: Instance): boolean
	for _, child in container:GetChildren() do
		if child.Name == "Campaign" and child ~= ignoredInstance then
			return true
		end
	end

	return false
end

const function ValidatePayload(): (Payload?, string?)
	if not Installer:IsA("Folder") then
		return nil, "the Campaign installer root must be a Folder"
	end
	const client = Installer:FindFirstChild("client")
	const shared = Installer:FindFirstChild("shared")
	const assets = Installer:FindFirstChild("assets")
	if not client or not client:IsA("Folder") then
		return nil, "the client payload folder is missing"
	end
	if not shared or not shared:IsA("Folder") then
		return nil, "the shared payload folder is missing"
	end
	if not assets or not assets:IsA("Folder") then
		return nil, "the assets payload folder is missing"
	end
	const clientEntry = client:FindFirstChild("initialization")
	if not clientEntry or not clientEntry:IsA("Script") or clientEntry.RunContext ~= Enum.RunContext.Client then
		return nil, "the client initialization Script is missing or has an invalid RunContext"
	end

	const serverRoot = script.Parent
	if not serverRoot:IsA("Folder") then
		return nil, "the server payload folder is invalid"
	end
	const serverEntry = serverRoot:FindFirstChild("Initialize")
	const runtimeRoot = serverRoot:FindFirstChild("runtimeRoot")
	if not serverEntry or not serverEntry:IsA("ModuleScript") then
		return nil, "the server Initialize ModuleScript is missing"
	end
	if not runtimeRoot or not runtimeRoot:IsA("ObjectValue") then
		return nil, "the server runtimeRoot ObjectValue is missing"
	end

	return {
		clientEntry = clientEntry,
		replicatedRoot = Installer,
		runtimeRoot = runtimeRoot,
		serverEntry = serverEntry,
		serverRoot = serverRoot,
	},
		nil
end

const function Teardown(removedRoot: Instance, destroyRemovedRoot: boolean)
	if TearingDown then
		return
	end
	TearingDown = true

	const replicatedRoot = InstalledReplicatedRoot
	const serverRoot = InstalledServerRoot
	if replicatedRoot and (replicatedRoot ~= removedRoot or destroyRemovedRoot) then
		replicatedRoot:Destroy()
	end
	if serverRoot and (serverRoot ~= removedRoot or destroyRemovedRoot) then
		serverRoot:Destroy()
	end
end

const function WatchInstallation(replicatedRoot: Folder, serverRoot: Folder)
	replicatedRoot.Destroying:Connect(function()
		Teardown(replicatedRoot, false)
	end)
	serverRoot.Destroying:Connect(function()
		Teardown(serverRoot, false)
	end)
	replicatedRoot:GetPropertyChangedSignal("Parent"):Connect(function()
		if replicatedRoot.Parent ~= ReplicatedStorage then
			Teardown(replicatedRoot, true)
		end
	end)
	serverRoot:GetPropertyChangedSignal("Parent"):Connect(function()
		if serverRoot.Parent ~= ServerScriptService then
			Teardown(serverRoot, true)
		end
	end)
end

const function Install(payload: Payload)
	const replicatedRoot = payload.replicatedRoot
	const serverRoot = payload.serverRoot
	payload.clientEntry.Enabled = false
	payload.runtimeRoot.Value = replicatedRoot
	serverRoot.Name = "Campaign"
	serverRoot.Parent = ServerScriptService
	replicatedRoot.Name = "Campaign"
	replicatedRoot:SetAttribute("expectedDescendantCount", #replicatedRoot:GetDescendants())
	replicatedRoot:SetAttribute("ready", false)
	replicatedRoot.Parent = ReplicatedStorage

	const initialized, initializationError = xpcall(function()
		const Initialization = require(payload.serverEntry)
		Initialization.initialize()
	end, debug.traceback)
	if not initialized then
		warn(`Campaign installation failed during server initialization: {initializationError}`)
		replicatedRoot:Destroy()
		serverRoot:Destroy()
		return
	end

	InstalledReplicatedRoot = replicatedRoot
	InstalledServerRoot = serverRoot
	WatchInstallation(replicatedRoot, serverRoot)
	replicatedRoot:SetAttribute("ready", true)
	payload.clientEntry.Enabled = true
end

--Init
if not IsSupportedLocation() then
	DisableInstaller("place Campaign beneath Workspace, ReplicatedStorage, or ServerScriptService")
	return
end
if HasCollision(ReplicatedStorage, Installer) or HasCollision(ServerScriptService, Installer) then
	DisableInstaller("ReplicatedStorage.Campaign or ServerScriptService.Campaign already exists")
	return
end
const payload, validationError = ValidatePayload()
if not payload then
	DisableInstaller(validationError or "the installer payload is invalid")
	return
end
Install(payload)
