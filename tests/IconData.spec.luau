local IconData = require("../src/App/Types/IconData")

return {
	["catalog has broad unique categorized coverage"] = function()
		local icons = IconData.list()
		assert(#icons >= 160, `expected at least 160 icons, got {#icons}`)
		local seen = {}
		local categories = {}
		for _, icon in icons do
			assert(not seen[icon.id], `duplicate icon id {icon.id}`)
			seen[icon.id] = true
			categories[icon.category] = true
			assert(not icon.fallback:find("[^%w%p%s]"), `non-ASCII fallback for {icon.id}`)
		end
		for _, category in { "World", "Characters", "UI", "Effects", "Audio", "Networking", "Values", "Services" } do
			assert(categories[category], `missing category {category}`)
		end
	end,
}
