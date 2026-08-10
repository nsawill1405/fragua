# Fragua UI Reliability and Script Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair Fragua's pointer interactions and type-property workflow, apply the approved Machined Modern component language, and deliver a fully editable custom Script Editor with lightweight Luau and Fragua-aware assistance.

**Architecture:** Pure modules own coordinate math, type drafts, document state, completion, and diagnostics so they can run under Lune without Studio. Roblox-facing controllers adapt GuiObjects, Registry data, and Studio services to those pure contracts. Existing Explorer, Properties, and Type Editor entry points remain intact while their duplicated interaction and styling logic moves into shared modules.

**Tech Stack:** Luau, Roblox Studio plugin APIs, Rojo 7.4+, Lune 0.10, StyLua, Selene.

## Global Constraints

- Explorer and Properties remain separate Studio dock panels.
- Preserve existing user changes and the current `cursor/explorer-properties-qol` feature branch.
- Use Machined Modern: Builder Sans with Studio-safe fallback, Roboto Mono for code/numbers, 6 px control radii, 8 px cards, and a 4 px spacing grid.
- Remove unsupported Unicode UI glyphs; use ASCII text or drawn/image shapes.
- Pointer input is normalized once into host-local coordinates.
- The custom Script Editor remains the primary editing surface; do not redirect editing to Studio's native editor.
- Completion is lightweight and Fragua-aware, not a claim of Studio-equivalent IntelliSense.
- Every behavioral repair begins with a failing regression test.

---

### Task 1: Pure Luau test harness and interaction math

**Files:**
- Create: `tests/TestRunner.luau`
- Create: `tests/run.luau`
- Create: `tests/InteractionMath.spec.luau`
- Create: `src/App/Shared/InteractionMath.luau`

**Interfaces:**
- Produces: `InteractionMath.toLocal(originX, originY, sampleX, sampleY): (number, number)`
- Produces: `InteractionMath.clampAlpha(localValue, extent): number`
- Produces: `InteractionMath.valueFromLocal(localValue, extent, minValue, maxValue): number`
- Produces: `InteractionMath.crossedThreshold(startX, startY, currentX, currentY, threshold): boolean`
- Produces: `TestRunner.run(suites): ()`

- [ ] **Step 1: Add the test runner and failing interaction tests**

```luau
local InteractionMath = require("../src/App/Shared/InteractionMath")

return {
    ["converts a host sample into control-local coordinates"] = function()
        local x, y = InteractionMath.toLocal(120, 80, 153, 94)
        assert(x == 33 and y == 14)
    end,
    ["maps a clamped slider sample across a signed range"] = function()
        assert(InteractionMath.valueFromLocal(25, 100, -1, 1) == -0.5)
        assert(InteractionMath.valueFromLocal(140, 100, -1, 1) == 1)
    end,
    ["starts dragging only after the Euclidean threshold"] = function()
        assert(not InteractionMath.crossedThreshold(10, 10, 14, 13, 6))
        assert(InteractionMath.crossedThreshold(10, 10, 17, 10, 6))
    end,
}
```

- [ ] **Step 2: Run the suite and verify the missing module fails**

Run: `lune run tests/run.luau`

Expected: non-zero exit because `InteractionMath.luau` does not exist.

- [ ] **Step 3: Implement the pure coordinate and range functions**

```luau
local InteractionMath = {}

function InteractionMath.toLocal(originX, originY, sampleX, sampleY)
    return sampleX - originX, sampleY - originY
end

function InteractionMath.clampAlpha(localValue, extent)
    return math.clamp(localValue / math.max(extent, 1), 0, 1)
end

function InteractionMath.valueFromLocal(localValue, extent, minValue, maxValue)
    return minValue + InteractionMath.clampAlpha(localValue, extent) * (maxValue - minValue)
end

function InteractionMath.crossedThreshold(startX, startY, currentX, currentY, threshold)
    local dx, dy = currentX - startX, currentY - startY
    return dx * dx + dy * dy >= threshold * threshold
end

return InteractionMath
```

- [ ] **Step 4: Run `lune run tests/run.luau` and verify all interaction tests pass**

- [ ] **Step 5: Commit the harness and interaction math**

```bash
git add tests src/App/Shared/InteractionMath.luau
git commit -m "test: add pure Luau interaction regressions"
```

