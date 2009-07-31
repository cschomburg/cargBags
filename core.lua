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

--[[doc
cargBags Core

Description:
	The main core used for bag organizing and filtering, it is the connection between handler, plugins and layout

Spawn with:
	cargBags:Spawn(name, parentFrame): Create a new bag object

cargBags functions:
	:Spawn(name, parentFrame): Create a new bag object
	:RegisterStyle(name, func): Register a new layout for use
	:SetActiveLayout(name): Set the active layout
	:RegisterHandler(name, handler, ...): Register a new handler, additional options are passed to handler:Enable()
	:SetActiveHandler(name, ...): Set the active handler, additional options are passed to handler:Enable()
	:GetHandler(): Returns the currently active handler
	:GetItemInfo(bagID, slotID): Returns a table with all item info of the specified slot
	:RegisterPlugin(name, func): Registers a new plugin, the function is called when the plugin needs to be created
	:AddCallback(object, func): Registers a callback for an object to be notified when the bags are updated

cargBags properties:
	.ItemKeys: table of all custom itemdata-functions
	.PositionEveryTime: Boolean whether UpdateButtonPositions should be called every time (default = nil)
	.Version: version number of cargBags

cargBags storage tables: (do not modify them!)
	.Bags: table of all bags, their slots and used buttons
	.Handler: table of all handlers
	.Objects: table of all spawned objects
	.Plugins: table of all plugins
	.TempButtons: table of all buttons currently unused

cargBags callback functions:
	:PreUpdateBags(event, bagID, slotID): fired before the objects are updated (filters added, item buttons updated)
	:PostUpdateBags(event, bagID, slotID): fired after the objects are updated (filters added, item buttons updated)
	:PreCheckFilters(item, updateType): fired before the filters of an item are checked

Bag object functions:
	:SpawnPlugin(name, ...): Spawn a plugin for use in the layout, parameters are plugin-specific
	:IterateButtons(): Creates an iterator over all item buttons for use within a for-loop [overwritable]
	:GetItemInfo(bagID, slotID): Returns a table with all item info of the specified slot
	:GetHandler(): Returns the currently active handler, provided from cargBags for convenience
	:CheckFilters(item): Returns if the item table fits into this bag object [overwritable]
	:SetFilter(func, state): Sets the state for the filter function (true: enabled, nil: disabled, -1: inverted; Default: nil)
	:Fire(callback, ...): Fires the function in the object named callback with the arguments

Bag object callback functions:
	:PostCreateBag(bag, bagID): fired after a bag was created in  the object
	:PostAddButton(button): fired after a button was added/moved to the object
	:PostRemoveButton(button): fired after a button was removed from the object
	:UpdateButton(button, item, updateType): fired if a button needs to be updated
	:UpdateButtonLock(button, i, updateType): fired if a button's lock needs to be updated
	:UpdateButtonCooldown(button, i, updateType): fired if a button's' cooldown needs to be updated
	:UpdateButtonPositions(): fired if the button positions need to be updated, typically after adding/removing buttons from the object
doc]]

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

local Prototype = CreateFrame"Button"
local metatable = {__index = Prototype}

local print = function(a) ChatFrame1:AddMessage("|cffee8800cargBags:|r "..tostring(a)) end
local error = function(...) print("|cffff0000Error:|r "..string.format(...)) end

local styles, style = {}
local objects = {}
local bags = {}
local handlers, handler = {}
local tempButtons = {}
local callbacks = {}
local plugins = {}
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
	if(type(name) ~= "string") then return error("Bad argument #1 to 'RegisterStyle' (string expected, got %s)", type(name)) end
	if(type(func) ~= "table" and type(getmetatable(func).__call) ~= "function") then return error("Bad argument #2 to 'RegisterStyle' (table expected, got %s)", type(func)) end
	if(styles[name]) then return error("Style [%s] already registered.", name) end
	if(not style) then style = name end

	styles[name] = func
end

-- Set the active style
function cargBags:SetActiveStyle(name, noVerbose)
	if(type(name) ~= "string") then return error("Bad argument #1 to 'SetActiveStyle' (string expected, got %s)", type(name)) end
	if(not styles[name]) then return not noVerbose and error("Style [%s] does not exist.", name) end

	style = name
	return true
end

-- Register a handler
function cargBags:RegisterHandler(name, func, ...)
	if(type(name) ~= "string") then return error("Bad argument #1 to 'RegisterHandler' (string expected, got %s)", type(name)) end
	if(type(func) ~= "table") then return error("Bad argument #2 to 'RegisterHandler' (table expected, got %s)", type(func)) end
	if(handlers[name]) then return error("Handler [%s] already registered.", name) end
	if(not handler) then
		handler = func
		fire(handler, "Enable", ...)
	end

	handlers[name] = func
end

-- Set the active handler
function cargBags:SetActiveHandler(name, noVerbose, ...)
	if(type(name) ~= "string") then return error("Bad argument #1 to 'SetActiveHandler' (string expected, got %s)", type(name)) end
	if(not handlers[name]) then return not noVerbose and error("Handler [%s] does not exist.", name) end

	fire(handler, "Disable")
	handler = handlers[name]
	fire(handler, "Enable", ...)
	if(not init) then self:UpdateBags() end
	return true
end

