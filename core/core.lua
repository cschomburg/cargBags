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

-- YOU CAN FIND A DETAILED DOCUMENTATION UNDER:
-- http://wiki.github.com/xconstruct/cargBags

local DEBUG = nil
-- if set to true:
-- button-history in .History
-- saved item data in button.i,
-- button:Recheck() for re-checking the filters
-- output update time in chat

local _G = getfenv(0)
local select = select
local type = type

-- add-on object
local cargBags = CreateFrame("Frame", "cargBags")
local metatable

local assertf = function(cond, ...) return assert(cond, format(...)) end
cargBags.assertf = assertf

local styles, style = {}
local objects = {}
local bags = {}
local handlers, handler = {}
local tempButtons = {}
local callbacks = {}
local plugins = {}
local events = {}
local init = true



--[[##############################
	Callback functions
		Because programmers are lazy
################################]]

-- Tries to call an object's function if it exists
local function fire(object, callback, ...)
	if(not object or not object[callback]) then return end
	--debug(object.GetName and object:GetName(), callback)
	object[callback](object, ...)
end

-- Tries to call the functions of all objects
local function fireAll(callback, ...)
	for _, object in ipairs(objects) do
		fire(object, callback, ...)
	end
end

-- Calls the functions from the callbacks-table
local function fireCallbacks(...)
	for object, func in pairs(callbacks) do
		func(object, ...)
	end
end



--[[##############################
	Registering/enabling functions
		Here you can register styles, plugins and handlers
################################]]

-- Register a style
function cargBags:RegisterStyle(name, func)
	assertf(type(name) == "string", "Bad argument #1 to 'RegisterStyle' (string expected, got %s)", type(name))
	assertf(type(func) == "table" and type(getmetatable(func).__call) == "function", "Bad argument #2 to 'RegisterStyle' (table expected, got %s)", type(func))
	assertf(not styles[name], "Style [%s] already registered.", name)

	if(not style) then style = name end
	styles[name] = func
end

-- Set the active style
function cargBags:SetActiveStyle(name, noVerbose)
	assertf(type(name) == "string", "Bad argument #1 to 'SetActiveStyle' (string expected, got %s)", type(name))
	assertf(styles[name] or noVerbose, "Style [%s] does not exist.", name)

	style = name
	return true
end

-- Register a handler
function cargBags:RegisterHandler(name, func, ...)
	assertf(type(name) == "string", "Bad argument #1 to 'RegisterHandler' (string expected, got %s)", type(name))
	assertf(type(func) == "table", "Bad argument #2 to 'RegisterHandler' (table expected, got %s)", type(func))
	assertf(not handlers[name], "Handler [%s] already registered.", name)

	if(not handler) then
		handler = func
		fire(handler, "Enable", ...)
	end

	handlers[name] = func
end

-- Set the active handler
function cargBags:SetActiveHandler(name, noVerbose, ...)
	assertf(type(name) == "string", "Bad argument #1 to 'SetActiveHandler' (string expected, got %s)", type(name))
	assertf(handlers[name] or noVerbose, "Handler [%s] does not exist.", name)

	fire(handler, "Disable")
	handler = handlers[name]
	fire(handler, "Enable", ...)
	if(not init) then self:UpdateBags() end
	return true
end

-- Register a plugin
function cargBags:RegisterPlugin(name, func)
	assertf(type(name) == "string", "Bad argument #1 to 'RegisterPlugin' (string expected, got %s)", type(name))
	assertf(type(func) == "function", "Bad argument #2 to 'RegisterPlugin' (function expected, got %s)", type(func))
	assertf(not plugins[name], "Plugin [%s] already registered.", name)

	plugins[name] = func
end

-- Spawn a plugin
function cargBags:SpawnPlugin(name, ...)
	assertf(type(name) == "string", "Bad argument #1 to 'SpawnPlugin' (string expected, got %s)", type(name))

	local plugin
	if(plugins[name]) then
		plugin = plugins[name](self, ...)
	end
	if(plugin and not self[name]) then self[name] = plugin end
	return plugin
end

-- Add a callback for UpdateBags()
function cargBags:AddCallback(object, func)
	assertf(type(object) == "table", "Bad argument #1 to 'AddCallback' (table expected, got %s)", type(name))
	assertf(type(func) == "function", "Bad argument #2 to 'AddCallback' (function expected, got %s)", type(func))

	callbacks[object] = func
end

-- Get the currently active handler
function cargBags:GetHandler()
	return handler
end

-- Spawn a new bag object
function cargBags:Spawn(name, ...)
		
	assert(name, "Unable to create frame. No name was defined.")
	assertf(style, "Unable to create frame [%s]. No styles have been registered.", name)
	assertf(handler, "Unable to create frame [%s]. No handlers have been registered.", name)

	local style = styles[style]
	local object = CreateFrame("Button", name, parent or UIParent)

	metatable = metatable or {__index = self.BagObject}
	object = setmetatable(object, metatable)

	object.Name = name
	object.Bags = {}
	object.Buttons = {}
	object.NumButtons = 0

	object.Filters = {}
	object.updateNeeded = true
	object.Init = true

	style(object, name, ...)
	fire(handler, "Init", object, name, ...)

	objects[#objects+1] = object

	return object
end

local Recheck
if(DEBUG) then
	Recheck = function(button)
		if(self.Object) then return self.Object:CheckFilters(self.i) end
	end
end

--[[##############################
	Button-recycling functions
		where the buttons are created, moved and deleted
################################]]

-- Remove a button and insert it in the temporary storage
local function recycleButton(button)
	if(DEBUG) then tinsert(button.history, "Recycled") end
	local tpl, bagID, slotID = button.template, button.bagID, button.slotID
	if(not bags[bagID]) then bags[bagID] = {} end
	bags[bagID][slotID] = nil
	button:Hide()
	if(not tempButtons[tpl]) then tempButtons[tpl] = {} end
	tinsert(tempButtons[tpl], button)
end

-- Create a button with the defined template or
-- fetch it from the temporary storage
local slots = 0
local function createButton(tpl, bagID, slotID)
	local button
	if(tempButtons[tpl] and #tempButtons[tpl] > 0) then
		button = tremove(tempButtons[tpl])
	else
		slots = slots+1
		local name = "cargBagsSlot"..slots
		button = handler:CreateButton(tpl, name)
		button.Name = name
		button.template = tpl
		if(DEBUG) then button.history = { "Created" } button.Recheck = Recheck end
		fire(cargBags, "PostCreateButton", button)
	end

	button:SetID(slotID)
	button.slotID = slotID
	button.bagID = bagID
	bags[bagID][slotID] = button

	return button
end

-- Create a 'parent bag' for the bag object
local function createObjectBag(object, bagID)
	local bag = CreateFrame("Frame", nil, object)
	bag.Size = 0
	bag:SetID(bagID)
	object.BagsLowest = object.BagsLowest == nil and bagID or min(object.BagsLowest, bagID)
	object.BagsHighest = object.BagsHighest == nil and bagID or max(object.BagsHighest, bagID)
	object.Bags[bagID] = bag
	fire(object, "PostCreateBag", bag, bagID)
	return bag
end

-- Move a button to the specified bag object or
-- recycle it if the object is nil
local function move(button, object)
	local bagID, slotID = button.bagID, button.slotID
	local oldObject = button.Object
	if(object == oldObject and object ~= nil) then return true end
	if(DEBUG) then tinsert(button.history, "Moved from "..(oldObject and oldObject.Name or "").." to "..(object and object.Name or "")) end

	if(oldObject) then
		if(oldObject == object) then return true end
		oldObject.Buttons[button] = nil
		oldObject.NumButtons = oldObject.NumButtons - 1
		oldObject.updateNeeded = true
		fire(oldObject, "PostRemoveButton", button)
	end

	button.Object = object
	if(not object) then return recycleButton(button) end

	local bag = object.Bags[bagID] or createObjectBag(object, bagID)
	button:SetParent(bag)
	button:Show()
	object.Buttons[button] = true
	object.NumButtons = object.NumButtons + 1
	object.updateNeeded = true
	fire(object, "PostAddButton", button)
	return true
end

-- get the right button from the button table or create one
local function getButton(bagID, slotID, noCreate)
	local tpl = handler:GetButtonTemplateName(bagID, slotID)
	if(not bags[bagID]) then bags[bagID] = {} end
	if(bags[bagID][slotID]) then
		local button = bags[bagID][slotID]
		if(button.template == tpl) then
			return button
		else
			move(button, nil)
		end
	end
	return not noCreate and createButton(tpl, bagID, slotID)
end



--[[##############################
	Core filter logic
		Check for filters and update slots
################################]]

-- Ask all objects if the button can go into them
-- and move it to the first one where it fits
local function checkButtonObject(i)
	local bagID = i.bagID
	for _, object in ipairs(objects) do
		if(not (object.Bags[bagID] and object.Bags[bagID].Hidden) and object:CheckFilters(i)) then
			local button = getButton(bagID, i.slotID)
			if(DEBUG) then
				local x = {}
				for k,v in pairs(i) do x[k] = v end
				button.i = x
				x.object = object
				tinsert(button.history, "Passed filters: "..object.Name)
			end
			return move(button, object)
		end
	end
	return nil
end

local i_keys = {}
local i = setmetatable({}, {__index = function(i, k) if(i_keys[k]) then return i_keys[k](i, k) end end})

function cargBags:GetItemInfo(bagID, slotID)
	for k in pairs(i) do i[k] = nil end
	i.bagID, i.slotID = bagID, slotID
	handler:LoadItemInfo(i)
	if(i.clink) then
		i.name, i.link, i.rarity, i.level, i.minLevel, i.type, i.subType, i.stackCount, i.equipLoc, i.texture, i.sellValue = GetItemInfo(i.clink)
	end
	fire(cargBags, "PreCheckFilters", i)
	return i
end

local LOCK, CD = 1, 2
-- First fetch the item data from the handler, then check if the filters
-- are right, and then let the layout update the button
local function updateSlot(bagID, slotID, updateType)
	local button = getButton(bagID, slotID, true)
	local object = button and button.Object
	if(object and object.Bags[bagID].Hidden) then
		return move(button, nil)
	end

	cargBags:GetItemInfo(bagID, slotID)

	if((updateType and object) or (not updateType and checkButtonObject(i))) then
		button = getButton(bagID, slotID, true)
		object = button.Object
		if(DEBUG and updateType ~= CD) then tinsert(button.history, "Holding: "..(i.link or "")) end
		if(not updateType) then fire(object, "UpdateButton", button, i, updateType) end
		if(updateType ~= CD) then fire(object, "UpdateButtonLock", button, i, updateType) end
		if(updateType ~= LOCK) then fire(object, "UpdateButtonCooldown", button, i, updateType) end
		fire(object, "PostUpdateButton", button, i, updateType)
	elseif(button) then
		move(button, nil)
	end
end

-- Update all slots of this bag
local function updateBag(bagID, updateType)
	if(not bags[bagID]) then bags[bagID] = {} end
	local bag = bags[bagID]
	local prevSlots =  bag.slots or 0
	local numSlots = handler.GetContainerNumSlots(bagID)
	_, bag.bagType = handler.GetContainerNumFreeSlots(bagID)
	bag.slots = numSlots

	for slotID=1, max(prevSlots, numSlots) do
		if(slotID <= numSlots) then
			updateSlot(bagID, slotID, updateType)
		elseif(bag[slotID]) then
			move(bag[slotID], nil)
		end
	end
end



--[[##############################
	The main update function
		Here begins and ends the function-switching
################################]]
local timedBags = {}
-- Update bags one frame later
cargBags:SetScript("OnUpdate", function(self)
	self:Hide()
	self:UpdateBags("CB_TIMED")
end)

-- This activates the update checking
function cargBags:TimeBag(bagID)
	timedUpdate = true
	timedBags[bagID] = true
	self:Show()
end

-- The main update routine, handles ... umm... everything
function cargBags:UpdateBags(event, ...)
	if(init) then init = nil end

	local completeUpdate
	completeUpdate, bagID, slotID, updateType = events[event] and events[event](self, event, ...)
	if(event and event ~= "CB_TIMED" and not completeUpdate) then return end

	-- Now start with updating the bags
	fireAll("PreUpdateBags", event, bagID, slotID)

	if(bagID and slotID) then
		updateSlot(bagID, slotID, updateType)
	elseif(bagID) then
		updateBag(bagID, updateType)
	elseif(timedUpdate) then
		for id, update in pairs(timedBags) do
			if(update) then
				updateBag(id)
				timedBags[id] = nil
			end
		end
		timedUpdate = nil
	else
		for i = -2, (NUM_BAG_SLOTS+NUM_BANKBAGSLOTS) do
			updateBag(i, updateType)
		end
	end

	-- Lots of PostUpdate-callbacks
	for _, object in ipairs(objects) do
		if(object.updateNeeded or object.PositionEveryTime) then fire(object, "UpdateButtonPositions", event, bagID, slotID) object.updateNeeded = nil end
		fire(object, "PostUpdateBags", event, bagID, slotID)
		if(object.Init) then object.Init = nil end
	end

	-- The plugins want, too
	fireCallbacks(event, bagID, slotID)
end

cargBags.Events = events
cargBags.Bags = bags
cargBags.Fire = fire
cargBags.FireAll = fireAll
cargBags.Handler = handlers
cargBags.TempButtons = tempButtons
cargBags.Objects = objects
cargBags.Plugins = plugins
cargBags.ItemKeys = i_keys
cargBags.Version = GetAddOnMetadata("cargBags", "Version")