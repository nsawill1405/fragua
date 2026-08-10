local LifecycleGate = {}
LifecycleGate.__index = LifecycleGate

function LifecycleGate.new()
	return setmetatable({ generation = 0 }, LifecycleGate)
end

function LifecycleGate:advance(): number
	self.generation += 1
	return self.generation
end

function LifecycleGate:isCurrent(token: number): boolean
	return token == self.generation
end

return LifecycleGate
