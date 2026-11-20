<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0f2027,50:203a43,100:2c5364&height=170&section=header&text=Fragua&fontSize=52&fontColor=ffffff&fontAlignY=36&desc=Custom%20instance%20types%20for%20Roblox%20Studio&descAlignY=58&descSize=16" alt="Fragua" width="100%" />

<p>
  <img src="https://img.shields.io/badge/Luau-00A2FF?style=for-the-badge&logo=roblox&logoColor=white" alt="Luau" />
  <img src="https://img.shields.io/badge/Roblox%20Studio-000000?style=for-the-badge&logo=roblox&logoColor=white" alt="Roblox Studio" />
  <a href="https://github.com/nsawill1405/fragua/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/nsawill1405/fragua/ci.yml?branch=main&style=for-the-badge&label=CI&logo=githubactions&logoColor=white" alt="CI" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-2c5364?style=for-the-badge" alt="License" /></a>
</p>

<p><a href="#features-v1">Features (v1)</a> · <a href="#install">Install</a> · <a href="#custom-types">Custom types</a> · <a href="#project-layout">Project layout</a> · <a href="#development">Development</a> · <a href="#contributing">Contributing</a></p>

</div>

**Fragua** (Spanish: *forge*) is a Roblox Studio plugin that remakes **Explorer** and **Properties**, and lets you forge **custom instance types** that behave like first-class objects inside those panels.

> Custom types are **not** real engine `ClassName`s (plugins cannot register those). They are authored and edited in Fragua, and saved in the place as tagged instances backed by a resolved Roblox class (for example `Part` or `SpawnLocation`).

## Features (v1)

- Studio-like **Explorer** dock (tree, filter, rename, delete, selection sync)
- Studio-like **Properties** dock (curated engine props + custom type attributes)
- **Insert Object** picker with:
  - Built-in classes
  - Your custom types (with icons)
  - **Create New Type…**
  - **Create New Enum…**
  - **Delete Type…**
- Type inheritance with visible read-only inherited properties and direct overrides
- Searchable categorized icon picker with 160+ Studio-style icons
- Three-sided **Behavior** modules (`Edit`, `Server`, `Client`) with typed method surfaces
- Automatic Fragua imports in every Script, LocalScript, and ModuleScript while editing in Roblox's native editor
- Runtime `Instance` / `Enum` compatibility proxies, wrapper interop, and typed defaults
- Modern compact controls, transactional sliders, smoother hex/RGB color input, animated booleans, and optional interface animations
- Sample **Zombie** type with a Studio nameplate

## Install

### From a release build

