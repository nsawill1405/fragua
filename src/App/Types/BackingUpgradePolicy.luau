local BackingUpgradePolicy = {}

function BackingUpgradePolicy.sourceValue(
	hasAttribute: boolean,
	attributeValue: any,
	hasNativeValue: boolean,
	nativeValue: any
): (any, boolean)
	if hasAttribute then
		return attributeValue, true
	end
	if hasNativeValue then
		return nativeValue, false
	end
	return nil, false
end

return BackingUpgradePolicy
