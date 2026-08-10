local source = require("../src/App/Runtime/ApiSource")

return {
	["gateway contains compatibility proxies"] = function()
		assert(source:find("Fragua.Instance", 1, true))
		assert(source:find("Fragua.Enum", 1, true))
		assert(source:find("RobloxInstance.new", 1, true))
		assert(source:find("RobloxEnum:GetEnums()", 1, true))
	end,
	["factory reads replicated types"] = function()
		assert(source:find("FraguaTypes", 1, true))
		assert(source:find("CollectionService:AddTag", 1, true))
		assert(source:find('definition:FindFirstChild("Defaults")', 1, true))
	end,
	["Roblox class construction is attempted before custom lookup"] = function()
		local nativeAt = source:find("RobloxInstance.new(className)", 1, true)
		local customAt = source:find("findDefinition(className)", 1, true)
		assert(nativeAt and customAt and nativeAt < customAt)
	end,
}
