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

local addon, ns = ...
local Implementation = ns.cargBags
Implementation:Needs("FilterSet")
Implementation:Provides("TextFilter")

local Container = Implementation.Class:Get("Container")
local FilterSet = Implementation.Class:Get("FilterSet")

FilterSet.defaultTextFilter = "n"
FilterSet.textFilters = {
	n = function(i, arg) return i.name and i.name:lower():match(arg) end,
	t = function(i, arg) return (i.type and i.type:lower():match(arg)) or (i.subType and i.subType:lower():match(arg)) or (i.equipLoc and i.equipLoc:lower():match(arg)) end,
	b = function(i, arg) return i.bindOn and i.bindOn:match(arg) end,
	q = function(i, arg) return i.rarity == tonumber(arg) end,
	bag = function(i, arg) return i.bagID == tonumber(arg) end,
	quest = function(i, arg) return i.isQuestItem end,
}

--[[
	Parses a text for filters and stores them in the FilterSet
	@param text <string> the text filter
	@param textFilters <table> table of text filters to parse from [optional]

	@note Basically works like this: text ----textFilters----> FilterSet	
]]


function FilterSet:SetTextFilter(text, caseSensitive)
	local filters = self.textFilters

	for match in text:gmatch("[^,;&]+") do
		local mod, type, value = match:trim():match("^(!?)(.-)[:=]?([^:=]*)$")

		if(value) then
			mod = (mod == "!" and -1) or true

			if(value and caseSensitive) then
				value = value:lower()
			end

			local filter
			if(type ~= "" and filters[type]) then
				filter = filters[type]
			elseif(type == "" and self.defaultTextFilter) then
				filter = filters[self.defaultTextFilter]
			end

			if(filter) then
				self:SetExtended(filter, value, mod)
			end
		end
	end
end

--[[!
	Applies a text filter to the container, for convenience
	@param text <string> the text filter
	@param textFilters <table> a table of textFilters to parse from [optional]
]]
function Container:SetTextFilter(text, textFilters)
	self.filters = self.filters or FilterSet:New()
	self.filters:SetTextFilter(text, textFilters)
end
