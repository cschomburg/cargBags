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
local Core = ns.cargBags

local ItemButton = Core.Class:New("ItemButton", nil, "Button")

local mt_gen_key = {__index = function(self,k) self[k] = {}; return self[k]; end}

--[[!
	Fetches a new instance of the ItemButton, creating one if necessary
	-> bagID <number>
	-> slotID <number>
	<- button <ItemButton>
]]
function ItemButton:New(bagID, slotID)
	self.recycled = self.recycled or setmetatable({}, mt_gen_key)

	local tpl = self:GetTemplate(bagID, slotID)
	local button = table.remove(self.recycled[tpl]) or self:Create(tpl, bagID)

	button.bagID = bagID
	button.slotID = slotID
	button:SetID(slotID)
	button:Show()

	return button
end

--[[!
	Gets a template name for the bagID
	-> bagID <number> [optional]
	<- tpl <string>
]]
function ItemButton:GetTemplate(bagID, slotID)
	bagID = bagID or self.bagID
	slotID = slotID or self.slotID

	return Core.source:GetButtonTemplate(bagID, slotID)
end

--[[!
	Creates a new ItemButton
	-> tpl <string> The template to use [optional]
	<- button <ItemButton>
	@callback button:OnCreate(tpl)
]]

local numSlots = 0
function ItemButton:Create(tpl, bagID)
	numSlots = numSlots + 1
	local name = ("%sSlot%d"):format(Core.name, numSlots)

	local frame = CreateFrame("Frame")
	frame:SetID(bagID)
	local button = self:NewInstance(name, frame, tpl)
	if(Core.source.OnButtonCreate) then Core.source:OnButtonCreate(button) end

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

ItemButton.handlers = {}

--[[!
	Handle button-specific internal events
	-> message <string> message-part of the event
	-> item <ItemTable> item data
]]
function ItemButton:Handle(message, item)
	local funcName = self.handlers[message]
	if(funcName) then
		self[funcName](self, item)
	end
end

--[[!
	Shortcut, fetches the item-data of the button
	-> item <table> [optional]
	<- item <table>
]]
function ItemButton:LoadItemInfo(item)
	return Core:LoadItemInfo(self.bagID, self.slotID, item)
end

--[[!
	Applies a button Scaffold to the button class
	-> scaffold <string, Scaffold>
	-> ... arguments passed to scaffold function
]]
function ItemButton:Scaffold(scaffold, ...)
	if(type(scaffold) == "string") then
		scaffold = Core:Get("scaffold", scaffold, true)
	end
	return scaffold(self, ...)
end