### Task 2: Shared pointer controller and repaired controls

**Files:**
- Create: `src/App/Shared/PointerController.luau`
- Modify: `src/App/Shared/UiUtil.luau`
- Modify: `src/App/Properties/Controls.luau`
- Extend: `tests/InteractionMath.spec.luau`

**Interfaces:**
- Consumes: `InteractionMath.toLocal`, `valueFromLocal`, and `crossedThreshold`
- Produces: `PointerController.capture(host, options): PointerSession`
- Produces: `PointerSession.cancel(): ()`
- Produces: `UiUtil.makeDraggable(handle, target, bounds)` using the shared controller

- [ ] **Step 1: Add failing tests for click-at-end, zero-width tracks, and color-plane clamping**

```luau
assert(InteractionMath.clampAlpha(99, 100) == 0.99)
assert(InteractionMath.clampAlpha(20, 0) == 1)
local sx, sy = InteractionMath.toLocal(50, 40, 35, 180)
assert(InteractionMath.clampAlpha(sx, 200) == 0)
assert(InteractionMath.clampAlpha(sy, 100) == 1)
```

- [ ] **Step 2: Run `lune run tests/run.luau` and verify the zero-width expectation fails**

- [ ] **Step 3: Correct zero-width behavior to return `0` before division and make the tests pass**

- [ ] **Step 4: Implement one pointer capture session**

`PointerController.capture` creates one transparent capture button under `host`, converts `MouseMoved` samples from the capture's absolute basis into host-local values, calls `onMove`, and guarantees `onFinish(cancelled)` plus scroll restoration exactly once. Starting another session on the host cancels the previous session.

- [ ] **Step 5: Replace slider input with the shared controller**

The slider maps `hostX` through `hit.AbsolutePosition.X - host.AbsolutePosition.X`, updates display continuously, and calls `onCommit` only when the value changes. It restores scrolling on every finish path.

- [ ] **Step 6: Replace color saturation/value, hue, and panel dragging with the shared controller**

Cancel restores the original color. Apply commits the final color once. RGB and hex fields call one parsing and paint path.

- [ ] **Step 7: Run tests and `rojo build -o /tmp/fragua-pointer.rbxm`**

- [ ] **Step 8: Commit the pointer controller and repaired controls**

```bash
git add src/App/Shared src/App/Properties/Controls.luau tests
git commit -m "fix: unify pointer capture for plugin controls"
```

### Task 3: Machined Modern tokens, components, and safe glyphs

**Files:**
- Modify: `src/App/Shared/Theme.luau`
- Modify: `src/App/Shared/UiUtil.luau`
- Modify: `src/App/Types/IconCatalog.luau`
- Modify: `src/App/Explorer/init.luau`
- Modify: `src/App/Explorer/InsertPicker.luau`
- Modify: `src/App/Explorer/ContextMenu.luau`
- Modify: `src/App/Properties/init.luau`
- Modify: `src/App/Settings/init.luau`

**Interfaces:**
- Produces: `Theme.spacing`, `Theme.radius`, `Theme.typeSize`, and `Theme.motion`
- Produces: `Theme.play(inst, key, props, info)` that cancels the prior tween for the same instance/key
- Produces: `UiUtil.makeChevron`, `makeCloseButton`, `makeFocusStroke`, `makeCard`, and `makeSectionHeader`

- [ ] **Step 1: Add token tables and keyed tween cancellation to Theme**

Use `Enum.Font.BuilderSans`, `Enum.Font.BuilderSansMedium`, and `Enum.Font.RobotoMono`; if the Builder Sans enum is unavailable at runtime, fall back to Gotham through a protected lookup. Define spacing `{ xs=4, sm=8, md=12, lg=16 }`, radii `{ control=6, card=8, overlay=10 }`, and fast/medium motion at 0.08/0.14 seconds.

- [ ] **Step 2: Build the shared visual primitives and keyboard focus rings**

Chevrons use two rotated one-pixel Frames. Close controls use ASCII `x`. More menus use three drawn dots. Settings uses an image/icon widget or ASCII label, never the gear glyph.

- [ ] **Step 3: Apply the primitives and 4 px spacing grid across existing docks and overlays**

Keep row hierarchy and panel separation unchanged. Replace direct corners, strokes, and hover color assignments with shared helpers.

