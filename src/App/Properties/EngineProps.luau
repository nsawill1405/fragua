local EnginePropertyCatalog = require(script.Parent.Parent.Types.EnginePropertyCatalog)

export type EngineProp = EnginePropertyCatalog.EngineProp

local EngineProps = {}

function EngineProps.forInstance(instance: Instance): { EngineProp }
	local rows = EnginePropertyCatalog.resolve(instance.ClassName, function(className)
		return instance:IsA(className)
	end, EnginePropertyCatalog.probeProperties())
	local out = {}
	for _, prop in rows do
		local ok = pcall(function()
			local _ = (instance :: any)[prop.name]
		end)
		if ok then
			table.insert(out, prop)
		end
	end
	return out
end

function EngineProps.get(instance: Instance, name: string): any
	return (instance :: any)[name]
end

function EngineProps.set(instance: Instance, name: string, value: any): boolean
	local ok = pcall(function()
		local current = (instance :: any)[name]
		if typeof(current) == "EnumItem" and typeof(value) == "string" then
			local enumType = current.EnumType
			local item = (enumType :: any)[value]
			if item then
				(instance :: any)[name] = item
				return
			end
		end
		(instance :: any)[name] = value
	end)
	return ok
end

function EngineProps.resolveEnumItems(prop: EngineProp, currentValue: any): { string }?
	if prop.enumItems then
		return prop.enumItems
	end
	if typeof(currentValue) == "EnumItem" then
		local items = {}
		for _, item in currentValue.EnumType:GetEnumItems() do
			table.insert(items, item.Name)
		end
		table.sort(items)
		return items
	end
	if prop.enumType then
		local ok, enumType = pcall(function()
			return (Enum :: any)[prop.enumType]
		end)
		if ok and enumType then
			local items = {}
			for _, item in enumType:GetEnumItems() do
				table.insert(items, item.Name)
			end
			table.sort(items)
			return items
		end
	end
	return nil
end

return EngineProps