-- Register a plugin
function cargBags:RegisterPlugin(name, func)
	if(type(name) ~= "string") then return error("Bad argument #1 to 'RegisterPlugin' (string expected, got %s)", type(name)) end
	if(type(func) ~= "function") then return error("Bad argument #2 to 'RegisterPlugin' (function expected, got %s)", type(func)) end
	if(plugins[name]) then return error("Plugin [%s] already registered.", name) end
	plugins[name] = func
end

-- Spawn a plugin
function cargBags:SpawnPlugin(name, ...)
	if(type(name) ~= "string") then return error("Bad argument #1 to 'SpawnPlugin' (string expected, got %s)", type(name)) end
	local plugin
	if(plugins[name]) then
		plugin = plugins[name](self, ...)
	end
	if(plugin and not self[name]) then self[name] = plugin end
	return plugin
end

-- Add a callback for UpdateBags()
function cargBags:AddCallback(object, func)
	if(type(object) ~= "table") then return error("Bad argument #1 to 'AddCallback' (table expected, got %s)", type(name)) end
	if(type(func) ~= "function") then return error("Bad argument #2 to 'AddCallback' (function expected, got %s)", type(func)) end
	callbacks[object] = func
end

-- Get the currently active handler
function cargBags:GetHandler()
	return handler
end

-- Spawn a new bag object
function cargBags:Spawn(name, ...)
		
	if(not name) then return error("Unable to create frame. No name was defined.") end
	if(not style) then return error("Unable to create frame. No styles have been registered.") end
	if(not handler) then return error("Unable to create frame. No handlers have been registered.") end

	local style = styles[style]
	local object = CreateFrame("Button", name, parent or UIParent)

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
	object.BagsLowest = object.BagsLowest == nil and bagID or min(object.BagsLowest or 0, bagID)
	object.BagsHighest = object.BagsHighest == nil and bagID or max(object.BagsHighest or 0, bagID)
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

local bagclosed
local timedBags = {}
-- Update bags one frame later
cargBags:SetScript("OnUpdate", function(self)
	self:Hide()
	self:UpdateBags("CB_TIMED")
end)

-- This activates the update checking
local function timeBag(bagID)
	timedUpdate = true
	timedBags[bagID] = true
	cargBags:Show()
end

-- The main update routine, handles ... umm... everything
function cargBags:UpdateBags(event, bagID, slotID)
	if(init) then init = nil end
	local start = GetTime()
	--debug(event, bagID, slotID) end

	-- Some event handling
	local updateType
	-- Update either the bank slot or the bank bag
	if(event == "PLAYERBANKSLOTS_CHANGED") then
		if(bagID <= NUM_BANKGENERIC_SLOTS) then
			slotID = bagID
			bagID = -1
		else
			return timeBag(bagID-NUM_BANKGENERIC_SLOTS)
		end
	-- Only update item lock info
	elseif(event == "ITEM_LOCK_CHANGED") then
		updateType = LOCK
	-- Only update cooldown info
	elseif(event == "BAG_UPDATE_COOLDOWN") then
		updateType = CD
	-- Only update callbacks
	elseif(event == "PLAYER_MONEY") then
		return fireCallbacks(event, bagID, slotID)
	-- schedule updating after closed bag
	elseif(event == "BAG_CLOSED") then
		bagclosed = bagID
		return
	elseif(bagclosed) then
		bagclosed, bagID, slotID = nil
	-- fake event for hiding bags
	elseif(event == "CB_BAG_HIDDEN") then
		bagID.updateNeeded = true -- Well, it's actually an object
		bagID = slotID
		slotID = nil
	elseif(event == "BAG_UPDATE" and bagID) then
		return timeBag(bagID)
	elseif(event == "PLAYER_LOGIN") then
		timeBag(0)
		timeBag(-2)
		return fireCallbacks(event, bagID, slotID)
	end

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
	if(DEBUG) then print(format("%.3f", GetTime()-start)) end
end



--[[##############################
	Functions of the bag object
		THEY R EVIL!!!!1111
################################]]

-- Check if the passed item data can go into this object
function Prototype:CheckFilters(item)
	for Filter, enabled in pairs(self.Filters) do
		if(enabled and (Filter(item, self) ~= true) ~= (enabled == -1)) then
			return nil
		end
	end
	return true
end

-- Set a filter for the object
function Prototype:SetFilter(filter, enabled, noUpdate)
	self.Filters[filter] = enabled
	if(not self.Init and not noUpdate) then cargBags:UpdateBags() end
end


-- The function for iterating the bags
-- it ensures that the buttons are placed in the right order
-- how they are in the Blizz bags
local iTable = {}
local iSort = function(a,b)
	return a.bagID == b.bagID and a.slotID < b.slotID or a.bagID < b.bagID
end

-- And now the function returning the iterator
local dummy = function() end
function Prototype:IterateButtons(func)
	local i = 1
	for button, _ in pairs(self.Buttons) do
		iTable[i] = button
		i = i + 1
	end
	while(iTable[i]) do
		iTable[i] = nil
		i = i + 1
	end
	sort(iTable, func or iSort)

	return next, iTable
end

Prototype.GetItemInfo = cargBags.GetItemInfo
Prototype.SpawnPlugin = cargBags.SpawnPlugin
Prototype.GetHandler = cargBags.GetHandler
Prototype.Fire = fire

cargBags.Bags = bags
cargBags.Fire = fire
cargBags.FireAll = fireAll
cargBags.Handler = handlers
cargBags.TempButtons = tempButtons
cargBags.Objects = objects
cargBags.Plugins = plugins
cargBags.ItemKeys = i_keys
cargBags.Version = GetAddOnMetadata("cargBags", "Version")