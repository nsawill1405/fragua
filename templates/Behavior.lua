-- Reference shape for a type's Edit behavior ModuleScript.
-- Fragua creates <Type>EditBehavior under ServerStorage.Fragua.Types.<Type> and runs these hooks in Studio edit mode.
-- Server / Client behaviors use onStart / onStop plus any methods you declare on that side.

local Behavior = {}

function Behavior.onCreated(instance: Instance)
	-- Runs when the instance is created or loaded in Studio edit mode.
end

function Behavior.onSelected(instance: Instance) end

function Behavior.onPropertyChanged(instance: Instance, key: string, value: any) end

function Behavior.onAncestryChanged(instance: Instance) end

return Behavior
