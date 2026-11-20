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
-- decoded JSON settings, keyed by setting name; cleared whenever the raw value changes
local decoded: { [string]: any } = {}
local changed = Instance.new("BindableEvent")
Store.Changed = changed.Event

function Store.bind(plugin: Plugin)
	pluginRef = plugin
	table.clear(cache)
	table.clear(decoded)
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
	decoded[key] = nil
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

local function decodeJson(key: string): any
	if decoded[key] ~= nil then
		return decoded[key]
	end
	local v = getRaw(key, nil)
	local result = false
	if typeof(v) == "string" then
		local ok, value = pcall(function()
			return HttpService:JSONDecode(v)
		end)
		if ok and typeof(value) == "table" then
			result = value
		end
	elseif typeof(v) == "table" then
		result = v
	end
	decoded[key] = result
	return result
end

function Store.getVisibleServices(): { string }
	local list = decodeJson("visibleServices")
	return if list then table.clone(list) else table.clone(DEFAULT_SERVICES)
end

function Store.setVisibleServices(list: { string })
	setRaw("visibleServices", HttpService:JSONEncode(list))
end

function Store.getSectionColors(): { [string]: { number } }
	local map = decodeJson("sectionColors")
	return if map then table.clone(map) else {}
end

function Store.setSectionColor(name: string, color: Color3)
	local map = Store.getSectionColors()
	map[name] = { color.R, color.G, color.B }
	setRaw("sectionColors", HttpService:JSONEncode(map))
end

function Store.colorForSection(name: string, fallback: Color3): Color3
	local map = decodeJson("sectionColors")
	local rgb = map and map[name]
	if typeof(rgb) == "table" and rgb[1] and rgb[2] and rgb[3] then
		return Color3.new(rgb[1], rgb[2], rgb[3])
	end
	return fallback
end

function Store.defaultServices(): { string }
	return table.clone(DEFAULT_SERVICES)
end

return Store
