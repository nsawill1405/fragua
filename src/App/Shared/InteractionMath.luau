local InteractionMath = {}

function InteractionMath.toLocal(originX: number, originY: number, sampleX: number, sampleY: number): (number, number)
	return sampleX - originX, sampleY - originY
end

function InteractionMath.clampAlpha(localValue: number, extent: number): number
	if extent <= 0 then
		return 0
	end
	return math.clamp(localValue / extent, 0, 1)
end

function InteractionMath.valueFromLocal(localValue: number, extent: number, minValue: number, maxValue: number): number
	return minValue + InteractionMath.clampAlpha(localValue, extent) * (maxValue - minValue)
end

function InteractionMath.crossedThreshold(
	startX: number,
	startY: number,
	currentX: number,
	currentY: number,
	threshold: number
): boolean
	local dx = currentX - startX
	local dy = currentY - startY
	return dx * dx + dy * dy >= threshold * threshold
end

return InteractionMath
