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
	The bag sieve just places items in the right containers based on their bagID

DEPENDENCIES
	mixins\parseBags.lua (optional)
]]

local addon, ns = ...
local Implementation = ns.cargBags

local Container = Implementation:Needs("Class", "Container")

local bagToContainer = {}
Implementation.bagToContainer = bagToContainer

--[[!
	Sets the handled bags for a container
	@param bags <BagType>
]]
function Container:SetBags(bags)
	if(Implementation.ParseBags) then
		bags = Implementation:ParseBags(bags)
	end

	if(not bags) then return end

	for i, bagID in pairs(bags) do
		bagToContainer[bagID] = self
	end
end

Implementation:Register("sieve", "Bags", function(self, item)
	return bagToContainer[item.bagID]
end)
