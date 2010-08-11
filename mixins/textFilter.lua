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
	Provides a text-based filtering approach, e.g. for searchbars or GUIs
	Only one text filter per container can be active at any time!

DEPENDENCIES:
	base-add/filters.sieve.lua
]]
local _, ns = ...
local cargBags = ns.cargBags

local Container = cargBags.classes.Container

local sText = {}
local textFilters = {
	n = function(i, self) return i.name and i.name:lower():match(self.textFilter.n) end,
	t = function(i, self) return (i.type and i.type:lower():match(self.textFilter.t)) or (i.subType and i.subType:lower():match(self.textFilter.t)) or (i.equipLoc and i.equipLoc:lower():match(self.textFilter.t)) end,
	b = function(i, self) return i.bindOn and i.bindOn:match(self.textFilter.b) end,
	q = function(i, self) return i.rarity == tonumber(self.textFilter.q) end,
	bag = function(i, self) return i.bagID == tonumber(self.textFilter.bag) end,
	quest = function(i, self) return i.isQuestItem end,
}

--[[!
	Applies a text filter to the container
	@param text <string> the text filter
	@param filters <table> a table of filters to parse from [optional]
]]
function Container:SetTextFilter(text, filters)
	self.textFilter = self.textFilter or {}
	filters = filters or self.filters

	for k,v in pairs(textFilters) do filters[v] = nil end

	for match in text:gmatch("[^,;&]+") do
		local mod, type, value = match:trim():match("^(!?)(.-)[:=]?([^:=]*)$")
		mod = (mod == "!" and -1 or true)
		if(value and type ~= "" and textFilters[type]) then
			self.textFilter[type] = value:lower()
			filters[textFilters[type]] = mod
		elseif(value and type == "") then
			self.textFilter.n = value:lower()
			filters[textFilters.n] = mod
		end
	end
end

cargBags.TextFilters = textFilters
