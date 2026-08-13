local Policy = require("../src/App/Types/BackingUpgradePolicy")

return {
	["stored attributes win native-name collisions and remain preserved"] = function()
		local value, preserveAttribute = Policy.sourceValue(true, "stored attribute", true, "old native")
		assert(value == "stored attribute")
		assert(preserveAttribute == true)
	end,
	["native values transfer when no stored attribute exists"] = function()
		local value, preserveAttribute = Policy.sourceValue(false, nil, true, "old native")
		assert(value == "old native")
		assert(preserveAttribute == false)
	end,
}
