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
	A collection of buttons for the bags.

	The buttons are not positioned automatically, use the standard-
	function :LayoutButtons() for this

DEPENDENCIES
	mixins/parseBags (optional)
	base-add/filters.sieve.lua (optional)

CALLBACKS
	BagButton:OnCreate(bagID)
]]

local addon, ns = ...
local Implementation = ns.cargBags
Implementation:Provides("BagBar")

local BagButton = Implementation.Class:New("BagButton", nil, "CheckButton")

-- Default attributes
BagButton.checkedTex = [[Interface\Buttons\CheckButtonHilight]]
BagButton.bgTex = [[Interface\Paperdoll\UI-PaperDoll-Slot-Bag]]
BagButton.itemFadeAlpha = 0.1

local buttonNum = 0
function BagButton:Create(bagID)
	buttonNum = buttonNum+1
	local name = addon.."BagButton"..buttonNum

	local button = self:NewInstance(name, nil, "ItemButtonTemplate")

	button.bagID = bagID

	button:RegisterForDrag("LeftButton", "RightButton")
	button:RegisterForClicks("anyUp")
	button:SetCheckedTexture(self.checkedTex, "ADD")

	button:SetSize(37, 37)

	button.Icon = 		_G[name.."IconTexture"]
	button.Count = 		_G[name.."Count"]
	button.Cooldown = 	_G[name.."Cooldown"]
	button.Quest = 		_G[name.."IconQuestTexture"]
	button.Border =		_G[name.."NormalTexture"]

	button:SetScriptHandlers("OnClick", "OnReceiveDrag", "OnEnter", "OnLeave", "OnDragStart")

	if(button.OnCreate) then button:OnCreate(bagID) end

	return button
end

function BagButton:Update()
	local source = Implementation.source
	local icon, link, locked, enabled = source:GetBagSlotInfo(self.bagID)
	self.Icon:SetTexture(icon or self.bgTex)
	self.Icon:SetDesaturated(locked)

	if(source:GetBagSlotInfo(self.bagID, "purchased")) then
		self.Icon:SetVertexColor(1, 1, 1)
		self.notBought = nil
	else
		self.notBought = true
		self.Icon:SetVertexColor(1, 0, 0)
	end

	self:SetChecked(not self.hidden and not self.notBought)

	if(self.OnUpdate) then self:OnUpdate() end
end

local function highlight(button, func, bagID)
	func(button, not bagID or button.bagID == bagID)
end

function BagButton:OnEnter()
	local hlFunction = self.bar.highlightFunction

	if(hlFunction) then
		if(self.bar.isGlobal) then
			for i, container in pairs(Implementation.containers) do
				container:ApplyToButtons(highlight, hlFunction, self.bagID)
			end
		else
			self.bar.container:ApplyToButtons(highlight, hlFunction, self.bagID)
		end
	end

	local icon, link, locked = Implementation.source:GetBagSlotInfo(self.bagID)

	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	if(link) then
		GameTooltip:SetHyperlink(link)
	else
		GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1)
	end
end

function BagButton:OnLeave()
	local hlFunction = self.bar.highlightFunction

	if(hlFunction) then
		if(self.bar.isGlobal) then
			for i, container in pairs(Implementation.contByID) do
				container:ApplyToButtons(highlight, hlFunction)
			end
		else
			self.bar.container:ApplyToButtons(highlight, hlFunction)
		end
	end

	GameTooltip:Hide()
end

function BagButton:OnClick()
	if(self.notBought) then
		self:SetChecked(nil)
		BankFrame.nextSlotCost = GetBankSlotCost(GetNumBankSlots())
		return StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
	end

	if(Implementation.source:PutItemInBag(self.bagID)) then return end

	-- Somehow we need to disconnect this from the filter-sieve
	local container = self.bar.container
	if(container and container.SetFilter) then
		if(not self.filter) then
			local bagID = self.bagID
			self.filter = function(i) return i.bagID ~= bagID end
		end
		self.hidden = not self.hidden

		if(self.bar.isGlobal) then
			for i, container in pairs(Implementation.containers) do
				container:SetFilter(self.filter, self.hidden)
			end
			Implementation:ForceUpdate(self.bagID)
		else
			container:SetFilter(self.filter, self.hidden)
			Implementation:ForceUpdate(self.bagID)
		end
	end
end
BagButton.OnReceiveDrag = BagButton.OnClick

function BagButton:OnDragStart()
	Implementation.source:PickupBag(self.bagID)
end

local disabled = {
	[-2] = true,
	[-1] = true,
	[0] = true,
}

-- Register the plugin
Implementation:Register("plugin", "BagBar", function(self, bags, bagButtonClass)
	if(Implementation.ParseBags) then
		bags = Implementation:ParseBags(bags)
	end

	local bar = CreateFrame("Frame",  nil, self)
	bar.container = self

	bar.LayoutButtons = Implementation.Class:Get("Container").LayoutButtons

	local buttonClass = Implementation:GetClass("BagButton", bagButtonClass)
	bar.buttons = {}
	for i=1, #bags do
		if(not disabled[bags[i]]) then -- Temporary until I include fake buttons for backpack, bankframe and keyring
			local button = buttonClass:Create(bags[i])
			button:SetParent(bar)
			button.bar = bar
			Implementation:RegisterCallback("Refresh", button, button.Update)
			Implementation:RegisterCallback("Inventory_Lock_Changed", button, button.Update)
			table.insert(bar.buttons, button)
		end
	end

	return bar
end)
