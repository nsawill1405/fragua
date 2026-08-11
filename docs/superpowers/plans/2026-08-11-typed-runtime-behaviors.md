# Typed Runtime, Split Behaviors, and Type Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Fragua custom types return native-feeling typed wrappers, split type behavior into edit/server/client execution, expose context-aware native-editor autocomplete, and use type-specific controls for property defaults.

**Architecture:** Pure policy modules resolve backing classes, typed defaults, behavior templates, signatures, and autocomplete items. Studio-facing modules apply those decisions to the Registry, managed runtime scripts, ScriptEditorService, and the existing type editor; the generated `ReplicatedStorage.Fragua` gateway owns wrappers and context facades.

**Tech Stack:** Luau, Roblox Studio plugin APIs, ScriptEditorService, CollectionService, ChangeHistoryService, Rojo 7.6.1, Lune 0.10.4, Selene 0.30.1, StyLua 0.20.0.

## Global Constraints

- Preserve Roblox behavior for ordinary `Instance`, `Enum`, `type`, and `typeof` calls.
- `type(wrapper)` returns `"userdata"`; `typeof(wrapper)` returns `"Instance"`; `Fragua.GetTypeId(wrapper)` returns the custom type ID.
- Edit Behavior never runs during play; Client Behavior never runs in edit mode or on the server; Server Behavior never runs on the client.
- Client code cannot receive edit or server behavior source through managed replication.
- Never rewrite a script whose complete managed import header is already current.
- Never modify user source outside the managed import markers.
- Never silently replace a legacy backing instance whose `ClassName` is incompatible with its resolved engine ancestor.
- Never reset an existing placed-instance value merely because another property or the type schema changed.
- Custom property and method names cannot collide with inherited Roblox members or Fragua core members.
- Keep autocomplete additive and lightweight; a Fragua callback failure must leave Roblox's response usable.
- Do not print a plugin-loaded message.
- Do not stage or modify the unrelated `.superpowers/` directory.

---

## File Structure

### New focused modules

- `src/App/Types/TypeValue.luau`: supported value-type descriptors, typed defaults, validation, serialization helpers, and control-kind decisions.
- `src/App/Types/BackingClassResolver.luau`: resolves a Fragua inheritance chain to its first Roblox engine ancestor.
- `src/App/Types/BehaviorModel.luau`: canonical behavior sides, names, skeletons, legacy migration decisions, and reserved lifecycle hooks.
- `src/App/Runtime/BehaviorSignatures.luau`: conservatively extracts annotated exported behavior functions.
- `src/App/Runtime/TypeSurface.luau`: builds context-specific property/method/type records from registry snapshots.
- `src/App/Runtime/ScriptContext.luau`: selects `Server`, `Client`, or `Core` from a source container's class and location.
- `src/App/Runtime/AutocompleteModel.luau`: pure request-to-suggestion planning.
- `src/App/Runtime/AutocompleteProvider.luau`: registers and unregisters the ScriptEditorService callback.
- `src/App/Runtime/ClientBootstrapSource.luau`: generated play-mode client host source.
- `src/App/Types/DefaultControlModel.luau`: maps property metadata to a stable default-editor descriptor.
- `src/App/Types/DefaultEditor.luau`: mounts one compact type-specific control without rebuilding the dialog.

### Existing modules with expanded responsibilities

- `src/App/Types/Registry.luau`: versioned property metadata, typed defaults/references, backing-class creation, and three behavior templates.
- `src/App/Runtime/TypeCatalog.luau`: mirrors public type metadata and Client Behavior only.
- `src/App/Runtime/ApiSource.luau`: becomes a source builder for typed facades, wrappers, constructors, and compatibility aliases.
- `src/App/Runtime/EnsurePlaceModules.luau`: refreshes generated API/server/client hosts only when source differs.
- `src/App/Runtime/BootstrapSource.luau`: server-only behavior lifecycle.
- `src/App/Behaviors/Host.luau`: edit-only behavior lifecycle.
- `src/App/Runtime/ScriptHeader.luau` and `ScriptInjector.luau`: context-specific, idempotent headers.
- `src/App/Types/TypeDraft.luau` and `TypeEditor.luau`: typed draft values, metadata, validation, and compact controls.
- `src/App/Properties/Controls.luau`: reusable animated boolean toggle alongside existing dropdown, number, and color controls.
- `src/init.server.luau`: starts/stops autocomplete and all registry/runtime synchronization.

---

### Task 1: Typed property metadata and value codec

**Files:**
- Create: `src/App/Types/TypeValue.luau`
- Modify: `src/App/Types/Registry.luau`
- Modify: `src/App/Types/TypeDraft.luau`
- Modify: `src/App/Shared/Util.luau`
- Create: `tests/TypeValue.spec.luau`
- Modify: `tests/TypeDraft.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces `TypeValue.supported(): { string }`.
- Produces `TypeValue.default(valueType: string, metadata: table?): any`.
- Produces `TypeValue.validate(valueType: string, value: any, metadata: table?): (boolean, string?)`.
- Produces `TypeValue.serialize(value: any): any` and `TypeValue.deserialize(value: any): any` for JSON-safe Roblox datatypes except object references.
- Expands `Registry.PropDef` with `enumType`, `minimum`, `maximum`, `step`, `multiline`, and `referenceType`.
- Draft properties store `defaultValue`. `defaultText` remains a temporary compatibility field until Task 10 so the existing TypeEditor and invalid legacy drafts continue to render and validate during intermediate commits.

- [ ] **Step 1: Write failing codec and draft tests.**

```luau
local TypeValue = require("../src/App/Types/TypeValue")

