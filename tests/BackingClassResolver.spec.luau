local Resolver = require("../src/App/Types/BackingClassResolver")

local function lookup(types)
	return function(typeId)
		return types[typeId]
	end
end

return {
	["resolves a direct custom engine ancestor"] = function()
		local className, err = Resolver.resolve(
			"Zombie",
			lookup({
				Zombie = { id = "Zombie", extends = "SpawnLocation" },
			})
		)
		assert(className == "SpawnLocation" and err == nil)
	end,
	["resolves through multiple custom ancestors"] = function()
		local className, err = Resolver.resolve(
			"Boss",
			lookup({
				Boss = { id = "Boss", extends = "Zombie" },
				Zombie = { id = "Zombie", extends = "SpawnLocation" },
			})
		)
		assert(className == "SpawnLocation" and err == nil)
	end,
	["reports custom inheritance cycles"] = function()
		local className, err = Resolver.resolve(
			"Boss",
			lookup({
				Boss = { id = "Boss", extends = "Zombie" },
				Zombie = { id = "Zombie", extends = "Boss" },
			})
		)
		assert(className == nil)
		assert(err and string.find(err, "cycle", 1, true))
	end,
}
