# Native Editor and Runtime Gateway Design

## Goal

Use Roblox's native script editor while making Fragua's runtime API available in every editable `Script`, `LocalScript`, and `ModuleScript`. Preserve ordinary Roblox `Instance` and `Enum` behavior while adding Fragua custom types through compatible proxies. Fix the Properties dock so engine subclasses inherit relevant parent-class properties.

## Script surface

Fragua manages one marked header at the beginning of every editable script:

```luau
-- Fragua imports begin
local Fragua = require(game:GetService("ReplicatedStorage"):WaitForChild("Fragua"))
local Instance = Fragua.Instance
local Enum = Fragua.Enum
-- Fragua imports end
```

Only these three bindings are injected. Fragua does not replace `require`, `type`, `typeof`, `game`, standard libraries, or other Roblox globals.

Injection is idempotent. A script with the current marked header is unchanged. An older marked header is replaced in place without altering the rest of the source. A script without a header receives it at the beginning. Fragua processes existing scripts during plugin startup and watches `game.DescendantAdded` for newly inserted scripts. It also repairs a removed or outdated managed header when an editable script source changes.

The injector skips the managed `ReplicatedStorage.Fragua` gateway and `ServerScriptService.FraguaRuntime` bootstrap to prevent self-require cycles. It must also avoid recursive source-change handling and catch Studio edit failures. Failed or protected scripts remain unchanged and produce a concise warning containing the script path.

All source updates use `ScriptEditorService:UpdateSourceAsync` so Studio's native editor and undo/source-management behavior remain authoritative.

## Runtime gateway

`ReplicatedStorage.Fragua` remains the single gateway ModuleScript and gains two compatibility proxies:

- `Fragua.Instance.new(classOrType, parent?)`
- `Fragua.Enum`

`Fragua.Instance.new("Part")` delegates to Roblox's original `Instance.new`. A registered Fragua type ID creates a Fragua instance with its resolved defaults, type attribute, and collection tag. `Fragua.Instance.new(Enum.FraguaType.Zombie)` accepts the corresponding custom enum item. Roblox class names take precedence if a Fragua type ID collides with a Roblox class name; the enum-item form remains unambiguous.

`Fragua.Enum` forwards unknown keys and Roblox enum names directly to the original Roblox `Enum` object. This is a live proxy rather than a copied snapshot, so Roblox enum additions automatically become available without a Fragua release. It adds `Enum.FraguaType`, whose items represent the currently registered Fragua type IDs. `Enum:GetEnums()` returns Roblox's current enum list plus the Fragua type enum descriptor.

Fragua enum items are immutable proxy values with stable names and string representations. They are not native `EnumItem` userdata, so native `typeof` continues to report their underlying Luau representation. Fragua does not override `typeof`; code can inspect the item through the documented Fragua fields or pass it directly to `Fragua.Instance.new`.

Existing helpers remain available: `Fragua.Get`, `GetTypeId`, `IsA`, `GetProperty`, `SetProperty`, and `GetInstances`.

## Replicated type catalogue

The plugin mirrors the registered type catalogue into a managed container under `ReplicatedStorage`, accessible to both server and client code. Each entry contains the type ID, display name, resolved property defaults, and a managed behavior template that the runtime factory can clone without reading or writing `Source` during play. Registry changes refresh this catalogue without requiring users to reopen Studio.

The runtime gateway reads the catalogue dynamically. New, renamed, edited, or removed Fragua types therefore update `Enum.FraguaType` and `Fragua.Instance.new` during the same Studio session.

## Native script editor integration

The custom Script Editor dock, toolbar button, source editor modules, and editor-specific tests are removed. The Properties dock's **Edit behavior** action opens the shared behavior `ModuleScript` with Roblox Studio's native editor through the plugin API. Script selection and editing otherwise remain normal Roblox Studio behavior.

Fragua continues to synchronize shared behavior source to placed instances through the existing Registry and runtime bootstrap.

## Engine property inheritance

The Properties dock builds engine-property rows from reusable class-family layers rather than a single exact-class table. The order is:

1. common `Instance` properties;
2. applicable family properties such as `GuiObject` or `BasePart`;
3. exact-class additions or overrides.

Rows are deduplicated by property name, with the most specific definition winning while retaining deterministic category ordering. For example, `SpawnLocation` receives BasePart properties including `Transparency`, `Reflectance`, `Material`, collision flags, size, position, and orientation, plus SpawnLocation-specific properties such as `Enabled`, `Duration`, and `Neutral`. Other BasePart subclasses receive the same common coverage automatically.

## Output behavior

The plugin no longer prints the “Plugin loaded - forge custom instance types” message. It emits output only for actionable failures such as a script that Studio refused to update or a malformed runtime catalogue entry.

## Safety and compatibility

- Managed headers are identifiable and reversible.
- User source outside the marked header is preserved byte-for-byte.
- Source mutation is guarded against feedback loops.
- Fragua-owned runtime scripts are never injected.
- Roblox class and enum behavior remains available through the aliases.
- Existing places using `local Fragua = require(...)` continue to work.
- The unrelated untracked `.superpowers/` directory is not staged or modified.

## Testing

Pure tests cover header insertion, replacement, idempotence, skip decisions, and source preservation. Runtime source tests verify the generated API contains the `Instance` and live `Enum` proxy contracts. Engine-property tests verify BasePart inheritance, exact-class overrides, and deduplication, including the SpawnLocation regression.

The final verification runs formatting, Selene, the full Lune suite, `git diff --check`, and a Rojo plugin build. The built plugin is copied to the Roblox Plugins directory and verified by checksum before handoff.