return {
	["selects typed defaults"] = function()
		assert(TypeValue.default("boolean") == false)
		assert(TypeValue.default("Vector3") == Vector3.zero)
		assert(TypeValue.default("UDim2") == UDim2.new())
	end,
	["validates enum and constrained numbers"] = function()
		assert(TypeValue.validate("enum", "Smooth", { enumItems = { "Smooth", "Studs" } }))
		local ok = TypeValue.validate("number", 11, { minimum = 0, maximum = 10 })
		assert(not ok)
	end,
	["round trips supported value datatypes"] = function()
		local encoded = TypeValue.serialize(CFrame.new(1, 2, 3) * CFrame.Angles(0.1, 0.2, 0.3))
		local decoded = TypeValue.deserialize(encoded)
		assert(typeof(decoded) == "CFrame" and decoded.Position:FuzzyEq(Vector3.new(1, 2, 3)))
	end,
}
```

Extend `tests/TypeDraft.spec.luau` with a typed property:

```luau
local propertyId = TypeDraft.addProperty(draft, categoryId, "Enabled", "boolean", false)
TypeDraft.updateProperty(draft, propertyId, { defaultValue = true })
assert(TypeDraft.snapshotEditableProperties(draft)[1].defaultValue == true)
```

- [ ] **Step 2: Run `lune run tests/run.luau`; expect failure because `TypeValue` is missing and `TypeDraft` still expects text.**

- [ ] **Step 3: Implement the value descriptor table and typed validation.**

```luau
local DESCRIPTORS = {
	string = { default = "" },
	number = { default = 0 },
	integer = { default = 0 },
	boolean = { default = false },
	Color3 = { default = Color3.new(1, 1, 1) },
	BrickColor = { default = BrickColor.new("Medium stone grey") },
	Vector2 = { default = Vector2.zero },
	Vector3 = { default = Vector3.zero },
	UDim = { default = UDim.new() },
	UDim2 = { default = UDim2.new() },
	CFrame = { default = CFrame.identity },
	enum = { default = "" },
	Instance = { default = nil },
	FraguaInstance = { default = nil },
}

function TypeValue.default(valueType, metadata)
	local descriptor = assert(DESCRIPTORS[valueType], `Unsupported value type: {valueType}`)
	if valueType == "enum" and metadata and metadata.enumItems then
		return metadata.enumItems[1] or ""
	end
	return descriptor.default
end
```

Use explicit tagged objects such as `{ __typeof = "UDim2", XScale = ..., XOffset = ... }`; never stringify typed values for storage.

- [ ] **Step 4: Update Registry encode/decode and TypeDraft validation to preserve every new metadata field and call `TypeValue.validate`. `TypeDraft.addProperty` accepts `defaultInput: any`; when the old UI supplies text, parse it with `Util.parseValue`, store a typed `defaultValue` on success, and retain `defaultText` for display or an invalid-input error. This keeps every intermediate commit runnable while existing types migrate.**

- [ ] **Step 5: Run `stylua src/App/Types/TypeValue.luau src/App/Types/TypeDraft.luau src/App/Types/Registry.luau tests/TypeValue.spec.luau tests/TypeDraft.spec.luau`, then `lune run tests/run.luau`; expect all tests to pass.**

- [ ] **Step 6: Commit.**

```bash
git add src/App/Types/TypeValue.luau src/App/Types/Registry.luau src/App/Types/TypeDraft.luau src/App/Shared/Util.luau tests/TypeValue.spec.luau tests/TypeDraft.spec.luau tests/run.luau
git commit -m "feat: add typed custom property metadata"
```

### Task 2: Backing-class inheritance and creation

**Files:**
- Create: `src/App/Types/BackingClassResolver.luau`
- Modify: `src/App/Types/Registry.luau`
- Modify: `src/App/Explorer/InsertPicker.luau`
- Modify: `src/App/Properties/init.luau`
- Create: `tests/BackingClassResolver.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces `BackingClassResolver.resolve(typeId: string, lookupType: (string) -> TypeDef?): (string?, string?)`.
- Produces `Registry.getBackingClass(typeId: string): (string?, string?)`.
- `Registry.createInstance(typeId, parent?)` creates the resolved engine class.
- Properties receives a read-only backing mismatch row and an explicit `Registry.upgradeBackingInstance(instance)` action.

- [ ] **Step 1: Write failing direct, multi-level, and cycle tests.**

```luau
local Resolver = require("../src/App/Types/BackingClassResolver")
local types = {
	Boss = { id = "Boss", extends = "Zombie" },
	Zombie = { id = "Zombie", extends = "SpawnLocation" },
}

return {
	["resolves through custom inheritance"] = function()
		local className = Resolver.resolve("Boss", function(id) return types[id] end)
		assert(className == "SpawnLocation")
	end,
	["reports cycles"] = function()
		types.Zombie.extends = "Boss"
		local className, err = Resolver.resolve("Boss", function(id) return types[id] end)
		assert(className == nil and err:find("cycle", 1, true))
	end,
}
```

- [ ] **Step 2: Run `lune run tests/run.luau`; expect module-not-found failure.**

- [ ] **Step 3: Implement resolution by following registered custom IDs until `lookupType(parentId)` returns nil; treat that parent ID as the engine class and return a cycle error on repeats.**

```luau
function Resolver.resolve(typeId, lookupType)
	local visited = {}
	local current = typeId
	while lookupType(current) do
		if visited[current] then return nil, `Inheritance cycle at "{current}"` end
		visited[current] = true
		current = lookupType(current).extends
	end
	return current
end
```

