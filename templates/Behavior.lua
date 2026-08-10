-- Template edit-time / runtime behavior ModuleScript for a Fragua instance.
-- Copied onto each placed instance as a child named "Behavior".

local Behavior = {}

function Behavior.onCreated(instance)
	-- Runs when the instance is created or loaded in Studio edit mode.
end

function Behavior.onSelected(instance)
end

function Behavior.onPropertyChanged(instance, key, value)
end

function Behavior.onAncestryChanged(instance)
end

return Behavior
