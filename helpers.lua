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

local bagStrings = {
	["backpack"]		= { 0 },
	["bags"]			= { 1, 2, 3, 4 },
	["backpack+bags"]	= { 0, 1, 2, 3, 4, },
	["bankframe"]		= { -1 },
	["bank"]			= { 5, 6, 7, 8, 9, 10, 11 },
	["bankframe+bank"]	= { -1, 5, 6, 7, 8, 9, 10, 11 },
	["keyring"]			= { -2 },
}
cargBags.BagStrings = bagStrings

-- Some helper function for standardized bag-strings
function cargBags:ParseBags(bags)
	if(type(bags) == "table") then return bags end
	if(bagStrings[bags]) then return bagStrings[bags] end
	local min, max = bags and bags:match("(%d+)-(%d+)")
	if(min) then
		local t = {}
		for i=min, max do
			t[#t+1] = i
		end
		return t
	end
	return tonumber(bags) and {tonumber(bags)}
end




-- ContainerID to InventoryID
function cargBags.C2I(id)
	return ContainerIDToInventoryID(id)
end

-- InventoryID to ContainerID (the hackish way)
function cargBags.I2C(id)
	return (id < 24 and id-19) or (id > 67 and id-63)
end