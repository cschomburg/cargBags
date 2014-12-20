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

DESCRIPTION
	The Default-Source provides an interface to the bankframe / inventory.

PROVIDES
	source: Default
]]

local addon, ns = ...
local Implementation = ns.cargBags

local itemLinks, itemCounts, numBagSlots = {}, {}, {}
local forcedUpdate

local toBagSlot = Implementation.toBagSlot

local function getDB(bagID, slotID)
	local bagSlot = toBagSlot(bagID, slotID)
	return itemLinks[bagSlot], itemCounts[bagSlot]
end

local function getCurrent(bagID, slotID)
	local link = GetContainerItemLink(bagID, slotID)
	local count = select(2, GetContainerItemInfo(bagID, slotID))
	return link, count
end

local function setDB(bagID, slotID, link, count)
	local bagSlot = toBagSlot(bagID, slotID)
	itemLinks[bagSlot], itemCounts[bagSlot] = link, count
end

local function fire(event, ...)
	Implementation:Handle(event, ...)
end

local function checkSlot(bagID, slotID, newSlotCount, oldSlotCount)
	local oLink, oCount = getDB(bagID, slotID)
	local nLink, nCount = getCurrent(bagID, slotID)
	setDB(bagID, slotID, nLink, nCount)

	if(oldSlotCount and slotID > oldSlotCount) then
		fire("Slot_Update", bagID, slotID, "added")
	elseif(newSlotCount and slotID > newSlotCount) then
		return fire("Slot_Update", bagID, slotID, "removed")
	end

	if(oLink == nLink) then
		if(oLink and nCount-oCount ~= 0) then
			fire("Item_Update", bagID, slotID, "count", oLink, nCount-oCount, nCount)
		elseif(forcedUpdate) then
			fire("Slot_Update", bagID, slotID, "forced", nLink, nCount)
		end
	elseif(oLink and nLink) then
		fire("Item_Update", bagID, slotID, "changed", nLink, oLink, nCount, oCount)
	elseif(oLink) then
		fire("Item_Update", bagID, slotID, "removed", oLink, oCount)
	else
		fire("Item_Update", bagID, slotID, "added", nLink, nCount)
	end
end

local bagUpdates = {}
local hasSource = {}

local updater = CreateFrame("Frame", nil, Implementation)
updater:Hide()
updater:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)

function updater:BAG_UPDATE(event, bagID)
	bagUpdates[bagID] = true
	self:Show()
end
updater.BAG_CLOSED = updater.BAG_UPDATE

function updater:BAG_UPDATE_COOLDOWN(event, bagID)
    if (not bagID) then
        for bagID = -1, 11 do
            self:BAG_UPDATE_COOLDOWN(event, bagID)
        end
        return
    end

    for slotID = 1, GetContainerNumSlots(bagID) do
        if (getDB(bagID, slotID)) then
            fire("Item_Update", bagID, slotID, "cooldown")
        end
    end
end

function updater:BAG_NEW_ITEMS_UPDATED(event, ...)
    print("default.source", event, ...)
end

function updater:BANKFRAME_OPENED(event)
	hasSource["bank"] = true
	self:BAG_UPDATE(event, -1)
	for bagID=5, 11 do
		self:BAG_UPDATE(event, bagID)
	end
	fire("Group_State", "bank", true)
end

function updater:BANKFRAME_CLOSED(event)
	hasSource["bank"] = nil
	self:BAG_UPDATE(event, -1)
	for bagID=5, 11 do
		self:BAG_UPDATE(event, bagID)
	end
	fire("Group_State", "bank", nil)
end

function updater:PLAYERBANKSLOTS_CHANGED(event, bagID)
    if(bagID <= NUM_BANKGENERIC_SLOTS) then
        checkSlot(-1, bagID)
        fire("Items_Update")
        return
    else
        self:BAG_UPDATE(event, bagID - NUM_BANKGENERIC_SLOTS)
    end
end

function updater:ITEM_LOCK_CHANGED(event, bagID, slotID)
    if(bagID == -1 and slotID > 28) then
        bagID, slotID = ContainerIDToInventoryID(slotID-28)
    end

    if(bagID and slotID) then
        fire("Item_Update", bagID, slotID, "lock")
    elseif(bagID) then
        fire("Inventory_Lock_Changed", bagID)
    end
end

function updater:INVENTORY_SEARCH_UPDATE(event, ...)
    print("default.source", event, ...)
end

