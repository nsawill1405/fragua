-- range and toggle selection for explorer rows.

local SelectionModel = {}

function SelectionModel.range(order: { any }, from: any, to: any): { any }
	local a = table.find(order, from)
	local b = table.find(order, to)
	if not a or not b then
		return { to }
	end
	local lo, hi = math.min(a, b), math.max(a, b)
	local list = {}
	for index = lo, hi do
		table.insert(list, order[index])
	end
	return list
end

function SelectionModel.toggle(current: { any }, target: any): { any }
	local list = {}
	local found = false
	for _, item in current do
		if item == target then
			found = true
		else
			table.insert(list, item)
		end
	end
	if not found then
		table.insert(list, target)
	end
	return list
end

function SelectionModel.apply(
	order: { any },
	current: { any },
	anchor: any,
	target: any,
	shift: boolean,
	mod: boolean
): ({ any }, any)
	if shift and anchor ~= nil then
		return SelectionModel.range(order, anchor, target), anchor
	end
	if mod then
		return SelectionModel.toggle(current, target), target
	end
	return { target }, target
end

return SelectionModel
