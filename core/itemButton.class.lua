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
local Implementation = ns.cargBags

--[[!
	@class ItemButton
		This class serves as the basis for all itemSlots in a container
]]
local ItemButton = Implementation.Class:New("ItemButton", nil, "Button")
ItemButton.handlers = {}

--[[!
	Gets a template name for the bagID
	@param bagID <number> [optional]
	@return tpl <string>
]]
function ItemButton:GetTemplate(bagID, slotID)
	bagID = bagID or self.bagID
	slotID = slotID or self.slotID

	return Implementation.source:GetButtonTemplate(bagID, slotID)
end

local mt_gen_key = {__index = function(self,k) self[k] = {}; return self[k]; end}

--[[!
	Fetches a new instance of the ItemButton, creating one if necessary
	@param bagID <number>
	@param slotID <number>
	@return button <ItemButton>
]]
function ItemButton:New(bagID, slotID)
	self.recycled = self.recycled or setmetatable({}, mt_gen_key)

	local tpl = self:GetTemplate(bagID, slotID)
	local button = table.remove(self.recycled[tpl]) or self:Create(tpl)

	button.bagID = bagID
	button.slotID = slotID
	button:SetID(slotID)
	button:Show()

	return button
end

--[[!
	Creates a new ItemButton
	@param tpl <string> The template to use [optional]
	@return button <ItemButton>
	@callback button:OnCreate(tpl)
]]

local numSlots = 0
function ItemButton:Create(tpl)
	numSlots = numSlots + 1
	local name = ("%sSlot%d"):format(Implementation.name, numSlots)

	local button = self:NewInstance(name, nil, tpl)
	if(Implementation.source.OnButtonCreate) then Implementation.source:OnButtonCreate(button) end

	if(button.Scaffold) then button:Scaffold(tpl) end
	if(button.OnCreate) then button:OnCreate(tpl) end

	return button
end

--[[!
	Frees an ItemButton, storing it for later use
]]
function ItemButton:Free()
	self:Hide()
	table.insert(self.recycled[self:GetTemplate()], self)
end

function ItemButton:Handle(message, item)
	local funcName = self.handlers[message]
	if(funcName) then
		self[funcName](self, item)
	end
end

--[[!
	Fetches the item-info of the button, just a small wrapper for comfort
	@param item <table> [optional]
	@return item <table>
]]
function ItemButton:GetItemInfo(item)
	return Implementation:GetItemInfo(self.bagID, self.slotID, item)
end

function ItemButton:Scaffold(name, ...)
	return Implementation:Get("scaffold", name)(self, ...)
end
