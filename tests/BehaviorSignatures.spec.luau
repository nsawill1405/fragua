local ok, Signatures = pcall(function()
	return require("../src/App/Runtime/BehaviorSignatures")
end)

local function requireSignatures()
	assert(ok and Signatures, "BehaviorSignatures should be available")
	return Signatures
end

return {
	["parses annotated behavior exports and excludes lifecycle hooks"] = function()
		local methods = requireSignatures().parse([[
function Behavior.onStart(instance: Instance) end
function Behavior.Attack(instance: Instance, target: Instance, damage: number): boolean
	return true
end
]])
		assert(#methods == 1 and methods[1].name == "Attack")
		assert(#methods[1].parameters == 2)
		assert(methods[1].parameters[1].name == "target")
		assert(methods[1].parameters[1].typeName == "Instance")
		assert(methods[1].parameters[2].name == "damage")
		assert(methods[1].parameters[2].typeName == "number")
		assert(methods[1].returns == "boolean")
	end,
	["splits nested annotations only at top-level commas"] = function()
		local methods = requireSignatures().parse([[
function Behavior.Configure(instance: Instance, options: { names: { string }, callback: (number, string) -> boolean }, target: Instance?): (boolean, string?)
end
]])
		assert(#methods == 1)
		assert(#methods[1].parameters == 2)
		assert(methods[1].parameters[1].name == "options")
		assert(methods[1].parameters[1].typeName == "{ names: { string }, callback: (number, string) -> boolean }")
		assert(methods[1].parameters[2].typeName == "Instance?")
		assert(methods[1].returns == "(boolean, string?)")
	end,
	["ignores dynamic unannotated and unsafe exports"] = function()
		local methods = requireSignatures().parse([[
Behavior.Dynamic = function(instance, target) end
function Behavior.MissingReturn(instance: Instance, target: Instance) end
function Behavior.MissingParameter(instance: Instance, target): boolean end
function Behavior.WrongReceiver(instance: Model, target: Instance): boolean end
function Behavior.Unsafe(instance: Instance, target: number; print("bad")): boolean
end
function Behavior.InlineBody(instance: Instance): boolean return true end
function Behavior.UnclosedGeneric(instance: Instance, values: Map<string): boolean
end
function Behavior.TrailingUnion(instance: Instance): boolean |
end
function Behavior.InvalidOperator(instance: Instance, value: number / string): boolean
end
function Behavior.LocalAlias(instance: Instance, value: Options): boolean
end
function Behavior.Clone(instance: Instance): boolean
end
function Behavior.Safe(instance: Instance): ()
end
]])
		assert(#methods == 1 and methods[1].name == "Safe")
	end,
}
