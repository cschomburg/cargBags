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

DESCRIPTION:
	Provides a searchbar for your containers.
	If you specify a frame as arg #2, it will serve as a clickable placeholder to open it

DEPENDENCIES
	mixins/textFilter.lua
]]

local addon, ns = ...
local Implementation = ns.cargBags
Implementation:Needs("TextFilter")
Implementation:Provides("SearchBar")

local function apply(self, container, text, mode)
	if(text == "" or not text) then
		container:ApplyToButtons(self.highlightFunction, true)
	else
		container:FilterForFunction(self.highlightFunction, self.currFilters)
	end
end

local function SearchBar_DoSearch(self, text)
	if(type(text) == "string") then
		self:SetText(text)
	else
		text = self:GetText()
	end

	if(self.currFilters) then
		self.currFilters:Empty()
	else
		self.currFilters = Implementation.Class:Get("FilterSet"):New()
	end

	self.currFilters:SetTextFilter(text, self.textFilters)

	if(self.isGlobal) then
		for id, container in pairs(Implementation.containers) do
			apply(self, container, text)
		end
	else
		apply(self, self.parent, text)
	end

	Implementation:ForceUpdate()
end

local function Target_OpenSearch(self)
	self:Hide()
	self.search:Show()
end

local function SearchBar_CloseSearch(self)
	self.target:Show()
	self:Hide()
end

local function SearchBar_OnEscape(self)
	self:DoSearch("")
	self:ClearFocus()
	if(self.OnEscapePressed) then self:OnEscapePressed() end
end

local function SearchBar_OnEnter(self)
	self:ClearFocus()
	if(self.OnEnterPressed) then self:OnEnterPressed() end
end

Implementation:Register("plugin", "SearchBar", function(self, target)
	local search = CreateFrame("EditBox", nil, self)
	search:SetFontObject(GameFontHighlight)
	search.parent = self

	search.Clear = SearchBar_OnEscape
	search.DoSearch = SearchBar_DoSearch

	local left = search:CreateTexture(nil, "BACKGROUND")
	left:SetTexture("Interface\\Common\\Common-Input-Border")
	left:SetTexCoord(0, 0.0625, 0, 0.625)
	left:SetWidth(8)
	left:SetHeight(20)
	left:SetPoint("LEFT", -5, 0)
	search.Left = left

	local right = search:CreateTexture(nil, "BACKGROUND")
	right:SetTexture("Interface\\Common\\Common-Input-Border")
	right:SetTexCoord(0.9375, 1, 0, 0.625)
	right:SetWidth(8)
	right:SetHeight(20)
	right:SetPoint("RIGHT", 0, 0)
	search.Right = right

	local center = search:CreateTexture(nil, "BACKGROUND")
	center:SetTexture("Interface\\Common\\Common-Input-Border")
	center:SetTexCoord(0.0625, 0.9375, 0, 0.625)
	center:SetHeight(20)
	center:SetPoint("RIGHT", right, "LEFT", 0, 0)
	center:SetPoint("LEFT", left, "RIGHT", 0, 0)
	search.Center = center

	search:SetScript("OnTextChanged", SearchBar_DoSearch)
	search:SetScript("OnEscapePressed", SearchBar_OnEscape)
	search:SetScript("OnEnterPressed", SearchBar_OnEnter)

	if(target) then
		search:SetAutoFocus(true)
		search:SetAllPoints(target)
		search:Hide()

		target.search, search.target = search, target
		target:RegisterForClicks("anyUp")
		target:SetScript("OnClick", Target_OpenSearch)
		search:SetScript("OnEditFocusLost", SearchBar_CloseSearch)
	end

	return search
end)
