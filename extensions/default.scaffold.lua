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
	Provides a Scaffold that generates a default Blizz' ContainerButton

PROVIDES
	scaffold: Default
]]

local addon, ns = ...
local Core = ns.cargBags

local function noop() end

--[[!
	Apply scaffold options to this instance
]]
local function ItemButton_Scaffold(self)
	self:SetSize(37, 37)

	local name = self:GetName()
    --[[ keyed in ItemButtonTemplate 
        self.icon - IconTexture
        self.Count
        self.searchOverlay
        self.IconBorder
    ]]
    self.Stock =      _G[name.."Stock"]
    self.Border =     _G[name.."NormalTexture"]

    --[[ keyed in ContainerFrameItemButtonTemplate 
        self.JunkIcon
        self.flash
        self.NewItemTexture
        self.BattlepayItemTexture
    ]]
    self.Quest = _G[name.."IconQuestTexture"]
	self.Cooldown = _G[name.."Cooldown"]
end

--[[!
	Update the button with new item-data
	-> item <ItemTable>)
	@callback OnUpdate(item)
]]
local function ItemButton_Update(self, item)
	self.icon:SetTexture(item.texture or self.bgTex)

	if(item.count and item.count > 1) then
		self.Count:SetText(item.count >= 1e3 and "*" or item.count)
		self.Count:Show()
	else
		self.Count:Hide()
	end
	self.count = item.count

    if self.NewItemTexture then
        if C_NewItems.IsNewItem(item.bagID, item.slotID) then
            if IsBattlePayItem(item.bagID, item.slotID) then
                self.NewItemTexture:Hide();
                self.BattlepayItemTexture:Show();
            else
                if (self.quality and NEW_ITEM_ATLAS_BY_QUALITY[self.quality]) then
                    self.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[self.quality]);
                else
                    self.NewItemTexture:SetAtlas("bags-glow-white");
                end
                self.BattlepayItemTexture:Hide();
                self.NewItemTexture:Show();
            end
            if (not self.flashAnim:IsPlaying() and not self.newitemglowAnim:IsPlaying()) then
                self.flashAnim:Play();
                self.newitemglowAnim:Play();
            end
        else
            self.BattlepayItemTexture:Hide();
            self.NewItemTexture:Hide();
            if (self.flashAnim:IsPlaying() or self.newitemglowAnim:IsPlaying()) then
                self.flashAnim:Stop();
                self.newitemglowAnim:Stop();
            end
        end
    end

	self:UpdateCooldown(item)
	self:UpdateLock(item)
	self:UpdateQuest(item)

	if(self.OnUpdate) then self:OnUpdate(item) end
end

--[[!
	Updates the buttons cooldown with new item-data
	-> item <ItemTable>
	@callback OnUpdateCooldown(item)
]]
local function ItemButton_UpdateCooldown(self, item)
	if(item.cdEnable == 1 and item.cdStart and item.cdStart > 0) then
		self.Cooldown:SetCooldown(item.cdStart, item.cdFinish)
		self.Cooldown:Show()
	else
		self.Cooldown:Hide()
	end

	if(self.OnUpdateCooldown) then self:OnUpdateCooldown(item) end
end

--[[!
	Updates the buttons lock with new item-data
	-> item <ItemTable>
	@callback OnUpdateLock(item)
]]
local function ItemButton_UpdateLock(self, item)
	self.icon:SetDesaturated(item.locked)

	if(self.OnUpdateLock) then self:OnUpdateLock(item) end
end

--[[!
	Updates the buttons quest texture with new item-data
	-> item <ItemTable>
	@callback OnUpdateQuest(item)
]]
local function ItemButton_UpdateQuest(self, item)
    if not self.Quest then return end
	local r,g,b,a = 1,1,1,1
	local tL,tR,tT,tB = 0,1, 0,1
	local blend = "BLEND"
	local texture

	if(item.questID and not item.questActive) then
		texture = TEXTURE_ITEM_QUEST_BANG
	elseif(item.questID or item.isQuestItem) then
		texture = TEXTURE_ITEM_QUEST_BORDER
	elseif(item.quality and item.quality > 1 and self.glowTex) then
		a, r,g,b = self.glowAlpha, GetItemQualityColor(item.quality)
		texture = self.glowTex
		blend = self.glowBlend
		tL,tR,tT,tB = unpack(self.glowCoords)
	end

	if (texture) then
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

Core:Register("scaffold", "Default", function(self)
	self.glowTex = "Interface\\Buttons\\UI-ActionButton-Border"		--! [] glowTex <string> The textures used for the glow
	self.glowAlpha = 0.8											--! [] glowAlpha <number> The alpha of the glow texture
	self.glowBlend = "ADD"											--! [] glowBlend <string> The blendMode of the glow texture
	self.glowCoords = { 14/64, 50/64, 14/64, 50/64 }				--! [] glowCoords <table> Indexed table of texCoords for the glow texture
	self.bgTex = nil												--! [] bgTex <string> Texture used as a background if no item is in the slot

	self.CreateFrame = ItemButton_CreateFrame
	self.Scaffold = ItemButton_Scaffold

	self.Update = ItemButton_Update
	self.UpdateCooldown = ItemButton_UpdateCooldown
	self.UpdateLock = ItemButton_UpdateLock
	self.UpdateQuest = ItemButton_UpdateQuest

	self.handlers['added'] = "Update"
	self.handlers['removed'] = "Update"
	self.handlers['changed'] = "Update"
	self.handlers['forced'] = "Update"
	self.handlers['count'] = "Update"
	self.handlers['lock'] = "UpdateLock"
	self.handlers['cooldown'] = "UpdateCooldown"
	self.handlers['quest'] = "UpdateQuest"

	self.OnEnter = ItemButton_OnEnter
	self.OnLeave = ItemButton_OnLeave
end)
