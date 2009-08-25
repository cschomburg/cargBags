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

--[[##############################
	Common layout functions
		extending the BagObject
################################]]

local BagObject = cargBags.BagObject

local hasOGlow = oGlow and oGlow.RegisterPipe
local createGlow
if(hasOGlow) then
	local function dummy() end
	oGlow:RegisterPipe('cargBags', dummy, nil, dummy, [[cargBags, an inventory framework.]])
	oGlow:RegisterFilterOnPipe('cargBags', 'quality')
	oGlow:RegisterFilterOnPipe('cargBags', 'quest')
else
	createGlow = function(button)
		local glow = button:CreateTexture(nil, "OVERLAY")
		glow:SetTexture"Interface\\Buttons\\UI-ActionButton-Border"
		glow:SetBlendMode"ADD"
		glow:SetAlpha(.8)
		glow:SetWidth(70)
		glow:SetHeight(70)
		glow:SetPoint("CENTER", button)
		button.Glow = glow
	end
end

function BagObject:UpdateButton(button, item)
	if(button.Icon) then
		local icon = button.Icon
		button.Icon:SetTexture(item.texture)
		button.Icon:SetTexCoord(0.03, 0.98, 0.03, 0.98)
	end
	if(button.Count) then
		local count = button.Count
		if(item.count > 1) then
			count:SetText(item.count and item.count >= 1e3 and "*" or item.count)
			count:Show()
		else
			count:Hide()
		end
	end

	-- Color the button's border based on the item's rarity / quality!
	if(not self.NoGlow) then
		if(hasOGlow) then
			oGlow:CallFilters('cargBags', button, item.link)
		elseif(item.rarity and item.rarity > 1) then
			if(not button.Glow) then createGlow(button) end
			button.Glow:SetVertexColor(GetItemQualityColor(item.rarity))
			button.Glow:Show()
		elseif(button.Glow) then
			button.Glow:Hide()
		end
	end
end

function BagObject:UpdateButtonLock(button, item)
	if(button.Icon) then
		button.Icon:SetDesaturated(item.locked)
	end
end

function BagObject:UpdateButtonCooldown(button, item)
	if(button.Cooldown) then
		CooldownFrame_SetTimer(button.Cooldown, item.cdStart, item.cdFinish, item.cdEnable) 
	end
end

function BagObject:UpdateButtonPositions()
	local button
	local col, row = 0, 0

	for _, button in self:IterateButtons() do
		button:ClearAllPoints()
		local xPos = col * 38 + 10
		local yPos = -1 * row * 38 - margin

		button:SetPoint("TOPLEFT", self, "TOPLEFT", xPos, yPos)	 
		if(col >= self.Columns-1) then	 
			col = 0	 
			row = row + 1	 
		else	 
			col = col + 1	 
		end
	end

	local height = (row + (col>0 and 1 or 0)) * 38 + margin
	self:Fire("UpdateDimensions", height)
end