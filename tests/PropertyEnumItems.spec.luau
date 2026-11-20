local PropertyEnumItems = require("../src/App/Properties/PropertyEnumItems")

return {
	["attribute enums resolve through enumType not the current value"] = function()
		local items = PropertyEnumItems.forRow(
			{
				valueType = "enum",
				enumType = "StickerKind",
			},
			"Bouncy",
			function(prop)
				assert(prop.enumType == "StickerKind")
				return { "Bouncy", "Heavy", "Floaty", "Fast" }
			end
		)
		assert(items)
		assert(#items == 4)
		assert(items[1] == "Bouncy" and items[2] == "Heavy")
		assert(items[4] == "Fast")
	end,
	["native EnumItem rows still resolve"] = function()
		local fake = {
			Name = "Plastic",
		}
		-- typeof is not EnumItem in lune; valueType enum still forces resolve
		local items = PropertyEnumItems.forRow(
			{
				valueType = "enum",
				enumType = "Material",
			},
			fake,
			function()
				return { "Plastic", "Neon", "Wood" }
			end
		)
		assert(items and #items == 3 and items[2] == "Neon")
	end,
	["inline enumItems are kept when resolver is missing"] = function()
		local items = PropertyEnumItems.forRow({
			valueType = "enum",
			enumItems = { "A", "B" },
		}, "A", nil)
		assert(items and items[1] == "A" and items[2] == "B")
	end,
	["non-enum rows do not invent a single-value list"] = function()
		local items = PropertyEnumItems.forRow(
			{
				valueType = "string",
			},
			"Bouncy",
			function()
				return { "should-not-run" }
			end
		)
		assert(items == nil)
	end,
	["empty resolver result falls back to inline items"] = function()
		local items = PropertyEnumItems.forRow(
			{
				valueType = "enum",
				enumItems = { "Keep", "These" },
			},
			"Keep",
			function()
				return {}
			end
		)
		assert(items and items[1] == "Keep" and items[2] == "These")
	end,
}
