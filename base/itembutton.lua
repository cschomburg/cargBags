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
local _, ns = ...
local cargBags = ns.cargBags

--[[!
	@class ItemButton
		This class serves as the basis for all itemSlots in a container
]]
local ItemButton = cargBags:NewClass("ItemButton", nil, "Button")

ItemButton.glowTex = "Interface\\Buttons\\UI-ActionButton-Border" --! @property glowTex <string> The textures used for the glow
ItemButton.glowAlpha = 0.8 --! @property glowAlpha <number> The alpha of the glow texture
ItemButton.glowBlend = "ADD" --! @property glowBlend <string> The blendMode of the glow texture
ItemButton.glowCoords = { 14/64, 50/64, 14/64, 50/64 } --! @property glowCoords <table> Indexed table of texCoords for the glow texture
ItemButton.bgTex = nil --! @property bgTex <string> Texture used as a background if no item is in the slot

--[[!
	Gets a template name for the bagID
	@param bagID <number> [optional]
	@return tpl <string>
]]
function ItemButton:GetTemplate(bagID)
	bagID = bagID or self.bagID
	return (bagID == -1 and "BankItemButtonGenericTemplate") or (bagID and "ContainerFrameItemButtonTemplate") or "ItemButtonTemplate"
end

local mt_gen_key = {__index = function(self,k) self[k] = {}; return self[k]; end}

--[[!
	Fetches a new instance of the ItemButton, creating one if necessary
	@param bagID <number>
	@param slotID <number>
	@return button <ItemButton>
]]
function ItemButton:New(bagID, slotID)
	self.recycled = self.recycled or setmetatable({}, mt_gen_key)

	local tpl = self:GetTemplate(bagID)
	local button = tremove(self.recycled[tpl]) or self:Create(tpl)

	button.bagID = bagID
	button.slotID = slotID
	button:SetID(slotID)
	button:Show()

	return button
end

--[[!
	Creates a new ItemButton
	@param tpl <string> The template to use [optional]
	@return button <ItemButton>
	@callback button:OnCreate(tpl)
]]
local slotsNum = 0
function ItemButton:Create(tpl)
	slotsNum = slotsNum+1
	local name = "cargBagsSlot"..slotsNum

	local button = setmetatable(CreateFrame("Button", name, nil, tpl), self.__index)

	button:SetSize(37, 37)

	button.Icon = 		_G[name.."IconTexture"]			--! @property Icon <widget> The button's IconTexture
	button.Count = 		_G[name.."Count"]				--! @property Count <widget> The button's Count-FontString
	button.Cooldown = 	_G[name.."Cooldown"]			--! @property Cooldown <widget> The button's Cooldown-Widget
	button.Quest = 		_G[name.."IconQuestTexture"]	--! @property Quest <widget> The button's IconQuestTexture
	button.Border =		_G[name.."NormalTexture"]		--! @property Border <widget> The button's NormalTexture

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

--[[!
	Update the button with new item-information
	@param item <table> The itemTable holding information, see Implementation:GetItemInfo()
	@callback OnUpdate(item)
]]
function ItemButton:Update(item)
	self.Icon:SetTexture(item.texture or self.bgTex)

	if(item.count and item.count > 1) then
		self.Count:SetText(item.count >= 1e3 and "*" or item.count)
		self.Count:Show()
	else
		self.Count:Hide()
	end
	self.count = item.count -- Thank you Blizz for not using local variables >.> (BankFrame.lua @ 234 )

	self:UpdateCooldown(item)
	self:UpdateLock(item)
	self:UpdateQuest(item)

	if(self.OnUpdate) then self:OnUpdate(item) end
end

--[[!
	Updates the buttons cooldown with new item-information
	@param item <table> The itemTable holding information, see Implementation:GetItemInfo()
	@callback OnUpdateCooldown(item)
]]
function ItemButton:UpdateCooldown(item)
	if(item.cdEnable and item.cdStart and item.cdStart > 0) then
		self.Cooldown:SetCooldown(item.cdStart, item.cdFinish)
		self.Cooldown:Show()
	else
		self.Cooldown:Hide()
	end

	if(self.OnUpdateCooldown) then self:OnUpdateCooldown(item) end
end

--[[!
	Updates the buttons lock with new item-information
	@param item <table> The itemTable holding information, see Implementation:GetItemInfo()
	@callback OnUpdateLock(item)
]]
function ItemButton:UpdateLock(item)
	self.Icon:SetDesaturated(item.locked)

	if(self.OnUpdateLock) then self:OnUpdateLock(item) end
end

--[[!
	Updates the buttons quest texture with new item information
	@param item <table> The itemTable holding information, see Implementation:GetItemInfo()
	@callback OnUpdateQuest(item)
]]
function ItemButton:UpdateQuest(item)
	local r,g,b,a = 1,1,1,1
	local tL,tR,tT,tB = 0,1, 0,1
	local blend = "BLEND"
	local texture

	if(item.questID and not item.questActive) then
		texture = TEXTURE_ITEM_QUEST_BANG
	elseif(item.questID or item.isQuestItem) then
		texture = TEXTURE_ITEM_QUEST_BORDER
	elseif(item.rarity and item.rarity > 1 and self.glowTex) then
		a, r,g,b = self.glowAlpha, GetItemQualityColor(item.rarity)
		texture = self.glowTex
		blend = self.glowBlend
		tL,tR,tT,tB = unpack(self.glowCoords)
	end

	if(texture) then
		self.Quest:SetTexture(texture)
		self.Quest:SetTexCoord(tL,tR,tT,tB)
		self.Quest:SetBlendMode(blend)
		self.Quest:SetVertexColor(r,g,b,a)
		self.Quest:Show()
	else
		self.Quest:Hide()
	end

	if(self.OnUpdateQuest) then self:OnUpdateQuest(item) end
end

--[[!
	Fetches the item-info of the button, just a small wrapper for comfort
	@param item <table> [optional]
	@return item <table>
]]
function ItemButton:GetItemInfo(item)
	return self.implementation:GetItemInfo(self.bagID, self.slotID, item)
end
