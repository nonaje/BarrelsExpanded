local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelUseAction = require("BarrEx_BarrelUseAction")
local TransferRules = require("core/BarrEx_TransferRules")

---@class BarrEx_EmptyBarrelAction : BarrEx_BarrelUseAction
local BarrEx_EmptyBarrelAction = BarrEx_BarrelUseAction:derive("BarrEx_EmptyBarrelAction")

function BarrEx_EmptyBarrelAction:getAnimName()
    if CharacterActionAnims and CharacterActionAnims.Pour then
        return CharacterActionAnims.Pour
    end
    return "fill_container_tap"
end

function BarrEx_EmptyBarrelAction:getSoundName()
    return "PourWaterIntoObject"
end

---@param player IsoPlayer
---@param barrel IsoObject
---@return BarrEx_EmptyBarrelAction
function BarrEx_EmptyBarrelAction:new(player, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    local amount = barrelData and barrelData.amount or 0
    local maxTime = TransferRules.getTransferActionTime(amount)
    local o = BarrEx_BarrelUseAction.new(self, player, barrel, Constant.NETWORK.EMPTY_BARREL, maxTime)
    ---@cast o BarrEx_EmptyBarrelAction
    return o
end

return BarrEx_EmptyBarrelAction
