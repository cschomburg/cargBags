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
]]
local addon, ns = ...
local cargBags = ns.cargBags

--[[!
	@class Implementation
		The Implementation-class serves as the basis for your cargBags-instance, handling
		item-data-fetching and dispatching events for containers and items.
]]
local Implementation = cargBags.Class:New("Implementation", nil, "Button")

Implementation.events = {}

--[[!
	Creates a new instance of the class
	@param name <string>
	@return impl <Implementation>
]]
function Implementation:New(name)
	if(_G[name]) then return error(("cargBags: Global '%s' for Implementation is already used!"):format(name)) end

	local impl = self:NewInstance(name, UIParent)
	impl.name = name

	impl:SetAllPoints()
	impl:EnableMouse(nil)
	impl:Hide()

	impl:SetScriptHandlers("OnEvent", "OnShow", "OnHide")

	impl.contByID = {} --! @property contByID <table> Holds all child-Containers by index
	impl.contByName = {} --!@ property contByName <table> Holds all child-Containers by name
	impl.buttons = {} -- @property buttons <table> Holds all ItemButtons by bagSlot
	impl.notInited = true -- @property notInited <bool>

	_G[name] = impl
	table.insert(UISpecialFrames, name)

	return impl
end

function Implementation:Open()
	if(self.notInited) then self:Init() end
	self:Show()
	if(self.OnOpen) then self:OnOpen() end
end

function Implementation:Close()
	if(self.notInited) then return end
	self:Hide()
	if(self.OnClose) then self:OnClose() end
end

--[[!
	Toggles the implementation
	@param forceopen <bool> Only open it
]]
function Implementation:Toggle(forceopen)
	if(not forceopen and self:IsShown()) then
		self:Close()
	else
		self:Open()
	end
end

--[[!
	Fetches a child-Container by name
	@param name <string>
	@return container <Container>
]]
function Implementation:GetContainer(name)
	return self.contByName[name]
end

function Implementation:GetClass(name, variant)
	if(variant) then
		local variantName = name.."-"..variant
		return cargBags.Class:Get(variantName, true, name)
	else
		return cargBags.Class:Get(name)
	end
end

--[[!
	Sets the ItemButton class to use for spawning new buttons
	@param name <string> The relative itembutton class name
	@return class <table> The newly set class
]]
function Implementation:SetDefaultItemButtonClass(name)
	self.buttonClass = self:GetClass("ItemButton")
	return self.buttonClass
end

--[[!
	Registers the implementation to overwrite Blizzards Bag-Toggle-Functions
]]
function Implementation:ReplaceBlizzard(bank)
	local function toggleBag(forceopen)	self:Toggle(forceopen)	end
	local function toggleNoForce()		self:Toggle()			end
	local function openBag()			self:Open()				end
	local function closeBag()			self:Close()			end	

	-- Can we maybe live without hooking ToggleBag(id)?
	ToggleBag = toggleNoForce
	ToggleBackpack = toggleNoForce
	OpenAllBags = toggleBag	-- Name is misleading, Blizz-function actually toggles bags
	OpenBackpack = openBag -- Blizz does not provide toggling here
	CloseAllBags = closeBag
	CloseBackpack = closeBag

	if(bank) then
		BankFrame:UnregisterAllEvents()
	end
end

function Implementation:SetSource(source)
	if(type(source) == "string") then
		source = cargBags:Get("source", source)
	end
	self.source = source
end

--[[!
	Inits the implementation by registering events
	@callback OnInit
]]
function Implementation:Init()
	if(not self.notInited) then return end
	self.notInited = nil

	if(self.OnInit) then self:OnInit() end

	if(not self.buttonClass) then
		self:SetDefaultItemButtonClass()
	end

	assert(self.source, ("cargBags: Implementation '%s' needs a Data Source!"):format(self.name))
	self.source:Enable()
	self.source:Update()
end

function Implementation:ForceUpdate()
	self.source:Update()
end

local toBagSlot = cargBags.toBagSlot

--[[
	Fetches a button by bagID-slotID-pair
	@param bagID <number>
	@param slotID <number>
	@return button <ItemButton>
]]
function Implementation:GetButton(bagID, slotID)
	return self.buttons[toBagSlot(bagID, slotID)]
end

--[[!
	Stores a button by bagID-slotID-pair
	@param bagID <number>
	@param slotID <number>
	@param button <ItemButton> [optional]
]]
function Implementation:SetButton(bagID, slotID, button)
	self.buttons[toBagSlot(bagID, slotID)] = button
end

local defaultItem = setmetatable({}, {__index = function(i,k) return cargBags:Has("itemkey", k) and cargBags:Has("itemkey", k)(i, k) end})

--[[!
	Fetches the itemInfo of the item in bagID/slotID into the table
	@param bagID <number>
	@param slotID <number>
	@param i <table> [optional]
	@return i <table>
]]
function Implementation:GetItemInfo(bagID, slotID, i)
	i = i or defaultItem
	for k in pairs(i) do i[k] = nil end

	i.bagID = bagID
	i.slotID = slotID

	self.source:LoadItemInfo(i)

	return i
end

function Implementation:Handle(event, ...)
	if(self.preHooks and self.preHooks[event]) then self.preHooks[event](self, event, ...) end
	if(self.events[event]) then self.events[event](self, ...) end
	if(self.postHooks and self.postHooks[event]) then self.postHooks[event](self, event, ...) end
end

--[[!
	Updates the defined slot, creating/removing buttons as necessary
	@param bagID <number>
	@param slotID <number>
]]
function Implementation:UpdateSlot(bagID, slotID)
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
		self:RemoveSlot(bagID, slotID)
	end
end

function Implementation:UpdateSlotCooldown(bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	if(not button) then return end

	local item = self:GetItemInfo(bagID, slotID)
	button:UpdateCooldown(item)
end

function Implementation:UpdateLock(bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	if(not button) then return end

	local item = self:GetItemInfo(bagID, slotID)
	button:UpdateLock(item)
end

function Implementation:UpdateQuest(bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	if(not button) then return end

	local item = self:GetItemInfo(bagID, slotID)
	button:UpdateQuest(item)
end

function Implementation:RemoveSlot(bagID, slotID)
	local button = self:GetButton(bagID, slotID)
	if(button) then
		button.container:RemoveButton(button)
		self:SetButton(bagID, slotID, nil)
		button:Free()
	end
end

function Implementation.events.Source_Update(name, state)
	if(name ~= "bank") then return end

	if(state) then
		self:Open()
		if(self.OnBankOpened) then self:OnBankOpened() end
	else
		self:Close()
		if(self.OnBankClosed) then self:OnBankCloed() end
	end
end

Implementation.events.Slot_Added = Implementation.UpdateSlot
Implementation.events.Slot_Removed = Implementation.RemoveSlot
Implementation.events.Slot_Update_Forced = Implementation.UpdateSlot

Implementation.events.Item_Count_Changed = Implementation.UpdateSlot
Implementation.events.Item_Changed = Implementation.UpdateSlot
Implementation.events.Item_Removed = Implementation.UpdateSlot
Implementation.events.Item_Added = Implementation.UpdateSlot

Implementation.events.Item_Lock_Changed = Implementation.UpdateSlotLock
Implementation.events.Item_Cooldown_Changed = Implementation.UpdateSlotCooldown
Implementation.events.Item_Quest_Changed = Implementation.UpdateSlotQuest

Implementation.SpawnPlugin = cargBags.SpawnPlugin
