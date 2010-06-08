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
	Spawns a Blizzard Money-Frame

	Currently very small and unnecessary as a plugin, until I figure out
	how to implement the Handler-API in the new system.
	Then we can expect events here.
	
	attributes:
		.CopperText - Copper fontstring
		.SilverText - Silver fontstring
		.GoldText - Gold fontstring
]]

cargBags:RegisterPlugin("Money", function(self, parent)
	local money = CreateFrame("Frame", self:GetName().."Money", parent or self, "SmallMoneyFrameTemplate")
	
	money.CopperText = _G[money:GetName() .. "CopperButtonText"]
	money.SilverText = _G[money:GetName() .. "SilverButtonText"]
	money.GoldText = _G[money:GetName() .. "GoldButtonText"]
	
	return money
end)