- [ ] **Step 4: Change both plugin insertion paths to call `Registry.createInstance`; construct the resolved class with `pcall(Instance.new, backingClass)`, then apply defaults/tag/type ID without overwriting native engine properties that already exist.**

- [ ] **Step 5: Add explicit upgrade behavior: copy writable custom values, attributes, tags, children, name, parent, and selection inside ChangeHistoryService waypoints; never invoke it automatically. Show the action only when `instance.ClassName ~= Registry.getBackingClass(typeId)`.**

- [ ] **Step 6: Run Lune, Selene on changed files, and `rojo build -o /tmp/Fragua-backing.rbxm`; expect success. Commit.**

```bash
git add src/App/Types/BackingClassResolver.luau src/App/Types/Registry.luau src/App/Explorer/InsertPicker.luau src/App/Properties/init.luau tests/BackingClassResolver.spec.luau tests/run.luau
git commit -m "feat: back custom types with inherited engine classes"
```

### Task 3: Canonical Edit, Server, and Client behavior templates

**Files:**
- Create: `src/App/Types/BehaviorModel.luau`
- Modify: `src/App/Types/BehaviorTemplatePolicy.luau`
- Modify: `src/App/Types/Registry.luau`
- Modify: `src/App/Behaviors/Host.luau`
- Modify: `src/App/Properties/init.luau`
- Modify: `src/App/Explorer/Tree.luau`
- Create: `tests/BehaviorModel.spec.luau`
- Modify: `tests/BehaviorTemplatePolicy.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- `BehaviorModel.SIDES = { "Edit", "Server", "Client" }`.
- Produces `BehaviorModel.name(typeId, side): string`.
- Produces `BehaviorModel.defaultSource(typeId, side): string`.
- Produces `BehaviorModel.serverMigrationSource(typeId): string`.
- Registry methods become `ensureBehaviorTemplate(typeId, side)`, `getBehaviorSource(typeId, side)`, `setBehaviorSource(typeId, side, source)`, and `watchBehaviorTemplates()`.

- [ ] **Step 1: Write failing skeleton and migration tests.**

```luau
local Model = require("../src/App/Types/BehaviorModel")

return {
	["client skeleton has runtime hooks only"] = function()
		local source = Model.defaultSource("Zombie", "Client")
		assert(source:find("Behavior.onStart", 1, true))
		assert(source:find("Behavior.onStop", 1, true))
		assert(not source:find("onSelected", 1, true))
		assert(not source:find("onPropertyChanged", 1, true))
	end,
	["edit skeleton has no play hooks"] = function()
		local source = Model.defaultSource("Zombie", "Edit")
		assert(source:find("onSelected", 1, true))
		assert(not source:find("Behavior.onStart", 1, true))
	end,
}
```

- [ ] **Step 2: Run Lune; expect failure because `BehaviorModel` does not exist.**

- [ ] **Step 3: Implement exact canonical names and skeletons.**

```luau
local SUFFIX = { Edit = "EditBehavior", Server = "ServerBehavior", Client = "ClientBehavior" }
local LIFECYCLE = {
	Edit = { "onCreated", "onSelected", "onPropertyChanged", "onAncestryChanged" },
	Server = { "onStart", "onStop" },
	Client = { "onStart", "onStop" },
}
```

Generate each function with `instance: Instance` and `return Behavior`. `serverMigrationSource(typeId)` requires the canonical Edit template and explicitly forwards only `onStart` and `onStop` when present.

- [ ] **Step 4: Migrate a legacy `{typeId}Behavior` once: canonicalize duplicates first, preserve the original in `BehaviorBackups`, rename/copy it to Edit Behavior, create the forwarding Server Behavior, and create an empty Client Behavior. Mark all canonical templates with `_FraguaBehaviorSide`.**

- [ ] **Step 5: Restrict `Host.luau` to Edit Behavior and `RunService:IsEdit()`; update Properties and Explorer actions to show three clearly named “Edit … Behavior” commands that open the shared ModuleScripts in Roblox's editor. Remove creation/sync of per-instance Behavior children.**

- [ ] **Step 6: Run Lune and `rg -n 'ensureBehaviorTemplate\([^,\)]*\)' src` to find every unsided call; the only matches may be the function definition or migration compatibility wrapper. Commit.**

```bash
git add src/App/Types/BehaviorModel.luau src/App/Types/BehaviorTemplatePolicy.luau src/App/Types/Registry.luau src/App/Behaviors/Host.luau src/App/Properties/init.luau src/App/Explorer/Tree.luau tests/BehaviorModel.spec.luau tests/BehaviorTemplatePolicy.spec.luau tests/run.luau
git commit -m "feat: split custom type behaviors by execution side"
```

### Task 4: Server/client runtime hosts and replicated catalogue privacy

**Files:**
- Modify: `src/App/Runtime/TypeCatalog.luau`
- Modify: `src/App/Runtime/BootstrapSource.luau`
- Create: `src/App/Runtime/ClientBootstrapSource.luau`
- Modify: `src/App/Runtime/EnsurePlaceModules.luau`
- Modify: `src/App/Runtime/ScriptHeader.luau`
- Modify: `tests/TypeCatalog.spec.luau`
- Create: `tests/RuntimeSources.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Public catalogue entries expose resolved schema, backing class, inheritance IDs, and Client Behavior.
- Server runtime resolves Server Behavior from `ServerStorage.Fragua.Types`.
- Client runtime resolves Client Behavior from `ReplicatedStorage.FraguaTypes`.
- Ensures `StarterPlayer.StarterPlayerScripts.FraguaClientRuntime` as a managed LocalScript.

