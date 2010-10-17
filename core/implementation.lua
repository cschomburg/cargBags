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

local Implementation = CreateFrame("Button", nil, UIParent)
ns.cargBags = Implementation

Implementation.Class = ns.SimpleOOP
Implementation.Version = "2.2"
Implementation.name = "cargBags" -- gets overwritten by addon in :Setup()
Implementation.extensions = {}

local function error(s, ...) error(string.format("%s: "..s, Implementation.name, ...)) end

function Implementation:Register(type, name, value)
	type = type:lower()
	local ext = self.extensions
	if(not ext[type]) then ext[type] = {} end

	if(ext[type][name]) then
		error("Extension '%s' of type '%s' already registered!", type, name)
	end

	ext[type][name] = value
end

function Implementation:Has(type, name)
	type = type:lower()
	return self.extensions[type] and self.extensions[type][name]
end

function Implementation:Get(type, name)
	local extension = self:Has(type, name)
	if(not extension) then
		error("Missing Extension '%s' of type '%s'!", type, name)
	end
	return extension
end

function Implementation:Provides(extension) self:Register("extension", extension, true) end
function Implementation:Needs(extension) return self:Get("extension", extension) end

function Implementation.toBagSlot(bagID, slotID)
	return bagID*100+slotID
end

function Implementation.fromBagSlot(bagSlot)
	return math.floor(bagSlot/100), bagSlot % 100
end

function Implementation:SpawnPlugin(name, ...)
	return Implementation:Get("plugin", name)(self, ...)
end

function Implementation:Setup(name)
	if(_G[name]) then error("Global '%s' is already used!", name) end

	self.name = name

	self:SetAllPoints()
	self:EnableMouse(nil)
	self:Hide()

	self.Class.Prototype.SetScriptHandlers(self, "OnEvent", "OnShow", "OnHide")

	self.containers = {}
	self.buttons = {}
	self.notInited = true
	self.callbacks = {}

	self.itemChecks = {
		["added"] = true,
		["removed"] = true,
		["changed"] = true,
		["forced"] = true,
	}

	_G[name] = self
	table.insert(UISpecialFrames, name)

	return self
end

function Implementation:Open()
	if(self:IsShown()) then return end

	if(self.notInited) then self:Init() end
	self:Show()
	if(self.OnOpen) then self:OnOpen() end
	self:Handle("Refresh")
end

function Implementation:Close()
	if(not self:IsShown()) then return end

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

function Implementation:GetClass(name, variant)
	if(variant) then
		local variantName = name.."-"..variant
		return self.Class:Get(variantName, true, name)
	else
		return self.Class:Get(name)
	end
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
		source = self:Get("source", source)
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

	if(not self.source) then
		error("Needs a Data Source!")
	end
	self.source:Enable()
	self.source:ForceUpdate()
end

function Implementation:ForceUpdate(...)
	self.source:ForceUpdate(...)
end

function Implementation:GetButton(bagID, slotID)
	return self.buttons[self.toBagSlot(bagID, slotID)]
end

function Implementation:SetButton(bagID, slotID, button)
	self.buttons[self.toBagSlot(bagID, slotID)] = button
end

local defaultItem = setmetatable({}, {__index = function(i,k) return Implementation:Has("itemkey", k) and Implementation:Has("itemkey", k)(i, k) end})

function Implementation:LoadItemInfo(bagID, slotID, i)
	i = i or defaultItem
	for k in pairs(i) do i[k] = nil end

	i.bagID = bagID
	i.slotID = slotID

	self.source:LoadItemInfo(i)

	return i
end

function Implementation:RegisterCallback(event, object, func)
	self.callbacks[event] = self.callbacks[event] or {}
	self.callbacks[event][object] = func
end

function Implementation:Handle(event, ...)
	if(self.callbacks and self.callbacks[event]) then
		for object, func in pairs(self.callbacks[event]) do
			func(object, event, ...)
		end
	end
	if(self[event]) then self[event](self, ...) end
end

function Implementation:Slot_Update(bagID, slotID, message)
	if(message == "added") then
		return self:Item_Update(bagID, slotID, "added")
	elseif(message == "removed") then
		local button = self:GetButton(bagID, slotID)
		if(button) then
			button.container:RemoveButton(button)
			self:SetButton(bagID, slotID, nil)
			button:Free()
		end
	elseif(message == "forced") then
		return self:Item_Update(bagID, slotID, "forced")
	end
end

function Implementation:Item_Update(bagID, slotID, message)
	local item = self:LoadItemInfo(bagID, slotID)
	local button = self:GetButton(bagID, slotID)

	if(message == "forced") then
		print("forced", bagID, slotID)
	end

	if(self.itemChecks[message]) then
		local container = self:GetContainerForItem(item, button)
		if(not container) then
			if(button) then
				button.container:RemoveButton(button)
				self:SetButton(bagID, slotID, nil)
				button:Free()
			end
			return
		end
	
		if(button) then
			if(container ~= button.container) then
				button.container:RemoveButton(button)
				container:AddButton(button)
			end
		else
			button = self:GetClass("ItemButton"):New(bagID, slotID)
			self:SetButton(bagID, slotID, button)
			container:AddButton(button)
		end
	end

	if(button) then
		button:Handle(message, item)
	end
end

function Implementation:Source_Update(name, state)
	if(name ~= "bank") then return end

	if(state) then
		self:Open()
		if(self.OnBankOpened) then self:OnBankOpened() end
	else
		self:Close()
		if(self.OnBankClosed) then self:OnBankClosed() end
	end
end
