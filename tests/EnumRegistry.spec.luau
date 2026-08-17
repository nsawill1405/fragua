local EnumRegistry = require("../src/App/Types/EnumRegistry")

return {
	["encodes and decodes enum definitions"] = function()
		local encoded = EnumRegistry.encode({
			id = "Mood",
			name = "Mood",
			items = { "Happy", "Sad", "Neutral" },
		})
		assert(encoded:find('"id"', 1, true))
		assert(encoded:find("Happy", 1, true))
		local decoded = EnumRegistry.decode(encoded)
		assert(decoded and decoded.id == "Mood")
		assert(decoded.name == "Mood")
		assert(#decoded.items == 3 and decoded.items[2] == "Sad")
		local wrapped = EnumRegistry.moduleSource(decoded)
		assert(wrapped:find("Fragua enum definition: Mood", 1, true))
		local fromModule = EnumRegistry.decode(wrapped)
		assert(fromModule and fromModule.items[1] == "Happy")
	end,
	["rejects invalid names reserved collisions and empty items"] = function()
		local reserved = { "Material", "FraguaType", "GetEnums" }
		local badName, nameMessage = EnumRegistry.validate({ id = "1Mood", name = "1Mood", items = { "A" } }, reserved)
		assert(not badName and nameMessage and nameMessage:find("identifier", 1, true))
		local reservedName, reservedMessage =
			EnumRegistry.validate({ id = "Material", name = "Material", items = { "A" } }, reserved)
		assert(not reservedName and reservedMessage and reservedMessage:find("Material", 1, true))
		local fraguaType, fraguaMessage =
			EnumRegistry.validate({ id = "FraguaType", name = "FraguaType", items = { "A" } }, reserved)
		assert(not fraguaType and fraguaMessage)
		local empty, emptyMessage = EnumRegistry.validate({ id = "Mood", name = "Mood", items = {} }, reserved)
		assert(not empty and emptyMessage and emptyMessage:find("item", 1, true))
		local badItem, itemMessage =
			EnumRegistry.validate({ id = "Mood", name = "Mood", items = { "Happy", "so-sad" } }, reserved)
		assert(not badItem and itemMessage)
		local dup, dupMessage =
			EnumRegistry.validate({ id = "Mood", name = "Mood", items = { "Happy", "Happy" } }, reserved)
		assert(not dup and dupMessage)
		local ok = EnumRegistry.validate({ id = "Mood", name = "Mood", items = { "Happy", "Sad" } }, reserved)
		assert(ok)
	end,
	["finds types that still use an enum"] = function()
		local types = {
			{
				id = "Zombie",
				properties = {
					{ name = "Mood", valueType = "enum", enumType = "Mood" },
					{ name = "Health", valueType = "number" },
				},
			},
			{
				id = "Ghost",
				properties = { { name = "Kind", valueType = "enum", enumType = "FraguaType" } },
			},
		}
		local using = EnumRegistry.typesUsing(types, "Mood")
		assert(#using == 1 and using[1] == "Zombie")
		assert(#EnumRegistry.typesUsing(types, "Unused") == 0)
	end,
	["reserved names include FraguaType and GetEnums"] = function()
		assert(EnumRegistry.isReservedName("FraguaType", { "Material" }))
		assert(EnumRegistry.isReservedName("GetEnums", {}))
		assert(EnumRegistry.isReservedName("Material", { "Material" }))
		assert(not EnumRegistry.isReservedName("Mood", { "Material" }))
	end,
}
