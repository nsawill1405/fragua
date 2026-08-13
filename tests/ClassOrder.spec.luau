local ClassOrder = require("../src/App/Explorer/ClassOrder")
local EngineSchemas = require("../src/App/Types/EngineSchemas")

local function fake(className: string, name: string)
	return {
		ClassName = className,
		Name = name,
	}
end

return {
	["scripts sort above every other common class"] = function()
		assert(ClassOrder.rank("Script") < ClassOrder.rank("LocalScript"))
		assert(ClassOrder.rank("LocalScript") < ClassOrder.rank("ModuleScript"))
		assert(ClassOrder.rank("ModuleScript") < ClassOrder.rank("Folder"))
		assert(ClassOrder.rank("ModuleScript") < ClassOrder.rank("Humanoid"))
		assert(ClassOrder.rank("ModuleScript") < ClassOrder.rank("Part"))
		assert(ClassOrder.rank("ModuleScript") < ClassOrder.rank("Shirt"))
		assert(ClassOrder.compare(fake("Script", "A"), fake("Humanoid", "Humanoid")))
		assert(ClassOrder.compare(fake("ModuleScript", "Z"), fake("MeshPart", "Head")))
	end,
	["humanoids still sort above clothing"] = function()
		assert(ClassOrder.rank("Humanoid") < ClassOrder.rank("MeshPart"))
		assert(ClassOrder.rank("MeshPart") < ClassOrder.rank("Shirt"))
		assert(ClassOrder.rank("Shirt") < ClassOrder.rank("Pants"))
		assert(ClassOrder.compare(fake("Shirt", "Shirt"), fake("Pants", "Pants")))
	end,
	["every insertable class has a stable rank"] = function()
		for _, section in EngineSchemas.insertSections() do
			assert(section.title ~= nil)
			for _, className in section.classes do
				assert(ClassOrder.rank(className) < 100000, className .. " should be ranked")
			end
		end
		assert(EngineSchemas.insertSections()[1].title == "Scripts")
	end,
	["same class falls back to name"] = function()
		assert(ClassOrder.compare(fake("Part", "Arm"), fake("Part", "Head")))
	end,
}
