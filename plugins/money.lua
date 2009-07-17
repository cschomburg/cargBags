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
Plugin: Money

Description:
	Creates a frame which shows the player's money

Spawns with:
	:SpawnPlugin("Money"): spawn a frame with the player's money
	:SpawnPlugin("Money", "static"): spawn a frame with a static amount of money
	:SpawnPlugin("Money, frame): change the frame into a frame of the player's money

Money callbacks functions:
	:UpdateMoney(cost): To set the amount of money in copper
doc]]

-- Update the display
local function updater(self, event)
	if((not event or event == "PLAYER_MONEY" or event == "PLAYER_LOGIN") and self.UpdateMoney) then
		local cost = cargBags:GetHandler().GetMoney()
		self:UpdateMoney(cost)
	end
end

-- Register the plugin
local count = 0
cargBags:RegisterPlugin("Money", function(self, arg1)
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
	end
	frame.Object = self

	if((arg1) ~= "static") then
		cargBags:AddCallback(frame, updater)
	end
	return frame
end)