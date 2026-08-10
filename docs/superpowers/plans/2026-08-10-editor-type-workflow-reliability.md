# Editor and Type Workflow Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair Fragua's editor, type creation, inheritance, sliders, and color picker while adding a scrollable syntax-colored editor, lightweight type-aware IntelliSense, animated booleans, create-and-insert behavior, and a broader icon catalog.

**Architecture:** Keep Roblox-facing rendering in the existing docks, but move geometry, schema resolution, lexical coloring, diagnostics, and commit-state decisions into pure Luau modules covered by Lune tests. Controls preview locally and persist once at interaction completion; Type Creator renders stable draft IDs and resolved inherited schema; CodeCanvas synchronizes an editable layer with a RichText layer inside one native scrolling viewport.

**Tech Stack:** Roblox Luau, Roblox Studio PluginGui APIs, Lune 0.10.4, Rojo 7.6.1, StyLua 0.20.0, Selene 0.30.1.

## Global Constraints

- Editing remains entirely inside Fragua's custom docks; do not hand off to Studio's native Script Editor.
- Type creation inserts under the selected parent and falls back to `Workspace` when no valid parent exists.
- Creating or selecting a Fragua instance must not automatically open its behavior document.
- The editor provides focused local diagnostics, not a claim of full Studio Luau language-server parity.
- Direct properties are editable; inherited properties are visible and read-only in the child type dialog.
- Pointer cancellation never persists a preview value.
- All runtime UI strings and icon fallbacks remain ASCII-safe.
- Interface animation respects `Settings.Store.getAnimations()`.

---

### Task 1: Editor document geometry and native scrolling

**Files:**
- Create: `src/App/ScriptEditor/EditorLayout.luau`
- Create: `tests/EditorLayout.spec.luau`
- Modify: `src/App/ScriptEditor/CodeCanvas.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `EditorLayout.measure(source: string, viewportWidth: number, viewportHeight: number, metrics: Metrics): Size`
- Produces: `EditorLayout.caretPoint(source: string, cursor: number, metrics: Metrics): Point`
- Produces: `EditorLayout.popupPoint(caret: Point, canvasX: number, canvasY: number, viewportWidth: number, viewportHeight: number, popupWidth: number, popupHeight: number): Point`
- Changes: `CodeCanvas` owns one `ScrollingFrame` and sizes gutter, RichText layer, and TextBox from `EditorLayout.measure`.

- [ ] **Step 1: Add failing geometry tests**

```luau
local EditorLayout = require("../src/App/ScriptEditor/EditorLayout")
local metrics = { charWidth = 8, lineHeight = 18, gutterWidth = 44, padX = 12, padY = 10 }

return {
    ["long documents grow vertically beyond the viewport"] = function()
        local size = EditorLayout.measure("a\nb\nc\nd", 200, 40, metrics)
        assert(size.height == 92, `expected 92, got {size.height}`)
    end,
    ["long lines grow horizontally beyond the viewport"] = function()
        local size = EditorLayout.measure(string.rep("x", 40), 180, 100, metrics)
        assert(size.width == 388, `expected 388, got {size.width}`)
    end,
    ["popup position subtracts canvas scroll and clamps to viewport"] = function()
        local point = EditorLayout.popupPoint({ x = 300, y = 220 }, 160, 120, 240, 140, 100, 60)
        assert(point.x == 140 and point.y == 80, `{point.x},{point.y}`)
    end,
}
```

- [ ] **Step 2: Run `lune run tests/run.luau` and verify failure**

Expected: module-not-found failure for `EditorLayout`.

- [ ] **Step 3: Implement pure measurement and caret geometry**

Use literal line splitting. Height is `max(viewportHeight, lineCount * lineHeight + 2 * padY)`. Width is `max(viewportWidth, gutterWidth + longestLineBytes * charWidth + 2 * padX)`. `popupPoint` converts document to viewport coordinates and clamps within the viewport.

- [ ] **Step 4: Run the geometry tests and verify they pass**

Run: `lune run tests/run.luau`
Expected: all existing tests plus three new tests pass.

- [ ] **Step 5: Rebuild CodeCanvas around a ScrollingFrame**

Create `Viewport: ScrollingFrame` under `CodeCanvas`; create `Content: Frame` under it; parent `Gutter`, a reserved `Highlight` label, divider, and `Editor` to `Content`. On text or viewport-size changes, call `EditorLayout.measure`, update `Content.Size`, and set `Viewport.CanvasSize`. Keep `TextWrapped = false` and make the gutter height equal the content height.

- [ ] **Step 6: Position completion using document caret minus `CanvasPosition`**

Replace the fixed `caretPosition()` arithmetic with `EditorLayout.caretPoint` and `EditorLayout.popupPoint`. Parent the popup to the root so it remains fixed over the viewport while the document scrolls.

- [ ] **Step 7: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-editor-scroll.rbxm
git add src/App/ScriptEditor/EditorLayout.luau src/App/ScriptEditor/CodeCanvas.luau tests/EditorLayout.spec.luau tests/run.luau
git commit -m "fix: make custom editor canvas scrollable"
```

