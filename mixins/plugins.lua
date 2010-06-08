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
	Base functions for the plugin-system
]]

local cargBags = cargBags
local Implementation = cargBags.classes.Implementation
local Container = cargBags.classes.Container

local plugins = {}

function Implementation:SpawnPlugin(name, ...)
	if(plugins[name]) then
		local plugin = plugins[name](self, ...)
		if(plugin) then
			self[name] = plugin
			plugin.parent = self
		end
		return plugin
	end
end
Container.SpawnPlugin = Implementation.SpawnPlugin

function cargBags:RegisterPlugin(name, func)
	plugins[name] = func
end
