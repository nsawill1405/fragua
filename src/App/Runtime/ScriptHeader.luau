local ScriptHeader = {}

local BEGIN_MARKER = "-- Fragua imports begin"
local END_MARKER = "-- Fragua imports end"
local HEADER = table.concat({
	BEGIN_MARKER,
	'local Fragua = require(game:GetService("ReplicatedStorage"):WaitForChild("Fragua"))',
	"local Instance = Fragua.Instance",
	"local Enum = Fragua.Enum",
	END_MARKER,
}, "\n")

local function directivePrefixEnd(source: string): number
	local cursor = 1
	local prefixEnd = 0
	while cursor <= #source do
		local lineEnd = source:find("\n", cursor, true)
		local line = source:sub(cursor, if lineEnd then lineEnd - 1 else #source):gsub("\r$", "")
		if not line:match("^%-%-![%w_]+%s*$") then
			break
		end
		prefixEnd = lineEnd or #source
		if not lineEnd then
			break
		end
		cursor = lineEnd + 1
	end
	return prefixEnd
end

function ScriptHeader.apply(source: string): (string, boolean)
	local startByte = source:find(BEGIN_MARKER, 1, true)
	local nextSource
	if startByte then
		local endByte = source:find(END_MARKER, startByte + #BEGIN_MARKER, true)
		if endByte then
			local blockEnd = endByte + #END_MARKER - 1
			nextSource = source:sub(1, startByte - 1) .. HEADER .. source:sub(blockEnd + 1)
		else
			local prefixEnd = directivePrefixEnd(source)
			local prefix = source:sub(1, prefixEnd)
			local separator = if prefixEnd > 0 and prefix:sub(-1) ~= "\n" then "\n" else ""
			nextSource = prefix .. separator .. HEADER .. "\n\n" .. source:sub(prefixEnd + 1)
		end
	else
		local prefixEnd = directivePrefixEnd(source)
		local prefix = source:sub(1, prefixEnd)
		local separator = if prefixEnd > 0 and prefix:sub(-1) ~= "\n" then "\n" else ""
		nextSource = prefix .. separator .. HEADER .. "\n\n" .. source:sub(prefixEnd + 1)
	end
	return nextSource, nextSource ~= source
end

function ScriptHeader.shouldSkip(fullName: string): boolean
	return fullName == "ReplicatedStorage.Fragua"
		or fullName == "ServerScriptService.FraguaRuntime"
		or fullName == "StarterPlayer.StarterPlayerScripts.FraguaClientRuntime"
end

ScriptHeader.HEADER = HEADER

return ScriptHeader
