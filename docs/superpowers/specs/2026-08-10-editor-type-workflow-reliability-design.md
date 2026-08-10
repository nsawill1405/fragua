# Fragua Editor and Type Workflow Reliability Design

Date: 2026-08-10
Status: Approved

## Goal

Make Fragua's custom Script Editor and type-authoring workflow reliable enough for everyday Studio work while keeping all editing inside Fragua's docks. Repair the current scrolling, inheritance, property-layout, pointer-control, and creation regressions; then add lightweight syntax coloring, type-aware diagnostics, richer completion, animated booleans, and a broader icon library.

## Confirmed workflow

- **Create New Type** saves the definition and immediately inserts one instance.
- The instance is parented to the selected insert target. If there is no valid target, it is parented to `Workspace`.
- The created instance becomes the Studio selection and is revealed in Fragua Explorer.
- Creation closes the type dialog but does not open Script Editor or the behavior document.
- Script Editor opens documents only from explicit editor actions, including **Edit behavior** in Properties and explicit script selection/open actions inside the editor.

## Root causes being addressed

1. `CodeCanvas` uses a fixed-height `TextBox`, so source and line numbers are clipped instead of participating in a scroll canvas.
2. Sliders and the color picker call their persistence callback on every mouse sample. The resulting property-change rebuild destroys the active control and pointer capture, which makes sliders stop and makes the picker stutter.
3. Plugin GUI mouse events report screen coordinates while descendant `AbsolutePosition` values use the PluginGui coordinate space. Pointer conversion must begin with `PluginGui:GetRelativeMousePosition()`.
4. Type Creator clamps to minimum dimensions that can exceed a narrow or short Explorer dock. Its hand-calculated section heights also omit layout padding, and rebuild closures still depend on transient array positions.
5. Type Creator only displays direct draft properties, so inheritance is invisible during authoring. Registry definitions can also become stale when reading a previously required ModuleScript after its `Source` changes.
6. The create-type Insert Picker branch refreshes definitions but deliberately does not create an instance.
7. Script Editor subscribes to every Studio selection change, which opens a behavior document as a side effect of inserting/selecting a custom instance.

## Script Editor design

### Scrollable canvas

`CodeCanvas` will contain one `ScrollingFrame` with a dynamically sized content frame. The gutter, syntax layer, selection/edit layer, and completion anchor share the same content coordinates. Source measurement produces:

- content height from line count, line height, and vertical padding;
- content width from the longest line, monospace character width, gutter, and horizontal padding;
- minimum dimensions equal to the visible viewport;
- synchronized line numbers for the complete source.

Mouse wheel, trackpad, and scrollbar movement use the native `ScrollingFrame`. The completion popup is positioned from the caret's document coordinates minus `CanvasPosition`, then clamped to the visible viewport.

### Syntax coloring

A pure lexical highlighter converts source to escaped Roblox RichText. It recognizes comments, quoted strings, numbers, Luau keywords, built-in globals/types, behavior hooks, custom type identifiers, and schema property names. Coloring is incremental at the document-update boundary and is deferred/coalesced so rapid typing performs at most one repaint per task cycle.

The editable `TextBox` remains the input authority. A RichText label underneath mirrors its exact font, line height, padding, and source. The edit layer keeps selection and caret usability while its glyphs are visually suppressed enough for the colored layer to show through.

### IntelliSense and type checking

Completion remains lightweight and local. It adds:

- Luau keywords, common Roblox globals, and symbols declared with `local` or `function`;
- behavior hook snippets;
- all registered Fragua type IDs in `Fragua.create()` calls;
- inherited and direct schema properties in `GetAttribute()` and `SetAttribute()` strings;
- type-specific details, origin, and default values in completion metadata;
- completion scrolling when more than seven results exist.

Diagnostics add focused semantic checks without pretending to be Studio's full Luau language server:

- existing unmatched bracket, unclosed string, duplicate hook, and hook-arity checks;
- unknown Fragua type IDs;
- unknown schema properties;
- literal `SetAttribute` values that conflict with a property's declared Fragua type;
- duplicate local declarations in the same simple lexical scope;
- unresolved names only where the analyzer can prove the result without broad false positives.