### Task 2: Safe RichText syntax coloring

**Files:**
- Create: `src/App/ScriptEditor/SyntaxHighlighter.luau`
- Create: `tests/SyntaxHighlighter.spec.luau`
- Modify: `src/App/ScriptEditor/CodeCanvas.luau`
- Modify: `src/App/Shared/Theme.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `SyntaxHighlighter.render(source: string, context: HighlightContext): string`
- Consumes: `context.typeIds: { string }`, `context.schema: { { name: string } }`
- Changes: CodeCanvas mirrors editor source into a RichText `TextLabel` and coalesces repaint with one `task.defer` token.

- [ ] **Step 1: Add failing lexical rendering tests**

```luau
local SyntaxHighlighter = require("../src/App/ScriptEditor/SyntaxHighlighter")

return {
    ["escapes RichText before coloring"] = function()
        local out = SyntaxHighlighter.render('local x = "<tag>&"', { schema = {}, typeIds = {} })
        assert(out:find("&lt;tag&gt;&amp;", 1, true), out)
    end,
    ["colors comments strings numbers and keywords"] = function()
        local out = SyntaxHighlighter.render('local hp = 100 -- value', { schema = {}, typeIds = {} })
        assert(out:find('color="#C586C0"', 1, true), out)
        assert(out:find('color="#B5CEA8"', 1, true), out)
        assert(out:find('color="#6A9955"', 1, true), out)
    end,
    ["colors custom types and schema properties"] = function()
        local out = SyntaxHighlighter.render('Fragua.create("Zombie"):SetAttribute("Health", 90)', {
            typeIds = { "Zombie" }, schema = { { name = "Health" } },
        })
        assert(out:find('color="#4EC9B0"', 1, true), out)
        assert(out:find('color="#9CDCFE"', 1, true), out)
    end,
}
```

- [ ] **Step 2: Run tests and verify the module-not-found failure**

- [ ] **Step 3: Implement a single-pass tokenizer and RichText renderer**

Tokenize comments, single/double quoted strings with escapes, decimal/hex numbers, identifiers, and punctuation without using the output as tokenizer input. Escape `&`, `<`, `>`, `"`, and `'` per token before wrapping it in `<font color="#RRGGBB">`.

- [ ] **Step 4: Run tests and verify all lexical cases pass**

- [ ] **Step 5: Add Theme editor token colors**

Add named colors `syntaxKeyword`, `syntaxString`, `syntaxNumber`, `syntaxComment`, `syntaxType`, `syntaxProperty`, and `syntaxGlobal` with the exact hex values asserted by the tests.

- [ ] **Step 6: Add the synchronized highlight layer**

Under `Content`, place a `TextLabel` with `RichText = true`, `TextWrapped = false`, `Font = Theme.fontMono`, identical line height/padding to `Editor`, and `TextYAlignment = Top`. Make the editor glyphs transparent while preserving its caret/selection interaction. If rendering fails in `pcall`, show escaped uncolored source.

- [ ] **Step 7: Coalesce highlighting**

Maintain `highlightGeneration`. Each text/context change increments it and schedules `task.defer`; the deferred closure paints only if its captured generation remains current.

