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

--[[
Tooltip Table of ItemKeys

Description:
	Custom item data which can be addressed like the default one (item.key)
	This data requires to parse a tooltip to work, so it gets its extra file
]]

local function generateTooltip()
	local tooltip = CreateFrame("GameTooltip", "cargBagsTooltip")
	tooltip:SetOwner(WorldFrame, "ANCHOR_NONE") 
	tooltip:AddFontStrings( 
		tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"), 
		tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
	)
end

cargBags.ItemKeys["bindOn"] = function(i)
	if(not i.link) then return end
	if(not cargBagsTooltip) then generateTooltip() end
	cargBagsTooltip:ClearLines()
	cargBagsTooltip:SetHyperlink(i.link)
	local bound = cargBagsTooltipTextLeft2 and cargBagsTooltipTextLeft2:GetText()
	if(not bound) then return end

	local bindOn
	if(bound:match(ITEM_BIND_ON_EQUIP)) then bindOn = "equip"
	elseif(bound:match(ITEM_BIND_QUEST)) then bindOn = "quest"
	elseif(bound:match(ITEM_BIND_TO_ACCOUNT)) then bindOn = "account"
	elseif(bound:match(ITEM_BIND_ON_PICKUP)) then bindOn = "pickup"
	elseif(bound:match(ITEM_BIND_ON_USE)) then bindOn = "use" end
	i.bindOn = bindOn
	return bindOn
end

cargBags.ItemKeys["stats"] = function(i)
	if(not i.link or not GetItemStats) then return end
	local stats = GetItemStats(i.link)
	i.stats = stats
	return stats
end
