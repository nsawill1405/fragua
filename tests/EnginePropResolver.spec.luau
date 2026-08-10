local Resolver = require("../src/App/Properties/EnginePropResolver")

return {
	["SpawnLocation receives BasePart and exact rows"] = function()
		local rows = Resolver.resolve("SpawnLocation", function(name)
			return name == "BasePart"
		end, {
			Instance = { { name = "Name" } },
			SpawnLocation = { { name = "Enabled" } },
		}, {
			{ className = "BasePart", properties = { { name = "Transparency" } } },
		})
		local found = {}
		for _, row in rows do
			found[row.name] = true
		end
		assert(found.Name and found.Transparency and found.Enabled)
	end,
	["exact rows override family rows without duplicates"] = function()
		local rows = Resolver.resolve("SpawnLocation", function()
			return true
		end, {
			Instance = {},
			SpawnLocation = { { name = "Color", category = "Spawn" } },
		}, {
			{ className = "BasePart", properties = { { name = "Color", category = "Appearance" } } },
		})
		assert(#rows == 1 and rows[1].category == "Spawn")
	end,
	["baseline probe rows are retained for curated subclasses"] = function()
		local rows = Resolver.resolve("TextButton", function(name)
			return name == "GuiObject"
		end, {
			Instance = { { name = "Archivable", category = "Data" } },
			TextButton = { { name = "Text", category = "Text" } },
		}, {
			{ className = "GuiObject", properties = { { name = "Visible", category = "Data" } } },
		}, {
			{ name = "BackgroundTransparency", category = "Appearance" },
		})
		local found = {}
		for _, row in rows do
			found[row.name] = true
		end
		assert(found.Archivable and found.BackgroundTransparency and found.Visible and found.Text)
	end,
}