- [ ] **Step 8: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-syntax.rbxm
git add src/App/ScriptEditor/SyntaxHighlighter.luau src/App/ScriptEditor/CodeCanvas.luau src/App/Shared/Theme.luau tests/SyntaxHighlighter.spec.luau tests/run.luau
git commit -m "feat: add syntax coloring to custom editor"
```

### Task 3: Type-aware completion and semantic diagnostics

**Files:**
- Modify: `src/App/ScriptEditor/CompletionEngine.luau`
- Modify: `src/App/ScriptEditor/Diagnostics.luau`
- Modify: `src/App/ScriptEditor/CodeCanvas.luau`
- Modify: `src/App/ScriptEditor/init.luau`
- Modify: `tests/CompletionEngine.spec.luau`
- Modify: `tests/Diagnostics.spec.luau`

**Interfaces:**
- Extends completion context with `schema[].origin`, `schema[].valueType`, and `typeIds`.
- Extends diagnostics context with `typeIds: { string }` and schema property types.
- Produces diagnostic codes `unknown-type`, `attribute-type-mismatch`, and `duplicate-local`.

- [ ] **Step 1: Add failing completion tests for globals, functions, inherited origin, and result paging**

```luau
local items = CompletionEngine.complete({
    source = 'instance:GetAttribute("He', cursor = 26,
    schema = { { name = "Health", valueType = "number", origin = "Character" } },
    typeIds = { "Character" },
})
assert(items[1].label == "Health")
assert(items[1].detail:find("Character", 1, true))

local globals = CompletionEngine.complete({ source = "game:GetS", cursor = 10, schema = {}, typeIds = {} })
assert(globals[1].label == "GetService")
```

- [ ] **Step 2: Add failing diagnostics tests**

```luau
local issues = Diagnostics.analyze('Fragua.create("Missing")', { typeIds = { "Zombie" }, schema = {} })
assert(issues[1].code == "unknown-type")

issues = Diagnostics.analyze('instance:SetAttribute("Health", "high")', {
    typeIds = {}, schema = { { name = "Health", valueType = "number" } },
})
assert(issues[1].code == "attribute-type-mismatch")

issues = Diagnostics.analyze("local hp = 1\nlocal hp = 2", { typeIds = {}, schema = {} })
assert(issues[1].code == "duplicate-local")
```

- [ ] **Step 3: Run tests and verify failures identify the missing completion/diagnostic branches**

- [ ] **Step 4: Implement completion metadata and common member suggestions**

Add common globals (`game`, `workspace`, `script`, `plugin`, `task`, `math`, `string`, `table`) and member snippets for `game:GetService`, `Instance.new`, and Fragua runtime operations. Preserve prefix ranking and cap stored results at 50.

- [ ] **Step 5: Implement provable semantic diagnostics**

Parse only literal `Fragua.create("Type")` and `SetAttribute("Property", literal)` forms. Infer literal types for quoted strings, numbers, booleans, `Color3.new/fromRGB`, and `Vector3.new`. Report duplicate `local name` declarations only within the flat lexical document model; do not report unresolved arbitrary identifiers.

- [ ] **Step 6: Make the completion popup scroll through all results**

Track `windowStart`; Up/Down changes `selectedIndex` from `1..#suggestions`, and rendering shows seven items starting at the window containing the selected index. Mouse rows capture the absolute suggestion index.

- [ ] **Step 7: Show highest-severity diagnostic with line and column in status**

Keep issue count, but append the first error/warning message and calculate its line/column from `startByte`. Never block save for warnings.

- [ ] **Step 8: Wire external source conflicts into DocumentStore**

For each open target, connect `target:GetPropertyChangedSignal("Source")`. When the changed source differs from the document's saved source, call `DocumentStore.markExternalChange`; preserve dirty local text and set the status to `External change conflict`, otherwise refresh the clean document. Disconnect target listeners when ScriptEditor is destroyed.

