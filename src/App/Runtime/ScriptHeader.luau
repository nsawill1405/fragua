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

function ScriptHeader.apply(source: string): (string, boolean)
	local startByte = source:find(BEGIN_MARKER, 1, true)
	local nextSource
	if startByte then
		local endByte = source:find(END_MARKER, startByte + #BEGIN_MARKER, true)
		if endByte then
			local blockEnd = endByte + #END_MARKER - 1
			nextSource = source:sub(1, startByte - 1) .. HEADER .. source:sub(blockEnd + 1)
		else
			nextSource = HEADER .. "\n\n" .. source
		end
	else
		nextSource = HEADER .. "\n\n" .. source
	end
	return nextSource, nextSource ~= source
end

function ScriptHeader.shouldSkip(fullName: string): boolean
	return fullName == "ReplicatedStorage.Fragua" or fullName == "ServerScriptService.FraguaRuntime"
end

ScriptHeader.HEADER = HEADER

return ScriptHeader
