local LiquidTransferAction = require("BarrEx_LiquidTransferAction")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local TransferRules = require("core/BarrEx_TransferRules")

---@class BarrEx_ExtractFromBarrelAction : BarrEx_LiquidTransferAction
local BarrEx_ExtractFromBarrelAction = LiquidTransferAction:derive("BarrEx_ExtractFromBarrelAction")

function BarrEx_ExtractFromBarrelAction:getEstimatedTransferAmount(barrel, targetItem)
    if not barrel or not targetItem then return 0 end
    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then return 0 end
    return TransferRules.getExtractAmount(barrelData, targetItem)
end

function BarrEx_ExtractFromBarrelAction:getStartCommand()
    return Constant.NETWORK.START_EXTRACT_FROM_BARREL
end

function BarrEx_ExtractFromBarrelAction:getStopCommand()
    return Constant.NETWORK.STOP_EXTRACT_FROM_BARREL
end

function BarrEx_ExtractFromBarrelAction:getCompleteCommand()
    return Constant.NETWORK.COMPLETE_EXTRACT_FROM_BARREL
end

function BarrEx_ExtractFromBarrelAction:getMode()
    return "extract"
end

function BarrEx_ExtractFromBarrelAction:getAnimName()
    return "MixFluids"
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param targetItem InventoryItem
---@return BarrEx_ExtractFromBarrelAction
function BarrEx_ExtractFromBarrelAction:new(player, barrel, targetItem)
    local o = LiquidTransferAction.new(self, player, barrel, targetItem)
    ---@cast o BarrEx_ExtractFromBarrelAction
    return o
end

return BarrEx_ExtractFromBarrelAction
