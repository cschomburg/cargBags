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
local cargBags = CreateFrame("Button", nil, UIParent)
ns.cargBags = cargBags
cargBags.Version = "2.1.2"

cargBags.contByID = {} --! @property contByID <table> Holds all child-Containers by index
cargBags.contByName = {} --!@ property contByName <table> Holds all child-Containers by name
cargBags.notInited = true -- @property notInited <bool>

local defaultOptions = {__index={
	replaceBags = true,
	replaceBank = true,
	closeOnEscape = true,
}}

--[[!
	Sets up cargBags
	@param name <string> name of cargBags (you can also provide it in options.name)
	@param options <table> options for setup [optional]
]]
function cargBags:Setup(name, options)
	if(type(name) == "table") then
		name = name.name
		options = name
	end
	options = setmetatable(options or {}, defaultOptions)

	if(_G[name]) then return error(("cargBags: Global '%s' is already used!"):format(name)) end
	_G[name] = self

	self.name = name

	self:SetAllPoints()
	self:EnableMouse(nil)
	self:Hide()

	self.Class.Prototype.SetScriptHandlers(self, "OnEvent", "OnShow", "OnHide")

	if(options.closeOnEscape) then
		table.insert(UISpecialFrames, name)
	end

	if(options.replaceBags) then
		local function toggleBag(forceopen)	self:Toggle(forceopen)	end
		local function toggleNoForce()		self:Toggle()			end
		local function openBag()			self:Show()				end
		local function closeBag()			self:Hide()				end

		-- Can we maybe live without hooking ToggleBag(id)?
		ToggleBag = toggleNoForce
		ToggleBackpack = toggleNoForce
		OpenAllBags = toggleBag	-- Name is misleading, Blizz-function actually toggles bags
		OpenBackpack = openBag -- Blizz does not provide toggling here
		CloseAllBags = closeBag
		CloseBackpack = closeBag
	end

	if(options.replaceBank) then
		BankFrame:UnregisterAllEvents()

		self:RegisterEvent("BANKFRAME_OPENED", self, function(self, event)
			self.atBank = true

			if(self:IsShown()) then
				self:Update()
			else
				self:Show()
			end

			if(cargBags.OnBankOpened) then cargBags:OnBankOpened() end
		end)
		self:RegisterEvent("BANKFRAME_CLOSED", self, function(self, event)
			self.atBank = nil

			if(self:IsShown()) then
				self:Hide()
			end

			if(self.OnBankClosed) then self:OnBankClosed() end
		end)
	end

	return self
end

function cargBags:DebugEvents()
	self:RegisterEvent("Item_Added", "cargBags", print)
	self:RegisterEvent("Item_Removed", "cargBags", print)
	self:RegisterEvent("Item_Changed", "cargBags", print)
	self:RegisterEvent("Item_Count_Changed", "cargBags", print)
	self:RegisterEvent("Slot_Added", "cargBags", print)
	self:RegisterEvent("Slot_Removed", "cargBags", print)
end

--[[!
	Returns whether the user is currently at the bank
	@return atBank <bool>
]]
function cargBags:AtBank()
	return self.atBank
end

--[[!
	Script handler, inits and updates cargBags when shown
	@callback OnOpen
]]
function cargBags:OnShow()
	if(self.notInited) then
		self:Init()
	end

	self:Update()

	if(self.OnOpen) then self:OnOpen() end
end

--[[!
	Script handler, closes cargBags when hidden
	@callback OnClose
]]
function cargBags:OnHide()
	if(self.notInited) then return end

	if(self.OnClose) then self:OnClose() end
	if(self:AtBank()) then CloseBankFrame() end
end

--[[!
	Toggles cargBags
	@param forceopen <bool> Only open it
]]
function cargBags:Toggle(forceopen)
	if(not forceopen and self:IsShown()) then
		self:Hide()
	else
		self:Show()
	end
end

