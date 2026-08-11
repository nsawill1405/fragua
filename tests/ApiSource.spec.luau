local ApiSource = require("../src/App/Runtime/ApiSource")
local fs = require("@lune/fs")

local function buildSource()
	assert(typeof(ApiSource) == "table" and ApiSource.build, "ApiSource should expose build(surface?)")
	return ApiSource.build({ types = {} })
end

local function typedSurface()
	return {
		types = {
			{
				id = "Enemy",
				backingClass = "Part",
				properties = {
					{ name = "Threat", typeName = "number" },
				},
				serverMethods = {},
				clientMethods = {},
			},
			{
				id = "Zombie",
				backingClass = "Part",
				properties = {
					{ name = "Health", typeName = "number" },
					{ name = "Leader", typeName = "Enemy", valueType = "FraguaInstance", referenceType = "Enemy" },
					{ name = "Target", typeName = "Instance", valueType = "Instance" },
				},
				serverMethods = {
					{
						name = "Attack",
						parameters = {
							{ name = "target", typeName = "Instance" },
							{ name = "damage", typeName = "number" },
						},
						returns = "boolean",
					},
				},
				clientMethods = {
					{
						name = "PlayEffect",
						parameters = { { name = "color", typeName = "Color3" } },
						returns = "()",
					},
				},
			},
		},
	}
end

