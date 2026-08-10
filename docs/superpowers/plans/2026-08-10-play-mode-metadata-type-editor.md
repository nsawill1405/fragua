# Play-Mode Stability, Metadata Editing, and Type Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Fragua Explorer and Properties fully editable across Studio simulation transitions, add full safe tag/attribute management, make the type editor responsive, and canonicalize duplicate shared behavior templates without losing customized source.

**Architecture:** Pure helpers own lifecycle-generation decisions, metadata validation/defaults, responsive geometry, and duplicate-template selection. Existing Roblox-facing modules consume those helpers and keep side effects at the UI/registry boundary. Explorer and Properties remain mounted and refresh in place when `RunService.RunState` changes.

**Tech Stack:** Luau, Roblox Studio plugin APIs (`RunService`, `CollectionService`, `Selection`, `ChangeHistoryService`), Lune tests, StyLua, Selene, Rojo.

## Global Constraints

- Explorer and Properties remain fully editable during Play and Run sessions.
- Preserve the current Fragua colors, typography, corners, and section styling.
- Protect `_FraguaType` and the required `FraguaInstance` tag from destructive metadata actions.
- Preserve every distinct customized behavior source when reconciling duplicate templates.
- Use one vertical scrolling owner in the type-editor form and keep its footer visible.
- Do not stage, alter, or delete the unrelated untracked `.superpowers/` directory.

---

### Task 1: Generation-Safe Studio Lifecycle Refresh

**Files:**
- Create: `src/App/Shared/LifecycleGate.luau`
- Create: `tests/LifecycleGate.spec.luau`
- Modify: `tests/run.luau`
- Modify: `src/App/Explorer/Tree.luau`
- Modify: `src/App/Explorer/init.luau`
- Modify: `src/App/Properties/init.luau`
- Modify: `src/init.server.luau`

**Interfaces:**
- Produces: `LifecycleGate.new(): Gate`, `Gate:advance(): number`, and `Gate:isCurrent(token: number): boolean`.
- Produces: Explorer API method `refreshForRunState()` and Properties API method `refreshForRunState()`.
- Consumes: `RunService:GetPropertyChangedSignal("RunState")` and existing Explorer/Properties rebuild functions.

- [ ] **Step 1: Write the failing lifecycle-generation tests**

```luau
local ok, LifecycleGate = pcall(function()
	return require("../src/App/Shared/LifecycleGate")
end)

return {
	["transition invalidates work scheduled by the previous generation"] = function()
		assert(ok and LifecycleGate, "LifecycleGate should be available")
		local gate = LifecycleGate.new()
		local stale = gate:advance()
		local current = gate:advance()
		assert(not gate:isCurrent(stale))
		assert(gate:isCurrent(current))
	end,
	["the initial generation can schedule one current refresh"] = function()
		assert(ok and LifecycleGate, "LifecycleGate should be available")
		local gate = LifecycleGate.new()
		assert(gate:isCurrent(0))
	end,
}
```

Register `LifecycleGate.spec` in `tests/run.luau`.

- [ ] **Step 2: Run the suite and verify the lifecycle contract fails**

Run: `lune run tests/run.luau`

Expected: FAIL with `LifecycleGate should be available`.

- [ ] **Step 3: Implement the minimal lifecycle gate**

```luau
local LifecycleGate = {}
LifecycleGate.__index = LifecycleGate

function LifecycleGate.new()
	return setmetatable({ generation = 0 }, LifecycleGate)
end

function LifecycleGate:advance(): number
	self.generation += 1
	return self.generation
end

function LifecycleGate:isCurrent(token: number): boolean
	return token == self.generation
end

return LifecycleGate
```

- [ ] **Step 4: Run the suite and verify the lifecycle tests pass**

Run: `lune run tests/run.luau`

Expected: PASS, including both lifecycle tests.

- [ ] **Step 5: Add transition refresh APIs without remounting the docks**

In `Tree.mount`, return a `refreshForRunState` function which calls the existing drag abort path, clears stale hover/drop/selection-anchor references, and schedules the existing debounced rebuild. Expose it through `Explorer.mount`.