--[[!
	Fetches a child-Container by name
	@param name <string>
	@return container <Container>
]]
function cargBags:GetContainer(name)
	return self.contByName[name]
end

--[[!
	Fetches a class or creates a 'variant', inheriting from the class
	@param name <string> name of the class
	@param variant <string> the variant of the class [optional]
	@return class <table>
]]
function cargBags:GetClass(name, variant)
	if(variant) then
		return self.Class:Get(variant..name, true, name)
	else
		return self.Class:Get(name)
	end
end

--[[!
	Inits cargBags by registering events and calling OnInit
	@callback OnInit
]]
function cargBags:Init()
	if(not self.notInited) then return end
	self.notInited = nil

	if(self.OnInit) then self:OnInit() end

	if(not self.buttonClass) then
		self.buttonClass = self:GetClass("ItemButton")
	end

	self:RegisterEvent("Item_Changed", self, self.UpdateSlot)
	self:RegisterEvent("Item_Removed", self, self.UpdateSlot)
	self:RegisterEvent("Item_Added", self, self.UpdateSlot)
	self:RegisterEvent("Item_Count_Changed", self, self.UpdateSlot)
	self:RegisterEvent("Slot_Added", self, self.UpdateSlot)
	self:RegisterEvent("Slot_Removed", self, self.RemoveSlot)

	self:RegisterEvent("BAG_UPDATE_COOLDOWN", self, self.UpdateCooldowns)
	self:RegisterEvent("ITEM_LOCK_CHANGED", self, self.UpdateLock)
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", self, self.UpdateQuests)
end


