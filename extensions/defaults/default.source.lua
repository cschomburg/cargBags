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

function updater:PLAYERBANKSLOTS_CHANGED(event, bagID)
	if(bagID <= NUM_BANKGENERIC_SLOTS) then
		return checkSlot(-1, bagID)
	else
		self:BAG_UPDATE(event, bagID - NUM_BANKGENERIC_SLOTS)
	end
end

function updater:BANKFRAME_OPENED(event)
	hasSource["bank"] = true
	self:BAG_UPDATE(event, -1)
	for bagID=5, 11 do
		self:BAG_UPDATE(event, bagID)
	end
	fire("Source_Update", "bank", true)
end

function updater:BANKFRAME_CLOSED(event)
	hasSource["bank"] = nil
	self:BAG_UPDATE(event, -1)
	for bagID=5, 11 do
		self:BAG_UPDATE(event, bagID)
	end
	fire("Source_Update", "bank", nil)
end

function updater:BAG_UPDATE_COOLDOWN(event, bagID)
	if(not bagID) then
		for bagID=-1, 11 do
			self:BAG_UPDATE(event, bagID)
		end
		return
	end

	for slotID=1, GetContainerNumSlots(bagID) do
		if(getDB(bagID, slotID)) then
			fire("Item_Update", bagID, slotID, "cooldown")
		end
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

	forcedUpdate = nil
end)

local DefaultSource = {}

function DefaultSource:Enable()
	updater:RegisterEvent("BAG_UPDATE")
	updater:RegisterEvent("BAG_CLOSED")
	updater:RegisterEvent("BANKFRAME_OPENED")
	updater:RegisterEvent("BANKFRAME_CLOSED")
	updater:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	updater:RegisterEvent("BAG_UPDATE_COOLDOWN")
	updater:RegisterEvent("ITEM_LOCK_CHANGED")
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
		i.texture, i.count, i.locked, i.quality, i.readable = GetContainerItemInfo(bagID, slotID)
		i.cdStart, i.cdFinish, i.cdEnable = GetContainerItemCooldown(bagID, slotID)
		i.isQuestItem, i.questID, i.questActive = GetContainerItemQuestInfo(bagID, slotID)
		i.name, i.link, i.rarity, i.level, i.minLevel, i.type, i.subType, i.stackCount, i.equipLoc, i.texture = GetItemInfo(link)
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

function DefaultSource:Has(source)
	return has[source]
end

function DefaultSource:GetButtonTemplate(bagID, slotID)
	return (bagID == -1 and "BankItemButtonGenericTemplate") or (bagID and "ContainerFrameItemButtonTemplate") or "ItemButtonTemplate"
end

Implementation:Register("source", "Default", DefaultSource)
