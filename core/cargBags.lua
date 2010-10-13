--[[
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
	class-generation, helper-functions and the Blizzard-replacement.
]]

local addon, ns = ...

--- @class table
--  @name cargBags
--  This class provides the underlying fundamental functions, such as
--  class-generation, helper-functions and the Blizzard-replacement
local cargBags = CreateFrame("Button")
ns.cargBags = cargBags
cargBags.Version = "2.2"

cargBags.extensions = {}

function cargBags:CreateImplementation(name)
	if(self.implementation) then
		error(("cargBags: Implementation '%s' already registered!"):format(self.implementation.name))
	end

	self.implementation = self.Class:Get("Implementation"):New(name)
	self.implementation.cargBags = self
	return self.implementation
end

function cargBags:Register(type, name, value)
	type = type:lower()
	local ext = self.extensions
	if(not ext[type]) then ext[type] = {} end

	if(ext[type][name]) then
		error(("cargBags: Extension '%s' of type '%s' already registered!"):format(type, name))
	end

	ext[type][name] = value
end

function cargBags:Has(type, name)
	type = type:lower()
	return self.extensions[type] and self.extensions[type][name]
end

function cargBags:Get(type, name)
	local extension = self:Has(type, name)
	assert(extension, ("cargBags: Missing Extension '%s' of type '%s'!"):format(type, name))
	return extension
end

function cargBags:Provides(extension) self:Register("extension", extension, true) end
function cargBags:Needs(extension) return self:Get("extension", extension) end

--- Gets the bagSlot-index of a bagID-slotID-pair
--  @param bagID <number>
--  @param slotID <number>
--  @return bagSlot <number>
function cargBags.toBagSlot(bagID, slotID)
	return bagID*100+slotID
end

--- Gets the bagID-slotID-pair of a bagSlot-index
--  @param bagSlot <number>
--  @return bagID <number>
--  @return bagSlot <number>
function cargBags.fromBagSlot(bagSlot)
	return math.floor(bagSlot/100), bagSlot % 100
end

function cargBags:SpawnPlugin(name, ...)
	return cargBags:Get("plugin", name)(self, ...)
end
