-- Example Fragua type definition payload (stored as ModuleScript source by the plugin).
-- Shape mirrors what Registry.save encodes to JSON.

return {
	id = "Zombie",
	name = "Zombie",
	description = "Humanoid-like custom NPC type with a Studio nameplate.",
	extends = "Humanoid",
	icon = "emoji_zombie",
	properties = {
		{ name = "DisplayName", valueType = "string", default = "Zombie", category = "Display" },
		{ name = "WalkSpeed", valueType = "number", default = 12, category = "Control" },
		{ name = "MaxHealth", valueType = "number", default = 150, category = "Health" },
		{ name = "IsHostile", valueType = "boolean", default = true, category = "AI" },
		{ name = "DetectRange", valueType = "number", default = 40, category = "AI" },
	},
}
