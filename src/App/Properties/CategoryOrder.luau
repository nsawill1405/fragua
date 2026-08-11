local CategoryOrder = {}

local ENGINE_ORDER = {
	"Behavior",
	"Appearance",
	"Transform",
	"Part",
	"Physics",
	"Health",
	"Control",
	"Display",
	"Text",
	"Audio",
	"Camera",
	"World",
	"Streaming",
	"Celestial",
	"Fog",
}

function CategoryOrder.sort(categories: { string }, directCategories: { string }?): { string }
	local directRank = {}
	for index, name in directCategories or {} do
		if name ~= "Data" and name ~= "Tags" and name ~= "Attributes" and directRank[name] == nil then
			directRank[name] = index
		end
	end
	local engineRank = {}
	for index, name in ENGINE_ORDER do
		engineRank[name] = index
	end
	local function priority(name: string): (number, number)
		if name == "Data" then
			return 0, 0
		elseif directRank[name] then
			return 1, directRank[name]
		elseif engineRank[name] then
			return 2, engineRank[name]
		elseif name == "Tags" then
			return 4, 0
		elseif name == "Attributes" then
			return 5, 0
		end
		return 3, 0
	end
	table.sort(categories, function(a, b)
		local aTier, aRank = priority(a)
		local bTier, bRank = priority(b)
		if aTier == bTier and aRank == bRank then
			return a < b
		end
		return aTier < bTier or (aTier == bTier and aRank < bRank)
	end)
	return categories
end

return CategoryOrder