- [ ] **Step 1: Add failing source/privacy tests.**

```luau
local TypeCatalog = require("../src/App/Runtime/TypeCatalog")
local serverSource = require("../src/App/Runtime/BootstrapSource")
local clientSource = require("../src/App/Runtime/ClientBootstrapSource")

return {
	["catalog snapshot identifies public client behavior only"] = function()
		local snapshot = TypeCatalog.snapshot({ { id = "Zombie", name = "Zombie", extends = "Part" } }, function()
			return {}
		end, function() return "Part" end)
		assert(snapshot[1].backingClass == "Part")
	end,
	["runtime sources are side-specific"] = function()
		assert(serverSource:find("ServerBehavior", 1, true))
		assert(not serverSource:find("ClientBehavior", 1, true))
		assert(clientSource:find("ClientBehavior", 1, true))
		assert(not clientSource:find("ServerStorage", 1, true))
	end,
}
```

- [ ] **Step 2: Run Lune; expect failure for the missing client source and old catalogue signature.**

- [ ] **Step 3: Update catalogue sync so each entry has `BackingClass`, ordered `FraguaAncestors`, full property metadata, attributes for attribute-compatible defaults, ObjectValue children for references, and only a cloned `ClientBehavior`. Explicitly destroy legacy replicated `Behavior`, `EditBehavior`, or `ServerBehavior` children.**

- [ ] **Step 4: Implement symmetrical hosts with `started[instance]`, CollectionService add/remove signals, isolated `pcall`, and `onStart`/`onStop`. The server requires the ServerStorage template; the client requires the replicated client template. Neither host edits `Source` during play.**

- [ ] **Step 5: Make `EnsurePlaceModules.ensureModule` write only when managed source differs. Create the client host under StarterPlayerScripts and add all three managed runtime paths to `ScriptHeader.shouldSkip`.**

- [ ] **Step 6: Run Lune, Selene, and Rojo build; inspect the built tree with `rojo sourcemap default.project.json -o /tmp/fragua-sourcemap.json` and confirm all three managed locations. Commit.**

```bash
git add src/App/Runtime/TypeCatalog.luau src/App/Runtime/BootstrapSource.luau src/App/Runtime/ClientBootstrapSource.luau src/App/Runtime/EnsurePlaceModules.luau src/App/Runtime/ScriptHeader.luau tests/TypeCatalog.spec.luau tests/RuntimeSources.spec.luau tests/run.luau
git commit -m "feat: add isolated server and client behavior hosts"
```

### Task 5: Wrapper policy and runtime gateway

**Files:**
- Create: `src/App/Runtime/WrapperPolicy.luau`
- Modify: `src/App/Runtime/ApiSource.luau`
- Modify: `src/App/Runtime/EnsurePlaceModules.luau`
- Modify: `tests/ApiSource.spec.luau`
- Create: `tests/WrapperPolicy.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- `ApiSource.build(surface?): string` replaces the static source return.
- `EnsurePlaceModules.sync(surface?)` calls `ApiSource.build(surface or { types = {} })` so the repository remains runnable before Task 7 supplies generated types.
- Runtime exports `Core`, `Server`, and `Client` facades, each with `Instance`, `Enum`, `type`, `typeof`, and Fragua helpers.
- `WrapperPolicy.readOrder` and `WrapperPolicy.isReserved(name, nativeMembers)` centralize collision policy for Registry validation and generated runtime code.

- [ ] **Step 1: Write failing policy/source contract tests.**

```luau
local ApiSource = require("../src/App/Runtime/ApiSource")
local WrapperPolicy = require("../src/App/Runtime/WrapperPolicy")

return {
	["gateway exposes constructors and compatibility aliases"] = function()
		local source = ApiSource.build({ types = {} })
		assert(source:find("FraguaInstance.fromExisting", 1, true))
		assert(source:find("function Facade.typeof", 1, true))
		assert(source:find('return "Instance"', 1, true))
		assert(source:find('return "userdata"', 1, true))
	end,
	["core members are reserved"] = function()
		assert(WrapperPolicy.isReserved("Destroy", {}))
		assert(WrapperPolicy.isReserved("Instance", {}))
		assert(WrapperPolicy.isReserved("FindFirstChild", { FindFirstChild = true }))
	end,
}
```

- [ ] **Step 2: Run Lune; expect failure because `ApiSource` is not a builder and `WrapperPolicy` is absent.**

- [ ] **Step 3: Implement the facade and wrapper runtime in the generated source. Use weak caches and a protected metatable.**

```luau
local wrappersBySide = {
	Core = setmetatable({}, { __mode = "kv" }),
	Server = setmetatable({}, { __mode = "kv" }),
	Client = setmetatable({}, { __mode = "kv" }),
}

local function wrap(backing: Instance, side: string)
	local wrappers = wrappersBySide[side]
	local existing = wrappers[backing]
	if existing then return existing end
	local state = { backing = backing, side = side, methods = {}, destroyed = false }
	local proxy = setmetatable({}, WRAPPER_METATABLE)
	wrapperStates[proxy] = state
	wrappers[backing] = proxy
	return proxy
