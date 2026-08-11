local ok, TypeCatalog = pcall(function()
	return require("../src/App/Runtime/TypeCatalog")
end)
local fs = require("@lune/fs")

return {
	["snapshot contains resolved inherited defaults"] = function()
		assert(ok and TypeCatalog, "TypeCatalog should be available")
		local rows = TypeCatalog.snapshot({ { id = "FastZombie", name = "Fast Zombie" } }, function()
			return { { name = "Health", default = 100 }, { name = "WalkSpeed", default = 24 } }
		end)
		assert(rows[1].id == "FastZombie")
		assert(rows[1].name == "Fast Zombie")
		assert(rows[1].properties[2].default == 24)
	end,
	["snapshot clones property records"] = function()
		assert(ok and TypeCatalog, "TypeCatalog should be available")
		local property = { name = "Health", default = 100 }
		local rows = TypeCatalog.snapshot({ { id = "Zombie", name = "Zombie" } }, function()
			return { property }
		end)
		property.default = 0
		assert(rows[1].properties[1].default == 100)
	end,
	["catalog snapshot exposes backing and ordered Fragua ancestry metadata"] = function()
		assert(ok and TypeCatalog, "TypeCatalog should be available")
		local definitions = {
			{ id = "Enemy", name = "Enemy", extends = "Part" },
			{ id = "Zombie", name = "Zombie", extends = "Enemy" },
		}
		local rows = TypeCatalog.snapshot(definitions, function()
			return {}
		end, function()
			return "Part"
		end)
		assert(rows[2].backingClass == "Part")
		assert(#rows[2].ancestors == 1 and rows[2].ancestors[1] == "Enemy")
	end,
	["runtime catalog does not call the removed unsided behavior API"] = function()
		local source = fs.readFile("src/App/Runtime/TypeCatalog.luau")
		assert(
			not source:find("registry.getSharedBehavior", 1, true),
			"TypeCatalog.sync must not call removed Registry.getSharedBehavior"
		)
	end,
	["catalog source mirrors only the canonical client behavior"] = function()
		local source = fs.readFile("src/App/Runtime/TypeCatalog.luau")
		assert(source:find('ensureBehaviorTemplate(entry.id, "Client")', 1, true))
		assert(not source:find('ensureBehaviorTemplate(entry.id, "Edit")', 1, true))
		assert(not source:find('ensureBehaviorTemplate(entry.id, "Server")', 1, true))
	end,
	["native collision metadata covers known concrete abstract and service classes"] = function()
		assert(ok and TypeCatalog, "TypeCatalog should be available")
		local names = TypeCatalog.nativeClassNames()
		for _, expected in { "Instance", "Part", "BasePart", "GuiObject", "Workspace", "ServerStorage" } do
			assert(table.find(names, expected), `missing native class metadata for {expected}`)
		end
		for index = 2, #names do
			assert(names[index - 1] < names[index], "native class metadata should be sorted and unique")
		end
	end,
}