- [ ] **Step 9: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-intellisense.rbxm
git add src/App/ScriptEditor tests/CompletionEngine.spec.luau tests/Diagnostics.spec.luau
git commit -m "feat: add type-aware editor assistance"
```

### Task 4: Transactional sliders, color previews, and PluginGui pointer coordinates

**Files:**
- Create: `src/App/Shared/PreviewCommit.luau`
- Create: `tests/PreviewCommit.spec.luau`
- Modify: `src/App/Shared/PointerController.luau`
- Modify: `src/App/Properties/Controls.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `PreviewCommit.new(initial): State`
- Produces: `PreviewCommit.preview(state, value)`, `commit(state): value`, `cancel(state): value`
- Changes: PointerController samples PluginGui-relative mouse position through `GetRelativeMousePosition()`.
- Changes: number/color controls persist only in `onFinish` or explicit **Done**.

- [ ] **Step 1: Add failing transaction tests**

```luau
local PreviewCommit = require("../src/App/Shared/PreviewCommit")

return {
    ["multiple previews produce one final commit value"] = function()
        local state = PreviewCommit.new(10)
        PreviewCommit.preview(state, 20)
        PreviewCommit.preview(state, 30)
        assert(state.original == 10 and state.current == 30 and state.committed == false)
        assert(PreviewCommit.commit(state) == 30 and state.committed == true)
    end,
    ["cancellation restores original value"] = function()
        local state = PreviewCommit.new("#FF0000")
        PreviewCommit.preview(state, "#00FF00")
        assert(PreviewCommit.cancel(state) == "#FF0000")
    end,
}
```

- [ ] **Step 2: Run tests and verify the missing-module failure**

- [ ] **Step 3: Implement PreviewCommit and make tests pass**

The state contains `original`, `current`, and `committed`. `preview` changes only `current`; `commit` marks and returns `current`; `cancel` resets/returns `original`.

- [ ] **Step 4: Correct PluginGui sampling at the source**

In `PointerController.capture`, resolve `host:FindFirstAncestorWhichIsA("PluginGui")`. When present, call `pluginGui:GetRelativeMousePosition()` and subtract `host.AbsolutePosition`; otherwise use the event's screen coordinates. Use this same sampler for the initial point rather than trusting mixed event coordinates.

- [ ] **Step 5: Make sliders preview during drag and commit once on release**

`onMove` calls `paint(nextValue)` only. `onFinish` calls `onCommit(working)` only when not cancelled and when the value differs from the initial value. Keep the enclosing Properties `ScrollingFrame` disabled only for the capture lifetime.

- [ ] **Step 6: Make the color picker local-first and coalesced**

`refresh` updates `working`, preview swatches, cursors, and hex text only. Maintain a generation token so repeated movement performs one deferred visual refresh. Pointer finish retains the pending color; **Done** calls `onCommit(working)` once; **Cancel** closes without another write because no preview was persisted.

- [ ] **Step 7: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-controls.rbxm
git add src/App/Shared/PreviewCommit.luau src/App/Shared/PointerController.luau src/App/Properties/Controls.luau tests/PreviewCommit.spec.luau tests/run.luau
git commit -m "fix: commit property drags transactionally"
```

### Task 5: Deterministic inherited schema and fresh definition reads

**Files:**
- Create: `src/App/Types/SchemaResolver.luau`
- Create: `tests/SchemaResolver.spec.luau`
- Modify: `src/App/Types/Registry.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `SchemaResolver.resolve(definition, lookupCustom, lookupEngine): { ResolvedProperty }`
- `ResolvedProperty` adds `origin: string` and `inherited: boolean`.
- Changes: `Registry.list()` decodes current ModuleScript source before considering `require` fallback.
- Changes: `Registry.resolvedSchema(def)` delegates merge behavior to SchemaResolver.

- [ ] **Step 1: Add failing inheritance tests**

```luau
local SchemaResolver = require("../src/App/Types/SchemaResolver")
local defs = {
    Base = { id = "Base", extends = "Configuration", properties = {
        { name = "Health", valueType = "number", default = 100, category = "Data" },
    } },
    Child = { id = "Child", extends = "Base", properties = {
        { name = "Health", valueType = "number", default = 150, category = "Data" },
        { name = "Speed", valueType = "number", default = 8, category = "Data" },
    } },
}
local result = SchemaResolver.resolve(defs.Child, function(id) return defs[id] end, function() return {} end)
assert(#result == 2)
assert(result[1].name == "Health" and result[1].default == 150 and result[1].origin == "Child")
assert(result[2].name == "Speed")
```

