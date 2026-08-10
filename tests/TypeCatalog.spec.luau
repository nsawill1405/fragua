local ok, TypeCatalog = pcall(function()
	return require("../src/App/Runtime/TypeCatalog")
end)

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
}
