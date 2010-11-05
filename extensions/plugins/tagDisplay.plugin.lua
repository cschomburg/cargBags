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
	An infotext-module which can display several things based on tags.

	Supported tags:
		space - specify a formatstring as arg #1, using "free" / "max" / "used"
		item - count of the item in arg #1 (itemID, itemLink, itemName)
		currency - displays the currency with id arg #1
			currencies - displays all tracked currencies
		money - formatted money display

	The space-tag still needs .bags defined in the plugin!
	e.g. tagDisplay.bags = Core:ParseBags("backpack+bags")

PROVIDES
	plugin: TagDisplay
]]

local addon, ns = ...
local Implementation = ns.cargBags

local tagPool, tagEvents, object = {}, {}
local function tagger(tag, ...)
	local tagFunc = Implementation:Get("tag", tag)
	return tagFunc and tagFunc(object, ...) or ""
end

-- Update the space display
local function EventFrame_Update(self)
	object = self.parent
	object:SetText(object.tagString:gsub("%[([^%]:]+):?(.-)%]", tagger))

	if(object.OnTagUpdate) then object:OnTagUpdate(event) end
end

local function TagDisplay_SetTagString(self, tagString)
	self.tagString = tagString
	self.eventframe:UnregisterAllEvents()
	for tag in tagString:gmatch("%[([^%]:]+):?.-]") do
		local tagEvents = Implementation:Get("tagEvents", tag)
		if(tagEvents) then
			for i, event in pairs(tagEvents) do
				if(event:upper() == event) then
					self.eventframe:RegisterEvent(event)
				else
					Implementation:RegisterCallback(event, self.eventframe, EventFrame_Update)
				end
			end
		end
	end
	EventFrame_Update(self.eventframe)
end

Implementation:Register("plugin", "TagDisplay", function(self, tagString, parent)
	parent = parent or self
	tagString = tagString or ""

	local plugin = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	plugin.implementation = self.implementation
	plugin.SetTagString = TagDisplay_SetTagString
	plugin.tags = tagPool
	plugin.tagEvents = tagEvents
	plugin.iconValues = "16:16:0:0"

	local eventframe = CreateFrame("Frame")
	eventframe:SetScript("OnEvent", EventFrame_Update)
	eventframe.parent = plugin
	plugin.eventframe = eventframe
	Implementation:RegisterEvent("Refresh", plugin.eventframe, EventFrame_Update)

	plugin:SetTagString(tagString)

	return plugin
end)

local function createIcon(icon, iconValues)
	if(type(iconValues) == "table") then
		iconValues = table.concat(iconValues, ":")
	end
	return ("|T%s:%s|t"):format(icon, iconValues)
end


-- Tags

Implementation:Register("tag", "space", function(self, str)
	if(not self.bags) then
		return "no bags defined"
	end
	
	local free, max = 0, 0
	for i, bagID in pairs(self.bags) do
		local bMax, bFree = Implementation.source:GetBagSlotInfo(bagID, "slots")
		free = free + bFree
		max = max + bMax
	end
	str = str or "free/max"
	return str:gsub("free", free):gsub("max", max):gsub("used", max-free)
end)
Implementation:Register("tagEvents", "space", { "Items_Update" })

Implementation:Register("tag", "item", function(self, item)
	local bags = GetItemCount(item, nil)
	local total = GetItemCount(item, true)
	local bank = total-bags

	if(total > 0) then
		return bags .. (bank and " ("..bank..")") .. createIcon(GetItemIcon(item), self.iconValues)
	end
end)

Implementation:Register("tag", "currency", function(self, id)
	local name, count, icon = GetBackpackCurrencyInfo(id)

	if(type == 1) then
		icon = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
	elseif(type == 2) then
		icon = "Interface\\PVPFrame\\PVP-Currency-"..UnitFactionGroup("player")
	end

	if(count) then
		return count .. createIcon(icon, self.iconValues)
	end
end)
Implementation:Register("tagEvents", "currency", { "CURRENCY_DISPLAY_UPDATE" })

Implementation:Register("tag", "currencies", function(self)
	local str
	for i=1, GetNumWatchedTokens() do
		local curr = Implementation:Get("tag", "currency")(self, i)
		if(curr) then
			str = (str and str.." " or "")..curr
		end
	end
	return str
end)
Implementation:Register("tagEvents", "currencies", Implementation:Get("tagEvents", "currency"))

Implementation:Register("tag", "money", function(self)
	local money = GetMoney() or 0
	local str

	local g,s,c = floor(money/1e4), floor(money/100) % 100, money % 100

	if(g > 0) then str = (str and str.." " or "") .. g .. createIcon("Interface\\MoneyFrame\\UI-GoldIcon", self.iconValues) end
	if(s > 0) then str = (str and str.." " or "") .. s .. createIcon("Interface\\MoneyFrame\\UI-SilverIcon", self.iconValues) end
	if(c > 0) then str = (str and str.." " or "") .. c .. createIcon("Interface\\MoneyFrame\\UI-CopperIcon", self.iconValues) end
	return str
end)
Implementation:Register("tagEvents", "money", { "PLAYER_MONEY" })
