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

--[[
Basic Table of ItemKeys

Description:
	Custom item data which can be addressed like the default one (item.key)
]]

-- Returns the numeric item id (12345)
cargBags.ItemKeys["id"] = function(i)
	return i.link and tonumber(i.link:match("item:(%d+)"))
end

-- Returns the type of the parent bag
cargBags.ItemKeys["bagType"] = function(i)
	return cargBags.Bags[i.bagID].bagType
end

-- Returns the item string (12345:0:0:0)
cargBags.ItemKeys["string"] = function(i)
	return i.link and i.link:match("item:(%d+:%d+:%d+:%d+)")
end