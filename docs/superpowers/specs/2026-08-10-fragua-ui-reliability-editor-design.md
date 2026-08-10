# Fragua UI Reliability and Script Editor Design

Date: 2026-08-10

## Objective

Repair Fragua's broken pointer interactions and custom-type property workflow, remove unsupported text glyphs, and refresh the existing Explorer and Properties dock structure with a cohesive modern component system. Add a fully editable Script Editor dock with lightweight Luau assistance and schema-aware Fragua completions.

Explorer and Properties remain separate Studio dock panels. Their information architecture remains familiar; the redesign changes component construction, typography, spacing, states, and motion rather than replacing the underlying workflow.

## Current problems and root causes

The current branch builds successfully, but several interaction paths use different assumptions about pointer coordinates. Slider dragging, color picking, floating-panel dragging, and Explorer reparenting mix screen, plugin, host, and control-local values. Capture and cleanup are duplicated, so pointer release can leave stale drag state or disabled scrolling.

The Type Editor rebuilds dynamic property controls directly from mutable tables. Rebuilds can destroy focused controls, stale closures can refer to old category names or indices, and tightly calculated fixed heights can clip or misplace property rows. Validation occurs late, after substantial UI state has already changed.

Several labels append Unicode symbols to Gotham-rendered text. Roblox Studio font coverage is inconsistent for these characters, producing the reported trailing boxes.

The existing Script Editor implementation is a single multiline TextBox. It has no document abstraction, completion context, diagnostics, tabs, line gutter, or clear custom-type behavior context.

## Approved visual system: Machined Modern

Fragua will use a medium-density dark interface with calm layered surfaces and soft-square controls.

- Typography: Builder Sans where available, with a safe Studio font fallback; Roboto Mono for code and numeric input.
- Radius: 6 px for fields and buttons, 8 px for cards and modal panels, and fully rounded toggles and slider knobs.
- Spacing: a 4 px base grid, primarily using 8 px internal gaps and 12 px panel padding.
- Borders: one-pixel low-contrast borders distinguish interactive controls from surfaces. Rows remain mostly borderless.
- Type scale: 13 px primary text, 12 px control text, 11 px secondary labels, and 10 px utility captions.
- Selection: a distinct filled selection surface with a narrow leading indicator. Hover is quieter than selection.
- Focus: visible focus rings for keyboard-editable controls.
- Motion: 80-160 ms transitions with one tween per property. Hover, press, selection, disclosure, modal entrance, and drag-target feedback use the shared motion tokens.
- Reduced motion: Settings can reduce transitions to near-instant changes or disable them.
- Glyphs: UI shapes, image assets, or ASCII-safe text replace unsupported Unicode arrows, bullets, ellipses, crosses, gears, and status separators.

## Component architecture

### Theme and UI kit

`Theme` becomes the single token source for colors, typography, radii, spacing, sizes, focus styles, and motion. Shared UI helpers create buttons, icon buttons, close controls, chevrons, fields, dropdown surfaces, cards, section headers, focus rings, and status indicators.

Components expose explicit states rather than styling themselves through unrelated event handlers. Each component owns and cancels its active tween before starting a replacement. Destruction disconnects component-owned listeners.

### Pointer controller

A shared pointer controller owns all press, movement, release, and cancellation sessions. Callers supply an anchor control, a coordinate space, movement and release callbacks, and optional scrolling to suspend during the session.

The controller normalizes every sample into host-local coordinates, then provides helpers for host-to-control conversion and clamped scalar mapping. It cleans up when input ends, the host closes, the source is destroyed, a rebuild occurs, or another pointer session begins.

Number sliders, saturation/value fields, hue sliders, draggable panels, and Explorer drag-and-drop use this controller. No component reads callback coordinates as both local and screen coordinates.

### Explorer dragging

Explorer dragging follows a single transaction:

