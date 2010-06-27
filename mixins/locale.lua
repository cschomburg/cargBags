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
	Provides translation-tables for the auction house categories

USAGE:
	local L = cargBags:GetLocalizedNames()
	OR local L = Implementation:GetLocalizedNames()

	L[englishName] returns localized name
]]
local _, ns = ...
local cargBags = ns.cargBags

local L

function cargBags:GetLocalizedTypes()
	if(L) then return L end

	L = {}

	L["Weapon"], L["Armor"], L["Container"], L["Consumable"], L["Glyph"], L["Trade Goods"], L["Projectile"], L["Quiver"], L["Recipe"], L["Gem"], L["Misc"], L["Quest"] = GetAuctionItemClasses()

	--GetAuctionItemSubClasses(1)

	return L
end

cargBags.classes.Implementation.GetLocalizedNames = cargBags.GetLocalizedNames
