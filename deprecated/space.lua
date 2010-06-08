--[[
LICENSE
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
	Two simple space-displays for your bags.

	"Space" transforms a frame/table into a space-updater, provide frame:UpdateSpace(free, max) - e.g. :SpawnPlugin("Space", myFrame, "backpack+bags"
	"SpaceText" creates a tagged space-fontstring, e.g. :SpawnPlugin("SpaceText", "[used]/[max] used", "bankframe+bank") 
	
	Following tags are supported for tagString: [free], [used], [max]
	bags can either be a table of bagIDs or an argument for ParseBags, e.g. a bagString like "backpack"
DEPENDENCIES
	mixins/plugins
	mixins/parseBags (optional)
CALLBACKS
	:UpdateSpace(free, max) - only for default fontstring
]]


-- Update the space display
local function updater(self, event)
	local max, free = 0, 0
	if(self.bags) then
		for _, id in pairs(self.bags) do
			free = free + GetContainerNumFreeSlots(id)
			max = max + GetContainerNumSlots(id)
		end
	end

	if(self.UpdateSpace) then return self:UpdateSpace(free, max) end
end

-- Register the plugin
cargBags:RegisterPlugin("Space", function(self, frame, bags)
	frame.bags = type(bags) == "table" and bags or cargBags:ParseBags(bags)
	self.implementation:RegisterCallback("BAG_UPDATE", frame, updater)
	return frame
end)

local function updateSpaceText(self, free, max)
	local text = self.tagString or ""

	local text = text:gsub("%[free%]", free)
	text = text:gsub("%[used%]", max-free)
	text = text:gsub("%[max%]", max)
	self:SetText(text)

	if(self.OnUpdateSpace) then self:OnUpdateSpace(free, max) end
end

cargBags:RegisterPlugin("SpaceText", function(self, tagString, bags, parent)
	parent = parent or self
	local plugin = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

	plugin.tagString = tagString or "[free] / [max]"
	plugin.UpdateSpace = updateSpaceText

	return self:SpawnPlugin("Space", plugin, bags)
end)
