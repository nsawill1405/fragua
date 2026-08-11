# Typed Runtime, Split Behaviors, and Type Defaults Design

## Goal

Make Fragua custom types feel native in Roblox scripts without replacing Roblox's editor. `Instance.new("Zombie")` should expose inherited Roblox members, resolved Fragua properties, and context-appropriate custom methods. Fragua must preserve Roblox compatibility for ordinary instances, support the complete current `Instance` constructor surface, separate edit, server, and client behavior, and provide type-aware default editors in the custom type workflow.

## Compatibility aliases

The managed script header selects a typed facade based on script context. A server `Script` uses:

```luau
-- Fragua imports begin
local FraguaGateway = require(game:GetService("ReplicatedStorage"):WaitForChild("Fragua"))
local Fragua = FraguaGateway.Server
local Instance = Fragua.Instance
local Enum = Fragua.Enum
local type = Fragua.type
local typeof = Fragua.typeof
-- Fragua imports end
```

A `LocalScript` selects `FraguaGateway.Client`. A ModuleScript stored in a server-only container selects `Server`; a replicated or otherwise ambiguous ModuleScript selects the neutral `FraguaGateway.Core` facade. Authors of a shared ModuleScript can explicitly obtain the Server or Client facade at the call site when they intentionally write side-specific code.

The injector continues to compare the complete managed header before editing source. A script that already has the current header is not written again. An older marked header is replaced once without changing user code outside the marker. This preserves the cursor, selection, undo history, and native editor responsiveness.

`Fragua.type` and `Fragua.typeof` capture and delegate to Roblox's original functions. For a Fragua wrapper they return `"userdata"` and `"Instance"`, respectively. All other values retain Roblox behavior. `Fragua.GetTypeId(value)` is the supported way to retrieve a custom ID such as `"Zombie"`.

These aliases shadow globals only inside managed scripts. Fragua does not mutate Roblox's process-wide environment.

## `Instance` constructor surface

`Fragua.Instance` is a forwarding facade over Roblox's original `Instance` datatype. It explicitly implements:

- `Instance.new(classOrType, parent?)`
- `Instance.fromExisting(existing)`

Unknown static members are read live from Roblox's original `Instance` value. This lets future compatible static additions work at runtime without Fragua copying a fixed list. Known constructors have explicit generated typings and autocomplete documentation.

For a normal Roblox class, `Instance.new` and `Instance.fromExisting` return the genuine Roblox object. For a Fragua type, they return a Fragua wrapper around a genuine backing Roblox object. The backing class is the resolved engine ancestor of the Fragua inheritance chain. For example, a type extending `SpawnLocation` is backed by a `SpawnLocation`; a type extending another Fragua type ultimately backed by `Part` is backed by a `Part`.

Newly inserted instances use the resolved backing class. Existing legacy instances whose backing class does not match the resolved engine ancestor are not silently replaced, because replacement can invalidate references. The Properties dock identifies the mismatch and offers an explicit upgrade/recreate action with ChangeHistoryService support.

`Instance.fromExisting` delegates to Roblox for ordinary instances. For a Fragua wrapper or tagged Fragua backing object it uses Roblox's `fromExisting` constructor, retains the custom type ID and custom values, reconnects Fragua behavior by type, and returns a fresh wrapper. Like Roblox's constructor, it does not copy descendants.

## Fragua wrapper

The wrapper is a Luau table with a protected metatable and a stable reference to its backing object through `.Instance`.

Read precedence is:

1. Fragua core members such as `Instance`, `TypeId`, `Destroy`, `Clone`, and `IsA`;
2. custom methods valid for the current runtime context;
3. resolved custom properties;
4. properties and methods on the backing Roblox object.

Write precedence is custom property, then writable backing property. Reserved Fragua names and every inherited Roblox property or method name are rejected during type validation, so a custom member cannot silently shadow native behavior.

Native methods returned through `__index` are bound to the backing object and cached. Consequently `zombie:FindFirstChild()`, `zombie:Destroy()`, and other colon calls receive the genuine Roblox instance as `self`. Core methods receive explicit implementations where Fragua must preserve wrapper semantics:

