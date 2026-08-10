local ColorText = {}

local function byte(channel: number): number
	return math.floor(math.clamp(channel, 0, 1) * 255 + 0.5)
end

function ColorText.format(r: number, g: number, b: number): string
	return string.format("#%02X%02X%02X", byte(r), byte(g), byte(b))
end

function ColorText.parse(text: string): (number?, number?, number?)
	local hex = text:match("^%s*#?([%x][%x][%x][%x][%x][%x])%s*$")
	if hex then
		return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
	end
	local r, g, b = text:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
	if r then
		return math.clamp(tonumber(r), 0, 255) / 255,
			math.clamp(tonumber(g), 0, 255) / 255,
			math.clamp(tonumber(b), 0, 255) / 255
	end
	return nil, nil, nil
end

return ColorText