- [ ] **Step 4: Remove unsupported glyphs from runtime UI strings**

Replace text suffixes such as bullets, down triangles, typographic crosses, arrows, ellipses, and status separators with separate drawn controls or ASCII labels.

- [ ] **Step 5: Run `rg -n '[^\x00-\x7F]' src` and review every remaining match**

Only source comments and deliberate non-UI strings may remain.

- [ ] **Step 6: Run StyLua, Selene, and a Rojo build, then commit**

```bash
stylua src tests
selene src tests
rojo build -o /tmp/fragua-theme.rbxm
git add src tests
git commit -m "feat: apply Machined Modern component system"
```

### Task 4: Stable type draft model and validation

**Files:**
- Create: `src/App/Types/TypeDraft.luau`
- Create: `tests/TypeDraft.spec.luau`
- Modify: `src/App/Types/TypeEditor.luau`

**Interfaces:**
- Produces: `TypeDraft.fromDefinition(definition): Draft`
- Produces: `TypeDraft.addCategory`, `renameCategory`, `removeCategory`, `addProperty`, `removeProperty`, and `updateProperty`
- Produces: `TypeDraft.validate(draft, lookupType): { DraftError }`
- Produces stable `category.id` and `property.id` strings for UI closures

- [ ] **Step 1: Add failing tests for stable IDs, category rename, duplicate names, invalid defaults, and inheritance cycles**

```luau
local draft = TypeDraft.new("Zombie")
local categoryId = TypeDraft.addCategory(draft, "AI")
local propertyId = TypeDraft.addProperty(draft, categoryId, "DetectRange", "number", "40")
TypeDraft.renameCategory(draft, categoryId, "Senses")
assert(draft.properties[propertyId].categoryId == categoryId)
assert(#TypeDraft.validate(draft, function() return nil end) == 0)
```

Include literal failing fixtures for two `Health` properties, `number = "fast"`, and `A extends B extends A`.

- [ ] **Step 2: Run tests and verify failure because TypeDraft is missing**

- [ ] **Step 3: Implement draft mutations and validation as pure functions**

IDs are monotonic within a draft (`category-1`, `property-1`). Validation returns `{ fieldId, code, message }` records and never mutates the draft.

- [ ] **Step 4: Run TypeDraft tests and verify they pass**

- [ ] **Step 5: Refactor TypeEditor to render from stable draft IDs**

Commit focused text into the draft before any rebuild. Handlers capture IDs, never indices or category names. Render inline errors next to fields and keep the overlay open on validation failure.

- [ ] **Step 6: Verify create, add, rename, retype, delete, and reopen behavior in the Studio checklist**

- [ ] **Step 7: Commit the type draft refactor**

```bash
git add src/App/Types/TypeDraft.luau src/App/Types/TypeEditor.luau tests/TypeDraft.spec.luau
git commit -m "fix: stabilize custom type property drafts"
```

### Task 5: Transactional registry updates and migration decisions

**Files:**
- Create: `src/App/Types/SchemaMigration.luau`
- Create: `tests/SchemaMigration.spec.luau`
- Modify: `src/App/Types/Registry.luau`

**Interfaces:**
- Produces: `SchemaMigration.plan(previous, nextDefinition): MigrationPlan`
- Produces: `Registry.validateDefinition(definition): (boolean, string?)`
- Changes: `Registry.save(definition)` validates and writes without destroying the previous module first

- [ ] **Step 1: Add failing migration tests**

Cover added defaults, removed attributes, a single same-type rename retaining values, and incompatible type changes reported in `plan.warnings`.

- [ ] **Step 2: Run the suite and verify SchemaMigration is missing**

- [ ] **Step 3: Implement deterministic migration planning**

The plan contains literal `add`, `remove`, `rename`, and `warnings` arrays sorted by property name.

- [ ] **Step 4: Update Registry to encode and validate before mutating storage**

Update an existing ModuleScript's Source in place after validation; create a new module only for new IDs. Apply one migration plan to all placed instances under one ChangeHistory recording.

- [ ] **Step 5: Run tests and a Rojo build**

- [ ] **Step 6: Commit transactional type persistence**

```bash
git add src/App/Types/Registry.luau src/App/Types/SchemaMigration.luau tests/SchemaMigration.spec.luau
git commit -m "fix: make custom type saves transactional"
```

