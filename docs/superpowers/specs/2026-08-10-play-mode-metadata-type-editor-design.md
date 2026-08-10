# Play-Mode Stability, Metadata Editing, and Type Editor Design

## Scope

This change keeps Fragua Explorer and Properties fully editable during Studio Play and Run sessions, adds complete tag and attribute management to Properties, repairs the new-type dialog at small dock sizes, and removes the root cause of duplicate shared behavior modules.

The existing Fragua visual language remains unchanged. This is a lifecycle, interaction, and responsive-layout correction rather than a visual redesign.

## Play-Mode Lifecycle

Fragua will observe `RunService.RunState` as the authoritative Studio simulation transition signal. Explorer and Properties remain mounted throughout a transition so dock visibility, search text, collapsed sections, and expansion state are preserved.

When the run state changes, Fragua will:

1. Invalidate work tied to the previous DataModel generation.
2. Abort any active Explorer drag or pending pointer capture.
3. Disconnect Properties listeners from stale selected instances.
4. Defer one coalesced refresh until transition-related descendant and selection events settle.
5. Rebuild Explorer from the current services and rebind Properties to the current valid Studio selection.

Selections that are no longer descendants of the active `game` are ignored. Descendant event storms use the existing debounce path and cannot execute an older-generation rebuild after a newer transition.

Editing is not disabled in Play mode. Property, attribute, tag, insert, rename, and drag operations continue to target instances in the active Play/Run DataModel.

## Tags and Attributes

Properties will show two dedicated metadata sections for both engine and Fragua instances.

### Tags

The Tags section shows current CollectionService tags as removable rows and provides an add action. Tag names are trimmed, empty names are rejected, and adding an existing tag is idempotent.

The internal `FraguaInstance` tag is visible but locked while `_FraguaType` identifies the selected object as a Fragua instance. Other tags can be added or removed. Tag signals refresh only the Tags section or trigger a coalesced metadata rebuild; they do not recreate unrelated property controls.

### Attributes

Existing non-schema attributes appear in Attributes with value controls matching supported Roblox attribute types. Users can add, rename, change type, edit value, and delete them. Attribute names must be non-empty and unique. A rename copies the current value to the new name before removing the old name.

For Fragua instances, schema-defined attributes remain in their configured categories and continue using the schema controls. They are not duplicated in Attributes and cannot be renamed or deleted there. `_FraguaType` is shown as protected metadata and cannot be renamed, retyped, or removed. Arbitrary user attributes on a Fragua instance remain fully manageable.

Supported creation types are the types already supported by Fragua's value parser: string, number, boolean, Color3, and Vector3. Changing type resets the attribute to a safe default for the chosen type rather than attempting an ambiguous coercion.

All mutations create ChangeHistoryService waypoints. External attribute/tag changes update the relevant controls without refreshing the whole Properties window unless row membership changes.

## Responsive Type Editor

The type editor retains the current colors, typography, corners, and section styling.

The dialog becomes three regions:

- A fixed title bar.
- One vertically scrollable form body containing Name, Extends, Icon, direct property segments, inherited-property summaries, and the add-segment action.
- A fixed footer containing validation feedback, Cancel, and Create/Save.

The form uses one vertical scrolling owner. Property segments no longer resize an inner scrolling frame or enlarge the dialog itself. Rebuilding segments updates the body canvas through layout content size.

The footer uses computed responsive widths and gaps. At the minimum supported dock width, Cancel and Create/Save remain separate, visible, and clickable. Dialog dimensions never exceed the host. Small heights reduce the body viewport but retain access to every field through scrolling and always retain the footer.

## Shared Behavior Canonicalization

`Registry.save()` already creates a shared `<TypeId>Behavior` module. Default Zombie seeding currently creates a second module with the same name; seeding will instead obtain the canonical module through `ensureBehaviorTemplate()` and assign the demo source to it.

For existing places, canonicalization inspects same-name shared behavior modules:

- A non-default/customized source is preferred over an untouched generated default.
- If only generated duplicates exist, one canonical module is retained.
- If multiple distinct customized sources exist, one remains canonical and the others are moved to a clearly named backup container with their shared-template marker removed. No customized source is deleted.

Registry reads and behavior watches use only the canonical module. Canonicalization is idempotent and runs during registry initialization before behavior watchers and catalog synchronization start.

## Components and Boundaries

- A small pure lifecycle-generation helper decides whether scheduled refresh work is current.
- Explorer exposes a transition refresh that reuses its existing rebuild and drag-abort behavior.
- Properties owns metadata presentation but delegates pure tag/attribute validation and mutation planning to a testable helper.
- TypeEditorLayout calculates responsive body/footer geometry independently of Roblox UI instances.
- Registry owns behavior canonicalization because it already owns type-definition and template storage.

Each helper returns data or decisions; Roblox side effects remain in the existing UI/registry modules.

## Error Handling

Invalid metadata names or values remain in the editor with an inline error instead of partially mutating the instance. Roblox API failures are caught and shown or warned with a concise Fragua-prefixed message. A failed Play transition refresh can be retried by the next selection, descendant, registry, or run-state event.

Behavior canonicalization never discards a distinct customized source. Backup creation occurs before an ambiguous duplicate stops participating as a shared template.

## Testing and Verification

Test-first regression coverage will verify:

- Old-generation refreshes are ignored after a Play/Run transition.
- Valid current-generation refreshes execute.
- Tag names and attribute rename/type/delete plans enforce protected and duplicate-name rules.
- Responsive type-editor geometry remains non-negative and footer buttons never overlap at minimum and large host sizes.
- Zombie seeding reuses the canonical behavior template.
- Duplicate canonicalization prefers customized source and preserves conflicting customized backups.

The complete Luau test suite, StyLua check, Selene analysis, Rojo build, and diff checks must pass before the plugin is committed, pushed, and installed.