end
```

`__index` resolves core members, side behavior methods, custom schema values, then backing members. When a backing member is a function, cache `function(_, ...) return member(backing, unwrapArguments(...)) end`. `__newindex` writes custom attributes/reference ObjectValues or a backing property and unwraps wrapper values.

Load and cache behavior tables by type ID and side. Server resolves `{typeId}ServerBehavior` under `ServerStorage.Fragua.Types`; Client resolves the replicated `ClientBehavior`; Core never loads a side behavior. A custom method closure calls `method(backing, ...)`. Reject lifecycle names and raise a side-specific error when a known method exists only on the other facade.

- [ ] **Step 4: Implement explicit `Destroy`, `Clone`, and `IsA`. `Clone` returns nil when Roblox returns nil; otherwise it reapplies type metadata and wraps the clone. After `Destroy`, every access except a diagnostic `TypeId` raises `[Fragua] attempted to use a destroyed <type> wrapper`.**

- [ ] **Step 5: Implement constructors. Native class strings win collisions. Custom `new` resolves the catalogue backing class, applies only custom defaults, tags it, and wraps it. Custom `fromExisting` calls captured `RobloxInstance.fromExisting(backing)`, copies custom/reference values explicitly, retains the type ID, and returns a wrapper. The facade metatable forwards unknown static keys to captured `RobloxInstance`.**

For enum properties, store the item name and return `RobloxEnum[prop.enumType][storedName]`; accept only an item of the declared EnumType or one of the declared names. For reference properties, read/write the managed `_FraguaRef_<propertyName>` ObjectValue and unwrap assigned Fragua wrappers.

- [ ] **Step 6: Implement compatible aliases.**

```luau
function Facade.type(value)
	return if wrapperStates[value] then "userdata" else RobloxType(value)
end

function Facade.typeof(value)
	return if wrapperStates[value] then "Instance" else RobloxTypeof(value)
end
```

- [ ] **Step 7: Update EnsurePlaceModules to build the API source from its optional surface. Update Registry/TypeDraft reserved-name validation to consume `WrapperPolicy`; run Lune, Selene, `git diff --check`, and Rojo build. Commit.**

```bash
git add src/App/Runtime/WrapperPolicy.luau src/App/Runtime/ApiSource.luau src/App/Runtime/EnsurePlaceModules.luau src/App/Types/Registry.luau src/App/Types/TypeDraft.luau tests/ApiSource.spec.luau tests/WrapperPolicy.spec.luau tests/run.luau
git commit -m "feat: add native-feeling Fragua instance wrappers"
```

### Task 6: Context-aware, cursor-safe import headers

**Files:**
- Create: `src/App/Runtime/ScriptContext.luau`
- Modify: `src/App/Runtime/ScriptHeader.luau`
- Modify: `src/App/Runtime/ScriptInjector.luau`
- Modify: `tests/ScriptHeader.spec.luau`
- Create: `tests/ScriptContext.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces `ScriptContext.select(className: string, fullName: string): "Server" | "Client" | "Core"`.
- `ScriptHeader.apply(source, facade): (string, boolean)`.
- Injector determines the facade once per update from the container and passes it to both the preflight and UpdateSourceAsync callback.

- [ ] **Step 1: Write failing context and complete-header idempotence tests.**

```luau
assert(Context.select("Script", "ServerScriptService.Game") == "Server")
assert(Context.select("LocalScript", "StarterPlayer.StarterPlayerScripts.Game") == "Client")
assert(Context.select("ModuleScript", "ReplicatedStorage.Shared") == "Core")
assert(Context.select("ModuleScript", "ServerStorage.Private") == "Server")

local once = Header.apply("print('ok')", "Client")
local twice, changed = Header.apply(once, "Client")
assert(not changed and once == twice)
assert(once:find("FraguaGateway.Client", 1, true))
assert(once:find("local type = Fragua.type", 1, true))
```

- [ ] **Step 2: Run Lune; expect signature/assertion failures against the single old header.**

- [ ] **Step 3: Generate the exact approved header using `FraguaGateway.<facade>`, `Instance`, `Enum`, `type`, and `typeof`. Preserve leading Luau directives and all bytes outside the first complete marker block.**

- [ ] **Step 4: Update ScriptInjector so `ScriptUpdateGate` avoids UpdateSourceAsync when the current editor source already has the exact context header. Keep weak recursion/warning guards and never react to generated gateway/runtime source changes.**

- [ ] **Step 5: Run Lune and `rg -n 'UpdateSourceAsync' src/App/Runtime`; verify the injector remains the only user-script writer. Commit.**

```bash
git add src/App/Runtime/ScriptContext.luau src/App/Runtime/ScriptHeader.luau src/App/Runtime/ScriptInjector.luau tests/ScriptHeader.spec.luau tests/ScriptContext.spec.luau tests/run.luau
git commit -m "feat: inject typed Fragua runtime facades"
```

### Task 7: Behavior signatures and generated Luau type surfaces

