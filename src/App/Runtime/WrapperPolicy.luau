local WrapperPolicy = {}

WrapperPolicy.readOrder = table.freeze({ "core", "behavior", "schema", "native" })

local WRAPPER_MEMBERS = {
	Instance = true,
	TypeId = true,
	Destroy = true,
	Clone = true,
	IsA = true,
}

local CORE_MEMBERS = {
	Name = true,
	Archivable = true,
	GetTypeId = true,
	GetProperty = true,
	SetProperty = true,
	Get = true,
	GetInstances = true,
	Enum = true,
	type = true,
	typeof = true,
}
for name in WRAPPER_MEMBERS do
	CORE_MEMBERS[name] = true
end

local LIFECYCLE_MEMBERS = {
	onCreated = true,
	onSelected = true,
	onPropertyChanged = true,
	onAncestryChanged = true,
	onStart = true,
	onStop = true,
}

local NATIVE_INSTANCE_MEMBERS = {
	Parent = true,
	AncestryChanged = true,
	AttributeChanged = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	Destroying = true,
	AddTag = true,
	ClearAllChildren = true,
	FindFirstAncestor = true,
	FindFirstAncestorOfClass = true,
	FindFirstAncestorWhichIsA = true,
	FindFirstChild = true,
	FindFirstChildOfClass = true,
	FindFirstChildWhichIsA = true,
	FindFirstDescendant = true,
	GetActor = true,
	GetAttribute = true,
	GetAttributeChangedSignal = true,
	GetAttributes = true,
	GetChildren = true,
	GetDebugId = true,
	GetDescendants = true,
	GetFullName = true,
	GetPropertyChangedSignal = true,
	GetTags = true,
	HasTag = true,
	IsAncestorOf = true,
	IsDescendantOf = true,
	IsPropertyModified = true,
	RemoveTag = true,
	ResetPropertyToDefault = true,
	SetAttribute = true,
	WaitForChild = true,
}

WrapperPolicy.coreMembers = table.freeze(table.clone(CORE_MEMBERS))
WrapperPolicy.lifecycleMembers = table.freeze(table.clone(LIFECYCLE_MEMBERS))
WrapperPolicy.wrapperMembers = table.freeze(table.clone(WRAPPER_MEMBERS))
WrapperPolicy.nativeInstanceMembers = table.freeze(table.clone(NATIVE_INSTANCE_MEMBERS))

function WrapperPolicy.isReserved(name: string, nativeMembers: { [any]: any }): boolean
	if
		string.sub(name, 1, 7) == "_Fragua"
		or CORE_MEMBERS[name]
		or LIFECYCLE_MEMBERS[name]
		or NATIVE_INSTANCE_MEMBERS[name]
	then
		return true
	end
	return nativeMembers[name] ~= nil or table.find(nativeMembers, name) ~= nil
end

return WrapperPolicy
