# Native Editor and Runtime Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Replace the custom editor with Roblox Studio's native editor, automatically inject Fragua aliases, expose custom types through compatible Instance and Enum proxies, and inherit engine properties by Roblox class family.

**Architecture:** Pure modules own property-layer resolution, source-header transformation, and catalogue snapshots. Studio services use those decisions through ScriptEditorService and mirror the registry into ReplicatedStorage; the runtime gateway reads the mirror dynamically.

**Tech Stack:** Luau, Roblox plugin APIs, ScriptEditorService, CollectionService, Rojo, Lune, Selene, StyLua.

## Global Constraints

- Inject only Fragua, Instance, and Enum.
- Never replace require, type, typeof, game, or standard libraries.
- Preserve all source outside the marked header byte-for-byte.
- Skip ReplicatedStorage.Fragua and ServerScriptService.FraguaRuntime.
- Roblox classes win string collisions.
- Never stage or modify .superpowers/.

---

### Task 1: Engine property inheritance

**Files:**
- Create: src/App/Properties/EnginePropResolver.luau
- Modify: src/App/Properties/EngineProps.luau
- Create: tests/EnginePropResolver.spec.luau
- Modify: tests/run.luau

**Interfaces:**
- Produces EnginePropResolver.resolve(className, isA, exact, families).
- families is ordered { className, properties } data.

- [ ] **Step 1: Write failing tests**

~~~luau
local Resolver = require("../src/App/Properties/EnginePropResolver")
return {
    ["SpawnLocation receives BasePart and exact rows"] = function()
        local rows = Resolver.resolve("SpawnLocation", function(name)
            return name == "BasePart"
        end, {
            Instance = { { name = "Name" } },
            SpawnLocation = { { name = "Enabled" } },
        }, {
            { className = "BasePart", properties = { { name = "Transparency" } } },
        })
        local found = {}
        for _, row in rows do found[row.name] = true end
        assert(found.Name and found.Transparency and found.Enabled)
    end,
    ["exact rows override family rows without duplicates"] = function()
        local rows = Resolver.resolve("SpawnLocation", function() return true end, {
            Instance = {},
            SpawnLocation = { { name = "Color", category = "Spawn" } },
        }, {
            { className = "BasePart", properties = { { name = "Color", category = "Appearance" } } },
        })
        assert(#rows == 1 and rows[1].category == "Spawn")
    end,
}
~~~

- [ ] **Step 2: Run Lune and verify RED because EnginePropResolver is missing.**
- [ ] **Step 3: Merge Instance, matching families, then exact class; replace duplicate names in place. Move Part-common rows into a BasePart family and call the resolver from EngineProps.forInstance with instance:IsA.**
- [ ] **Step 4: Run Lune and verify GREEN.**
- [ ] **Step 5: Commit with message fix: inherit engine properties by class family.**

### Task 2: Managed source header

**Files:**
- Create: src/App/Runtime/ScriptHeader.luau
- Create: tests/ScriptHeader.spec.luau
- Modify: tests/run.luau

**Interfaces:**
- Produces ScriptHeader.apply(source): (source, changed).
- Produces ScriptHeader.shouldSkip(fullName): boolean.

- [ ] **Step 1: Write failing tests**

~~~luau
local Header = require("../src/App/Runtime/ScriptHeader")
return {
    ["adds aliases and preserves source"] = function()
        local result, changed = Header.apply("print('hello')\n")
        assert(changed and result:find("local Instance = Fragua.Instance", 1, true))
        assert(result:sub(-15) == "print('hello')\n")
    end,
    ["is idempotent and replaces old marked content"] = function()
        local once = Header.apply("return true")
        local twice, changed = Header.apply(once)
        assert(not changed and twice == once)
        local updated = Header.apply("-- Fragua imports begin\nold\n-- Fragua imports end\nreturn true")
        assert(updated:find("local Enum = Fragua.Enum", 1, true))
        assert(not updated:find("\nold\n", 1, true))
    end,
    ["skips managed runtime modules"] = function()
        assert(Header.shouldSkip("ReplicatedStorage.Fragua"))
        assert(Header.shouldSkip("ServerScriptService.FraguaRuntime"))
    end,
}
~~~

- [ ] **Step 2: Run Lune and verify RED.**
- [ ] **Step 3: Implement the exact managed block below, replacing the first complete marked block or prepending it plus one blank line.**

~~~luau
-- Fragua imports begin
local Fragua = require(game:GetService("ReplicatedStorage"):WaitForChild("Fragua"))
local Instance = Fragua.Instance
local Enum = Fragua.Enum
-- Fragua imports end
~~~

- [ ] **Step 4: Run Lune and verify GREEN.**
- [ ] **Step 5: Commit with message feat: add managed Fragua script imports.**

### Task 3: Automatic script injection

**Files:**
- Create: src/App/Runtime/ScriptInjector.luau
- Modify: src/init.server.luau

**Interfaces:**
- Consumes ScriptHeader.apply and shouldSkip.
- Produces ScriptInjector.start(): { destroy: () -> () }.

- [ ] **Step 1: Scan game:GetDescendants() for LuaSourceContainer instances and update them through ScriptEditorService:UpdateSourceAsync.**
- [ ] **Step 2: Add a weak-key recursion guard, game.DescendantAdded handling, and Source listeners that repair removed or outdated headers.**
- [ ] **Step 3: Catch failures and warn exactly [Fragua] Could not add imports to <full name>: <error>.**
- [ ] **Step 4: Start after EnsurePlaceModules.sync and destroy every connection during plugin.Unloading.**
- [ ] **Step 5: Run StyLua check, Selene, Lune, and Rojo build; commit with message feat: inject Fragua aliases into place scripts.**

### Task 4: Replicated type catalogue

**Files:**
- Create: src/App/Runtime/TypeCatalog.luau
- Modify: src/init.server.luau
- Create: tests/TypeCatalog.spec.luau
- Modify: tests/run.luau

**Interfaces:**
- Produces TypeCatalog.snapshot(definitions, resolveSchema).
- Produces TypeCatalog.sync(registry).
- Creates managed ReplicatedStorage.FraguaTypes entries with Defaults and Behavior children.

- [ ] **Step 1: Write the failing snapshot test**

~~~luau
local TypeCatalog = require("../src/App/Runtime/TypeCatalog")
return {
    ["snapshot contains resolved inherited defaults"] = function()
        local rows = TypeCatalog.snapshot({ { id = "FastZombie", name = "Fast Zombie" } }, function()
            return { { name = "Health", default = 100 }, { name = "WalkSpeed", default = 24 } }
        end)
        assert(rows[1].id == "FastZombie")
        assert(rows[1].properties[2].default == 24)
    end,
}
~~~

- [ ] **Step 2: Run Lune and verify RED.**
- [ ] **Step 3: Keep snapshot service-free. In sync, modify only managed catalogue children, store TypeId and DisplayName, write resolved defaults on Defaults, and clone Registry.getSharedBehavior(id) as Behavior.**
- [ ] **Step 4: Call sync after Registry.seedDefaults and whenever Registry.Changed fires.**
- [ ] **Step 5: Run Lune and commit with message feat: replicate Fragua type catalogue.**

### Task 5: Runtime Instance and Enum proxies

**Files:**
- Modify: src/App/Runtime/ApiSource.luau
- Create: tests/ApiSource.spec.luau
- Modify: tests/run.luau
- Modify: README.md

**Interfaces:**
- Produces Fragua.Instance.new(classOrType, parent), Fragua.Enum, and Fragua.Enum.FraguaType.
- Consumes ReplicatedStorage.FraguaTypes.

- [ ] **Step 1: Write failing source-contract tests**

~~~luau
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
    end,
}
~~~