Add a three-level inheritance fixture and a cycle fixture that returns a structured `inheritance-cycle` error.

- [ ] **Step 2: Run tests and verify the missing-module failure**

- [ ] **Step 3: Implement ordered recursive schema resolution**

Resolve the base first, retain base order, replace overridden properties in place, append new direct properties, and clone records before adding `origin`/`inherited`. Use a recursion stack distinct from the completed set so only active cycles fail.

- [ ] **Step 4: Run resolver tests and verify pass**

- [ ] **Step 5: Read current definition source without require caching**

In `Registry.list`, inspect `ModuleScript.Source`, extract the long-bracket JSON payload, and decode it first. Use `require` only for legacy definitions whose source does not contain a decodable payload. Preserve StringValue legacy support.

- [ ] **Step 6: Delegate Registry resolution and preserve public property shape**

`Registry.resolvedSchema` returns resolved records including the extra metadata; existing consumers continue to read the original fields. Surface cycle errors to TypeDraft validation and Type Creator rather than silently truncating.

- [ ] **Step 7: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-inheritance.rbxm
git add src/App/Types/SchemaResolver.luau src/App/Types/Registry.luau tests/SchemaResolver.spec.luau tests/run.luau
git commit -m "fix: resolve inherited type schemas deterministically"
```

### Task 6: Responsive stable Type Creator with inherited rows

**Files:**
- Create: `src/App/Types/TypeEditorLayout.luau`
- Create: `tests/TypeEditorLayout.spec.luau`
- Modify: `src/App/Types/TypeDraft.luau`
- Modify: `src/App/Types/TypeEditor.luau`
- Modify: `tests/TypeDraft.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `TypeEditorLayout.panelSize(hostWidth: number, hostHeight: number): { width: number, height: number }`
- Extends TypeDraft with `setExtends` and `snapshotEditableProperties`; existing `renameCategory` and `updateProperty` remain the stable-ID mutation APIs.
- Consumes: `Registry.resolvedSchema` metadata to render inherited groups.
- Changes: `TypeEditor.open` accepts an `onSaved(typeId): (boolean?, string?)` callback so failed insertion can keep the dialog open.

- [ ] **Step 1: Add failing responsive-layout tests**

```luau
local Layout = require("../src/App/Types/TypeEditorLayout")
return {
    ["dialog never exceeds a small dock"] = function()
        local size = Layout.panelSize(220, 260)
        assert(size.width == 204 and size.height == 244, `{size.width}x{size.height}`)
    end,
    ["dialog caps itself in a large dock"] = function()
        local size = Layout.panelSize(900, 800)
        assert(size.width == 520 and size.height == 620, `{size.width}x{size.height}`)
    end,
}
```

- [ ] **Step 2: Add failing TypeDraft tests for rebuild-safe mutations**

Create a draft, retain a property ID, call `renameCategory`, call `setExtends`, call `updateProperty`, and assert the same ID and new values remain. Add a `snapshotEditableProperties` fixture that returns direct properties in category/property order without returning inherited records.

- [ ] **Step 3: Run tests and verify the missing layout/mutation APIs fail**

- [ ] **Step 4: Implement layout math and stable draft APIs**

Panel size is `min(max(host - 16, 1), cap)` with caps `520x620`; it never applies a minimum larger than the host. Mutations locate records by stable ID and never accept array indices from UI closures.

- [ ] **Step 5: Refactor TypeEditor shell into fixed header/workspace/footer zones**

Keep identity controls in a fixed header, property groups in the only `ScrollingFrame`, and validation/actions in a 48-pixel footer. Update panel size on host `AbsoluteSize` changes. Use `UIListLayout.AbsoluteContentSize` for group height and canvas sizing.

- [ ] **Step 6: Render editable and inherited groups from the draft**

Commit focused fields before rebuild. Direct groups provide add/delete/type/default controls. Inherited groups use muted read-only rows with `origin` labels. Changing extends updates the draft, resolves inherited schema, filters overridden names, and rebuilds once.

