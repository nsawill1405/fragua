-- source string for ServerStorage.Fragua.README (ai / mcp guide)
return [=[
-- Fragua AI / MCP guide. Managed by the plugin (_FraguaManaged). Do not edit this Source.
-- Search terms: Fragua, custom types, MCP, Roblox Studio plugin, Instance.new, FraguaInstance
-- require(this) returns the same guide text as a string.

return [==[
# Fragua — AI / MCP usage guide

If you are an AI using a Roblox Studio MCP server (search_game_tree, inspect_instance,
script_read, script_grep, execute_luau) or editing this place, read this first.

Fragua is a Studio plugin that remakes Explorer and Properties and lets authors forge
custom instance types. Those types are NOT real engine ClassNames. They are tagged
instances backed by a resolved Roblox class (Part, Humanoid, SpawnLocation, …).

This ModuleScript is injected by the plugin into ServerStorage.Fragua.README.
The plugin overwrites it whenever it syncs place modules. Treat it as read-only.

## DataModel map

ServerStorage.Fragua                          plugin root (hidden in Fragua Explorer)
  README                                      this guide (ModuleScript, _FraguaManaged)
  Types/                                      authoring source of truth
    <TypeId>                                  type definition ModuleScript (JSON payload)
    <TypeId>EditBehavior                      edit-mode hooks (Studio only)
    <TypeId>ServerBehavior                    play server (onStart / onStop + methods)
    <TypeId>ClientBehavior                    play client template (source of truth)
    …                                         ObjectValues named _FraguaRef_<Prop> for refs
  BehaviorBackups/                            old behavior sources, never overwrite these
  Enums/                                      custom enum definitions
    <EnumId>                                  enum ModuleScript (JSON payload)
  RefreshEditBehaviors                        BindableFunction the plugin honors

ReplicatedStorage.Fragua                      runtime API gateway (ModuleScript, managed)
ReplicatedStorage.FraguaTypes                 replicated catalogue for play + client
  _FraguaNativeClasses                        known engine class names
  <TypeId>                                    Configuration: TypeId, DisplayName, BackingClass
    Properties/                               per-property Configuration metadata
    Defaults/                                 default attributes + _FraguaRef_* ObjectValues
    ClientBehavior                            clone of the client template
    FraguaAncestors/                          inheritance chain
ReplicatedStorage.FraguaEnums                 replicated custom enums
  <EnumId>                                    Configuration + EnumItems StringValues

ServerScriptService.FraguaRuntime             play-server behavior host (Script, managed)
StarterPlayer.StarterPlayerScripts
  FraguaClientRuntime                         play-client behavior host (LocalScript, managed)

Do not edit any instance with attribute _FraguaManaged = true. The plugin recreates
those sources. Do not inject Fragua import headers into these paths; ScriptHeader skips them.

## How to inspect with MCP

1. search_game_tree / inspect_instance for "Fragua", "FraguaTypes", "FraguaRuntime".
2. script_read ServerStorage.Fragua.README (this file) and ReplicatedStorage.Fragua.
3. script_grep for "_FraguaType", "FraguaInstance", "EditBehavior", "ServerBehavior".
4. execute_luau to list types and placed instances (edit mode or play):

   local types = game:GetService("ServerStorage"):FindFirstChild("Fragua")
   types = types and types:FindFirstChild("Types")
   if types then
     for _, child in types:GetChildren() do
       print(child.ClassName, child.Name, child:GetAttribute("_FraguaBehaviorSide"))
     end
   end

   local CollectionService = game:GetService("CollectionService")
   for _, inst in CollectionService:GetTagged("FraguaInstance") do
     print(inst:GetFullName(), inst.ClassName, inst:GetAttribute("_FraguaType"))
   end

5. Read a type definition ModuleScript Source. It looks like:
   -- Fragua type definition: Zombie
   return [[ {json} ]]
   JSON fields: id, name, description, extends, icon, properties[].
   Property fields: name, valueType, default, category, readonly?, enumItems?,
   enumType?, minimum?, maximum?, step?, multiline?, referenceType?.

valueType is one of: string, number, integer, boolean, Color3, BrickColor,
Vector2, Vector3, UDim, UDim2, CFrame, enum, Instance, FraguaInstance.

extends is a Roblox class name or another Fragua type id. Backing ClassName is
resolved from that chain. Studio Explorer still shows the backing class; Fragua
Explorer shows the custom type name and icon.

## Placed instances

A Fragua instance is a normal Roblox instance plus:

- Attribute _FraguaType = type id (string, e.g. "Zombie")
- CollectionService tag FraguaInstance
- Custom properties as attributes of the same name (non-reference)
- Reference properties as child ObjectValues named _FraguaRef_<Property>
- Engine properties stay on the backing instance (Size, WalkSpeed, …)

Fragua.GetTypeId(instance) is the type id. ClassName is the backing engine class.
Prefer GetTypeId / Fragua.IsA over ClassName when you care about the custom type.

## Creating / editing types

Preferred: tell the human to use Fragua Explorer → + / Insert Object → Create New Type…
(name, extends, properties, typed defaults, icon) then Create & insert.

Insert Object → Custom places another instance of an existing type.
Insert Object → Delete Type… removes the definition only. Placed instances stay
(v1) and show a missing-type fallback until deleted or reassigned.

Direct DataModel writes (MCP / scripts) can work. After you add or edit a type
ModuleScript, enum ModuleScript, or Edit Behavior Source, call:

  local Fragua = require(game:GetService("ReplicatedStorage"):WaitForChild("Fragua"))
  Fragua.RefreshEditBehaviors()            -- every type
  Fragua.RefreshEditBehaviors("Zombie")    -- one type

That reloads Edit Behavior hooks (onCreated runs again) and rebuilds the
catalogue / gateway / autocomplete. Do not reload the plugin just to pick up
those writes. If the gateway is stale, invoke ServerStorage.Fragua.RefreshEditBehaviors
(BindableFunction) with the same argument.

Type ModuleScript name must equal id. Keep it next to the three behavior
templates named:
  {id}EditBehavior   {id}ServerBehavior   {id}ClientBehavior
Mark those templates with attributes:
  _FraguaSharedBehavior = true
  _FraguaBehaviorSide = "Edit" | "Server" | "Client"

Do not put extra ModuleScripts under Types/ that look like type JSON unless they
are real types — Registry.list() decodes every ModuleScript/StringValue there.

## Creating / editing enums

Preferred: Fragua Explorer → + / Insert Object → Create New Enum…
(name plus item list, e.g. Mood = Happy, Sad). Edit or delete existing enums
from the Enums section in that picker. Delete is blocked while a type property
still uses that enumType.

Custom enums are first-class on Fragua.Enum. Roblox enum names and FraguaType
are reserved; Roblox wins on a name collision.

  zombie.Stance = Enum.Mood.Happy
  print(zombie.Stance.Name)          -- "Happy"
  print(tostring(zombie.Stance))     -- "Enum.Mood.Happy"

Custom enum items are Fragua proxy values, not native EnumItem userdata.
Store them on instances as the item name string.

Enum ModuleScripts live at ServerStorage.Fragua.Enums.<Id> with JSON
{ id, name, items }. After an MCP write, call Fragua.RefreshEditBehaviors.

## Creating instances

Preferred: Fragua Explorer Insert Object, or in a place Script/LocalScript after
the managed import header:

  local zombie = Instance.new("Zombie")
  zombie.Health = 100
  zombie:Attack(target)          -- server-side method if declared
  zombie.Parent = workspace

  print(typeof(zombie))          -- "Instance"
  print(Fragua.GetTypeId(zombie)) -- "Zombie"
  print(zombie.Instance)         -- rare: real userdata for APIs that insist on it

  Instance.new("Part")           -- still a genuine Part
  Instance.new(Enum.FraguaType.Zombie, workspace)
  Instance.fromExisting(zombie)  -- same type, values copied, no descendants

MCP / execute_luau equivalent in edit mode (no wrappers):

  local inst = Instance.new("Humanoid") -- backing class from the type's extends
  inst.Name = "Zombie"
  inst:SetAttribute("_FraguaType", "Zombie")
  game:GetService("CollectionService"):AddTag(inst, "FraguaInstance")
  inst:SetAttribute("IsHostile", true)
  inst.Parent = workspace

Copy defaults from ReplicatedStorage.FraguaTypes.<TypeId>.Defaults attributes
and _FraguaRef_* children. Match BackingClass on that Configuration.

## Behaviors

Every type has three ModuleScripts. Edit them — they are authoring files, not
_FraguaManaged runtime hosts.

Edit (Studio edit mode, plugin host):
  onCreated(instance)
  onSelected(instance)
  onPropertyChanged(instance, key, value)
  onAncestryChanged(instance)

Server (play, ServerScriptService.FraguaRuntime):
  onStart(instance)
  onStop(instance)
  plus declared server methods, e.g. function Behavior.Attack(instance, target, damage)

Client (play, FraguaClientRuntime; template is replicated under FraguaTypes):
  onStart(instance) / onStop(instance)
  plus declared client methods

Hosts require the matching template, pcall lifecycle, and start/stop from the
FraguaInstance tag. They never write .Source during play.

After you change {TypeId}EditBehavior (Studio save or MCP script write), call
Fragua.RefreshEditBehaviors(typeId) so onCreated / onSelected run on the new
code. Properties also has a Refresh Edit Behavior button next to Edit Edit
Behavior. Auto-reload on Source save still runs; refresh is the reliable
fallback after a compile error or unsaved buffer.

Declare a play method on the matching side only. A server Attack does not appear
on the client surface. Lifecycle names are reserved; do not reuse them as methods.

Shape:

  local Behavior = {}
  function Behavior.onStart(instance: Instance)
  end
  function Behavior.onStop(instance: Instance)
  end
  return Behavior

## Scripts and the import header

While the plugin is loaded, every Script / LocalScript / ModuleScript in the
place (except managed Fragua paths and CoreGui) gets a marked header:

  -- Fragua imports begin
  local FraguaGateway = require(game:GetService("ReplicatedStorage"):WaitForChild("Fragua"))
  local Fragua = FraguaGateway.Server   -- or .Client / .Core
  local Instance = Fragua.Instance
  local Enum = Fragua.Enum
  local type = Fragua.type
  local typeof = Fragua.typeof
  -- Fragua imports end

Script → Server facade (native + custom props + server methods)
LocalScript → Client facade
ModuleScript → Core until context is obvious

Do not delete that block. Do not copy it into ServerStorage.Fragua templates;
the edit host strips it so Instance/Enum stay Roblox natives there.

Facade helpers on Fragua / Fragua.Server / Fragua.Client / Fragua.Core:
  GetTypeId, IsA, Get, GetProperty, SetProperty, GetInstances(typeId?),
  RefreshEditBehaviors(typeId?)

Wrappers interoperate with native Instance APIs. Use .Instance only at the rare
boundary where an engine API requires real userdata.

## What not to do

- Do not edit ReplicatedStorage.Fragua, FraguaTypes, FraguaEnums, FraguaRuntime,
  FraguaClientRuntime, or this README. They are regenerated.
- Do not remove _FraguaType or the FraguaInstance tag from live instances unless
  you intend to un-type them.
- Do not treat custom types as engine ClassNames in Instance.new without the
  Fragua Instance proxy (edit-mode MCP Instance.new("Zombie") will fail; use the
  backing class + tag + attribute, or a place script with the header).
- Do not bulk-delete placed instances when deleting a type definition (v1 leaves them).
- Custom enum items are Fragua proxy values, not native EnumItem userdata.

## Sample type

A default Zombie type is seeded if missing. It extends Humanoid and adds
IsHostile, DetectRange, AttackDamage. Its Edit behavior draws a Studio nameplate
named _FraguaNameplate. Use it as the reference implementation.
]==]
]=]
