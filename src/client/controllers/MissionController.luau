--Imports
const CampaignController = require("./CampaignController")
const CareerController = require("./CareerController")
const Janitor = require("../../shared/Packages/Janitor")
const SoftwareEngineer = require("../missions/SoftwareEngineer")
const Teacher = require("../missions/Teacher")

--Declarations
const ControllerJanitor = Janitor.new()
const MissionController = {}

-- Lifecycle Methods
function MissionController.init()
	SoftwareEngineer.init()
	Teacher.init()
	ControllerJanitor:LinkToInstance(script.Parent.Parent.Parent)
end

function MissionController.start()
	ControllerJanitor:Add(CareerController.careerClassified:Connect(function(profession: string, startToken: string?)
		if profession == "teaching" and startToken then
			Teacher.start(startToken)
		elseif profession == "softwareEngineering" and startToken then
			SoftwareEngineer.start(startToken)
		end
	end))
	ControllerJanitor:Add(CampaignController.activeChanged:Connect(function(active: boolean)
		if not active then
			SoftwareEngineer.stop(true)
			Teacher.stop(true)
		end
	end))
end

return MissionController
