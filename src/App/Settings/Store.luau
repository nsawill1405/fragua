-- Plugin settings persistence for Fragua.
local HttpService = game:GetService("HttpService")

local DEFAULT_SERVICES = {
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
}

local Store = {}

local pluginRef: Plugin? = nil
local cache: { [string]: any } = {}
local changed = Instance.new("BindableEvent")
Store.Changed = changed.Event

function Store.bind(plugin: Plugin)
	pluginRef = plugin
	table.clear(cache)
end

local function getRaw(key: string, default: any): any
	if cache[key] ~= nil then
		return cache[key]
	end
	if not pluginRef then
		return default
	end
	local ok, value = pcall(function()
		return pluginRef:GetSetting(key)
	end)
	if ok and value ~= nil then
		cache[key] = value
		return value
	end
	return default
end

local function setRaw(key: string, value: any)
	cache[key] = value
	if pluginRef then
		pcall(function()
			pluginRef:SetSetting(key, value)
		end)
	end
	changed:Fire(key, value)
end

function Store.getConfirmOnDelete(): boolean
	local v = getRaw("confirmOnDelete", true)
	return v ~= false
end

function Store.setConfirmOnDelete(value: boolean)
	setRaw("confirmOnDelete", value)
end

function Store.getMatchHighlight(): boolean
	local v = getRaw("matchHighlight", true)
	return v ~= false
end

function Store.setMatchHighlight(value: boolean)
	setRaw("matchHighlight", value)
end

function Store.getAnimations(): boolean
	local value = getRaw("animations", true)
	return value ~= false
end

function Store.setAnimations(value: boolean)
	setRaw("animations", value)
end

function Store.getVisibleServices(): { string }
	local v = getRaw("visibleServices", nil)
	if typeof(v) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(v)
		end)
		if ok and typeof(decoded) == "table" then
			return decoded
		end
	elseif typeof(v) == "table" then
		return v
	end
	return table.clone(DEFAULT_SERVICES)
end

function Store.setVisibleServices(list: { string })
	setRaw("visibleServices", HttpService:JSONEncode(list))
end

function Store.getSectionColors(): { [string]: { number } }
	local v = getRaw("sectionColors", nil)
	if typeof(v) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(v)
		end)
		if ok and typeof(decoded) == "table" then
			return decoded
		end
	end
	return {}
end

function Store.setSectionColor(name: string, color: Color3)
	local map = Store.getSectionColors()
	map[name] = { color.R, color.G, color.B }
	setRaw("sectionColors", HttpService:JSONEncode(map))
end

function Store.colorForSection(name: string, fallback: Color3): Color3
	local map = Store.getSectionColors()
	local rgb = map[name]
	if typeof(rgb) == "table" and rgb[1] and rgb[2] and rgb[3] then
		return Color3.new(rgb[1], rgb[2], rgb[3])
	end
	return fallback
end

function Store.defaultServices(): { string }
	return table.clone(DEFAULT_SERVICES)
end

return Store
