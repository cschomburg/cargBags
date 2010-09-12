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
	Item keys for the Blizz equipment sets

DEPENDENCIES
	mixins-add/itemkeys/basic.lua (for item.id)
]]

local parent, ns = ...
local cargBags = ns.cargBags

local ItemKeys = cargBags.itemKeys

local setItems, setNames
local emptyResult = {}

local function initUpdater()

	local function updateSets()
		setItems = setItems or {}
		setNames = setNames or {}

		for k in pairs(setItems) do setItems[k] = nil end
		for k in pairs(setNames) do setNames[k] = nil end

		for setID = 1, GetNumEquipmentSets() do
			local name = GetEquipmentSetInfo(setID)
			local items = GetEquipmentSetItemIDs(name)

			setNames[name] = setID

			for slot, id in pairs(items) do
				setItems[id] = setItems[id] or {}
				setItems[id][setID] = true
			end
		end
	end

	local updater = CreateFrame("Frame")
	updater:RegisterEvent("EQUIPMENT_SETS_CHANGED")
	updater:SetScript("OnEvent", function()
		updateSets()
		cargBags:FireEvent("BAG_UPDATE")
	end)

	updateSets()
end

local currentID
local function hasSet(specific)
	if(not setItems) then initUpdater() end

	local sets = setItems[currentID]
	if(not sets) then return nil end
	if(not specific) then return true end

	specific = specific and setNames[specific] or specific
	return sets[specific]
end

-- I know that's a hack ...
ItemKeys['set'] = function(i)
	currentID = item.id
	return hasSet
end