### Task 6: Properties behavior workflow

**Files:**
- Modify: `src/App/Properties/init.luau`
- Modify: `src/App/Types/TypeEditor.luau`
- Modify: `src/init.server.luau`

**Interfaces:**
- Consumes: `Registry.getSharedBehavior`, `ensureBehaviorTemplate`, `findInstances`
- Produces: `onEditScript(target, context)` callbacks from Properties and TypeEditor mounts

- [ ] **Step 1: Add an `onEditScript` option to Properties and TypeEditor mount/open contracts**

The callback receives `{ target = ModuleScript, typeId = string, sharedCount = number }`.

- [ ] **Step 2: Render the Behavior card for Fragua instances**

Show shared scope, placed instance count, implemented hooks derived from source, `Edit behavior`, and guarded `Reset`. Use plain text labels and shared buttons.

- [ ] **Step 3: Wire Edit behavior to enable/focus the Script Editor dock and open the shared target**

- [ ] **Step 4: Expose Edit behavior after a type is saved in TypeEditor**

- [ ] **Step 5: Build and manually verify Properties-to-Behavior navigation**

- [ ] **Step 6: Commit the behavior workflow**

```bash
git add src/App/Properties/init.luau src/App/Types/TypeEditor.luau src/init.server.luau
git commit -m "feat: open shared behaviors from Properties"
```

### Task 7: Script documents and save-state model

**Files:**
- Create: `src/App/ScriptEditor/DocumentStore.luau`
- Create: `tests/DocumentStore.spec.luau`
- Modify: `src/App/ScriptEditor/init.luau`

**Interfaces:**
- Produces: `DocumentStore.open(state, descriptor): (state, documentId)`
- Produces: `DocumentStore.edit`, `markSaved`, `markExternalChange`, `closeDecision`, and `select`
- Document fields: `id`, `targetKey`, `title`, `source`, `savedSource`, `dirty`, `typeId`, `sharedCount`, `cursor`, `selectionStart`, and `scrollY`

- [ ] **Step 1: Add failing tests for tab reuse, dirty state, save state, external changes, and close decisions**

Use string target keys in pure tests and hand-derived state assertions.

- [ ] **Step 2: Run tests and verify DocumentStore is missing**

- [ ] **Step 3: Implement immutable-style document operations**

Opening the same `targetKey` focuses the existing document. Editing changes `source` and derives `dirty` from `source ~= savedSource`. A dirty external change sets `conflicted = true` without replacing source.

- [ ] **Step 4: Run DocumentStore tests**

- [ ] **Step 5: Refactor ScriptEditor mount around DocumentStore and `openTarget(context)`**

Save regular scripts with `ScriptEditorService:UpdateSourceAsync`; save shared behavior with `Registry.setSharedBehaviorSource`. On failure, preserve dirty source and show the returned error.

- [ ] **Step 6: Commit document and save behavior**

```bash
git add src/App/ScriptEditor/DocumentStore.luau src/App/ScriptEditor/init.luau tests/DocumentStore.spec.luau
git commit -m "feat: add reliable script document state"
```

### Task 8: Fragua completion and diagnostics engines

**Files:**
- Create: `src/App/ScriptEditor/CompletionEngine.luau`
- Create: `src/App/ScriptEditor/Diagnostics.luau`
- Create: `tests/CompletionEngine.spec.luau`
- Create: `tests/Diagnostics.spec.luau`

**Interfaces:**
- Produces: `CompletionEngine.complete(request): { CompletionItem }`
- Request fields: `source`, `cursor`, `typeId`, `schema`, `typeIds`, and `runtimeHelpers`
- Produces: `Diagnostics.analyze(source, context): { Diagnostic }`
- Diagnostic fields: `severity`, `code`, `message`, `startByte`, and `endByte`

- [ ] **Step 1: Add failing completion tests**

Cover Luau keyword filtering, local symbol extraction, Behavior hook snippets, type IDs after `Fragua.create("`, and inherited schema properties inside `GetAttribute("`.

- [ ] **Step 2: Add failing diagnostic tests**

Cover unknown attributes for a known type, duplicate `onCreated`, wrong `onPropertyChanged` arity, unmatched brackets, and strings/comments that contain bracket characters without false positives.

- [ ] **Step 3: Run tests and verify both modules are missing**

