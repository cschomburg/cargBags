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
	class-generation, helper-functions and the Blizzard-replacement.
]]

local addon, ns = ...
local cargBags = ns.cargBags

local Class = {}
cargBags.Class = Class

local Prototype = {}
Class.classes = {}
Class.Prototype = Prototype

local widgets = setmetatable({}, {__index = function(self, widget)
	self[widget] = getmetatable(CreateFrame(widget))
	return self[widget]
end})

function Class:New(name, parent, widget)
	if(self.classes[name]) then return end
	local class = {}
	class.__index = class

	if(parent) then
		parent = self.classes[parent]
		class._parent = parent
		setmetatable(class, parent)
	elseif(widget) then
		class._widgetName = widget
		widget = widgets[widget]
		class._widget = widget
		setmetatable(class, widget)
	end

	if(not parent) then
		for k,v in pairs(Prototype) do
			class[k] = v
		end
	end

	self.classes[name] = class

	return class
end

function Class:Get(name, create, ...)
	return self.classes[name] or (force and self:New(name, ...))
end

function Prototype:NewInstance(...)
	local instance = self._widgetName and CreateFrame(self._widgetName, ...) or {}
	return setmetatable(instance, self.__index)
end

local handlerFuncs = setmetatable({}, {__index=function(self, handler)
	self[handler] = function(self, ...) return self[handler] and self[handler](self, ...) end
	return self[handler]
end})

--- Sets a number of script handlers by redirecting them to the members function, e.g. self:OnEvent(self, ...)
--  @param self <frame>
--  @param ... <string> A number of script handlers
function Prototype:SetScriptHandlers(...)
	for i=1, select("#", ...) do
		local handler = select(i, ...)
		self:SetScript(handler, handlerFuncs[handler])
	end
end
