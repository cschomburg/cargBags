--[[
    Copyright (C) 2009  Constantin Schomburg

    This file is part of cargBags.

    cargBags is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    cargBags is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with cargBags.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[doc
Handler: Standard

Description:
	Provides item and container information for cargBags

Pipe functions:
	See Blizz-API for complete syntax, you should provide these as default:
	GetContainerNumSlots
	GetContainerNumFreeSlots
	GetContainerItemInfo
	GetContainerItemLink
	GetInventoryItemLink
	GetInventoryItemTexture
	GetNumBankSlots
	GetMoney

Callback functions:
	:Enabled(): called when this handler was enabled
	:Disable(): called when this handler was disabled
	template = :GetButtonTemplate(bagID, slotID): Return the needed template for this button
	button = :CreateButton(template, name): Return an item button with the passed name and template type
	:LoadItemInfo(item): Write all available item data into the passed table
	.BagSlotButton_OnEnter(button): called when a bag slot is entered by the mouse cursor
	success = .PutItemInBag(bagID, slotID): Puts the item from the cursor in the selected container
	PickupBagFromSlot(bagID, slotID): called when a bag should be picked from its bag slot
doc]]

local handler = CreateFrame"Frame"
handler.GetContainerNumSlots = GetContainerNumSlots
handler.GetContainerNumFreeSlots = GetContainerNumFreeSlots
handler.GetContainerItemInfo = GetContainerItemInfo
handler.GetContainerItemLink = GetContainerItemLink
handler.PutItemInBag = PutItemInBag
handler.BagSlotButton_OnEnter = BagSlotButton_OnEnter
handler.PickupBagFromSlot = PickupBagFromSlot
handler.GetInventoryItemLink = GetInventoryItemLink
handler.GetInventoryItemTexture = GetInventoryItemTexture
handler.GetNumBankSlots = GetNumBankSlots
handler.GetMoney = GetMoney

handler:SetScript("OnEvent", function(self, event, ...) cargBags:UpdateBags(event, ...) end)

-- Enable the handler ...
function handler:Enable()
	self:RegisterEvent"PLAYER_LOGIN"
	self:RegisterEvent"BAG_UPDATE"
	self:RegisterEvent"ITEM_LOCK_CHANGED"
	self:RegisterEvent"BAG_UPDATE_COOLDOWN"
	self:RegisterEvent"BANKFRAME_OPENED"
	self:RegisterEvent"PLAYERBANKSLOTS_CHANGED"
	self:RegisterEvent"PLAYERBANKBAGSLOTS_CHANGED"
	self:RegisterEvent"BAG_CLOSED"
	self:RegisterEvent"PLAYER_MONEY"
end

-- ... and disable it
handler.Disable = handler.UnregisterAllEvents

-- Which button template is needed?
function handler:GetButtonTemplateName(bagID, slotID)
	if(bagID == BANK_CONTAINER) then
		return "BankItemButtonGenericTemplate"
	else
		return "ContainerFrameItemButtonTemplate"
	end
end

-- Create an item button with the defined template and name
function handler:CreateButton(template, name)
	local button = CreateFrame("Button", name, nil, template)
	button.Count = _G[name.."Count"]
	button.Icon = _G[name.."IconTexture"]
	button.Cooldown = _G[name.."Cooldown"]
	button.NormalTexture = _G[name.."NormalTexture"]
	button:SetHeight(37)
	button:SetWidth(37)
	return button
end

function handler:LoadItemInfo(i)
	local bagID, slotID = i.bagID, i.slotID
	i.clink = GetContainerItemLink(bagID, slotID)
	i.texture, i.count, i.locked, i.quality, i.readable = GetContainerItemInfo(bagID, slotID)
	i.cdStart, i.cdFinish, i.cdEnable = GetContainerItemCooldown(bagID, slotID)
end

-- Register the handler
cargBags:RegisterHandler("Standard", handler)