- [ ] **Step 4: Implement context detection, ranking, and insertion ranges**

Exact prefix matches rank before case-insensitive contains matches. Schema items include type, category, default, and inherited detail. Completion results are deterministic and capped at 50.

- [ ] **Step 5: Implement focused lexical diagnostics**

Mask comments and strings while retaining byte positions, then scan brackets and Behavior function declarations. Do not report general Luau syntax errors.

- [ ] **Step 6: Run completion and diagnostic tests**

- [ ] **Step 7: Commit the assistance engines**

```bash
git add src/App/ScriptEditor tests/CompletionEngine.spec.luau tests/Diagnostics.spec.luau
git commit -m "feat: add Fragua-aware code assistance"
```

### Task 9: Fully editable custom code canvas

**Files:**
- Create: `src/App/ScriptEditor/CodeCanvas.luau`
- Create: `src/App/ScriptEditor/EditorChrome.luau`
- Modify: `src/App/ScriptEditor/init.luau`
- Modify: `src/init.server.luau`

**Interfaces:**
- Consumes: DocumentStore, CompletionEngine, Diagnostics, Registry, and Theme components
- Produces: `CodeCanvas.mount(parent, options)` with `setDocument`, `focus`, `destroy`, and change/cursor callbacks
- Produces: `ScriptEditor.openTarget(context)` for Properties, TypeEditor, and Explorer

- [ ] **Step 1: Build the Machined Modern tab bar, breadcrumb, action bar, gutter, editor, completion popup, diagnostic list, and status bar**

Use Roboto Mono and line height 20 px. The editable TextBox owns input and selection; the syntax overlay mirrors text and scroll position without intercepting input.

- [ ] **Step 2: Add indentation, bracket/quote pairing, Tab/Shift-Tab, find/replace, and format indentation**

Pair only when there is no conflicting selection or escaped quote. Undo/redo records source and selection snapshots with coalescing for adjacent typing.

- [ ] **Step 3: Connect completion popup keyboard behavior**

Up/Down moves selection, Tab/Enter applies the selected insertion range, Escape closes, and typing refreshes results. Position uses line/column times measured monospaced cell size and clamps to canvas bounds.

- [ ] **Step 4: Connect schema refresh and diagnostics**

Resolve `Registry.resolvedSchema` for the active `typeId` on open and Registry change. Debounce analysis by 120 ms.

- [ ] **Step 5: Wire toolbar button, selection opening, dirty close confirmation, save, and external change prompts**

- [ ] **Step 6: Build and run the Script Editor Studio checklist**

- [ ] **Step 7: Commit the custom editor UI**

```bash
git add src/App/ScriptEditor src/init.server.luau
git commit -m "feat: deliver custom Fragua script editor"
```

### Task 10: Explorer drag transaction and final verification

**Files:**
- Modify: `src/App/Explorer/Tree.luau`
- Modify: `src/App/Explorer/init.luau`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-08-10-fragua-ui-reliability-editor.md`

**Interfaces:**
- Consumes: PointerController and InteractionMath
- Produces: one validated Explorer drag transaction with cancel and cleanup

- [ ] **Step 1: Replace Tree's local capture and coordinate heuristics with PointerController**

Use one source snapshot, one threshold, one ghost, one current drop target, and one release mutation. Abort before rebuild and remove all session UI.

- [ ] **Step 2: Validate all reparent targets before mutation**

Reject service roots, self, descendants, hidden internals, nil parents, and assignments that fail a protected parent set. Multi-selection excludes descendants of another selected source to avoid moving them twice.

- [ ] **Step 3: Coalesce history and refresh selection after a successful drop**

- [ ] **Step 4: Update README with the completed Script Editor and behavior workflow**

- [ ] **Step 5: Run the complete automated verification**

```bash
lune run tests/run.luau
stylua --check src tests
selene src tests
rojo build -o /tmp/Fragua-final.rbxm
```

- [ ] **Step 6: Run `git diff --check`, inspect the full diff, and complete the Studio interaction checklist**

- [ ] **Step 7: Mark every completed checkbox in this plan and commit final integration changes**

```bash
git add src tests README.md docs/superpowers/plans/2026-08-10-fragua-ui-reliability-editor.md
git commit -m "fix: complete Fragua interaction and editor overhaul"
```
