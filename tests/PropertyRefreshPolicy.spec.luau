local ok, PropertyRefreshPolicy = pcall(function()
	return require("../src/App/Properties/PropertyRefreshPolicy")
end)

return {
	["ordinary engine property changes update controls in place"] = function()
		assert(ok and PropertyRefreshPolicy, "PropertyRefreshPolicy should be available")
		assert(PropertyRefreshPolicy.action("property", "Transparency") == "update")
		assert(PropertyRefreshPolicy.action("property", "Anchored") == "update")
	end,
	["ordinary custom attributes update controls in place"] = function()
		assert(ok and PropertyRefreshPolicy, "PropertyRefreshPolicy should be available")
		assert(PropertyRefreshPolicy.action("attribute", "Health") == "update")
	end,
	["type identity changes rebuild the schema"] = function()
		assert(ok and PropertyRefreshPolicy, "PropertyRefreshPolicy should be available")
		assert(PropertyRefreshPolicy.action("attribute", "_FraguaType") == "rebuild")
	end,
}
