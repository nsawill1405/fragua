local TypeValue = require("../src/App/Types/TypeValue")
local Roblox = require("@lune/roblox")
local CFrame = Roblox.CFrame
local Instance = Roblox.Instance
local UDim2 = Roblox.UDim2
local Vector3 = Roblox.Vector3

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
	["rejects object reference defaults and omits them from storage"] = function()
		local reference = Instance.new("Folder")
		local valid = TypeValue.validate("Instance", reference)
		assert(not valid)
		local fraguaValid = TypeValue.validate("FraguaInstance", reference)
		assert(not fraguaValid)
		assert(TypeValue.serialize(reference) == nil)
	end,
	["round trips supported value datatypes"] = function()
		local encoded = TypeValue.serialize(CFrame.new(1, 2, 3) * CFrame.Angles(0.1, 0.2, 0.3))
		local decoded = TypeValue.deserialize(encoded)
		assert(typeof(decoded) == "CFrame" and decoded.Position:FuzzyEq(Vector3.new(1, 2, 3), 1e-5))
	end,
}