Diagnostics are listed in the status area with line/column and severity. Editor work remains savable when warnings exist; malformed source and save failures produce a clear status rather than destroying the current document.

## Type Creator design

### Responsive shell

The dialog has three stable zones:

1. Identity: name, base type, and icon.
2. Property workspace: the only vertically scrolling region.
3. Footer: validation message, **Cancel**, and **Create & insert** or **Save changes**.

Panel bounds derive from the current host viewport with small edge insets and no minimum larger than the host. It listens for host-size changes and recenters/resizes safely. Dropdowns remain inside the dialog viewport.

### Stable property draft

Type Creator will use `TypeDraft` stable category/property IDs as its source of truth rather than parallel category arrays and index-capturing closures. Focused text is committed into the draft before rebuilds. Layout height derives from `UIListLayout.AbsoluteContentSize`, not a hand-maintained formula.

Direct properties are editable. Resolved inherited properties appear below them in read-only groups labeled with their origin type/class. A direct property with the same name is represented as an override, not a duplicate. Changing **Extends** refreshes inherited groups immediately and validates inheritance cycles.

Registry reads definition source directly and decodes it instead of relying on a cached `require()` result. A pure schema resolver will merge engine and custom bases deterministically and report each property's origin.

## Controls and animation

### Pointer normalization

Pointer sessions obtain the current PluginGui-relative mouse position through `GetRelativeMousePosition()` when hosted inside a PluginGui, then convert once into the chosen root/control coordinate space. Non-plugin GUIs retain screen-coordinate conversion. One capture session owns movement, release, cancellation, and scroll restoration.

### Sliders

Dragging updates only the slider's local visual state and numeric field. The backing property is committed once on release. Clicking a track commits the clicked value on release; typing a number still commits on focus loss. Range math remains clamped and handles zero-width tracks.

### Color picker

Dragging saturation/value or hue updates the preview, cursor, and text locally. It does not write the selected Instance on every mouse event. **Done** or pointer release updates the pending color, and closing with **Cancel** restores the original without redundant writes. Visual refreshes are coalesced to one task-cycle update to avoid unnecessary HSV and text work.

### Boolean values

Boolean rows optimistically animate the track color and knob position, then commit once. The animation respects Fragua's **Animate interface transitions** setting. Rebuilds reconcile the final authoritative value without replaying the entry animation.

## Icon library

The icon picker will include a broader, categorized set of valid Studio class icons covering world objects, constraints, UI, effects, audio, networking, values, characters, and services. ASCII fallback badges remain available and never use unsupported glyphs. Search covers both icon label and class category.

## Error handling

- Invalid or cyclic inheritance keeps Type Creator open and focuses the relevant field.
- A missing parent at insertion time falls back to `Workspace`.
- If definition save succeeds but instance insertion fails, the definition remains saved and the footer reports the insertion error with a retry action.
- Pointer cancellation leaves the persisted property unchanged.
- A syntax highlighter failure falls back to uncolored text without losing edits.
- External source conflicts retain the dirty local document and report a conflict instead of overwriting it silently.

## Testing and verification

Pure Lune tests will cover:

- editor content width/height and caret viewport positioning;
- RichText escaping and lexical token classes;
- completion ranking, inherited metadata, and long-result paging;
- semantic diagnostics for custom types and property literal types;
- schema resolution, property origin, override behavior, and stale-source decoding;
- create-and-insert parent fallback decisions;
- stable type draft mutations and responsive layout math;
- drag preview versus single release commit;
- color refresh coalescing and cancellation.

Verification also requires StyLua, Selene with zero warnings, all Lune tests, a clean Rojo build, ASCII-source scanning, and installation of the verified `.rbxm` into the user's Roblox Plugins folder. Studio-facing behavior that cannot run under Lune will be verified through deterministic pure helpers plus successful Rojo serialization.

## Non-goals

- Reimplementing Roblox Studio's full Luau parser, type solver, or language server.
- Opening the native Studio Script Editor as part of the normal Fragua workflow.
- Automatically opening behavior code because Studio selection changed.
- Allowing inherited rows to mutate the parent type from a child type dialog.