- `Destroy()` disconnects Fragua runtime state, destroys the backing instance, and invalidates the wrapper.
- `Clone()` follows Roblox's `Archivable` behavior; on success it preserves the Fragua type, descendants, and custom values, then returns a wrapper.
- `IsA(name)` returns true for the Fragua type and its Fragua ancestors, otherwise delegates to the backing object.

Fragua APIs, forwarded native property writes, and forwarded native method arguments unwrap Fragua wrappers automatically. External Roblox APIs called directly with a wrapper receive `value.Instance`; a table cannot be made genuine userdata, so this is the one deliberate interop boundary.

Wrappers are cached weakly by facade and backing instance so repeated `Fragua.Get(backing)` calls through the same facade return the same live wrapper without leaking Server methods into Core or Client wrappers. Access after destruction produces a concise Fragua error rather than an unrelated nil-index failure.

## Split behavior model

Every type owns three separate behavior templates:

- **Edit Behavior** runs only through the plugin while Studio is in edit mode. It contains editor hooks such as `onCreated`, `onSelected`, `onPropertyChanged`, and `onAncestryChanged`.
- **Server Behavior** runs only through the server runtime during play. Its lifecycle is `onStart` and `onStop`, plus user-defined server methods.
- **Client Behavior** runs only through a managed client runtime during play. Its lifecycle is `onStart` and `onStop`, plus user-defined client methods. It contains no edit-mode hooks and is never loaded by the plugin host.

Edit and server templates remain under `ServerStorage.Fragua.Types`. Only the client template and non-sensitive type metadata are mirrored into the managed replicated catalogue. A generated `LocalScript` host starts and stops client behaviors for tagged instances as they replicate. The existing server host performs the equivalent work using the server templates.

Runtime hosts resolve behavior from the shared type template rather than copying source-bearing ModuleScripts into every placed instance. This prevents duplicate behavior modules and makes a type edit authoritative. Legacy per-instance behavior children are migrated or ignored after their source is preserved in the existing backup policy.

Hooks are called at most once per host lifecycle. Loading failures are isolated per instance and reported with the type ID, behavior side, hook, and backing instance path. One broken behavior cannot stop other Fragua instances.

## Custom method dispatch

Any non-reserved function exported from Server or Client Behavior is a callable custom method for that side. A call such as `zombie:Attack(target)` dispatches to `Behavior.Attack(backingInstance, target)`. Lifecycle hooks are reserved and do not appear as ordinary instance methods.

Server code cannot dispatch client-only methods, and client code cannot dispatch server-only methods. An invalid side produces an explanatory Fragua error. ModuleScripts that can run on either side receive only context-neutral core suggestions unless the author explicitly selects `Fragua.Server` or `Fragua.Client`.

Behavior method discovery uses a conservative parser for exported function declarations and their Luau annotations. Unsupported dynamic table construction still runs at runtime but is not promised typed autocomplete. Invalid or duplicate signatures are surfaced in the type UI without modifying behavior source.

## Generated typing and native autocomplete

The managed `ReplicatedStorage.Fragua` gateway includes generated exported Luau types for the current catalogue. A custom type combines:

- its resolved Roblox backing type;
- properties inherited through the Fragua type chain;
- properties declared by the type;
- methods exposed by the selected server or client facade.

The `Instance.new` facade receives literal overloads for string IDs and `Enum.FraguaType` items. `Instance.fromExisting`, `Clone`, and `Fragua.Get` preserve the most specific type where the analyzer can infer it.

Fragua registers a lightweight `ScriptEditorService` autocomplete callback to supplement, not replace, Roblox's analyzer. Suggestions include custom type IDs, inherited and declared properties, method signatures, parameter hints, descriptions, enum items, and relevant Fragua helpers. The callback inspects the edited script:

- `Script` receives the server facade and server methods;
- `LocalScript` receives the client facade and client methods;
- a ModuleScript in a server-only container receives server suggestions;
- a replicated or ambiguous ModuleScript receives core members and lets the author explicitly choose a facade.

