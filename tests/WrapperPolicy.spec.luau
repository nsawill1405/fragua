local WrapperPolicy = require("../src/App/Runtime/WrapperPolicy")

return {
	["reads core behavior schema and native members in order"] = function()
		assert(table.concat(WrapperPolicy.readOrder, ",") == "core,behavior,schema,native")
	end,
	["core lifecycle and inherited native members are reserved"] = function()
		assert(WrapperPolicy.isReserved("Destroy", {}))
		assert(WrapperPolicy.isReserved("Instance", {}))
		assert(WrapperPolicy.isReserved("onStart", {}))
		assert(WrapperPolicy.isReserved("FindFirstChild", { FindFirstChild = true }))
		assert(not WrapperPolicy.isReserved("Attack", {}))
	end,
	["only wrapper-owned slots block backing property writes"] = function()
		assert(WrapperPolicy.wrapperMembers.Instance)
		assert(WrapperPolicy.wrapperMembers.TypeId)
		assert(not WrapperPolicy.wrapperMembers.Name)
		assert(not WrapperPolicy.wrapperMembers.Archivable)
	end,
}
