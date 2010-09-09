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

cargBags.itemKeys = {} --- <table> Holds all ItemKeys by their name

--- Creates a new instance of the class 'Implementation'
--  @param name <string> The name of the implementation
--  @return instance <Implementation> The new instance
function cargBags:Setup(name)
	if(_G[name]) then return error(("cargBags: Global '%s' is already used!"):format(name)) end
	_G[name] = self

	self.name = name

	self:SetAllPoints()
	self:EnableMouse(nil)
	self:Hide()

	self.Class.Prototype.SetScriptHandlers(self, "OnEvent", "OnShow", "OnHide")

	self.contByID = {} --! @property contByID <table> Holds all child-Containers by index
	self.contByName = {} --!@ property contByName <table> Holds all child-Containers by name
	self.buttons = {} -- @property buttons <table> Holds all ItemButtons by bagSlot
	self.bagSizes = {} -- @property bagSizes <table> Holds the size of all bags
	self.events = {} -- @property events <table> Holds all event callbacks
	self.notInited = true -- @property notInited <bool>

	table.insert(UISpecialFrames, name)

	return self
end

local function toggleBag(forceopen)	cargBags:Toggle(forceopen)	end
local function toggleNoForce()		cargBags:Toggle()			end
local function openBag()			cargBags:Show()				end
local function closeBag()			cargBags:Hide()				end

local bankHandler = CreateFrame"Frame"

--- Overwrites Blizzards Bag-Toggle-Functions with the implementations ones
--  @param bank <bool> also handle the bank
function cargBags:ReplaceBlizzard(bank)
	-- Can we maybe live without hooking ToggleBag(id)?
	ToggleBag = toggleNoForce
	ToggleBackpack = toggleNoForce
	OpenAllBags = toggleBag	-- Name is misleading, Blizz-function actually toggles bags
	OpenBackpack = openBag -- Blizz does not provide toggling here
	CloseAllBags = closeBag
	CloseBackpack = closeBag

	if(bank) then
		BankFrame:UnregisterAllEvents()
		bankHandler:RegisterEvent("BANKFRAME_OPENED")
		bankHandler:RegisterEvent("BANKFRAME_CLOSED")
	end
end

bankHandler:SetScript("OnEvent", function(self, event)
	if(event == "BANKFRAME_OPENED") then
		cargBags.atBank = true

		if(cargBags:IsShown()) then
			cargBags:UpdateAll()
		else
			cargBags:Show()
		end

		if(cargBags.OnBankOpened) then
			cargBags:OnBankOpened()
		end
	elseif(event == "BANKFRAME_CLOSED") then
		cargBags.atBank = nil

		if(cargBags:IsShown()) then
			cargBags:Hide()
		end

		if(cargBags.OnBankClosed) then
			cargBags:OnBankClosed()
		end
	end
end)

--[[!
	Returns whether the user is currently at the bank
	@return atBank <bool>
]]
function cargBags:AtBank()
	return self.atBank
end

--[[!
	Script handler, inits and updates the Implementation when shown
	@callback OnOpen
]]
function cargBags:OnShow()
	if(self.notInited) then
		self:Init()
	end

	if(self.OnOpen) then self:OnOpen() end
	self:UpdateAll()
end

--[[!
	Script handler, closes the Implementation when hidden
	@callback OnClose
]]
function cargBags:OnHide()
	if(self.notInited) then return end

	if(self.OnClose) then self:OnClose() end
	if(self:AtBank()) then CloseBankFrame() end
end

--[[!
	Toggles the implementation
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

function cargBags:GetClass(name, variant)
	variant = variant or ""
	return self.Class:Get(variant..name, true, name)
end

--[[!
	Inits the implementation by registering events
	@callback OnInit
]]
function cargBags:Init()
	if(not self.notInited) then return end
	self.notInited = nil

	if(self.OnInit) then self:OnInit() end

	if(not self.buttonClass) then
		self.buttonClass = self:GetClass("ItemButton")
	end

	self:RegisterEvent("BAG_UPDATE", self, self.BAG_UPDATE)
	self:RegisterEvent("BAG_UPDATE_COOLDOWN", self, self.BAG_UPDATE_COOLDOWN)
	self:RegisterEvent("ITEM_LOCK_CHANGED", self, self.ITEM_LOCK_CHANGED)
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED", self, self.PLAYERBANKSLOTS_CHANGED)
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", self, self.UNIT_QUEST_LOG_CHANGED)
	self:RegisterEvent("BAG_CLOSED", self, self.BAG_CLOSED)
end


--- Gets the bagSlot-index of a bagID-slotID-pair
--  @param bagID <number>
--  @param slotID <number>
--  @return bagSlot <number>
function cargBags.ToBagSlot(bagID, slotID)
	return bagID*100+slotID
end


--- Gets the bagID-slotID-pair of a bagSlot-index
--  @param bagSlot <number>
--  @return bagID <number>
--  @return bagSlot <number>
function cargBags.FromBagSlot(bagSlot)
	return floor(bagSlot/100), bagSlot % 100
end
--[[
	Fetches a button by bagID-slotID-pair
	@param bagID <number>
	@param slotID <number>
	@return button <ItemButton>
]]
function cargBags:GetButton(bagID, slotID)
	return self.buttons[self.ToBagSlot(bagID, slotID)]
end

--[[!
	Stores a button by bagID-slotID-pair
	@param bagID <number>
	@param slotID <number>
	@param button <ItemButton> [optional]
]]
function cargBags:SetButton(bagID, slotID, button)
	self.buttons[self.ToBagSlot(bagID, slotID)] = button
end