updater:SetScript("OnUpdate", function(self)
	self:Hide()

	for bagID in pairs(bagUpdates) do
		bagUpdates[bagID] = nil

		local newSlotCount = GetContainerNumSlots(bagID) or 0
		local oldSlotCount = numBagSlots[bagID] or 0
		numBagSlots[bagID] = newSlotCount

		for slotID=1, math.max(newSlotCount, oldSlotCount) do
			checkSlot(bagID, slotID, newSlotCount, oldSlotCount)
		end
	end

	fire("Items_Update")
	forcedUpdate = nil
end)

local DefaultSource = {}

function DefaultSource:Enable()
	updater:RegisterEvent("BAG_UPDATE")
    updater:RegisterEvent("BAG_CLOSED")
    updater:RegisterEvent("BAG_UPDATE_COOLDOWN")
    updater:RegisterEvent("BAG_NEW_ITEMS_UPDATED")

	updater:RegisterEvent("BANKFRAME_OPENED")
	updater:RegisterEvent("BANKFRAME_CLOSED")
	updater:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

    updater:RegisterEvent("ITEM_LOCK_CHANGED")
    updater:RegisterEvent("INVENTORY_SEARCH_UPDATE")
end

function DefaultSource:Disable()
	updater:UnregisterAllEvents()
	updater:Hide()
end

function DefaultSource:ForceUpdate(bagID, slotID)
	forcedUpdate = true

	if(bagID and slotID) then
		checkSlot(bagID, slotID)
		forcedUpdate = nil
	elseif(bagID) then
		updater:BAG_UPDATE("BAG_UPDATE", bagID)
	else
		for bagID=-2, 11 do
			updater:BAG_UPDATE("BAG_UPDATE", bagID)
		end
	end
end

function DefaultSource:LoadItemInfo(i)
	local bagID, slotID = i.bagID, i.slotID
	local link = GetContainerItemLink(bagID, slotID)

	if(link) then
		i.texture, i.count, i.locked, i.quality, i.readable, i.lootable, i.link, i.isFiltered = GetContainerItemInfo(bagID, slotID)
		i.cdStart, i.cdFinish, i.cdEnable = GetContainerItemCooldown(bagID, slotID)
		i.isQuestItem, i.questID, i.questActive = GetContainerItemQuestInfo(bagID, slotID)
		i.name, i.link, i.quality, i.level, i.minLevel, i.type, i.subType, i.stackCount, i.equipLoc, i.texture, i.sellPrice = GetItemInfo(link)
	end
end

function DefaultSource:GetItemSlotInfo(bagID, slotID, type)
	if(not type) then
		return GetContainerItemInfo(bagID, slotID)
	elseif(type == "link") then
		return GetContainerItemLink(bagID, slotID)
	elseif(type == "cooldown") then
		return GetContainerItemCooldown(bagID, slotID)
	elseif(type == "quest") then
		return GetContainerItemQuestInfo(bagID, slotID)
	end
end

function DefaultSource:GetBagSlotInfo(bagID, type)
	if(type == "slots") then
		return GetContainerNumSlots(bagID), GetContainerNumFreeSlots(bagID)
	elseif(not type) then
		local invID = ContainerIDToInventoryID(bagID)
		local texture = GetInventoryItemTexture("player", invID)
		local link = GetInventoryItemLink("player", invID)
		local locked = IsInventoryItemLocked(invID)
		return texture, link, locked
	elseif(type == "purchased") then
		if(bagID >= 5 and bagID <= 11) then
			return bagID-4 <= GetNumBankSlots()
		else
			return true
		end
	end
end

function DefaultSource:PutItemInBag(bagID)
	return PutItemInBag(ContainerIDToInventoryID(bagID))
end

function DefaultSource:PickupBag(bagID)
	return PickupBagFromSlot(ContainerIDToInventoryID(bagID))
end

function DefaultSource:CanInteract(bagID)
	if(bagID == -1 or (bagID >= 5 and bagID <= 11)) then
		return has['bank']
	else
		return true
	end
end

function DefaultSource:Has(group)
	return has[group]
end

function DefaultSource:GetButtonTemplate(bagID, slotID)
    local template = "ItemButtonTemplate"
    if bagID == -1 then
        template = "BankItemButtonGenericTemplate"
    elseif bagID == -3 then
        template = "ReagentBankItemButtonGenericTemplate"
    elseif bagID and bagID >= 0 then
        template = "ContainerFrameItemButtonTemplate"
    end
	return template
end

Implementation:Register("source", "Default", DefaultSource)
