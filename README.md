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
- Automatic Fragua imports in every Script, LocalScript, and ModuleScript while editing in Roblox's native editor
- Runtime `Instance` and `Enum` compatibility proxies for creating and enumerating custom types
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

Select a custom instance and choose **Edit behavior** in Fragua Properties. Fragua opens the shared type behavior in Roblox Studio's native script editor.

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

### Runtime creation

Fragua adds a managed import header to every place script. Normal Roblox classes and enums continue to work through the aliases, while Fragua type IDs are accepted by the same factory:

```luau
local part = Instance.new("Part")
part.Material = Enum.Material.Neon

local zombie = Instance.new("Zombie", workspace)
local anotherZombie = Instance.new(Enum.FraguaType.Zombie, workspace)
```

The original gateway remains available through `Fragua.Get`, `Fragua.IsA`, `Fragua.GetProperty`, and `Fragua.SetProperty`.

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
      Runtime/                # injected imports, runtime gateway, type catalogue
      Settings/               # persisted UI preferences
      Types/                  # registry, schemas, icon picker, type editor
      Behaviors/              # edit-time behavior host
      Shared/                 # theme, constants, util
  templates/
```

## Limits

- Not full Studio Explorer / Properties parity
- Custom type enum items are Fragua proxy values, not native Roblox `EnumItem` userdata
- Custom instances remain tagged `Configuration` objects rather than real engine ClassNames
- Deleting a type does not bulk-delete placed instances

## License

Private repository — all rights reserved.
