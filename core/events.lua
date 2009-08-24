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

local events = cargBags.Events
local LOCK, CD = 1, 2

-- Update either the bank slot or the bank bag
function events:PLAYERBANKSLOTS_CHANGED(event, bagID, slotID)
	if(bagID <= NUM_BANKGENERIC_SLOTS) then
		slotID = bagID
		bagID = -1
		return true, bagID, slotID
	end

	self:TimeBag(bagID-NUM_BANKGENERIC_SLOTS)
end

function events:PLAYER_LOGIN(event)
	self:TimeBag(0)
	self:TimeBag(-1)
	self:TimeBag(-2)
end

-- Only update item lock info
function events:ITEM_LOCK_CHANGED(event, bagID, slotID)
	return true, bagID, slotID, LOCK
end

function events:BAG_UPDATE(event, bagID, slotID)
	if(not bagID) then return true end
	cargBags:TimeBag(bagID)
end

-- fake event for hiding bags
function events:CB_BAG_HIDDEN(event, object, bagID)
	object.updateNeeded = true
	return true, bagID
end

function events:BAG_UPDATE_COOLDOWN(event, bagID, slotID)
	return true, bagID, slotID, CD
end