1. Record the source selection and press position.
2. Start dragging only after a shared threshold is crossed.
3. Show a stable ghost and calculate a drop target from normalized host coordinates.
4. Reject service roots, hidden internals, self-parenting, descendant cycles, destroyed targets, and invalid parent assignments.
5. Reparent the selected sources once on release.
6. Expand the destination, update Studio selection, record history, and rebuild.
7. Cancel without mutation on Escape, pointer cancellation, widget closure, or invalid release.

Hover and drag target visuals are separate states so they cannot overwrite one another.

## Properties controls

### Number field

The number control combines a slider and numeric field. Clicking maps directly to the track. Dragging uses normalized host-local motion without jumps. The field accepts signed decimals and clamps only on commit. Known engine properties use explicit ranges; custom numeric properties can declare a range later, but otherwise receive a stable derived range for the current editing session.

Continuous dragging updates the visible value immediately. History and behavior notifications are coalesced so a drag does not create one history entry per pointer sample.

### Color field

The color control shows a swatch plus RGB/hex text. The picker contains saturation/value, hue, a live preview, RGB and hex fields, and Cancel/Apply actions. All channels stay synchronized. Cancel restores the original value without generating an extra final change; Apply commits once.

Pointer sampling uses the shared controller. The picker remains inside the dock bounds and can be dragged by its title bar.

### Other controls

Toggles animate the knob and track as one state change. Enum dropdowns are anchored and clamped to the dock. Text and vector fields preserve invalid text while focused, display a useful inline error, and revert only when explicitly cancelled.

## Custom type editing

The Type Editor uses a persistent draft model separate from rendered controls. Categories and properties receive stable draft IDs, so rename and delete handlers do not depend on captured array indices or old category names.

Draft operations include adding, deleting, and renaming categories; adding, deleting, renaming, and retyping properties; editing defaults; changing inheritance; and choosing an icon. Re-rendering reads from the draft without discarding focused text unnecessarily.

Before saving, validation checks:

- type and property identifiers;
- duplicate property names across categories;
- supported default value types and parseable defaults;
- inheritance cycles;
- inherited-property collisions;
- reserved Fragua and engine names.

Validation errors appear beside the relevant field and in a compact summary. The draft remains intact.

Registry persistence is transactional. Fragua encodes and validates the complete definition before changing the stored ModuleScript. Once the definition is stored, placed instances migrate in one history operation. Added properties receive defaults, removed properties are removed, safe single-property renames retain values, and incompatible changes receive an explicit warning before save.

## Properties-to-Behavior workflow

Selecting a Fragua instance adds a Behavior section to Properties. It displays:

- the shared behavior name;
- how many placed instances use it;
- implemented and available hooks;
- an `Edit behavior` action;
- a guarded reset action.

`Edit behavior` opens or focuses the corresponding shared Behavior document in the custom Script Editor dock. Changes to a shared behavior apply to every instance of that type through the existing registry synchronization mechanism. The UI states this scope before editing and saving.

The Type Editor also exposes `Edit behavior` after a type has been saved. Unsaved types must be created before a Behavior ModuleScript can exist.

## Custom Script Editor

### Document model

The editor maintains one document record per open LuaSourceContainer. A record stores the target, display name, custom type context, shared-instance count, source text, saved source, cursor and selection, scroll position, dirty state, and diagnostic results.

Tabs switch records without overwriting unsaved text. Selection can open regular Script, LocalScript, ModuleScript, or the shared Behavior for a Fragua instance. Closing a dirty document requires Save, Discard, or Cancel.

Saving regular scripts uses `ScriptEditorService:UpdateSourceAsync`. If Studio rejects that update, the save fails visibly and the document remains dirty; Fragua does not fall back to an untracked direct write. Saving shared behavior uses the Registry synchronization path. External source changes trigger a reload prompt instead of silently replacing dirty text.

### Code canvas

The custom dock remains the primary editing surface. It includes:

- monospaced editable code input;
- synchronized syntax-color overlay;
- line-number gutter;
- current-line and selection feedback;
- tab and Shift-Tab indentation;
- automatic indentation and bracket/quote pairing;
- undo and redo within the document;
- find and replace;
- format indentation;
- line, column, language, save, and diagnostic status;
- keyboard navigation for all editor actions.

