local BehaviorModel = {}

BehaviorModel.SIDES = { "Edit", "Server", "Client" }

local SUFFIX = {
	Edit = "EditBehavior",
	Server = "ServerBehavior",
	Client = "ClientBehavior",
}

local LIFECYCLE = {
	Edit = { "onCreated", "onSelected", "onPropertyChanged", "onAncestryChanged" },
	Server = { "onStart", "onStop" },
	Client = { "onStart", "onStop" },
}

local function requireSide(side: string)
	assert(SUFFIX[side] ~= nil, `Unknown behavior side: {side}`)
end

function BehaviorModel.name(typeId: string, side: string): string
	requireSide(side)
	return typeId .. SUFFIX[side]
end

function BehaviorModel.templateIdentity(
	name: string,
	typeIds: { string },
	isTypeDefinition: boolean
): (string?, string?)
	if isTypeDefinition then
		return nil, nil
	end
	for _, typeId in typeIds do
		for _, side in BehaviorModel.SIDES do
			if name == BehaviorModel.name(typeId, side) then
				return typeId, side
			end
		end
	end
	return nil, nil
end

function BehaviorModel.defaultSource(typeId: string, side: string): string
	requireSide(side)
	local lines = {
		`-- Fragua {side} behavior for {typeId}`,
		"local Behavior = {}",
		"",
	}
	for _, hook in LIFECYCLE[side] do
		table.insert(lines, `function Behavior.{hook}(instance: Instance)`)
		table.insert(lines, "end")
		table.insert(lines, "")
	end
	table.insert(lines, "return Behavior")
	table.insert(lines, "")
	return table.concat(lines, "\n")
end

function BehaviorModel.serverMigrationSource(typeId: string): string
	local editName = BehaviorModel.name(typeId, "Edit")
	return table.concat({
		`-- Fragua Server migration forwarder for {typeId}`,
		`local EditBehavior = require(script.Parent:WaitForChild("{editName}"))`,
		"local Behavior = {}",
		"",
		"function Behavior.onStart(instance: Instance)",
		'\tif typeof(EditBehavior.onStart) == "function" then',
		"\t\tEditBehavior.onStart(instance)",
		"\tend",
		"end",
		"",
		"function Behavior.onStop(instance: Instance)",
		'\tif typeof(EditBehavior.onStop) == "function" then',
		"\t\tEditBehavior.onStop(instance)",
		"\tend",
		"end",
		"",
		"return Behavior",
		"",
	}, "\n")
end

return BehaviorModel
