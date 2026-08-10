local ok, MetadataModel = pcall(function()
	return require("../src/App/Properties/MetadataModel")
end)
local Roblox = require("@lune/roblox")
local constructors = { Color3 = Roblox.Color3, Vector3 = Roblox.Vector3 }

return {
	["attribute names are trimmed and cannot collide"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.normalizeName("  Score  ") == "Score")
		local valid = MetadataModel.validateAttributeName("Score", { Score = true }, nil)
		assert(not valid)
	end,
	["renaming an attribute to itself remains valid"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		local valid = MetadataModel.validateAttributeName("Score", { Score = true }, "Score")
		assert(valid)
	end,
	["Fragua identity metadata is protected"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.isProtectedAttribute("_FraguaType"))
		assert(MetadataModel.isProtectedTag("FraguaInstance", true))
		assert(not MetadataModel.isProtectedTag("Enemy", true))
	end,
	["new attribute types receive deterministic defaults"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.defaultFor("string", constructors) == "")
		assert(MetadataModel.defaultFor("number", constructors) == 0)
		assert(MetadataModel.defaultFor("boolean", constructors) == false)
		assert(typeof(MetadataModel.defaultFor("Color3", constructors)) == "Color3")
		assert(typeof(MetadataModel.defaultFor("Vector3", constructors)) == "Vector3")
	end,
	["unsupported Roblox attribute types are never parsed as strings"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.isSupportedType, "isSupportedType should be available")
		assert(MetadataModel.isSupportedType("Vector3"))
		assert(not MetadataModel.isSupportedType("CFrame"))
		assert(not MetadataModel.isSupportedType("UDim2"))
	end,
	["modal dropdown layers render above the overlay"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.modalLayers, "modalLayers should be available")
		local layers = MetadataModel.modalLayers(150)
		assert(layers.panel > layers.overlay)
		assert(layers.menu > layers.panel)
	end,
}
