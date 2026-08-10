# Fragua

**Fragua** (Spanish: *forge*) is a Roblox Studio plugin that remakes **Explorer** and **Properties**, and lets you forge **custom instance types** that behave like first-class objects inside those panels.

> Custom types are **not** real engine `ClassName`s (plugins cannot register those). They are authored and edited in Fragua, and saved in the place as tagged `Configuration` instances.

## Features (v1)

- Studio-like **Explorer** dock (tree, filter, rename, delete, selection sync)
- Studio-like **Properties** dock (curated engine props + custom type attributes)
- **Insert Object** picker with:
  - Built-in classes
  - Your custom types (with icons)
  - **Create New Type…**
  - **Delete Type…**
- Type inheritance with visible read-only inherited properties and direct overrides
- Searchable categorized icon picker with 160+ Studio-style icons
- Edit-time **Behavior** hooks (`onCreated`, `onSelected`, `onPropertyChanged`, `onAncestryChanged`)
- Scrollable docked **Script Editor** with tabs, syntax coloring, dirty/conflict state, search, and diagnostics
- Type-aware suggestions for Luau/Roblox symbols, behavior hooks, custom types, inherited properties, and literal attribute types
- Modern compact controls, transactional sliders, smoother hex/RGB color input, animated booleans, and optional interface animations
- Sample **Zombie** type with a Studio nameplate

## Install (development)

Requirements: [Aftman](https://github.com/LPGhatguy/aftman) (or Rojo 7.4+), Roblox Studio.

```bash
cd ~/Projects/fragua
aftman install
rojo build -o Fragua.rbxm
```

Copy `Fragua.rbxm` into your local plugins folder, then restart Studio (or reload plugins):

- macOS: `~/Documents/Roblox/Plugins/`
- Windows: `%LOCALAPPDATA%/Roblox/Plugins/`

Or use live sync with a Rojo plugin workflow pointing at this project.

### Toolbar

After install you should see a **Fragua** toolbar:

| Button | Action |
|--------|--------|
| Explorer | Toggle Fragua Explorer |
| Properties | Toggle Fragua Properties |
| Script Editor | Toggle the custom Fragua code editor |

## Custom types

Definitions live under:

```
ServerStorage
└── Fragua
    └── Types
        └── Zombie          (ModuleScript — type definition)
            └── Behavior    (ModuleScript — edit-time hooks)
```

### Create a type

1. Open **Fragua Explorer**
2. Optionally select a parent (e.g. a Model in Workspace)
3. Click **+** (or right-click a row → Insert Object)
4. Choose **Create New Type…**
5. Set name, `extends`, properties, and icon
6. Choose **Create & insert**. Fragua saves the definition and inserts its first instance under the selected parent, or under `Workspace` when nothing valid is selected.

### Place a type

From Insert Object, pick the type under **Custom**. Fragua creates a `Configuration` with:

- Attribute `_FraguaType` = type id
- CollectionService tag `FraguaInstance`
- Attributes for each declared property
- Child `Behavior` ModuleScript

Fragua Explorer shows it as e.g. `Zombie` with your icon. Built-in Studio Explorer still shows `Configuration` — that is expected.

### Delete a type

Insert Object → **Delete Type…**. This removes the definition from `ServerStorage.Fragua.Types`. Already-placed instances are left in the place (v1); they show a fallback “missing” label until you delete or reassign them.

### Behavior hooks

Select a custom instance and choose **Edit behavior** in Fragua Properties. Fragua opens the shared type behavior in its custom editor, where autocomplete understands the type's schema and hooks. The editor never opens merely because selection changed. To edit a normal Script, LocalScript, or ModuleScript, select it and choose **Open selected** in the Script Editor dock.

Behavior modules use this shape:

```lua
local Behavior = {}

function Behavior.onCreated(instance: Instance) end
function Behavior.onSelected(instance: Instance) end
function Behavior.onPropertyChanged(instance: Instance, key: string, value: any) end
function Behavior.onAncestryChanged(instance: Instance) end

return Behavior
```

The plugin runs these in **Edit** mode. The seeded **Zombie** type adds a green nameplate BillboardGui (Humanoid-style feedback).

## Project layout

```
fragua/
  default.project.json
  aftman.toml
  src/
    init.server.luau          # plugin entry (toolbar + docks)
    App/
      Explorer/               # tree + Insert Object picker
      Properties/             # property grid
      ScriptEditor/           # docked editor, autocomplete, diagnostics
      Settings/               # persisted UI preferences
      Types/                  # registry, schemas, icon picker, type editor
      Behaviors/              # edit-time behavior host
      Shared/                 # theme, constants, util
  templates/
```

## Limits

- Not full Studio Explorer / Properties parity
- The custom editor intentionally provides lightweight completion and diagnostics rather than the full native Studio language server
- Custom types are Fragua-surface only; gameplay should read attributes / your own runtime loader
- Deleting a type does not bulk-delete placed instances

## License

Private repository — all rights reserved.