In `Properties.mount`, add `refreshForRunState()` which calls `clearConns()`, rejects `current` when `not current:IsDescendantOf(game)`, and schedules `rebuild()`.

In `src/init.server.luau`, create one `LifecycleGate`, connect to `RunService.RunState`, and coalesce transition refreshes:

```luau
local RunService = game:GetService("RunService")
local LifecycleGate = require(script.App.Shared.LifecycleGate)
local lifecycleGate = LifecycleGate.new()

local runStateConnection = RunService:GetPropertyChangedSignal("RunState"):Connect(function()
	local token = lifecycleGate:advance()
	explorerApi.refreshForRunState()
	propertiesApi.refreshForRunState()
	task.defer(function()
		if lifecycleGate:isCurrent(token) then
			explorerApi.rebuild()
			propertiesApi.rebuild()
		end
	end)
end)
```

Disconnect `runStateConnection` during plugin unloading. Ensure Selection callbacks ignore instances no longer descended from `game`.

- [ ] **Step 6: Run lifecycle-focused verification**

Run: `stylua --check src tests && selene src tests && lune run tests/run.luau`

Expected: zero formatting/lint errors and all tests pass.

- [ ] **Step 7: Commit the lifecycle slice**

```bash
git add src/App/Shared/LifecycleGate.luau src/App/Explorer/Tree.luau src/App/Explorer/init.luau src/App/Properties/init.luau src/init.server.luau tests/LifecycleGate.spec.luau tests/run.luau
git commit -m "fix: refresh plugin panes across play transitions"
```

### Task 2: Safe Tag and Attribute Management Model

**Files:**
- Create: `src/App/Properties/MetadataModel.luau`
- Create: `tests/MetadataModel.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `MetadataModel.normalizeName(name: string): string`.
- Produces: `MetadataModel.validateAttributeName(name: string, existing: {[string]: boolean}, previous: string?): (boolean, string?)`.
- Produces: `MetadataModel.defaultFor(valueType: string): any`.
- Produces: `MetadataModel.isProtectedAttribute(name: string): boolean` and `MetadataModel.isProtectedTag(name: string, isFragua: boolean): boolean`.

- [ ] **Step 1: Write failing metadata contract tests**

```luau
local ok, MetadataModel = pcall(function()
	return require("../src/App/Properties/MetadataModel")
end)

