local Diagnostics = require("../src/App/ScriptEditor/Diagnostics")

local context = { schema = { { name = "Health" }, { name = "DetectRange" } } }

return {
	["reports unknown custom properties"] = function()
		local issues = Diagnostics.analyze('local value = instance:GetAttribute("Helth")', context)
		assert(issues[1].code == "unknown-property")
	end,
	["reports duplicate hooks and invalid signatures"] = function()
		local source =
			"function Behavior.onCreated(instance) end\nfunction Behavior.onCreated(instance) end\nfunction Behavior.onPropertyChanged(instance) end"
		local issues = Diagnostics.analyze(source, context)
		assert(issues[1].code == "duplicate-hook")
		assert(issues[2].code == "invalid-hook-arity")
	end,
	["ignores brackets in strings and comments"] = function()
		local issues = Diagnostics.analyze('local text = "]" -- (\nreturn { value = text }', context)
		assert(#issues == 0)
	end,
	["reports unmatched brackets"] = function()
		local issues = Diagnostics.analyze("return { value = (10 + 2 }", context)
		assert(issues[1].code == "unmatched-bracket")
	end,
	["does not apply custom schema warnings to ordinary scripts"] = function()
		local issues = Diagnostics.analyze('local value = instance:GetAttribute("Anything")', { schema = {} })
		assert(#issues == 0)
	end,
	["reports unknown Fragua type ids"] = function()
		local issues = Diagnostics.analyze('Fragua.create("Missing")', { typeIds = { "Zombie" }, schema = {} })
		assert(issues[1].code == "unknown-type")
	end,
	["reports literal attribute type mismatches"] = function()
		local issues = Diagnostics.analyze('instance:SetAttribute("Health", "high")', {
			typeIds = {},
			schema = { { name = "Health", valueType = "number" } },
		})
		assert(issues[1].code == "attribute-type-mismatch")
	end,
	["reports duplicate flat local declarations"] = function()
		local issues = Diagnostics.analyze("local hp = 1\nlocal hp = 2", { typeIds = {}, schema = {} })
		assert(issues[1].code == "duplicate-local")
	end,
}
