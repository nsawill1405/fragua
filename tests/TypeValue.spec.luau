local TypeValue = require("../src/App/Types/TypeValue")
local Roblox = require("@lune/roblox")
local CFrame = Roblox.CFrame
local Instance = Roblox.Instance
local UDim2 = Roblox.UDim2
local Vector3 = Roblox.Vector3
local fs = require("@lune/fs")

return {
	["selects typed defaults"] = function()
		assert(TypeValue.default("boolean") == false)
		assert(TypeValue.default("Vector3") == Vector3.zero)
		assert(TypeValue.default("UDim2") == UDim2.new())
	end,
	["validates enum and constrained numbers"] = function()
		assert(TypeValue.validate("enum", "Smooth", { enumItems = { "Smooth", "Studs" } }))
		local ok = TypeValue.validate("number", 11, { minimum = 0, maximum = 10 })
		assert(not ok)
	end,
	["validates native and typed object reference defaults"] = function()
		local reference = Instance.new("Folder")
		assert(TypeValue.validate("Instance", reference))
		local fraguaValid = TypeValue.validate("FraguaInstance", reference)
		assert(not fraguaValid)
		reference:SetAttribute("_FraguaType", "Zombie")
		local missingType, missingMessage = TypeValue.validate("FraguaInstance", reference)
		assert(not missingType and missingMessage and missingMessage:find("reference type", 1, true))
		assert(TypeValue.validate("FraguaInstance", reference, { referenceType = "Zombie" }))
		local wrongType, message = TypeValue.validate("FraguaInstance", reference, { referenceType = "Enemy" })
		assert(not wrongType and message and message:find("Enemy", 1, true))
		assert(TypeValue.serialize(reference) == nil)
	end,
	["object reference markers are explicit and property scoped"] = function()
		assert(TypeValue.referenceMarker, "referenceMarker should be available")
		local marker = TypeValue.referenceMarker("Leader")
		assert(marker.__typeof == "ObjectReference" and marker.property == "Leader")
		assert(TypeValue.referenceProperty(marker) == "Leader")
		assert(TypeValue.referenceProperty({ __typeof = "ObjectReference", property = 1 }) == nil)
	end,
	["registry persists references outside JSON in managed ObjectValues"] = function()
		local source = fs.readFile("src/App/Types/Registry.luau")
		assert(source:find("TypeValue.referenceMarker", 1, true), "registry should encode reference markers")
		assert(
			source:find("TypeValue.referenceProperty", 1, true),
			"registry should decode only property-scoped markers"
		)
		assert(source:find('Instance.new("ObjectValue")', 1, true), "registry should persist object values")
		assert(source:find("_FraguaManaged", 1, true), "reference values should be managed")
	end,
	["default editor exposes a headless reference validation seam"] = function()
		local ok, DefaultEditor = pcall(function()
			return require("../src/App/Types/DefaultEditor")
		end)
		assert(ok and DefaultEditor, `DefaultEditor should be available: {DefaultEditor}`)
		local source = fs.readFile("src/App/Types/DefaultEditor.luau")
		assert(not source:find('box.Text:gsub("^%s"', 1, true), "string defaults must preserve leading whitespace")
		local reference = Instance.new("Folder")
		reference:SetAttribute("_FraguaType", "Enemy")
		assert(DefaultEditor.referenceError(reference, { valueType = "Instance" }) == nil)
		local message = DefaultEditor.referenceError(reference, {
			valueType = "FraguaInstance",
			referenceType = "Zombie",
		})
		assert(message and message:find("Zombie", 1, true))
	end,
	["round trips supported value datatypes"] = function()
		local encoded = TypeValue.serialize(CFrame.new(1, 2, 3) * CFrame.Angles(0.1, 0.2, 0.3))
		local decoded = TypeValue.deserialize(encoded)
		assert(typeof(decoded) == "CFrame" and decoded.Position:FuzzyEq(Vector3.new(1, 2, 3), 1e-5))
	end,
}
