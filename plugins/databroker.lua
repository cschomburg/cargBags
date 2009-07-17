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

--[[doc
Plugin: DataBroker

Description:
	Creates a display block for a databroker object
	cargoShip is required for this addon to work

Spawns with:
	:SpawnPlugin("DataBroker", name [, options]): spawn a frame with named data object and the additional options
doc]]

-- Register the plugin
cargBags:RegisterPlugin("DataBroker", function(self, ...)
	if(not cargoShip) then return end
	local object = cargoShip(...)
	if(not object) then return end
	object:SetParent(self)
	return object
end)