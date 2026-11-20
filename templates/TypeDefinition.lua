-- Example Fragua type definition payload (stored as ModuleScript source by the plugin).
-- Shape mirrors what Registry.save encodes to JSON.

return {
	id = "Zombie",
	name = "Zombie",
	description = "Humanoid-like custom NPC type with a Studio nameplate.",
	extends = "Humanoid",
	icon = "emoji_zombie",
	properties = {
		{ name = "IsHostile", valueType = "boolean", default = true, category = "AI" },
		{ name = "DetectRange", valueType = "number", default = 40, category = "AI" },
		{ name = "AttackDamage", valueType = "number", default = 15, category = "AI" },
	},
}
