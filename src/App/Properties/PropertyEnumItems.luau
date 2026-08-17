-- resolves dropdown items for a properties row.
-- custom type attributes use enumType, not a native EnumItem.

export type EnumProp = {
	valueType: string?,
	enumType: string?,
	enumItems: { string }?,
}

local PropertyEnumItems = {}

function PropertyEnumItems.needsResolve(prop: EnumProp, value: any): boolean
	if prop.valueType == "enum" then
		return true
	end
	if typeof(value) == "EnumItem" then
		return true
	end
	return false
end

function PropertyEnumItems.forRow(
	prop: EnumProp,
	value: any,
	resolve: ((EnumProp, any) -> { string }?)?
): { string }?
	if PropertyEnumItems.needsResolve(prop, value) and resolve then
		local items = resolve(prop, value)
		if items and #items > 0 then
			return items
		end
	end
	if prop.enumItems and #prop.enumItems > 0 then
		return prop.enumItems
	end
	return nil
end

return PropertyEnumItems