1. Download `Fragua.rbxm` from the latest [CI run](https://github.com/nsawill1405/fragua/actions/workflows/ci.yml) (build artifact) or build it yourself (below).
2. Copy it into your local Roblox plugins folder:
   - macOS: `~/Documents/Roblox/Plugins/`
   - Windows: `%LOCALAPPDATA%\Roblox\Plugins\`
3. Restart Studio (or reload plugins).

### Build from source

Requirements: Roblox Studio and [Aftman](https://github.com/LPGhatguy/aftman) or [Rokit](https://github.com/rojo-rbx/rokit) (both read `aftman.toml`). The toolchain is pinned in `aftman.toml`: Rojo, Lune, StyLua, Selene.

```bash
git clone https://github.com/nsawill1405/fragua.git
cd fragua
aftman install            # or: rokit install
rojo build -o Fragua.rbxm
```

Copy `Fragua.rbxm` into your plugins folder as above. For a faster loop, build straight into it:

```bash
# macOS
rojo build -o ~/Documents/Roblox/Plugins/Fragua.rbxm
# Windows (PowerShell)
rojo build -o "$env:LOCALAPPDATA\Roblox\Plugins\Fragua.rbxm"
```

### Toolbar

After install you should see a **Fragua** toolbar:

| Button | Action |
|--------|--------|
| Explorer | Toggle Fragua Explorer |
| Properties | Toggle Fragua Properties |

### Explorer shortcuts

| Keys | Action |
|------|--------|
| F2 | Rename |
| Enter | Open script |
| Delete / Backspace / Shift+D | Delete selection |
| Ctrl/Cmd+D | Duplicate |
| Ctrl/Cmd+A | Select all visible |
| Ctrl/Cmd+X / C / V | Cut / copy / paste into selection |

## Custom types

Definitions live under:

```
ServerStorage
└── Fragua
    ├── Types
    │   └── Zombie                 (ModuleScript — type definition)
    │       ├── ZombieEditBehavior   (ModuleScript — edit-time hooks)
    │       ├── ZombieServerBehavior (ModuleScript — play server)
    │       └── ClientBehavior       (ModuleScript — play client; catalog copy)
    └── Enums
        └── Mood                   (ModuleScript — custom enum items)
```

### Create a type

1. Open **Fragua Explorer**
2. Optionally select a parent (e.g. a Model in Workspace)
3. Click **+** (or right-click a row → Insert Object)
4. Choose **Create New Type…**
5. Set name, `extends`, properties, typed defaults, and icon
6. Choose **Create & insert**. Fragua saves the definition and inserts its first instance under the selected parent, or under `Workspace` when nothing valid is selected.

### Place a type

From Insert Object, pick the type under **Custom**. Fragua creates a backing engine instance with:

- Attribute `_FraguaType` = type id
- CollectionService tag `FraguaInstance`
- Attributes for each declared custom property
- Defaults applied from the type's typed default controls

Fragua Explorer shows it as e.g. `Zombie` with your icon. Built-in Studio Explorer still shows the backing class — that is expected.

### Delete a type

Insert Object → **Delete Type…**. This removes the definition from `ServerStorage.Fragua.Types`. Already-placed instances are left in the place (v1); they show a fallback “missing” label until you delete or reassign them.

### Behavior sides

Every custom type has three behavior modules:

| Side | When it runs | Typical hooks / methods |
|------|--------------|-------------------------|
| **Edit** | Studio edit mode | `onCreated`, `onSelected`, `onPropertyChanged`, `onAncestryChanged` |
| **Server** | Play server | `onStart`, `onStop`, plus declared server methods |
| **Client** | Play client | `onStart`, `onStop`, plus declared client methods |

Select a custom instance and choose **Edit behavior** in Fragua Properties to open the side you need in Roblox Studio's native script editor. **Refresh Edit Behavior** reloads edit-time hooks after you change that script. MCP and place scripts can call the same path:

```luau
Fragua.RefreshEditBehaviors()         -- every type
Fragua.RefreshEditBehaviors("Zombie") -- one type
```

Edit skeleton shape:

```luau
local Behavior = {}

function Behavior.onCreated(instance: Instance) end
function Behavior.onSelected(instance: Instance) end
function Behavior.onPropertyChanged(instance: Instance, key: string, value: any) end
function Behavior.onAncestryChanged(instance: Instance) end

return Behavior
```

Server / Client skeletons use `onStart` / `onStop`. Declare play methods on the matching side only — for example a server `Attack` does not appear on the client surface:

```luau
-- ZombieServerBehavior
function Behavior.Attack(instance: Instance, target: Instance, damage: number): boolean
	return true
end
```

Script autocomplete exposes inherited native members + custom properties + **Server** methods. LocalScript autocomplete exposes inherited native members + custom properties + **Client** methods. Ambiguous ModuleScripts stay on core members until you pick an explicit facade.

### Runtime creation and wrappers

Fragua adds a managed import header to every place script. Normal Roblox classes and enums continue to work through the aliases, while Fragua type IDs are accepted by the same factory:

```luau
local part = Instance.new("Part") -- genuine Part
part.Material = Enum.Material.Neon

local zombie = Instance.new("Zombie")
zombie.Health = 100
zombie:Attack(target)
zombie.Parent = workspace

print(type(zombie)) -- userdata
print(typeof(zombie)) -- Instance
print(Fragua.GetTypeId(zombie)) -- Zombie

workspace:Raycast(origin, direction, params)
someRobloxApi(zombie.Instance) -- explicit boundary for APIs requiring userdata

local clone = Instance.fromExisting(zombie) -- same Fragua type, values copied, no descendants
zombie:Destroy() -- destroys backing instance and invalidates wrapper

local anotherZombie = Instance.new(Enum.FraguaType.Zombie, workspace)
```

Wrappers interoperate with native Instance APIs through the proxy. Use `.Instance` only at the rare boundary where an API insists on real userdata. Prefer `Fragua.GetTypeId` over `ClassName` when you need the Fragua type id.

The original gateway remains available through `Fragua.Get`, `Fragua.IsA`, `Fragua.GetProperty`, `Fragua.SetProperty`, `Fragua.GetInstances`, and `Fragua.RefreshEditBehaviors`.

### Custom enums

Insert Object → **Create New Enum…** to add a named enum (for example `Mood` with `Happy` / `Sad`). It shows up in the type editor enum-type dropdown and in scripts as `Enum.Mood.Happy`. Roblox enum names and `FraguaType` are reserved. Custom enum items are Fragua proxy values, not native `EnumItem` userdata.

### Typed defaults

In the type editor, every custom property has a typed default control that fits the property's value type (number, integer, string, boolean, Color3, enum, Instance reference, and so on). Defaults scroll with the editor, save with the type, and reopen with the same values. Native inherited properties keep engine defaults unless you override them on the instance.

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
  templates/                  # reference shapes for type definitions and behaviors
  tests/                      # Lune specs (run.luau is the entry point)
```

## Development

Run the same checks CI runs before opening a pull request:

```bash
selene src tests             # lint
stylua --check src tests     # format (run `stylua src tests` to fix)
lune run tests/run.luau      # unit tests
rojo build -o Fragua.rbxm    # plugin build
```

Tests are plain Luau specs under `tests/`, run with [Lune](https://github.com/lune-org/lune) outside Studio. Add new spec files to `tests/run.luau`.

## Contributing

Issues and pull requests are welcome. Keep changes focused, add or update a spec in `tests/` where practical, and make sure the checks above pass.

## Limits

- Not full Studio Explorer / Properties parity
- Custom type enum items are Fragua proxy values, not native Roblox `EnumItem` userdata
- Custom instances remain tagged objects rather than real engine ClassNames
- Deleting a type does not bulk-delete placed instances

## License

[MIT](LICENSE) © William North

---

<div align="center">

<sub>Made by <a href="https://github.com/nsawill1405">William North</a> · <a href="https://nsawill.co.uk">nsawill.co.uk</a></sub>

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:2c5364,50:203a43,100:0f2027&height=100&section=footer" alt="" width="100%" />

</div>
