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

-- YOU CAN FIND A DETAILED DOCUMENTATION UNDER:
-- http://wiki.github.com/xconstruct/cargBags

local _G = getfenv(0)
local FadeContainer
-- Fading functions
FadeContainer = function(self, id, main)
	if(not self.Bags) then
		if(not main) then return end
		for _, object in ipairs(cargBags.Objects) do
			FadeContainer(object, id)
		end
	else
		for bagID, bag in pairs(self.Bags) do
			if(not id or bagID == id ) then
				bag:SetAlpha(1)
			else
				bag:SetAlpha(self.BagBar and self.BagBar.FadeAlpha or .31)
			end
		end
	end
end

-- Hover = Fade
local EnterAndFade = function(self)
	local handler = cargBags:GetHandler()
	if(not self.Bar.NoFading) then FadeContainer(self.Object, self.bagID, true) end
	if(handler.BagSlotButton_OnEnter) then
		handler.BagSlotButton_OnEnter(self)
	end
end

-- Leave = Restore fade
local LeaveAndFade = function(self)
	if(not self.Bar.NoFading) then FadeContainer(self.Object, nil, true) end
	GameTooltip:Hide()
end

-- Hide the clicked bag ...
local BagButtonClick = function(self)
	local object = self.Object
	local handler = cargBags:GetHandler()
	if(not (handler.PutItemInBag and handler.PutItemInBag(self.id))) then
		local bag = object.Bags and object.Bags[self.bagID]
		if(bag) then
			bag.Hidden = not bag.Hidden
			cargBags:UpdateBags("CB_BAG_HIDDEN", object, self.bagID)
		else
			self:SetChecked(0)
		end
	end
end

-- ... or drag it
local BagButtonDrag = function(self)
	local handler = cargBags:GetHandler()
	if(handler.PickupBagFromSlot) then
		handler.PickupBagFromSlot(self.id)
	end
end

-- small helper for creating the buttons ...
local createBagButton = function(self, i, bagID)
	local name = self.Object.Name.."BagButton"..(#self.Bags)
	local button = CreateFrame("CheckButton", name, self, "ItemButtonTemplate")
	button:SetWidth(37)
	button:SetHeight(37)
	button.Bar = self
	button.Object = self.Object


	local id = cargBags.C2I(bagID)
	button.id = id
	button.bagID = bagID
	button:SetID(id)
	button:RegisterForDrag("LeftButton", "RightButton")
	button:RegisterForClicks("anyUp")
	button:SetPoint("TOPLEFT", (i-1) * 38, 0)
	button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")

	button:SetScript("OnClick", BagButtonClick)
	button:SetScript("OnReceiveDrag", BagButtonClick)
	button:SetScript("OnEnter", EnterAndFade)
	button:SetScript("OnLeave", LeaveAndFade)
	button:SetScript("OnDragStart", BagButtonDrag)

	self.Bags[i] = button
	return button
end

-- ... or a fake one for the key ring
local createKeyButton = function(self)
	local button = CreateFrame("CheckButton", nil, self)
	button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetWidth(18)
	button:SetHeight(37)
	button:SetPoint("TOPLEFT", (#self.Bags) * 38, 0)
	button:RegisterForClicks("LeftButtonUp")
	self:SetWidth(self:GetWidth()+19)

	local texture = button:CreateTexture()
	texture:SetTexture('Interface/Buttons/UI-Button-KeyRing')
	texture:SetAllPoints(button)
	texture:SetTexCoord(0, 0.5625, 0, 0.609375)

	button.Texture = texture
	button.Bar = self
	button.Object = self.Object

	return button
end

local bagButtonTexture = [[interface\paperdoll\UI-PaperDoll-Slot-Bag]]

-- Updating the icons
local function updater(self, event)
	if(event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_COOLDOWN") then return end

	local handler = cargBags:GetHandler()
	local object = self.Object
	for _, button in pairs(self.Bags) do
		cargBags.Fire(self, "PreUpdateBagButton", button)
		local bagID = button.bagID
		if(bagID > NUM_BAG_SLOTS) then
			if(bagID-NUM_BAG_SLOTS <= handler.GetNumBankSlots()) then
				SetItemButtonTextureVertexColor(button, 1.0,1.0,1.0);
				button.tooltipText = BANK_BAG
			else
				SetItemButtonTextureVertexColor(button, 1.0,0.1,0.1);
				button.tooltipText = BANK_BAG_PURCHASE
			end
		end
		local icon = handler.GetInventoryItemTexture("player", button.id)
		local texture = _G[button:GetName().."IconTexture"]
		texture:SetTexture(icon or self.BackgroundTexture or bagButtonTexture)
		button.backgroundTextureName = self.BackgroundTexture or bagButtonTexture

		if(object.Bags) then
			local bag = object.Bags[button.bagID]
			button:SetChecked(not bag or bag.Hidden)
		else
			button:SetChecked(nil)
		end
		cargBags.Fire(self, "PostUpdateBagButton", button)
	end
end

-- Register the plugin
cargBags:RegisterPlugin("BagBar", function(self, bagType)
	cargBags.assertf(type(bagType) == "string" or type(bagType) == "table", "Bad argument #2 to 'SpawnPlugin(BagBar)': (string/table expected, got %s", type(bagType))
	local table = cargBags:ParseBags(bagType)
	local bar = CreateFrame("Frame",  nil, self)
	bar.Object = self
	bar.CreateKeyRingButton = createKeyButton

	bar.Bags = {}
	for i=1, #table do
		createBagButton(bar, i, table[i])
	end

	bar:SetWidth(38*#bar.Bags-1)
	bar:SetHeight(37)

	cargBags:AddCallback(bar, updater)

	return bar
end)
