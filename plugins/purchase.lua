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
Plugin: Purchase

Description:
	Creates a button for purchasing bank slots

Spawn with:
	:SpawnPlugin("Purchase"): Create a purchase button
	:SpawnPlugin("Purchase", frame): Make this frame into a purchase button

Purchase properties:
	.Cost: Holds the money-plugin which displays the cost (Default: nil)
doc]]

-- Update the cost
local updater = function(self, event)
	local numSlots, isFull = cargBags:GetHandler().GetNumBankSlots()
	local cost = GetBankSlotCost(numSlots)

	if(isFull) then
		self:Hide()
		self.Cost:Hide()
	else
		local cost = GetBankSlotCost(numSlots)
		BankFrame.nextSlotCost = cost
		if(self.Cost and self.Cost.UpdateMoney) then
			self.Cost:UpdateMoney(cost)
		end
		self:Show()
		self.Cost:Show()
	end
end

-- Buy a slot
local function purchaseClick()
	StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
end

-- Register the purchase plugin
cargBags:RegisterPlugin("Purchase", function(self, frame)
	local button
	if(frame) then -- Use our own frame
		button = frame
	else -- Spawn the default one
		button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
		button:SetWidth(121)
		button:SetHeight(21)
	end
	button.Object = self
	gButton = button
	button:SetScript("OnClick", purchaseClick)
	cargBags:AddCallback(button, updater)
	return button
end)