- [ ] **Step 2: Run Lune and verify RED against the old gateway.**
- [ ] **Step 3: Capture RobloxInstance and RobloxEnum. Try native construction first; otherwise resolve a custom string or custom enum item, create Configuration, copy Defaults, set _FraguaType, tag it, clone Behavior, and parent it.**
- [ ] **Step 4: Implement Enum __index so FraguaType is dynamic, GetEnums combines live Roblox enums with the Fragua descriptor, and all other keys forward to RobloxEnum.**
- [ ] **Step 5: Document Instance.new("Part"), Instance.new("Zombie"), Instance.new(Enum.FraguaType.Zombie), and Enum.Material.Neon. Run tests and commit with message feat: expose Fragua Instance and Enum proxies.**

### Task 6: Remove custom editor

**Files:**
- Delete: src/App/ScriptEditor/
- Delete: tests/CompletionEngine.spec.luau
- Delete: tests/Diagnostics.spec.luau
- Delete: tests/DocumentStore.spec.luau
- Delete: tests/EditorLayout.spec.luau
- Delete: tests/SyntaxHighlighter.spec.luau
- Modify: tests/run.luau
- Modify: src/init.server.luau
- Modify: src/App/Properties/init.luau

**Interfaces:**
- Properties edit requests call plugin:OpenScript(context.target).

- [ ] **Step 1: Delete the editor modules/tests and remove test registrations.**
- [ ] **Step 2: Remove the editor require, toolbar button, DockWidget, mount, enabled listeners, and unload handling.**
- [ ] **Step 3: Mount Properties with onEditScript calling plugin:OpenScript(context.target).**
- [ ] **Step 4: Delete the startup print.**
- [ ] **Step 5: Run ! rg -n "ScriptEditor|FraguaScriptEditor|Plugin loaded - forge" src tests, then Lune and Rojo.**
- [ ] **Step 6: Commit with message refactor: use Roblox native script editor.**

### Task 7: Verification and deployment

- [ ] **Step 1: Run fresh verification**

~~~bash
/Users/williamnorth/.aftman/bin/stylua --check src tests
/Users/williamnorth/.aftman/bin/selene src tests
/Users/williamnorth/.aftman/bin/lune run tests/run.luau
/Users/williamnorth/.aftman/bin/rojo build -o /tmp/Fragua-native-runtime.rbxm
git diff --check
~~~

- [ ] **Step 2: Confirm git status contains only intended changes plus untouched .superpowers/.**
- [ ] **Step 3: Push main with git push origin main.**
- [ ] **Step 4: Install and verify**

~~~bash
cp /tmp/Fragua-native-runtime.rbxm /Users/williamnorth/Documents/Roblox/Plugins/Fragua.rbxm
shasum -a 256 /tmp/Fragua-native-runtime.rbxm /Users/williamnorth/Documents/Roblox/Plugins/Fragua.rbxm
git rev-parse HEAD
git ls-remote origin refs/heads/main
~~~
