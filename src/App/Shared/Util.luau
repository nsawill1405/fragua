local Util = {}

function Util.clearChildren(parent: Instance, keep: { [string]: boolean }?)
	for _, child in parent:GetChildren() do
		if not keep or not keep[child.Name] then
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

function Util.debounce(seconds: number, fn: (...any) -> ())
	local token = 0
	return function(...)
		token += 1
		local current = token
		local args = table.pack(...)
		task.delay(seconds, function()
			if current == token then
				fn(table.unpack(args, 1, args.n))
			end
		end)
	end
end

function Util.safePcall(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[Fragua] {label}: {err}`)
	end
	return ok
end

function Util.attributeTypeName(value: any): string
	local t = typeof(value)
	if
		t == "number"
		or t == "string"
		or t == "boolean"
		or t == "Color3"
		or t == "Vector3"
		or t == "Vector2"
		or t == "UDim2"
		or t == "CFrame"
		or t == "BrickColor"
	then
		return t
	end
	return "string"
end

function Util.parseValue(valueType: string, text: string): (boolean, any)
	if valueType == "string" or valueType == "enum" then
		return true, text
	elseif valueType == "number" or valueType == "integer" then
		local n = tonumber(text)
		if n == nil or (valueType == "integer" and n % 1 ~= 0) then
			return false, nil
		end
		return true, n
	elseif valueType == "boolean" then
		local lower = string.lower(text)
		if lower == "true" or lower == "1" then
			return true, true
		elseif lower == "false" or lower == "0" then
			return true, false
		end
		return false, nil
	elseif valueType == "Color3" then
		local r, g, b = string.match(text, "^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*$")
		if not r then
			return false, nil
		end
		local rn, gn, bn = tonumber(r), tonumber(g), tonumber(b)
		if not rn or not gn or not bn then
			return false, nil
		end
		if rn > 1 or gn > 1 or bn > 1 then
			return true, Color3.fromRGB(rn, gn, bn)
		end
		return true, Color3.new(rn, gn, bn)
	elseif valueType == "Vector2" then
		local x, y = string.match(text, "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
		if not x then
			return false, nil
		end
		return true, Vector2.new(tonumber(x), tonumber(y))
	elseif valueType == "Vector3" then
		local x, y, z = string.match(text, "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
		if not x then
			return false, nil
		end
		return true, Vector3.new(tonumber(x), tonumber(y), tonumber(z))
	elseif valueType == "BrickColor" then
		local ok, value = pcall(BrickColor.new, text)
		return ok, if ok then value else nil
	elseif valueType == "UDim" then
		local scale, offset = string.match(text, "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
		if not scale then
			return false, nil
		end
		return true, UDim.new(tonumber(scale), tonumber(offset))
	elseif valueType == "UDim2" then
		local xScale, xOffset, yScale, yOffset =
			string.match(text, "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
		if not xScale then
			return false, nil
		end
		return true, UDim2.new(tonumber(xScale), tonumber(xOffset), tonumber(yScale), tonumber(yOffset))
	elseif valueType == "CFrame" then
		local components = {}
		for component in string.gmatch(text, "[^,%s]+") do
			local number = tonumber(component)
			if not number then
				return false, nil
			end
			table.insert(components, number)
		end
		if #components ~= 12 then
			return false, nil
		end
		return true, CFrame.new(table.unpack(components))
	elseif valueType == "Instance" or valueType == "FraguaInstance" then
		return text == "", nil
	end
	return false, nil
end

function Util.formatValue(value: any): string
	local t = typeof(value)
	if t == "Color3" then
		return string.format(
			"%d, %d, %d",
			math.floor(value.R * 255 + 0.5),
			math.floor(value.G * 255 + 0.5),
			math.floor(value.B * 255 + 0.5)
		)
	elseif t == "Vector3" then
		return string.format("%.3g, %.3g, %.3g", value.X, value.Y, value.Z)
	elseif t == "Vector2" then
		return string.format("%.3g, %.3g", value.X, value.Y)
	elseif t == "boolean" then
		return if value then "true" else "false"
	elseif t == "BrickColor" then
		return value.Name
	elseif t == "UDim" then
		return string.format("%.3g, %d", value.Scale, value.Offset)
	elseif t == "UDim2" then
		return string.format("%.3g, %d, %.3g, %d", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	elseif t == "CFrame" then
		local components = { value:GetComponents() }
		for index, component in components do
			components[index] = string.format("%.6g", component)
		end
		return table.concat(components, ", ")
	elseif value == nil then
		return ""
	end
	return tostring(value)
end

return Util
