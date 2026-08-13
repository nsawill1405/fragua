local ClassOrder = require("../src/App/Explorer/ClassOrder")

local function fake(className: string, name: string)
	return {
		ClassName = className,
		Name = name,
	}
end

return {
	["humanoids sort above parts and clothing"] = function()
		local humanoid = fake("Humanoid", "Humanoid")
		local shirt = fake("Shirt", "Shirt")
		local pants = fake("Pants", "Pants")
		local head = fake("MeshPart", "Head")
		assert(ClassOrder.compare(humanoid, shirt))
		assert(ClassOrder.compare(humanoid, pants))
		assert(ClassOrder.compare(humanoid, head))
		assert(ClassOrder.compare(head, shirt))
		assert(ClassOrder.compare(shirt, pants))
		assert(ClassOrder.rank("Humanoid") < ClassOrder.rank("MeshPart"))
		assert(ClassOrder.rank("MeshPart") < ClassOrder.rank("Shirt"))
		assert(ClassOrder.rank("Shirt") < ClassOrder.rank("Pants"))
	end,
	["same class falls back to name"] = function()
		assert(ClassOrder.compare(fake("Part", "Arm"), fake("Part", "Head")))
	end,
}
