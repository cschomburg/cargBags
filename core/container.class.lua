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
local Core = ns.cargBags

--[[!
	@class Container
		The container class provides the virtual bags for cargBags
]]
local Container = Core.Class:New("Container", nil, "Button")

local mt_bags = {__index=function(self, bagID)
	self[bagID] = CreateFrame("Frame", nil, self.container)
	self[bagID]:SetID(bagID)
	return self[bagID]
end}

--[[!
	Creates a new instance of the class
	-> name <string>
	-> ... Arguments passed to the OnCreate-callback
	<- container <Container>
	@callback container:OnCreate(name, ...)
]]
function Container:New(name, ...)
	local container = self:NewInstance(Core.name..name)

	container.name = name
	container.buttons = {}
	container.bags = setmetatable({container = container}, mt_bags)
	container:ScheduleContentCallback()

	table.insert(Core.containers, container)
	container:SetParent(Core)

	if(container.OnCreate) then container:OnCreate(name, ...) end

	return container
end

--[[!
	Adds an ItemButton to this container
	-> button <ItemButton>
	@callback button:OnAdd(self)
	@callback OnButtonAdd(button)
]]
function Container:AddButton(button)
	button.container = self
	button:SetParent(self.bags[button.bagID])
	self:ScheduleContentCallback()
	table.insert(self.buttons, button)
	if(button.OnAdd) then button:OnAdd(self) end
	if(self.OnButtonAdd) then self:OnButtonAdd(button) end
end

--[[!
	Removes an ItemButton from the container
	-> button <ItemButton>
	@callback button:OnRemove(self)
	@callback OnButtonRemove(button)
]]
function Container:RemoveButton(button)
	for i, single in ipairs(self.buttons) do
		if(button == single) then
			self:ScheduleContentCallback()
			button.container = nil
			if(button.OnRemove) then button:OnRemove(self) end
			if(self.OnButtonRemove) then self:OnButtonRemove(button) end
			return table.remove(self.buttons, i)
		end
	end
end

--[[
	@callback OnContentsChanged()
]]
local updater, scheduled = CreateFrame"Frame", {}
updater:Hide()
updater:SetScript("OnUpdate", function(self)
	self:Hide()
	for container in pairs(scheduled) do
		if(container.OnContentsChanged) then container:OnContentsChanged() end
		scheduled[container] = nil
	end
end)

--[[
	Schedules a Content-callback in the next update
]]
function Container:ScheduleContentCallback()
	scheduled[self] = true
	updater:Show()
end

--[[
	Position the child buttons by specifying a layout to use
	-> layout <string, function>
	-> ... arguments passed to the layout function
	<- width <number> width of the button layout
	<- height <number> height of the button layout
]]

function Container:LayoutButtons(layout, ...)
	if(type(layout) == "function") then
		return layout(self, ...)
	else
		return Core:Get("layout", layout, true)(self, ...)
	end
end

--[[
	Sorts the child buttons with the specified sort function
	-> sort <string, function>
]]

function Container:SortButtons(sort)
	if(type(sort) == "function") then
		table.sort(self.buttons, sort)
	else
		table.sort(self.buttons, Core:Get("sort", sort, true))
	end
end

--[[
	Applies a function to the contained buttons
	-> func <function>
	-> ... Arguments which are passed to the function
]]
function Container:ApplyToButtons(func, ...)
	for i, button in pairs(self.buttons) do
		func(button, ...)
	end
end

Container.SpawnPlugin = Core.SpawnPlugin
