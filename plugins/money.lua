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

-- Update the display
local function updater(self, event)
	local cost = cargBags:GetHandler().GetMoney()
	self:UpdateMoney(cost)
end

-- Register the plugin
local count = 0
cargBags:RegisterPlugin("Money", function(self, arg1, arg2)
	local frame
	if(type(arg1) ~= "table") then
		-- Create our own frame
		count = count + 1
		frame = CreateFrame("Frame", self.Name.."Money"..count, self, "SmallMoneyFrameTemplate")
		MoneyFrame_SetType(frame, "STATIC")
		frame.UpdateMoney = MoneyFrame_Update
	else
		-- Use delivered frame
		frame = arg1
		arg1 = arg2
	end
	frame.Object = self

	if((arg1) ~= "static") then
		frame:RegisterEvent("PLAYER_MONEY")
		frame:RegisterEvent("PLAYER_LOGIN")
		frame:SetScript("OnEvent", updater)
	end
	return frame
end)