local ApiSource = require("../src/App/Runtime/ApiSource")

local function buildSource()
	assert(typeof(ApiSource) == "table" and ApiSource.build, "ApiSource should expose build(surface?)")
	return ApiSource.build({ types = {} })
end

return {
	["gateway contains compatibility proxies"] = function()
		local source = buildSource()
		assert(source:find("Fragua.Instance", 1, true))
		assert(source:find("Fragua.Enum", 1, true))
		assert(source:find("RobloxInstance.new", 1, true))
		assert(source:find("RobloxEnum:GetEnums()", 1, true))
	end,
	["factory reads replicated types"] = function()
		local source = buildSource()
		assert(source:find("FraguaTypes", 1, true))
		assert(source:find("CollectionService:AddTag", 1, true))
		assert(source:find('definition:FindFirstChild("Defaults")', 1, true))
	end,
	["Roblox class construction is attempted before custom lookup"] = function()
		local source = buildSource()
		local nativeAt = source:find("RobloxInstance.new(className)", 1, true)
		local customAt = source:find("findDefinition(className)", 1, true)
		assert(nativeAt and customAt and nativeAt < customAt)
	end,
	["gateway exposes constructors and compatibility aliases"] = function()
		local source = buildSource()
		assert(source:find("FraguaInstance.fromExisting", 1, true))
		assert(source:find("function Facade.typeof", 1, true))
		assert(source:find('return "Instance"', 1, true))
		assert(source:find('return "userdata"', 1, true))
	end,
	["generated gateway compiles as Luau"] = function()
		local source = buildSource()
		local compiled, chunk = pcall(loadstring, source, "Fragua")
		assert(compiled and chunk, tostring(chunk))
	end,
	["facades isolate cached wrappers and behavior sides"] = function()
		local source = buildSource()
		assert(source:find('Core = setmetatable({}, { __mode = "kv" })', 1, true))
		assert(source:find('Server = setmetatable({}, { __mode = "kv" })', 1, true))
		assert(source:find('Client = setmetatable({}, { __mode = "kv" })', 1, true))
		assert(source:find('WRAPPER_METATABLE.__metatable = "FraguaInstance"', 1, true))
		assert(source:find('types:FindFirstChild(typeId .. "ServerBehavior")', 1, true))
		assert(source:find('definition:FindFirstChild("ClientBehavior")', 1, true))
	end,
	["runtime binds native methods and never creates per-instance behavior modules"] = function()
		local source = buildSource()
		assert(source:find("return member(state.backing, unwrapArguments(...))", 1, true))
		assert(not source:find('behavior.Name = "Behavior"', 1, true))
	end,
	["native backing members win custom type ID origin collisions"] = function()
		local source = buildSource()
		local classifier = assert(source:find("local function isCustomProperty", 1, true))
		local nativeCheck = assert(source:find("hasBackingMember(backing, name)", classifier, true))
		local customReturn = assert(source:find("return property", nativeCheck, true))
		assert(nativeCheck < customReturn)
	end,
	["known behavior methods are encoded without loading the wrong side"] = function()
		local source = ApiSource.build({
			types = {
				{
					id = "Zombie",
					serverMethods = { { name = "Attack" } },
					clientMethods = { { name = "PlayEffect" } },
				},
			},
		})
		assert(source:find('[ "Attack" ] = true', 1, true))
		assert(source:find('[ "PlayEffect" ] = true', 1, true))
		local compiled, chunk = pcall(loadstring, source, "FraguaWithMethods")
		assert(compiled and chunk, tostring(chunk))
	end,
	["native writable properties are not treated as wrapper-owned slots"] = function()
		local source = buildSource()
		local newIndex = assert(source:find("WRAPPER_METATABLE.__newindex", 1, true))
		local wrapperCheck = assert(source:find("WRAPPER_MEMBERS[key]", newIndex, true))
		local write = assert(source:find("state.backing[key] = unwrap(value)", wrapperCheck, true))
		assert(wrapperCheck < write)
	end,
	["destroyed wrappers reject tostring like other non-diagnostic access"] = function()
		local source = buildSource()
		local tostringStart = assert(source:find("WRAPPER_METATABLE.__tostring", 1, true))
		local usable = assert(source:find("assertUsable(state)", tostringStart, true))
		local tostringBacking = assert(source:find("tostring(state.backing)", tostringStart, true))
		assert(usable < tostringBacking)
	end,
}
