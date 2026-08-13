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

local EDIT_HOOKS = {
	onCreated = true,
	onSelected = true,
	onPropertyChanged = true,
	onAncestryChanged = true,
}

local PLAY_HOOKS = {
	onStart = true,
	onStop = true,
}

local BEGIN_MARKER = "-- Fragua imports begin"
local END_MARKER = "-- Fragua imports end"

local function requireSide(side: string)
	assert(SUFFIX[side] ~= nil, `Unknown behavior side: {side}`)
end

local function stripManagedHeader(source: string): string
	local startByte = source:find(BEGIN_MARKER, 1, true)
	if not startByte then
		return source
	end
	local endByte = source:find(END_MARKER, startByte + #BEGIN_MARKER, true)
	if not endByte then
		return source
	end
	local before = source:sub(1, startByte - 1)
	local after = source:sub(endByte + #END_MARKER):gsub("^[\r\n]+", "")
	if before ~= "" and not before:match("\n$") and after ~= "" then
		return before .. "\n" .. after
	end
	return before .. after
end

local function stripHooks(source: string, hooks: { [string]: boolean }): string
	local lines = string.split(source, "\n")
	local out = {}
	local skipping = false
	local depth = 0
	for _, line in lines do
		if not skipping then
			local hook = line:match("^%s*function%s+Behavior%.([%w_]+)%s*%(")
			if hook and hooks[hook] then
				skipping = true
				depth = 1
			else
				table.insert(out, line)
			end
		else
			if line:match("^%s*function%s+") or line:match("^%s*local%s+function%s+") then
				depth += 1
			end
			if line:match("^%s*end%s*;?%s*$") or line:match("^%s*end%s+") then
				depth -= 1
				if depth <= 0 then
					skipping = false
					depth = 0
				end
			end
		end
	end
	local joined = table.concat(out, "\n")
	joined = joined:gsub("\n\n\n+", "\n\n")
	return joined
end

local function ensurePlayHooks(source: string, typeId: string): string
	local hasStart = source:find("function Behavior.onStart", 1, true) ~= nil
	local hasStop = source:find("function Behavior.onStop", 1, true) ~= nil
	if hasStart and hasStop then
		if not source:find("return Behavior", 1, true) then
			return source .. "\nreturn Behavior\n"
		end
		return source
	end
	local body = source
	if not body:find("local Behavior = {}", 1, true) then
		body = "-- Fragua Server behavior for " .. typeId .. "\nlocal Behavior = {}\n\n" .. body
	end
	body = body:gsub("%s*return%s+Behavior%s*;?%s*$", "")
	if not hasStart then
		body ..= "\nfunction Behavior.onStart(instance: Instance)\nend\n"
	end
	if not hasStop then
		body ..= "\nfunction Behavior.onStop(instance: Instance)\nend\n"
	end
	body ..= "\nreturn Behavior\n"
	return body
end

local function ensureEditHooks(source: string, typeId: string): string
	local body = source
	if not body:find("local Behavior = {}", 1, true) then
		body = "-- Fragua Edit behavior for " .. typeId .. "\nlocal Behavior = {}\n\n" .. body
	end
	body = body:gsub("%s*return%s+Behavior%s*;?%s*$", "")
	for _, hook in LIFECYCLE.Edit do
		if not body:find("function Behavior." .. hook, 1, true) then
			body ..= "\nfunction Behavior." .. hook .. "(instance: Instance)\nend\n"
		end
	end
	body ..= "\nreturn Behavior\n"
	return body
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

function BehaviorModel.isServerEditForwarder(source: string): boolean
	if source:find("Fragua Server migration forwarder", 1, true) then
		return true
	end
	return source:find("EditBehavior = require", 1, true) ~= nil and source:find("EditBehavior.onStart", 1, true) ~= nil
end

function BehaviorModel.editSourceFromLegacy(legacySource: string, typeId: string): string
	local cleaned = stripManagedHeader(legacySource)
	cleaned = stripHooks(cleaned, PLAY_HOOKS)
	cleaned = cleaned:gsub("^%-%-%s*Fragua Server migration forwarder[^\n]*\n", "")
	cleaned = cleaned:gsub("local EditBehavior = require%b()\n", "")
	return ensureEditHooks(cleaned, typeId)
end

function BehaviorModel.serverSourceFromEdit(editSource: string, typeId: string): string
	if BehaviorModel.isServerEditForwarder(editSource) then
		return BehaviorModel.defaultSource(typeId, "Server")
	end
	local cleaned = stripManagedHeader(editSource)
	cleaned = stripHooks(cleaned, EDIT_HOOKS)
	cleaned = cleaned:gsub("^%-%-%s*Fragua Edit behavior[^\n]*\n", "-- Fragua Server behavior for " .. typeId .. "\n")
	if cleaned:find("function Behavior.onStart", 1, true) or cleaned:find("function Behavior.onStop", 1, true) then
		return ensurePlayHooks(cleaned, typeId)
	end
	return BehaviorModel.defaultSource(typeId, "Server")
end

-- standalone server template; never requires Edit Behavior at play time
function BehaviorModel.serverMigrationSource(typeId: string, editSource: string?): string
	if typeof(editSource) == "string" and editSource ~= "" then
		return BehaviorModel.serverSourceFromEdit(editSource, typeId)
	end
	return BehaviorModel.defaultSource(typeId, "Server")
end

return BehaviorModel