--[[############################
	Event Handler
##############################]]

cargBags.events = {} --! @property events <table> Holds all events and the objects registered to them

local _register, _isRegistered = UIParent.RegisterEvent, UIParent.IsEventRegistered

function cargBags:RegisterEvent(event, key, func)
	local events = self.events

	if(not events[event]) then
		events[event] = {}
	end

	events[event][key] = func
	if(event:upper() == event and not _isRegistered(self, event)) then
		_register(self, event)
	end
end

function cargBags:IsEventRegistered(key, event, func)
	local events = self.events
	return events[event] and (not key or events[event][key])
end

function cargBags:Fire(event, ...)
	local events = self.events

	if(not events[event]) then return end
	for key, func in pairs(events[event]) do
		func(key, event, ...)
	end
end
cargBags.OnEvent = cargBags.Fire


--[[############################
	Button Database
##############################]]

cargBags.buttons = {} -- @property buttons <table> Holds all ItemButtons by bagSlot

local function toBagSlot(bagID, slotID) return bagID*100+slotID end
--local function fromBagSlot(bagSlot) return math.floor(bagSlot/100), bagSlot % 100 end -- for reference

--[[!
	Fetches a button by bagID-slotID-pair
	@param bagID <number>
	@param slotID <number>
	@return button <ItemButton>
]]
function cargBags:GetButton(bagID, slotID)
	return self.buttons[toBagSlot(bagID, slotID)]
end

--[[!
	Stores a button by bagID-slotID-pair
	@param bagID <number>
	@param slotID <number>
	@param button <ItemButton> [optional]
]]
function cargBags:SetButton(bagID, slotID, button)
	self.buttons[toBagSlot(bagID, slotID)] = button
end


--[[############################
	Item Data Fetching
##############################]]

cargBags.itemKeys = {} --! @property itemKeys <table> holds additional itemKeys

local m_item = {__index = function(i,k) return cargBags.itemKeys[k] and cargBags.itemKeys[k](i,k) end}
local defaultItem = setmetatable({}, m_item)

--[[!
	Fetches the itemInfo of the item in bagID/slotID into the table
	@param bagID <number>
	@param slotID <number>
	@param i <table> [optional]
	@return i <table>
]]
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

	self:Fire("ItemTable_Requested", i)

	return i
end


--[[############################
	Slot Updating
##############################]]

function cargBags:Update(bagID, slotID)
	if(bagID and slotID) then
		self:UpdateSlot(nil, bagID, slotID)
	elseif(bagID) then
		for slotID=1, GetContainerNumSlots(bagID) do
			self:Update(bagID, slotID)
		end
	else
		for bagID=-2, 11 do
			self:Update(bagID)
		end
		self:Fire("Complete_Update")
	end
end

--[[!
	Updates the defined slot, creating/removing buttons as necessary
	@param event <string> [optional]
	@param bagID <number>
	@param slotID <number>
]]
function cargBags:UpdateSlot(event, bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	local item = self:GetItemInfo(bagID, slotID)

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
		self:RemoveSlot(nil, bagID, slotID)
	end
end

--[[!
	Removes a slot from the system
	@param event <string> [optional]
	@param bagID <number>
	@param slotID <number>
]]
function cargBags:RemoveSlot(event, bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	if(not button) then return end

	button.container:RemoveButton(button)
	self:SetButton(bagID, slotID, nil)
	button:Free()
end

--[[!
	Updates the cooldown state of a range of slots
	@param event <string> [optional]
	@param bagID <number> [optional]
]]
function cargBags:UpdateCooldowns(event, bagID)
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
	Updates the locked-state of a slot
	@param event <string> [optional]
	@param bagID <number>
	@param slotID <number>
]]
function cargBags:UpdateItemLock(event, bagID, slotID)
	if(not slotID) then return end

	local button = self:GetButton(bagID, slotID)
	if(button) then
		local item = self:GetItemInfo(bagID, slotID)
		button:UpdateLock(item)
	end
end

--[[
	Updates the quest state of all items
	@param event <string> [optional]
]]
function cargBags:UpdateQuests(event)
	for id, container in pairs(self.contByID) do
		for i, button in pairs(container.buttons) do
			local item = self:GetItemInfo(button.bagID, button.slotID)
			button:UpdateQuest(item)
		end
	end
end

--[[############################
	Smart Events
##############################]]

local itemLinks, itemCounts, numBagSlots = {}, {}, {}
-- local toBagSlot -- from section "Button Database"

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

local function checkSlot(bagID, slotID, newSlotCount, oldSlotCount)
	local oLink, oCount = getDB(bagID, slotID)
	local nLink, nCount = getCurrent(bagID, slotID)
	setDB(bagID, slotID, nLink, nCount)

	if(oldSlotCount and slotID > oldSlotCount) then
		cargBags:Fire("Slot_Added", bagID, slotID)
	elseif(newSlotCount and slotID > newSlotCount) then
		cargBags:Fire("Slot_Removed", bagID, slotID)
	end

	if(not oLink and not nLink) then return end

	if(oLink == nLink) then
		local diff = nCount-oCount
		if(diff ~= 0) then
			cargBags:Fire("Item_Count_Changed", bagID, slotID, oLink, diff, nCount)
		end
	elseif(oLink and nLink) then
		cargBags:Fire("Item_Changed", bagID, slotID, nLink, oLink, nCount, oCount)
	elseif(oLink) then
		cargBags:Fire("Item_Removed", bagID, slotID, oLink, oCount)
	else
		cargBags:Fire("Item_Added", bagID, slotID, nLink, nCount)
	end
end

local bagUpdates = {}

-- I should integrate this into cargBags, somehow
local updater = CreateFrame("Frame", nil, cargBags)
updater:Hide()
updater:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
updater:RegisterEvent("BANKFRAME_OPENED")
updater:RegisterEvent("BAG_UPDATE")
updater:RegisterEvent("BAG_CLOSED")
updater:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

function updater:BANKFRAME_OPENED(event)
	self:BAG_UPDATE("BAG_UPDATE", -1)
	for bagID=1, 11 do
		self:BAG_UPDATE("BAG_UPDATE", bagID)
	end
end

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
