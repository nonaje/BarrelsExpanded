local Constant = require("BarrEx_Constant")
local BarrEx_BarrelUseAction = require("actions/BarrEx_BarrelUseAction")

---@class BarrEx_DrinkFromBarrelAction : BarrEx_BarrelUseAction
local BarrEx_DrinkFromBarrelAction = BarrEx_BarrelUseAction:derive("BarrEx_DrinkFromBarrelAction")

function BarrEx_DrinkFromBarrelAction:getAnimName()
    return "drink_tap"
end

function BarrEx_DrinkFromBarrelAction:getSoundName()
    return "DrinkingFromTap"
end

---@param player IsoPlayer
---@param barrel IsoObject
---@return BarrEx_DrinkFromBarrelAction
function BarrEx_DrinkFromBarrelAction:new(player, barrel)
    local o = BarrEx_BarrelUseAction.new(self, player, barrel, Constant.NETWORK.DRINK_FROM_BARREL, 120)
    ---@cast o BarrEx_DrinkFromBarrelAction
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end

return BarrEx_DrinkFromBarrelAction