- [ ] **Step 7: Change create copy and remove automatic editor behavior**

Use **Create & insert** for new types and **Save changes** for edits. After Registry save, call `onSaved(typeId)`. Destroy the overlay when it returns `true` or `nil`; when it returns `false, message`, retain a `definitionSaved` flag, keep the dialog open, show `message`, rename the primary action to **Retry insert**, and on retry call `onSaved` again without revalidating the now-existing definition. TypeEditor itself never opens Script Editor.

- [ ] **Step 8: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-type-editor.rbxm
git add src/App/Types/TypeEditorLayout.luau src/App/Types/TypeDraft.luau src/App/Types/TypeEditor.luau tests/TypeEditorLayout.spec.luau tests/TypeDraft.spec.luau tests/run.luau
git commit -m "fix: rebuild type creator around stable responsive drafts"
```

### Task 7: Create-and-insert flow and explicit-only script opening

**Files:**
- Create: `src/App/Explorer/InsertFlow.luau`
- Create: `tests/InsertFlow.spec.luau`
- Modify: `src/App/Explorer/InsertPicker.luau`
- Modify: `src/App/Explorer/init.luau`
- Modify: `src/App/ScriptEditor/init.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces: `InsertFlow.resolveParent(candidate, workspace): Instance`
- Changes: create-type callback invokes `Registry.createInstance(typeId, resolvedParent)` and the existing `afterInsert` path.
- Changes: ScriptEditor removes selection-driven `openFromInstance` subscription.

- [ ] **Step 1: Add failing pure parent-decision tests**

```luau
local InsertFlow = require("../src/App/Explorer/InsertFlow")
local workspace = { kind = "workspace" }
return {
    ["uses selected valid parent"] = function()
        local parent = { Parent = workspace }
        assert(InsertFlow.resolveParent(parent, workspace) == parent)
    end,
    ["falls back to workspace for missing or destroyed parent"] = function()
        assert(InsertFlow.resolveParent(nil, workspace) == workspace)
        assert(InsertFlow.resolveParent({ Parent = nil }, workspace) == workspace)
    end,
}
```

- [ ] **Step 2: Run tests and verify the missing-module failure**

- [ ] **Step 3: Implement InsertFlow and make tests pass**

Treat `workspace` itself as valid. A candidate is valid when it equals workspace or has a non-nil `Parent`; otherwise return workspace.

- [ ] **Step 4: Create the first instance immediately after definition save**

In the `create_type` branch, resolve the parent at callback time, call `Registry.createInstance(id, resolvedParent)`, then call `afterInsert(instance)` and `refresh()`. Return `true` from the TypeEditor callback on success. Wrap instance creation in `pcall`; return `false, "Type saved, but insertion failed. Retry insert."` on failure so TypeEditor retains the saved-definition retry state rather than deleting it.

- [ ] **Step 5: Remove selection-driven behavior opening**

Delete ScriptEditor's `Selection.SelectionChanged` connection and `Selection` service dependency. Add an explicit **Open selection** button in the editor toolbar that calls `openFromInstance(Selection:Get()[1])` only when clicked; Properties **Edit behavior** continues to call `openTarget`.

- [ ] **Step 6: Verify created selection does not enable/open Script Editor**

Use a pure state assertion around `DocumentStore`: inserting/selecting does not call `DocumentStore.open`; explicit `openTarget` still reuses tabs. Confirm via Rojo build that no automatic Selection connection remains.

- [ ] **Step 7: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-create-insert.rbxm
git add src/App/Explorer src/App/ScriptEditor/init.luau tests/InsertFlow.spec.luau tests/run.luau
git commit -m "feat: create and insert custom types in one flow"
```

### Task 8: Animated booleans and expanded icon catalog

**Files:**
- Modify: `src/App/Properties/init.luau`
- Create: `src/App/Types/IconData.luau`
- Modify: `src/App/Types/IconCatalog.luau`
- Modify: `src/App/Types/IconPicker.luau`
- Create: `tests/IconCatalog.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Changes: boolean rows own local `displayValue` and animate with keyed `Theme.play` calls before one commit.
- Produces: `IconData.list(): { IconDef }`, a pure catalog consumed by IconCatalog and Lune tests.
- Produces: icon definitions with `category: string` and searchable label/category metadata.

