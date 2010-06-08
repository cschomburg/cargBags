--[[
LICENSE
	cargBags: An inventory framework addon for World of Warcraft

	Copyright (C) 2010  Constantin "Cargor" Schomburg <xconstruct@gmail.com>

	cargBags is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version 2
	of the License, or (at your option) any later version.

	cargBags is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with cargBags; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

DESCRIPTION
	This file implements the filtering system for categories into cargBags.
	It is not compatible with other container-choosing extensions, especially not
	with the ones using Implementation:GetContainerForItem()
]]

local Implementation = cargBags.classes.Implementation

function Implementation:GetContainerForItem(item)
	for i, container in ipairs(self.contByID) do
		if(container:CheckFilters(item)) then
			return container
		end
	end
end

local Container = cargBags.classes.Container

function Container:CheckFilters(item, filters)
	for filter, flag in pairs(filters or self.filters) do
		local result = filter(item, self)
		if((flag == true and not result) or (flag == -1 and result)) then
			return nil
		end
	end
	return true
end

function Container:SetFilter(filter, flag)
	self.filters[filter] = flag
end

function Container:SetFilters(flag, ...)
	for i=1, select("#", ...) do
		local filter = select(i, ...)
		self:SetFilter(filter, flag)
	end
end

function Container:FilterForFunction(filters, func)
	for i, button in pairs(self.buttons) do
		local result = self:CheckFilters(button:GetItemInfo(), filters)
		func(button, result)
	end
end