**Files:**
- Create: `src/App/Runtime/BehaviorSignatures.luau`
- Create: `src/App/Runtime/TypeSurface.luau`
- Modify: `src/App/Runtime/ApiSource.luau`
- Modify: `src/App/Runtime/EnsurePlaceModules.luau`
- Modify: `src/App/Runtime/TypeCatalog.luau`
- Modify: `src/init.server.luau`
- Create: `tests/BehaviorSignatures.spec.luau`
- Create: `tests/TypeSurface.spec.luau`
- Modify: `tests/ApiSource.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- `BehaviorSignatures.parse(source): { { name, parameters, returns } }` excludes lifecycle hooks.
- `TypeSurface.build(definitions, resolveSchema, resolveBacking, getBehaviorSource): Surface`.
- Surface has ordered `types`, each with `id`, `backingClass`, `properties`, `serverMethods`, and `clientMethods`.
- `ApiSource.build(surface)` emits exported server/client/core type aliases and literal constructor overloads.
- `EnsurePlaceModules.sync(surface)` rebuilds the managed gateway from that exact surface.

- [ ] **Step 1: Write failing parser/surface tests.**

```luau
local methods = Signatures.parse([[
function Behavior.onStart(instance: Instance) end
function Behavior.Attack(instance: Instance, target: Instance, damage: number): boolean
	return true
end
]])
assert(#methods == 1 and methods[1].name == "Attack")
assert(methods[1].parameters[1].name == "target")
assert(methods[1].returns == "boolean")

local surface = TypeSurface.build(definitions, resolveSchema, resolveBacking, getBehaviorSource)
assert(surface.types[1].serverMethods[1].name == "Attack")
local propertyByName = {}
for _, property in surface.types[1].properties do propertyByName[property.name] = property end
assert(propertyByName.Health.typeName == "number")
```

- [ ] **Step 2: Run Lune; expect missing-module failures.**

- [ ] **Step 3: Implement a conservative line-oriented parser for declarations matching `function Behavior.Name(...)[: Return]`. Split parameters only at top-level commas, drop the first `instance` parameter, preserve annotations verbatim after validating allowed Luau type characters, and ignore unannotated/dynamic exports for typing.**

- [ ] **Step 4: Build deterministic surfaces sorted by type ID and member name. Map Fragua value types to Luau names (`enum` to `EnumItem`, references to `Instance` or the referenced generated type). Include inherited resolved properties exactly once.**

- [ ] **Step 5: Emit compilable aliases and overload intersections.**

```luau
export type ZombieServer = Part & {
	Health: number,
	Attack: (self: ZombieServer, target: Instance, damage: number) -> boolean,
}

type ServerNew = typeof(RobloxInstance.new)
	& ((className: "Zombie", parent: Instance?) -> ZombieServer)
```

Expose distinct `Server.Instance`, `Client.Instance`, and `Core.Instance` casts over the same runtime facade. Core types contain native/inherited properties and custom properties but no side-specific methods.

- [ ] **Step 6: Rebuild the gateway only on registry or behavior-template revision changes. In `init.server.luau`, seed/migrate the Registry first, build one `currentSurface`, then call `TypeCatalog.sync`, `EnsurePlaceModules.sync(currentSurface)`, and start ScriptInjector. On `Registry.Changed`, rebuild `currentSurface` and resync both managed outputs. Run Lune and build the plugin. In Studio, create a temporary Script and LocalScript and confirm the generated gateway has no syntax diagnostics before committing.**

- [ ] **Step 7: Commit.**

```bash
git add src/App/Runtime/BehaviorSignatures.luau src/App/Runtime/TypeSurface.luau src/App/Runtime/ApiSource.luau src/App/Runtime/EnsurePlaceModules.luau src/App/Runtime/TypeCatalog.luau src/init.server.luau tests/BehaviorSignatures.spec.luau tests/TypeSurface.spec.luau tests/ApiSource.spec.luau tests/run.luau
git commit -m "feat: generate context-aware custom instance types"
```

### Task 8: Lightweight native-editor autocomplete

**Files:**
- Create: `src/App/Runtime/AutocompleteModel.luau`
- Create: `src/App/Runtime/AutocompleteProvider.luau`
- Modify: `src/init.server.luau`
- Create: `tests/AutocompleteModel.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- `AutocompleteModel.complete(request, surface, facade): { CompletionItem }`.
- `AutocompleteProvider.start(getSurface): { destroy: () -> () }`.
- Provider registers callback name `FraguaAutocompleteV1` at priority 100 and appends to the incoming response.

- [ ] **Step 1: Write failing completion tests for construction, a typed local, enums, and side filtering.**

```luau
local request = {
	line = 'local zombie = Instance.new("Zombie")\nzombie:',
	position = 52,
}
local items = Model.complete(request, surface, "Server")
assert(find(items, "Attack"))
assert(not find(items, "PlayClientEffect"))

local enumItems = Model.complete({ line = "Enum.FraguaType.", position = 16 }, surface, "Core")
assert(find(enumItems, "Zombie"))
```

- [ ] **Step 2: Run Lune; expect missing-module failure.**

- [ ] **Step 3: Implement bounded context recognition: inspect only the current line plus at most 200 preceding lines; recognize `Instance.new("Literal")`, `Instance.new(Enum.FraguaType.Name)`, simple local assignments, `Fragua.Get(local)`, `Enum.FraguaType.`, and constructor string positions. Cache local-to-type inference by document text hash and catalogue revision.**

- [ ] **Step 4: Convert model items to ScriptEditorService completion items with `label`, `kind`, `detail`, `documentation`, and a replacement `textEdit` only when replacing a partial identifier. Never remove or reorder native response items.**

- [ ] **Step 5: Register with:**

```luau
ScriptEditorService:RegisterAutocompleteCallback("FraguaAutocompleteV1", 100, function(request, response)
	local ok, additions = pcall(buildAdditions, request)
	if ok then
		for _, item in additions do table.insert(response.items, item) end
	end
	return response
end)
```

On destroy, call `DeregisterAutocompleteCallback("FraguaAutocompleteV1")` in `pcall`. Start after Registry/catalog initialization and destroy during `plugin.Unloading`.

- [ ] **Step 6: Run Lune, Selene, and Rojo. In Studio verify `zombie:` retains Roblox suggestions and adds the correct side methods without typing lag. Commit.**

```bash
git add src/App/Runtime/AutocompleteModel.luau src/App/Runtime/AutocompleteProvider.luau src/init.server.luau tests/AutocompleteModel.spec.luau tests/run.luau
git commit -m "feat: add custom type autocomplete to Roblox editor"
```

### Task 9: Reusable toggle and default-control descriptors

**Files:**
- Modify: `src/App/Properties/Controls.luau`
- Modify: `src/App/Properties/init.luau`
- Create: `src/App/Types/DefaultControlModel.luau`
- Create: `tests/DefaultControlModel.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces `Controls.booleanToggle(parent, value, onCommit): (TextButton, update)`.
- Produces `DefaultControlModel.describe(prop): { kind, height, options? }`.
- Properties uses the shared toggle instead of its inline implementation.

- [ ] **Step 1: Write failing descriptor tests.**

```luau
assert(Model.describe({ valueType = "boolean" }).kind == "toggle")
assert(Model.describe({ valueType = "enum", enumItems = { "A", "B" } }).kind == "enum")
assert(Model.describe({ valueType = "number", minimum = 0, maximum = 1 }).kind == "slider")
assert(Model.describe({ valueType = "Vector3" }).components[3] == "Z")
assert(Model.describe({ valueType = "FraguaInstance", referenceType = "Zombie" }).kind == "reference")
```

- [ ] **Step 2: Run Lune; expect missing-module failure.**

- [ ] **Step 3: Extract the existing animated Properties boolean code into `Controls.booleanToggle`. Keep tween tokens so rapid clicks commit only the latest state. Return an updater that paints immediately without firing `onCommit`. Replace the inline Properties block with the shared function.**

- [ ] **Step 4: Implement descriptors with fixed heights: 22 for toggle/dropdown/text/number/color/reference, 48 for Vector2/Vector3/UDim, 72 for UDim2, and 96 for CFrame. A number becomes `slider` only when both finite minimum and maximum exist; otherwise it is `number`.**

- [ ] **Step 5: Run Lune and Rojo; manually toggle an existing boolean property rapidly and confirm one final commit. Commit.**

```bash
git add src/App/Properties/Controls.luau src/App/Properties/init.luau src/App/Types/DefaultControlModel.luau tests/DefaultControlModel.spec.luau tests/run.luau
git commit -m "refactor: share typed property control models"
```

### Task 10: Compact typed default editor

**Files:**
- Create: `src/App/Types/DefaultEditor.luau`
- Modify: `src/App/Types/TypeEditor.luau`
- Modify: `src/App/Types/TypeEditorLayout.luau`
- Modify: `src/App/Types/TypeDraft.luau`
- Modify: `src/App/Types/Registry.luau`
- Modify: `tests/TypeEditorLayout.spec.luau`
- Modify: `tests/TypeDraft.spec.luau`
- Modify: `tests/TypeValue.spec.luau`

**Interfaces:**
- `DefaultEditor.mount(parent, prop, options): { update, destroy }`.
- `options` contains `host`, `getEnumNames`, `getEnumItems`, `getSelection`, and `onChanged`.
- TypeEditor owns one default-control host per property row and replaces only that host when `valueType` changes.

- [ ] **Step 1: Extend failing layout/draft tests so a changed control height affects only its row and category order remains unchanged.**

```luau
local before = Layout.measureRows({ 22, 22, 22 }, 6)
local after = Layout.measureRows({ 22, 96, 22 }, 6)
assert(after - before == 74)

local order = TypeDraft.snapshotCategoryOrder(draft)
TypeDraft.updateProperty(draft, propertyId, { valueType = "CFrame", defaultValue = CFrame.identity })
assertDeepEqual(TypeDraft.snapshotCategoryOrder(draft), order)
```

- [ ] **Step 2: Run Lune; expect missing functions/assertion failures.**

- [ ] **Step 3: Implement DefaultEditor branches using existing Controls:**

```luau
if descriptor.kind == "toggle" then
	control, update = Controls.booleanToggle(parent, value == true, changed)
elseif descriptor.kind == "enum" then
	control = Controls.enumDropdown(parent, prop.enumItems, value, changed, prop.enumType, { host = options.host })
elseif descriptor.kind == "slider" then
	control, update = Controls.numberField(parent, value, changed, { prop.minimum, prop.maximum })
elseif descriptor.kind == "color" then
	control, update = Controls.colorField(parent, value, changed, options.onPreview)
end
```

Use compact labeled TextBoxes for vector/dimension/CFrame components. Commit only when all components parse. For enum, show an enum-type dropdown followed by the item dropdown and refresh items from Roblox's live Enum facade.

- [ ] **Step 4: Implement reference controls as a button displaying the selected path plus “Use selection” and clear actions. Validate `Instance` or `FraguaInstance`/`referenceType` before accepting. Registry stores reference defaults in managed ObjectValue children under the type definition and catalogue entry; JSON contains only `{ __typeof = "ObjectReference", property = name }`.**

- [ ] **Step 5: Replace TypeEditor's `VALUE_TYPES` and unconditional `defField` with the full supported list and a fixed host. On type change, call `oldEditor.destroy()`, set `prop.defaultValue = TypeValue.default(newType, prop)`, mount the replacement, and update only row height/canvas calculations. Do not call `rebuildProps()`.**

- [ ] **Step 6: Save typed `defaultValue` and metadata directly. Show `TypeValue.validate` messages beside their property rows, keep Create/Cancel outside the scrolling content, and preserve `CanvasPosition` across any necessary category rebuild.**

- [ ] **Step 7: Run Lune, Selene, and Rojo. In Studio create one property of every supported type, resize the dock narrowly, scroll to the bottom, toggle booleans, choose enum defaults, drag numeric sliders, preview colors, select references, and save/reopen the type. Commit.**

```bash
git add src/App/Types/DefaultEditor.luau src/App/Types/TypeEditor.luau src/App/Types/TypeEditorLayout.luau src/App/Types/TypeDraft.luau src/App/Types/Registry.luau tests/TypeEditorLayout.spec.luau tests/TypeDraft.spec.luau tests/TypeValue.spec.luau
git commit -m "feat: add typed controls for custom property defaults"
```

### Task 11: Integration regressions, documentation, and deployment

**Files:**
- Modify: `README.md`
- Modify: relevant tests from Tasks 1–10
- Build artifact: `/tmp/Fragua-typed-runtime.rbxm`
- Install artifact: `/Users/williamnorth/Documents/Roblox/Plugins/Fragua.rbxm`

**Interfaces:**
- Documents wrapper interop, all three behavior sides, `Instance.fromExisting`, `type`/`typeof`, explicit `.Instance`, method declarations, and typed defaults.

- [ ] **Step 1: Add cross-feature regression tests to the named existing suites.**

```luau
-- tests/ScriptHeader.spec.luau
local once = Header.apply("--!strict\nlocal x = 1\n", "Server")
local twice, changed = Header.apply(once, "Server")
assert(once:sub(1, 8) == "--!strict" and not changed and twice == once)

-- tests/BackingClassResolver.spec.luau
assert(Resolver.resolve("ArmoredZombie", function(id)
	return ({ ArmoredZombie = { extends = "Zombie" }, Zombie = { extends = "SpawnLocation" } })[id]
end) == "SpawnLocation")

-- tests/TypeSurface.spec.luau
local function findType(items, id)
	for _, item in items.types do if item.id == id then return item end end
	return nil
end
local function findProperty(item, name)
	for _, property in item.properties do if property.name == name then return property end end
	return nil
end
local function findMethod(items, name)
	for _, method in items do if method.name == name then return method end end
	return nil
end
local zombie = assert(findType(surface, "Zombie"))
assert(findProperty(zombie, "Transparency"))
assert(findProperty(zombie, "Health"))
assert(findMethod(zombie.serverMethods, "Attack"))
assert(not findMethod(zombie.clientMethods, "Attack"))

-- tests/BehaviorModel.spec.luau
local names = {
	Model.name("Zombie", "Edit"),
	Model.name("Zombie", "Server"),
	Model.name("Zombie", "Client"),
}
assert(names[1] ~= names[2] and names[2] ~= names[3] and names[1] ~= names[3])

-- tests/RuntimeSources.spec.luau
assert(clientSource:find("ClientBehavior", 1, true))
assert(not clientSource:find("ServerBehavior", 1, true))
assert(not clientSource:find("EditBehavior", 1, true))

-- tests/PropertyRefreshPolicy.spec.luau
assert(Policy.action("property", "Transparency") == "update")
assert(Policy.action("property", "Anchored") == "update")
```

Run `lune run tests/run.luau`; expect all assertions to pass.

- [ ] **Step 2: Update README with exact usage.**

```luau
local zombie = Instance.new("Zombie")
zombie.Health = 100
zombie:Attack(target)
zombie.Parent = workspace

print(type(zombie)) -- userdata
print(typeof(zombie)) -- Instance
print(Fragua.GetTypeId(zombie)) -- Zombie

workspace:Raycast(origin, direction, params)
someRobloxApi(zombie.Instance) -- explicit boundary for APIs requiring userdata
```

- [ ] **Step 3: Run fresh automated verification, not cached results.**

```bash
/Users/williamnorth/.aftman/bin/stylua --check src tests
/Users/williamnorth/.aftman/bin/selene src tests
/Users/williamnorth/.aftman/bin/lune run tests/run.luau
/Users/williamnorth/.aftman/bin/rojo build -o /tmp/Fragua-typed-runtime.rbxm
git diff --check
```

Expected: all commands exit 0 and the Lune output reports zero failed tests.

- [ ] **Step 4: Perform the Studio acceptance matrix.**

```text
Edit mode: Edit hooks run; Server/Client hooks do not.
Play server: Server hooks and methods run; Edit/Client hooks do not.
Play client: Client hooks and methods run; Edit/Server hooks do not.
Script autocomplete: inherited native + custom + Server methods.
LocalScript autocomplete: inherited native + custom + Client methods.
Ambiguous ModuleScript: core members only until explicit facade selection.
Instance.new("Part"): genuine Part.
Instance.new("Zombie"): wrapper backed by the resolved engine class.
Instance.fromExisting(zombie): same Fragua type, values copied, no descendants.
zombie:Destroy(): destroys backing instance and invalidates wrapper.
Type editor: every default control fits, scrolls, saves, and reopens.
```

- [ ] **Step 5: Inspect status and commit only intended integration/docs changes.**

```bash
git status --short
git add README.md tests
git commit -m "docs: document typed Fragua runtime workflows"
```

Do not add `.superpowers/`.

- [ ] **Step 6: Install the verified artifact and compare checksums.**

```bash
cp /tmp/Fragua-typed-runtime.rbxm /Users/williamnorth/Documents/Roblox/Plugins/Fragua.rbxm
shasum -a 256 /tmp/Fragua-typed-runtime.rbxm /Users/williamnorth/Documents/Roblox/Plugins/Fragua.rbxm
```

Expected: the two SHA-256 values are identical.

- [ ] **Step 7: Push only after every automated and Studio acceptance check passes.**

```bash
git push origin main
git rev-parse HEAD
git ls-remote origin refs/heads/main
```

Expected: local HEAD and the remote `refs/heads/main` hash match.
