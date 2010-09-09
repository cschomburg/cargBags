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
local cargBags = ns.cargBags



--- Creates a new item table which has access to ItemKeys
--  @return itemTable <table>
local m_item = {__index = function(i,k) return cargBags.itemKeys[k] and cargBags.itemKeys[k](i,k) end}
function cargBags:NewItemTable()
	return setmetatable({}, m_item)
end

local _registerEvent = UIParent.RegisterEvent
local _isEventRegistered = UIParent.IsEventRegistered

--[[!
	Registers an event callback - these are only called if the Implementation is currently shown
	The events do not have to be 'blizz events' - they can also be internal messages
	@param event <string> The event to register for
	@param key Something passed to the callback as arg #1, also serves as identification
	@param func <function> The function to call on the event
]]
function cargBags:RegisterEvent(event, key, func)
	local events = self.events
	
	if(not events[event]) then
		events[event] = {}
	end

	events[event][key] = func
	if(event:upper() == event and not _isEventRegistered(self, event)) then
		_registerEvent(self, event)
	end
end

--[[!
	Returns whether the Implementation has the specified event callback
	@param event <string> The event of the callback
	@param key The identification of the callback [optional]
]]
function cargBags:IsEventRegistered(event, key)
	return self.events[event] and (not key or self.events[event][key])
end

--[[!
	Script handler, dispatches the events
]]
function cargBags:OnEvent(event, ...)
	if(not (self.events[event] and self:IsShown())) then return end

	for key, func in pairs(self.events[event]) do
		func(key, event, ...)
	end
end

function cargBags:UpdateAll()
	self:OnEvent("BAG_UPDATE")
end

--[[!
	Fetches the itemInfo of the item in bagID/slotID into the table
	@param bagID <number>
	@param slotID <number>
	@param i <table> [optional]
	@return i <table>
]]

local defaultItem = cargBags:NewItemTable()

function cargBags:GetItemInfo(bagID, slotID, i)
	i = i or defaultItem
	for k in pairs(i) do i[k] = nil end

	i.bagID = bagID
	i.slotID = slotID

	local clink = GetContainerItemLink(bagID, slotID)

	if(clink) then
		i.texture, i.count, i.locked, i.quality, i.readable = GetContainerItemInfo(bagID, slotID)
		i.cdStart, i.cdFinish, i.cdEnable = GetContainerItemCooldown(bagID, slotID)
		i.isQuestItem, i.questID, i.questActive = GetContainerItemQuestInfo(bagID, slotID)
		i.name, i.link, i.rarity, i.level, i.minLevel, i.type, i.subType, i.stackCount, i.equipLoc, i.texture = GetItemInfo(clink)
	end
	return i
end

--[[!
	Updates the defined slot, creating/removing buttons as necessary
	@param bagID <number>
	@param slotID <number>
]]
function cargBags:UpdateSlot(bagID, slotID)
	local item = self:GetItemInfo(bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	local container = self:GetContainerForItem(item, button)

	if(container) then
		if(button) then
			if(container ~= button.container) then
				button.container:RemoveButton(button)
				container:AddButton(button)
			end
		else
			button = self.buttonClass:New(bagID, slotID)
			self:SetButton(bagID, slotID, button)
			container:AddButton(button)
		end

		button:Update(item)
	elseif(button) then
		button.container:RemoveButton(button)
		self:SetButton(bagID, slotID, nil)
		button:Free()
	end
end

local closed

--[[!
	Updates a bag and its containing slots
	@param bagID <number>
]]
function cargBags:UpdateBag(bagID)
	local numSlots
	if(closed) then
		numSlots, closed = 0
	else
		numSlots = GetContainerNumSlots(bagID)
	end
	local lastSlots = self.bagSizes[bagID] or 0
	self.bagSizes[bagID] = numSlots

	for slotID=1, numSlots do
		self:UpdateSlot(bagID, slotID)
	end
	for slotID=numSlots+1, lastSlots do
		local button = self:GetButton(bagID, slotID)
		if(button) then
			button.container:RemoveButton(button)
			self:SetButton(bagID, slotID, nil)
			button:Free()
		end
	end
end

--[[!
	Updates a set of items
	@param bagID <number> [optional]
	@param slotID <number> [optional]
	@callback Container:OnBagUpdate(bagID, slotID)
]]
function cargBags:BAG_UPDATE(event, bagID)
	if(bagID) then
		self:UpdateBag(bagID)
	else
		for bagID = -2, 11 do
			self:UpdateBag(bagID)
		end
	end
end

--[[!
	Updates a bag of the implementation (fired when it is removed)
	@param bagID <number>
]]
function cargBags:BAG_CLOSED(event, bagID)
	closed = bagID
	self:BAG_UPDATE(event, bagID)
end

--[[!
	Fired when the item cooldowns need to be updated
	@param bagID <number> [optional]
]]
function cargBags:BAG_UPDATE_COOLDOWN(event, bagID)
	if(bagID) then
		for slotID=1, GetContainerNumSlots(bagID) do
			local button = self:GetButton(bagID, slotID)
			if(button) then
				local item = self:GetItemInfo(bagID, slotID)
				button:UpdateCooldown(item)
			end
		end
	else
		for id, container in pairs(self.contByID) do
			for i, button in pairs(container.buttons) do
				local item = self:GetItemInfo(button.bagID, button.slotID)
				button:UpdateCooldown(item)
			end
		end
	end
end

--[[!
	Fired when the item is picked up or released
	@param bagID <number>
	@param slotID <number> [optional]
]]
function cargBags:ITEM_LOCK_CHANGED(event, bagID, slotID)
	if(not slotID) then return end

	local button = self:GetButton(bagID, slotID)
	if(button) then
		local item = self:GetItemInfo(bagID, slotID)
		button:UpdateLock(item)
	end
end

--[[!
	Fired when bank bags or slots need to be updated
	@param bagID <number>
	@param slotID <number> [optional]
]]
function cargBags:PLAYERBANKSLOTS_CHANGED(event, bagID, slotID)
	if(bagID <= NUM_BANKGENERIC_SLOTS) then
		slotID = bagID
		bagID = -1
	else
		bagID = bagID - NUM_BANKGENERIC_SLOTS
	end

	self:BAG_UPDATE(event, bagID, slotID)
end

--[[
	Fired when the quest log of a unit changes
]]
function cargBags:UNIT_QUEST_LOG_CHANGED(event)
	for id, container in pairs(self.contByID) do
		for i, button in pairs(container.buttons) do
			local item = self:GetItemInfo(button.bagID, button.slotID)
			button:UpdateQuest(item)
		end
	end
end
