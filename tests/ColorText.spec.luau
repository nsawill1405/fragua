local ColorText = require("../src/App/Shared/ColorText")

return {
	["formats normalized channels as hexadecimal"] = function()
		assert(ColorText.format(1, 128 / 255, 0) == "#FF8000")
	end,
	["parses hexadecimal and rgb input"] = function()
		local r, g, b = ColorText.parse("#3366CC")
		assert(r == 0x33 / 255 and g == 0x66 / 255 and b == 0xCC / 255)
		local rr, gg, bb = ColorText.parse("255, 128, 0")
		assert(rr == 1 and gg == 128 / 255 and bb == 0)
	end,
	["rejects incomplete colors"] = function()
		assert(ColorText.parse("#1234") == nil)
	end,
}
