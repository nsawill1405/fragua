local InteractionMath = require("../src/App/Shared/InteractionMath")

return {
	["converts a host sample into control-local coordinates"] = function()
		local x, y = InteractionMath.toLocal(120, 80, 153, 94)
		assert(x == 33 and y == 14)
	end,
	["maps a clamped slider sample across a signed range"] = function()
		assert(InteractionMath.valueFromLocal(25, 100, -1, 1) == -0.5)
		assert(InteractionMath.valueFromLocal(140, 100, -1, 1) == 1)
	end,
	["starts dragging only after the Euclidean threshold"] = function()
		assert(not InteractionMath.crossedThreshold(10, 10, 14, 13, 6))
		assert(InteractionMath.crossedThreshold(10, 10, 17, 10, 6))
	end,
	["keeps zero-width controls at their minimum"] = function()
		assert(InteractionMath.clampAlpha(20, 0) == 0)
	end,
	["clamps a color plane on both axes"] = function()
		local x, y = InteractionMath.toLocal(50, 40, 35, 180)
		assert(InteractionMath.clampAlpha(x, 200) == 0)
		assert(InteractionMath.clampAlpha(y, 100) == 1)
	end,
}