return {
	["attribute names are trimmed and cannot collide"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.normalizeName("  Score  ") == "Score")
		local ok = MetadataModel.validateAttributeName("Score", { Score = true }, nil)
		assert(not ok)
	end,
	["renaming an attribute to itself remains valid"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		local ok = MetadataModel.validateAttributeName("Score", { Score = true }, "Score")
		assert(ok)
	end,
	["Fragua identity metadata is protected"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.isProtectedAttribute("_FraguaType"))
		assert(MetadataModel.isProtectedTag("FraguaInstance", true))
		assert(not MetadataModel.isProtectedTag("Enemy", true))
	end,
	["new attribute types receive deterministic defaults"] = function()
		assert(ok and MetadataModel, "MetadataModel should be available")
		assert(MetadataModel.defaultFor("string") == "")
		assert(MetadataModel.defaultFor("number") == 0)
		assert(MetadataModel.defaultFor("boolean") == false)
		assert(typeof(MetadataModel.defaultFor("Color3")) == "Color3")
		assert(typeof(MetadataModel.defaultFor("Vector3")) == "Vector3")
	end,
}
```

Register the suite in `tests/run.luau`.

- [ ] **Step 2: Run the suite and verify it fails for the missing metadata model**

Run: `lune run tests/run.luau`

Expected: FAIL with `MetadataModel should be available`.

- [ ] **Step 3: Implement validation, protection, and defaults**

Implement exact trimming, empty/duplicate rejection, the `_FraguaType` and `FraguaInstance` protection rules, and literal defaults for `string`, `number`, `boolean`, `Color3`, and `Vector3`. Unknown types return `nil`.

- [ ] **Step 4: Run the suite and verify metadata tests pass**

Run: `lune run tests/run.luau`

Expected: PASS, including all four metadata tests.

- [ ] **Step 5: Commit the metadata model**

```bash
git add src/App/Properties/MetadataModel.luau tests/MetadataModel.spec.luau tests/run.luau
git commit -m "feat: define safe properties metadata operations"
```

### Task 3: Tags and Attributes UI

**Files:**
- Create: `src/App/Properties/MetadataEditor.luau`
- Modify: `src/App/Properties/init.luau`
- Modify: `src/App/Shared/UiUtil.luau`

**Interfaces:**
- Consumes: all `MetadataModel` functions from Task 2.
- Produces: `MetadataEditor.appendRows(context)` where `context` supplies `instance`, `push`, `schemaNames`, `requestRebuild`, and `registerLifetime`.
- Uses: `CollectionService:GetTags`, `AddTag`, `RemoveTag`, `GetInstanceAddedSignal`, and `GetInstanceRemovedSignal`.

- [ ] **Step 1: Add the MetadataEditor structure with explicit mutation callbacks**

Create rows for:

- A `Tags` add action.
- One tag row per sorted tag, with locked state for the protected Fragua tag.
- An `Attributes` add action.
- One row per non-schema attribute, with edit, rename/type, and delete actions.
- A locked `_FraguaType` row for Fragua objects.

Keep schema-defined attributes in their existing categories by passing their names through `schemaNames` and excluding them from the generic Attributes list.

- [ ] **Step 2: Implement same-style compact metadata dialogs**

Use the existing Theme button, input, dropdown, corner, and overlay patterns. The attribute dialog has Name, Type, and Value fields; changing Type applies `MetadataModel.defaultFor(type)`. The tag dialog has one trimmed Name field. Inline errors keep the dialog open.

All successful mutations set paired `ChangeHistoryService` waypoints and call `requestRebuild()` only when rows are added, removed, renamed, or retyped.

- [ ] **Step 3: Integrate metadata rows for engine and Fragua instances**

Call `MetadataEditor.appendRows` after normal property/schema rows are assembled. Track `schemaNames` while processing a Fragua definition. Replace the current engine-only attribute loop with the shared editor so both paths support the same operations.

Keep in-place `AttributeChanged` updates for value-only changes. If an attribute has no updater or its membership changes, defer one rebuild. Subscribe to selected-instance tag add/remove signals and coalesce a metadata rebuild.

- [ ] **Step 4: Run static and unit verification**

Run: `stylua --check src tests && selene src tests && lune run tests/run.luau`

Expected: zero formatting/lint errors and all tests pass.

- [ ] **Step 5: Commit the metadata UI**

```bash
git add src/App/Properties/MetadataEditor.luau src/App/Properties/init.luau src/App/Shared/UiUtil.luau
git commit -m "feat: manage tags and attributes in properties"
```

### Task 4: Responsive Single-Scroll Type Editor

**Files:**
- Modify: `src/App/Types/TypeEditorLayout.luau`
- Modify: `tests/TypeEditorLayout.spec.luau`
- Modify: `src/App/Types/TypeEditor.luau`

**Interfaces:**
- Produces: `TypeEditorLayout.geometry(hostWidth: number, hostHeight: number)` returning `panel`, `body`, and `footer` rectangles plus `cancelWidth`, `saveWidth`, and `buttonGap`.
- Consumes: existing `panelSize()` behavior for compatibility until TypeEditor is migrated.

- [ ] **Step 1: Write failing non-overlap and non-negative geometry tests**

```luau
["minimum dock keeps body and footer usable"] = function()
	assert(Layout.geometry, "geometry should be available")
	local g = Layout.geometry(220, 260)
	assert(g.body.height >= 1)
	assert(g.footer.height >= 44)
	assert(g.cancelWidth + g.buttonGap + g.saveWidth <= g.panel.width - 24)
end,
["short dock never produces a negative body"] = function()
	assert(Layout.geometry, "geometry should be available")
	local g = Layout.geometry(240, 200)
	assert(g.body.height >= 1)
	assert(g.footer.y + g.footer.height <= g.panel.height)
end,
["large dialog remains capped"] = function()
	assert(Layout.geometry, "geometry should be available")
	local g = Layout.geometry(900, 800)
	assert(g.panel.width == 520 and g.panel.height == 620)
end,
```

- [ ] **Step 2: Run the suite and verify geometry tests fail**

Run: `lune run tests/run.luau`

Expected: FAIL with `geometry should be available`.

- [ ] **Step 3: Implement responsive geometry**

Use an 8-pixel host inset, 34-pixel title bar, 48-pixel footer, and at least a 1-pixel body viewport. Reserve 12-pixel horizontal margins and an 8-pixel button gap. Clamp Cancel between 56 and 80 pixels; allocate the remaining action width to Save/Create with a minimum of 96 pixels when the panel permits it.

- [ ] **Step 4: Run the suite and verify layout tests pass**

Run: `lune run tests/run.luau`

Expected: PASS, including minimum, short, and large host geometry.

- [ ] **Step 5: Migrate TypeEditor to one body scroller and fixed footer**

Create a body `ScrollingFrame` from `geometry.body`, with one `UIListLayout`. Put a top-fields container, the `PROPERTIES & SEGMENTS` heading, each direct/inherited section, and the Add Segment action into this body. Remove the nested `propsScroll` ownership and its duplicate `UIPadding` allocation.

Create a footer frame from `geometry.footer`. Parent error text, Cancel, and Save/Create to the footer. Position the two buttons from the computed right margin, widths, and gap. `resizePanel()` updates panel, body, footer, and action geometry whenever host `AbsoluteSize` changes.

Section resize callbacks only change their own fixed-offset height. `UIListLayout.AbsoluteContentSize` drives the body canvas; sections never change panel size.

- [ ] **Step 6: Run type-editor verification**

Run: `stylua --check src tests && selene src tests && lune run tests/run.luau`

Expected: zero formatting/lint errors and all tests pass.

- [ ] **Step 7: Commit the type-editor slice**

```bash
git add src/App/Types/TypeEditorLayout.luau src/App/Types/TypeEditor.luau tests/TypeEditorLayout.spec.luau
git commit -m "fix: make type editor responsive and scrollable"
```

### Task 5: Canonical Shared Behavior Templates

**Files:**
- Create: `src/App/Types/BehaviorTemplatePolicy.luau`
- Create: `tests/BehaviorTemplatePolicy.spec.luau`
- Modify: `tests/run.luau`
- Modify: `src/App/Types/Registry.luau`

**Interfaces:**
- Produces: `BehaviorTemplatePolicy.plan(sources: {string}, generatedSource: string): {keep: number, discard: {number}, backup: {number}}`.
- Consumes: Registry's `defaultBehaviorSource(typeId)` result.
- Produces: `Registry.canonicalizeBehaviorTemplate(typeId: string): ModuleScript` used by save, seed, reads, and watchers.

- [ ] **Step 1: Write failing source-preservation policy tests**

```luau
local ok, Policy = pcall(function()
	return require("../src/App/Types/BehaviorTemplatePolicy")
end)

return {
	["custom source wins over generated duplicate"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		local plan = Policy.plan({ "generated", "custom" }, "generated")
		assert(plan.keep == 2)
		assert(#plan.discard == 1 and plan.discard[1] == 1)
		assert(#plan.backup == 0)
	end,
	["distinct custom duplicates are preserved as backups"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		local plan = Policy.plan({ "custom one", "custom two" }, "generated")
		assert(plan.keep == 1)
		assert(#plan.backup == 1 and plan.backup[1] == 2)
		assert(#plan.discard == 0)
	end,
	["identical custom duplicates do not need backups"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		local plan = Policy.plan({ "custom", "custom" }, "generated")
		assert(plan.keep == 1)
		assert(#plan.discard == 1 and #plan.backup == 0)
	end,
}
```

Register the suite in `tests/run.luau`.

- [ ] **Step 2: Run the suite and verify it fails for the missing policy**

Run: `lune run tests/run.luau`

Expected: FAIL with `BehaviorTemplatePolicy should be available`.

- [ ] **Step 3: Implement the minimal deterministic policy**

Prefer the first source not equal to `generatedSource`; otherwise keep index 1. Exact duplicate sources go to `discard`. Distinct non-kept custom sources go to `backup`; generated sources go to `discard`.

- [ ] **Step 4: Run the suite and verify policy tests pass**

Run: `lune run tests/run.luau`

Expected: PASS, including all behavior policy tests.

- [ ] **Step 5: Canonicalize Registry behavior storage**

Move `defaultBehaviorSource` above behavior lookup. Enumerate every same-name `ModuleScript`, apply the policy, and ensure one canonical module retains the exact `<TypeId>Behavior` name and `_FraguaSharedBehavior = true`.

Destroy only policy `discard` entries. Move policy `backup` entries into `ServerStorage.Fragua.BehaviorBackups`, assign unique names such as `<TypeId>BehaviorBackup1`, and clear `_FraguaSharedBehavior` before parenting. Never overwrite backup source.

Make `getSharedBehavior`, `ensureBehaviorTemplate`, `save`, and `watchBehaviorTemplates` use canonicalization. During `seedDefaults`, replace `Instance.new("ModuleScript")` with:

```luau
local template = Registry.ensureBehaviorTemplate("Zombie")
template.Source = ZOMBIE_BEHAVIOR_SOURCE
```

Store the demo source in a local constant so seeding updates the canonical module.

- [ ] **Step 6: Run registry verification**

Run: `stylua --check src tests && selene src tests && lune run tests/run.luau`

Expected: zero formatting/lint errors and all tests pass.

- [ ] **Step 7: Commit the behavior-template slice**

```bash
git add src/App/Types/BehaviorTemplatePolicy.luau src/App/Types/Registry.luau tests/BehaviorTemplatePolicy.spec.luau tests/run.luau
git commit -m "fix: canonicalize shared behavior templates"
```

### Task 6: Integrated Verification, Push, and Plugin Installation

**Files:**
- Modify only files required by failures found during integrated verification.
- Build artifact: `/tmp/Fragua-play-metadata.rbxm`
- Install artifact: `~/Documents/Roblox/Plugins/Fragua.rbxm`

**Interfaces:**
- Consumes all deliverables from Tasks 1-5.
- Produces a verified and installed Roblox plugin build.

- [ ] **Step 1: Run the complete verification gate**

```bash
stylua --check src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/Fragua-play-metadata.rbxm
git diff --check
```

Expected: zero formatting errors, zero Selene errors/warnings, every test passes, Rojo exits 0, and diff check is clean.

- [ ] **Step 2: Review the final diff against every design requirement**

Confirm run-state refresh is editable rather than disabling controls; protected metadata cannot be removed; user metadata has add/edit/rename/type/delete flows; the type editor has one scrolling body and non-overlapping fixed footer; seeding reuses the canonical behavior; customized duplicate sources are backed up.

- [ ] **Step 3: Commit any integration-only corrections**

If verification required code changes, repeat the failing-test-first cycle, rerun Step 1, then commit only those corrections:

```bash
git add src tests
git commit -m "fix: stabilize integrated plugin workflows"
```

- [ ] **Step 4: Push main and verify the remote hash**

```bash
git push origin main
git rev-parse HEAD
git ls-remote origin refs/heads/main
```

Expected: local and remote main hashes match.

- [ ] **Step 5: Install and compare the exact build artifact**

```bash
cp /tmp/Fragua-play-metadata.rbxm ~/Documents/Roblox/Plugins/Fragua.rbxm
shasum -a 256 /tmp/Fragua-play-metadata.rbxm ~/Documents/Roblox/Plugins/Fragua.rbxm
```

Expected: both SHA-256 hashes are identical.
