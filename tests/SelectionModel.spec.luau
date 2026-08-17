local SelectionModel = require("../src/App/Explorer/SelectionModel")

return {
	["shift range covers every visible row between anchor and click"] = function()
		local order = { "a", "b", "c", "d", "e" }
		local list, anchor = SelectionModel.apply(order, { "b" }, "b", "d", true, false)
		assert(anchor == "b")
		assert(#list == 3 and list[1] == "b" and list[2] == "c" and list[3] == "d")
	end,
	["shift range works backwards"] = function()
		local order = { "a", "b", "c", "d" }
		local list = SelectionModel.apply(order, { "d" }, "d", "a", true, false)
		assert(#list == 4 and list[1] == "a" and list[4] == "d")
	end,
	["shift without an anchor selects only the click"] = function()
		local list, anchor = SelectionModel.apply({ "a", "b" }, {}, nil, "b", true, false)
		assert(#list == 1 and list[1] == "b" and anchor == "b")
	end,
	["mod toggle adds and removes"] = function()
		local added = SelectionModel.toggle({ "a" }, "b")
		assert(#added == 2 and added[2] == "b")
		local removed = SelectionModel.toggle({ "a", "b" }, "a")
		assert(#removed == 1 and removed[1] == "b")
	end,
	["plain click replaces the selection"] = function()
		local list, anchor = SelectionModel.apply({ "a", "b", "c" }, { "a", "b" }, "a", "c", false, false)
		assert(#list == 1 and list[1] == "c" and anchor == "c")
	end,
}