- [ ] **Step 1: Add a failing icon catalog data test**

Require `IconData` directly in Lune. Assert at least 160 unique IDs, required categories (`World`, `Characters`, `UI`, `Effects`, `Audio`, `Networking`, `Values`, `Services`), and ASCII-only fallback text. Assert duplicate IDs fail the test by comparing a `seen` table before insertion.

- [ ] **Step 2: Run tests and verify failure on count/category support**

- [ ] **Step 3: Expand and categorize valid Studio class icons**

Move catalog records into `IconData.luau`. Add current creatable and service classes from EngineSchemas coverage, constraints, audio objects, modern UI objects, effects, controllers, networking, values, and environment classes. Deduplicate by ID during catalog construction. Keep `StudioService:GetClassIcon` protected by `pcall` in IconCatalog and retain letter fallbacks.

- [ ] **Step 4: Search icon labels and categories**

IconPicker filtering matches lowercase query against both `def.label` and `def.category`; category headers remain visible only when they have results.

- [ ] **Step 5: Animate boolean state optimistically**

On click, flip a local `displayValue`, call `Theme.play(toggle, "boolean-track", { BackgroundColor3 = ... })` and `Theme.play(knob, "boolean-knob", { Position = ... })`, then call `prop.onCommit(displayValue)` once. Use the setting-aware Theme duration and avoid a second animation when Properties rebuilds with the authoritative value.

- [ ] **Step 6: Format, test, build, and commit**

```bash
stylua src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/fragua-icons-booleans.rbxm
git add src/App/Properties/init.luau src/App/Types/IconData.luau src/App/Types/IconCatalog.luau src/App/Types/IconPicker.luau tests/IconCatalog.spec.luau tests/run.luau
git commit -m "feat: animate booleans and expand type icons"
```

### Task 9: Integration verification, documentation, and plugin installation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-08-10-editor-type-workflow-reliability.md`

**Interfaces:**
- Consumes all earlier tasks.
- Produces the verified `/tmp/Fragua-editor-type-final.rbxm` and installed `~/Documents/Roblox/Plugins/Fragua.rbxm`.

- [ ] **Step 1: Update README behavior descriptions**

Document scrolling/syntax coloring, lightweight type checks, explicit document opening, visible inherited properties, **Create & insert**, Workspace fallback, and expanded icon search. State clearly that diagnostics do not replace Studio's full Luau language server.

- [ ] **Step 2: Run the complete automated gate**

```bash
stylua --check src tests
selene src tests
lune run tests/run.luau
rojo build -o /tmp/Fragua-editor-type-final.rbxm
git diff --check
rg -nP '[^\x00-\x7F]' src --glob '*.luau'
```

Expected: formatting clean; Selene `0 errors, 0 warnings, 0 parse errors`; all tests pass; Rojo build succeeds; diff check succeeds; ASCII scan returns no source matches.

- [ ] **Step 3: Review requirement-level integration behavior**

Confirm from code paths and test fixtures:

- editor content/gutter share a scroll canvas and grow in both axes;
- slider/color movement has no persistence callback until completion;
- PluginGui capture uses relative mouse position;
- custom child schema includes current parent properties and origin metadata;
- dialog bounds never exceed host and rows use stable IDs/content size;
- create callback inserts/selects once with Workspace fallback;
- Script Editor has no automatic selection subscription;
- boolean transitions use keyed Theme animation;
- icon catalog count/category tests pass.

- [ ] **Step 4: Commit integration documentation**

```bash
git add README.md docs/superpowers/plans/2026-08-10-editor-type-workflow-reliability.md
git commit -m "docs: document reliable editor and type workflow"
```

- [ ] **Step 5: Install and verify the exact built artifact**

```bash
cp /tmp/Fragua-editor-type-final.rbxm ~/Documents/Roblox/Plugins/Fragua.rbxm
shasum -a 256 /tmp/Fragua-editor-type-final.rbxm ~/Documents/Roblox/Plugins/Fragua.rbxm
```

Expected: both SHA-256 hashes are identical.
