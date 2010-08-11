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
local cargBags = ns.cargBags

local itemButtonManagers = {}

cargBags:RegisterSource{
	name = "Default",

	pipes = {
		GetContainerItemInfo = function(self, bagID, slotID)
			return GetContainerItemInfo(bagID, slotID)
		end,

		GetContainerItemLink = function(self, bagID, slotID)
			return GetContainerItemLink(bagID, slotID)
		end,

		GetContainerItemCooldown = function(self, bagID, slotID)
			return GetContainerItemCooldown(bagID, slotID)
		end,

		GetContainerNumSlots = function(self, bagID)
			return GetContainerNumSlots(bagID)
		end,

		LoadItemInfo = function(self, i)
			local bagID, slotID = i.bagID, i.slotID
			i.clink = GetContainerItemLink(bagID, slotID)

			if(i.clink) then
				i.texture, i.count, i.locked, i.quality, i.readable = GetContainerItemInfo(bagID, slotID)
				i.cdStart, i.cdFinish, i.cdEnable = GetContainerItemCooldown(bagID, slotID)
				i.isQuestItem, i.questID, i.questActive = GetContainerItemQuestInfo(bagID, slotID)
				i.name, i.link, i.rarity, i.level, i.minLevel, i.type, i.subType, i.stackCount, i.equipLoc, i.texture = GetItemInfo(i.clink)
			end
		end,
	},

	events = {
		BAG_UPDATE = "BAG_UPDATE",
		BAG_UPDATE_COOLDOWN = "BAG_UPDATE_COOLDOWN",
		ITEM_LOCK_CHANGED = "ITEM_LOCK_CHANGED",
		UNIT_QUEST_LOG_CHANGED = "UNIT_QUEST_LOG_CHANGED",

		BAG_CLOSED = function(self, bagID)
			self.handler.closed = bagID
			self:OnEvent("BAG_UPDATE", bagID)
		end,

		PLAYERBANKSLOTS_CHANGED = function(self, bagID, slotID)
			if(bagID <= NUM_BANKGENERIC_SLOTS) then
				slotID, bagID = bagID, -1
			else
				bagID = bagID - NUM_BANKGENERIC_SLOTS
			end

			self:Update(bagID, slotID)
		end,
	},

	GetItemButtonManager = function(self, button)
		local bagID = button.bagID
		local tpl = (bagID == -1 and "BankItemButtonGenericTemplate") or "ContainerFrameItemButtonTemplate"
		return itemButtonManagers[tpl]
	end,
}

--[[!
	ItemButtonManagers
]]


local function Manager_OnLeave(self)
	self:Hide()
	if(self.manages.OnLeave) then
		self.manages:OnLeave()
	end
end

for i, tpl in pairs{ "BankItemButtonGenericTemplate", "ContainerFrameItemButtonTemplate" } do
	local manager = CreateFrame("Button", nil, nil, tpl)
	manager:HookScript("OnLeave", Manager_OnLeave)
	manager:SetAlpha(0)
	itemButtonManagers[tpl] = manager
end
