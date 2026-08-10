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
}
