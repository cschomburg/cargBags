local addon, ns = ...
local cargBags = ns.cargBags

local itemLinks, itemCounts, numBagSlots = {}, {}, {}
local hardUpdate

local toBagSlot = cargBags.toBagSlot

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
	cargBags.implementation:Handle(event, ...)
end

local function checkSlot(bagID, slotID, newSlotCount, oldSlotCount)
	local oLink, oCount = getDB(bagID, slotID)
	local nLink, nCount = getCurrent(bagID, slotID)
	setDB(bagID, slotID, nLink, nCount)

	if(oldSlotCount and slotID > oldSlotCount) then
		fire("Slot_Added", bagID, slotID)
	elseif(newSlotCount and slotID > newSlotCount) then
		fire("Slot_Removed", bagID, slotID)
	end

	if(oLink == nLink) then
		if(oLink and nCount-oCount ~= 0) then
			fire("Item_Count_Changed", bagID, slotID, oLink, nCount-oCount, nCount)
		elseif(hardUpdate) then
			fire("Slot_Update_Forced", bagID, slotID, nLink, nCount)
		end
	elseif(oLink and nLink) then
		fire("Item_Changed", bagID, slotID, nLink, oLink, nCount, oCount)
	elseif(oLink) then
		fire("Item_Removed", bagID, slotID, oLink, oCount)
	else
		fire("Item_Added", bagID, slotID, nLink, nCount)
	end
end

local bagUpdates = {}
local hasSource = {}

-- I should integrate this into cargBags, somehow
local updater = CreateFrame("Frame", nil, cargBags)
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
	for slotID=1, GetContainerNumSlots(bagID) do
		if(getDB(bagID, slotID)) then
			fire("Item_Cooldown_Changed", bagID, slotID)
		end
	end
end

function updater:ITEM_LOCK_CHANGED(event, bagID, slotID)
	if(bagID and slotID) then
		fire("Item_Lock_Changed", bagID, slotID)
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
end)

local DefaultSource = {}

DefaultSource.pipes = {
	["GetContainerItemInfo"] = GetContainerItemInfo,
	["GetContainerItemLink"] = GetContainerItemLink,
	["GetContainerItemCooldown"] = GetContainerItemCooldown,
	["GetContainerNumSlots"] = GetContainerNumSlots,
	["GetContainerNumFreeSlots"] = GetContainerNumFreeSlots,
}

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

function DefaultSource:Update()
	hardUpdate = true
	for bagID=-2, 11 do
		updater:BAG_UPDATE("BAG_UPDATE", bagID)
	end
	hardUpdate = nil
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

function DefaultSource:Has(source)
	return has[source]
end

function DefaultSource:GetButtonTemplate(bagID, slotID)
	return (bagID == -1 and "BankItemButtonGenericTemplate") or (bagID and "ContainerFrameItemButtonTemplate") or "ItemButtonTemplate"
end

cargBags:Register("source", "Default", DefaultSource)