Generated catalogue and gateway files may update when a type or behavior changes. Fragua never rewrites the user's active script merely to refresh suggestions, so typing and cursor position remain stable. Autocomplete work is cached by catalogue revision and avoids reparsing the full project on each keystroke.

## Property definitions and defaults

The custom type editor uses a control selected by `valueType`, instead of representing every default with an oversized text box:

- `boolean`: animated on/off toggle;
- `enum`: enum-type dropdown followed by an enum-item dropdown;
- `number` and `integer`: validated numeric field with optional minimum, maximum, step, and slider metadata;
- `string`: single-line field with an explicit multiline option;
- `Color3` and `BrickColor`: live color preview and picker;
- `Vector2` and `Vector3`: compact labeled component fields;
- `UDim` and `UDim2`: scale and offset component fields;
- `CFrame`: position and rotation component fields;
- `Instance`: Studio object picker backed by an `ObjectValue`;
- Fragua type reference: object picker restricted to the chosen custom type.

Changing the selected value type replaces only the default editor within that property row. It does not rebuild the dialog, move sections, change scroll position, or resize the property template. Newly added sections remain at the top of the editable section list.

The editor stores defaults in their real Roblox value type where attributes support them. Enum and reference metadata use an explicit serialized representation and are restored by the wrapper. Validation occurs before save and reports errors next to the affected field. Inherited properties retain their declared type metadata and therefore receive the same appropriate control.

Dropdowns use the current Roblox enum catalogue plus Fragua additions. Boolean defaults use the same animated toggle language as the Properties dock. Color changes preview continuously while the picker is open.

## Data and migration

Type definitions gain versioned metadata for value constraints, enum type, reference type, and the three behavior template names. Decoding remains tolerant of the current schema: an existing single behavior becomes Edit Behavior, while its `onStart` and `onStop` hooks are copied into Server Behavior during a one-time canonical migration. The original source is retained in the behavior backup folder.

Client Behavior starts empty except for its runtime lifecycle skeleton; edit hooks are never copied into it. Duplicate legacy templates are canonicalized before the split so the migration cannot recreate the earlier duplicate-behavior regression.

Placed-instance custom values survive schema and behavior migrations. Missing defaults are added without resetting values that users already changed.

## Safety and error handling

- Roblox globals are captured before Fragua aliases are created, preventing recursion.
- Wrapper caches are weak and runtime connections are disconnected on stop or destruction.
- Client code cannot read edit or server behavior source from Fragua-managed replication.
- Custom names that collide with Roblox or Fragua core members are rejected before save.
- Header injection remains idempotent and does not repeatedly edit open scripts.
- Autocomplete failures fall back to Roblox's native results.
- Managed runtime updates do not print a plugin-loaded message.
- All plugin-owned changes use ChangeHistoryService waypoints where Studio undo is meaningful.
- The unrelated untracked `.superpowers/` directory remains untouched and unstaged.

## Acceptance tests

Tests cover:

- forwarding `new`, `fromExisting`, and unknown future-style static members;
- genuine Roblox return values for native classes and wrappers for Fragua classes;
- native method binding, custom method dispatch, reserved-name validation, wrapper caching, destruction, cloning, and invalidation;
- compatible `type` and `typeof` results and native delegation for non-wrapper values;
- Roblox and Fragua `IsA` inheritance through multiple custom levels;
- edit/server/client lifecycle isolation and method visibility;
- no edit hooks in generated Client Behavior;
- canonical migration from one behavior without duplicate templates;
- generated overloads and inherited type members;
- server, client, and ambiguous ModuleScript autocomplete filtering;
- idempotent header upgrades that preserve all user source outside the marker;
- boolean, enum, numeric, color, vector, dimension, CFrame, instance-reference, and custom-reference default editors;
- control replacement without dialog growth, section reordering, or scroll resets;
- preservation of existing placed-instance values across schema edits;
- backing-class resolution for direct engine inheritance and multi-level Fragua inheritance.

Final verification runs StyLua, Selene, the full Lune suite, `git diff --check`, and a Rojo build. The verified plugin artifact is copied to the Roblox Plugins directory only after the implementation passes the full suite.