local function aliasBlock(source: string, alias: string): string
	local startAt = assert(source:find("export type " .. alias .. " =", 1, true), `missing {alias}`)
	local nextAlias = source:find("\nexport type ", startAt + 1, true)
	local nextSection = source:find("\ntype FraguaTypeEnum", startAt + 1, true)
	local nextAt = if nextAlias and nextSection
		then math.min(nextAlias, nextSection)
		else nextAlias or nextSection or #source + 1
	return source:sub(startAt, nextAt - 1)
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
	["generated aliases expose properties and only the selected side methods"] = function()
		local source = ApiSource.build(typedSurface())
		local server = aliasBlock(source, "ZombieServer")
		local client = aliasBlock(source, "ZombieClient")
		local core = aliasBlock(source, "ZombieCore")
		assert(server:find("Health: number", 1, true))
		assert(server:find("Leader: EnemyServer?", 1, true))
		assert(server:find("Target: Instance?", 1, true))
		assert(server:find("Attack: (self: ZombieServer, target: Instance, damage: number) -> boolean", 1, true))
		assert(not server:find("PlayEffect", 1, true))
		assert(client:find("Leader: EnemyClient?", 1, true))
		assert(client:find("PlayEffect: (self: ZombieClient, color: Color3) -> ()", 1, true))
		assert(not client:find("Attack", 1, true))
		assert(core:find("Leader: EnemyCore?", 1, true))
		assert(not core:find("Attack", 1, true) and not core:find("PlayEffect", 1, true))
	end,
	["constructors preserve Roblox signatures and add literal custom overloads"] = function()
		local source = ApiSource.build(typedSurface())
		assert(source:find("type ServerNew = typeof(RobloxInstance.new)", 1, true))
		assert(source:find('& ((className: "Zombie", parent: Instance?) -> ZombieServer)', 1, true))
		assert(source:find('& ((className: FraguaTypeItem<"Zombie">, parent: Instance?) -> ZombieServer)', 1, true))
		assert(source:find("type ClientNew = typeof(RobloxInstance.new)", 1, true))
		assert(source:find("type CoreNew = typeof(RobloxInstance.new)", 1, true))
	end,
	["facade casts preserve inferred values for Clone fromExisting and Get"] = function()
		local source = ApiSource.build(typedSurface())
		assert(aliasBlock(source, "ZombieServer"):find("Clone: (self: ZombieServer) -> ZombieServer?", 1, true))
		assert(aliasBlock(source, "ZombieServer"):find('TypeId: "Zombie"', 1, true))
		assert(source:find("type ServerFromExisting =", 1, true))
		assert(source:find("& typeof(RobloxInstance.fromExisting)", 1, true))
		assert(source:find("Get: ServerGet", 1, true))
		assert(source:find("local Server = ServerRuntime :: typeof(ServerRuntime) & ServerFacade", 1, true))
		assert(source:find("local Client = ClientRuntime :: typeof(ClientRuntime) & ClientFacade", 1, true))
		assert(source:find("local Core = CoreRuntime :: typeof(CoreRuntime) & CoreFacade", 1, true))
	end,
	["cross-facade helpers return the invoked facade alias"] = function()
		local source = ApiSource.build(typedSurface())
		local inputAliases = "ZombieServer | ZombieClient | ZombieCore"
		local clientGet = assert(source:find("type ClientGet =", 1, true))
		local clientGetSpecific =
			assert(source:find("((value: " .. inputAliases .. ") -> ZombieClient)", clientGet, true))
		local clientGetFallback = assert(source:find("& (<T>(value: T & Instance) -> T)", clientGetSpecific, true))
		assert(clientGetSpecific < clientGetFallback)

		local clientExisting = assert(source:find("type ClientFromExisting =", 1, true))
		local clientExistingSpecific =
			assert(source:find("((existing: " .. inputAliases .. ") -> ZombieClient?)", clientExisting, true))
		local clientExistingNative =
			assert(source:find("& typeof(RobloxInstance.fromExisting)", clientExistingSpecific, true))
		assert(clientExistingSpecific < clientExistingNative)

		assert(source:find("((value: " .. inputAliases .. ") -> ZombieServer)", 1, true))
		assert(source:find("((value: " .. inputAliases .. ") -> ZombieCore)", 1, true))
		assert(not source:find("Get: <T>(value: T & Instance) -> T", 1, true))
		local compiled, chunk = pcall(loadstring, source, "CrossFacadeFragua")
		assert(compiled and chunk, tostring(chunk))
	end,
	["populated generated gateway compiles as Luau"] = function()
		local source = ApiSource.build(typedSurface())
		local compiled, chunk = pcall(loadstring, source, "TypedFragua")
		assert(compiled and chunk, tostring(chunk))
	end,
	["typed behavior varargs compile in generated function types"] = function()
		local surface = typedSurface()
		table.insert(surface.types[2].serverMethods, {
			name = "DamageMany",
			parameters = { { name = "...", typeName = "number" } },
			returns = "number",
		})
		local source = ApiSource.build(surface)
		assert(source:find("DamageMany: (self: ZombieServer, ...number) -> number", 1, true))
		local compiled, chunk = pcall(loadstring, source, "VarargFragua")
		assert(compiled and chunk, tostring(chunk))
	end,
	["unsafe names and annotations cannot break generated source"] = function()
		local source = ApiSource.build({
			types = {
				{
					id = 'Bad-Type"\\',
					backingClass = "Part; error()",
					properties = {
						{ name = "health-value", typeName = "number; error()" },
					},
					serverMethods = {
						{
							name = "Do-Bad",
							parameters = { { name = "x", typeName = "number --[[" } },
							returns = "boolean; error()",
						},
					},
					clientMethods = {},
				},
			},
		})
		assert(not source:find("number; error()", 1, true))
		assert(not source:find("boolean; error()", 1, true))
		local compiled, chunk = pcall(loadstring, source, "EscapedFragua")
		assert(compiled and chunk, tostring(chunk))
	end,
	["startup builds and synchronizes one current surface before injection"] = function()
		local source = fs.readFile("src/init.server.luau")
		local seedAt = assert(source:find("Registry.seedDefaults()", 1, true))
		local buildAt = assert(source:find("local currentSurface = buildSurface()", seedAt, true))
		local catalogAt = assert(source:find("TypeCatalog.sync(Registry, currentSurface)", buildAt, true))
		local gatewayAt = assert(source:find("EnsurePlaceModules.sync(currentSurface)", catalogAt, true))
		local injectorAt = assert(source:find("ScriptInjector.start()", gatewayAt, true))
		assert(seedAt < buildAt and buildAt < catalogAt and catalogAt < gatewayAt and gatewayAt < injectorAt)

		local changedAt = assert(source:find("Registry.Changed:Connect(function()", injectorAt, true))
		local rebuildAt = assert(source:find("currentSurface = buildSurface()", changedAt, true))
		local resyncCatalogAt = assert(source:find("TypeCatalog.sync(Registry, currentSurface)", rebuildAt, true))
		local resyncGatewayAt = assert(source:find("EnsurePlaceModules.sync(currentSurface)", resyncCatalogAt, true))
		assert(rebuildAt < resyncCatalogAt and resyncCatalogAt < resyncGatewayAt)
	end,
	["catalog and gateway consume the supplied surface"] = function()
		local catalogSource = fs.readFile("src/App/Runtime/TypeCatalog.luau")
		local syncAt = assert(catalogSource:find("function TypeCatalog.sync(registry, surface)", 1, true))
		assert(catalogSource:find("for _, entry in surface.types do", syncAt, true))
		local gatewaySource = fs.readFile("src/App/Runtime/EnsurePlaceModules.luau")
		assert(gatewaySource:find("function EnsurePlaceModules.sync(surface: any)", 1, true))
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
	["Clone preserves remapped references while fromExisting copies source references"] = function()
		local source = buildSource()
		local cloneStart = assert(source:find('elseif key == "Clone" then', 1, true))
		local cloneEnd = assert(source:find('elseif key == "IsA" then', cloneStart, true))
		local cloneBlock = source:sub(cloneStart, cloneEnd - 1)
		assert(cloneBlock:find("copyCustomValues(state.backing, clone, definition, true)", 1, true))

		local existingStart = assert(source:find("function FraguaInstance.fromExisting", 1, true))
		local existingEnd = assert(source:find("setmetatable(FraguaInstance", existingStart, true))
		local existingBlock = source:sub(existingStart, existingEnd - 1)
		assert(existingBlock:find("copyCustomValues(backing, duplicate, definition, false)", 1, true))
	end,
	["known non-creatable native strings rethrow before custom lookup"] = function()
		local source = buildSource()
		local stringOnly = assert(source:find("if not forceCustom then", 1, true))
		local nativeCall = assert(source:find("RobloxInstance.new(className)", stringOnly, true))
		local collision = assert(source:find("if isKnownNativeClass(className) then", nativeCall, true))
		local nativeError = assert(source:find("error(nativeProblem, 2)", collision, true))
		local customLookup = assert(source:find("local definition = findDefinition(className)", nativeError, true))
		assert(
			stringOnly < nativeCall
				and nativeCall < collision
				and collision < nativeError
				and nativeError < customLookup
		)
	end,
	["Fragua enum items bypass native class collision routing"] = function()
		local source = buildSource()
		local enumItem = assert(source:find("forceCustom = true", 1, true))
		local stringOnly = assert(source:find("if not forceCustom then", enumItem, true))
		local customLookup = assert(source:find("local definition = findDefinition(className)", stringOnly, true))
		assert(enumItem < stringOnly and stringOnly < customLookup)
	end,
}
