--[[
    Copyright (C) 2009  Constantin Schomburg

    This file is part of cargBags.

    cargBags is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    cargBags is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with cargBags.  If not, see <http://www.gnu.org/licenses/>.
]]

-- YOU CAN FIND A DETAILED DOCUMENTATION UNDER:
-- http://wiki.github.com/xconstruct/cargBags

--[[##############################
	Functions of the bag object
		THEY R EVIL!!!!1111
################################]]

local cargBags = cargBags

local BagObject = CreateFrame"Button"
cargBags.BagObject = BagObject

-- Check if the passed item data can go into this object
function BagObject:CheckFilters(item)
	for Filter, enabled in pairs(self.Filters) do
		if(enabled and (Filter(item, self) ~= true) ~= (enabled == -1)) then
			return nil
		end
	end
	return true
end

-- Set a filter for the object
function BagObject:SetFilter(filter, enabled, noUpdate)
	self.Filters[filter] = enabled
	if(not self.Init and not noUpdate) then cargBags:UpdateBags() end
end


-- The function for iterating the bags
-- it ensures that the buttons are placed in the right order
-- how they are in the Blizz bags
local iTable = {}
local iSort = function(a,b)
	return a.bagID == b.bagID and a.slotID < b.slotID or a.bagID < b.bagID
end

-- And now the function returning the iterator
function BagObject:IterateButtons(func)
	local i = 1
	for button, _ in pairs(self.Buttons) do
		iTable[i] = button
		i = i + 1
	end
	while(iTable[i]) do
		iTable[i] = nil
		i = i + 1
	end
	sort(iTable, func or iSort)

	return next, iTable
end

BagObject.GetItemInfo = cargBags.GetItemInfo
BagObject.SpawnPlugin = cargBags.SpawnPlugin
BagObject.GetHandler = cargBags.GetHandler
BagObject.Fire = cargBags.Fire