The initial implementation deliberately does not promise Studio-equivalent semantic analysis, multi-cursor editing, a minimap, code folding, or AI code generation. A decorative minimap is omitted unless it can accurately represent and navigate the document.

### Lightweight completion engine

The completion engine combines lexical context with the active Fragua type schema. It offers:

- Luau keywords and common globals;
- identifiers declared in the current document;
- Behavior hook snippets and signatures;
- registered Fragua type IDs;
- direct and inherited properties for the active custom type;
- property categories, types, and defaults in completion documentation;
- Fragua runtime helper names and call snippets;
- schema-aware attribute strings inside `GetAttribute`, `SetAttribute`, and property-change comparisons.

The popup is keyboard operated: Up/Down changes selection, Tab or Enter accepts, Escape closes, and continued typing filters. It anchors to the caret using monospaced line and column measurements and remains within dock bounds.

The engine derives schemas from Registry data at request time or from an invalidated cache. Creating, editing, or deleting a type refreshes subsequent completions.

### Diagnostics

Fragua diagnostics are intentionally focused. They detect unknown custom type IDs, unknown attributes for a known type, duplicate Behavior hooks, unsupported hook names, and invalid hook parameter counts. A lightweight lexical pass also detects unclosed strings and unmatched brackets where reliable.

Diagnostics are non-destructive and do not claim to replace Luau's compiler. Errors and warnings appear in the status area and an accessible list; selecting one moves the cursor to its range. Saving remains possible after confirmation when only Fragua diagnostics are present.

## Error handling and recovery

- Pointer sessions always restore suspended scrolling and remove capture layers.
- UI rebuilds discard references to destroyed instances and controls.
- Dropdowns and overlays close when their anchors are destroyed.
- Registry writes preserve the previous definition until the replacement is ready.
- Instance migration reports partial failures and retains the saved schema; failed instances are listed for retry rather than silently ignored.
- Invalid field text stays visible with an explanation while focused.
- Script save errors keep the document dirty and display the failure without losing source.
- Reset and destructive type operations require confirmation and clearly state their scope.

## Testing and verification

Pure modules will isolate pointer math, range mapping, color parsing and formatting, type-draft validation, inheritance-cycle detection, schema migration decisions, completion context, completion ranking, and diagnostics. Each repaired behavior or new feature begins with a failing regression test.

Automated verification includes:

- pure Luau regression tests;
- StyLua formatting checks;
- Selene linting with project-appropriate configuration;
- a complete Rojo build.

Studio verification uses a written interaction checklist:

- click and drag sliders from the ends, middle, and outside prior positions;
- drag saturation/value and hue continuously, then Cancel and Apply;
- drag floating panels without jumps and close them mid-drag;
- reparent one and multiple objects, reject invalid targets, and undo/redo;
- create a type, add/rename/retype/delete properties and categories, save, reopen, and migrate placed instances;
- confirm all labels render without missing-glyph boxes;
- open Behavior from Properties, edit across tabs, exercise autocomplete and diagnostics, save, and verify instance synchronization;
- resize and redock every panel at narrow and wide dimensions;
- test keyboard focus, navigation, shortcuts, and reduced motion.

## Scope boundaries

This work does not merge Explorer and Properties, replace Studio's native Explorer, provide full Studio-equivalent IntelliSense, or add collaborative editing. It does not redesign the runtime Behavior API beyond documenting and completing the helpers already required for Fragua custom instances.

## Success criteria

The reported slider, color picker, panel dragging, Explorer dragging, type-property editing, and missing-glyph failures are reproducibly fixed. Existing Explorer and Properties workflows remain recognizable while every surface follows Machined Modern. Custom type behavior is discoverable from Properties. The Script Editor can edit regular and shared Behavior source entirely inside its dock and provides reliable lightweight Luau and Fragua-aware assistance.
