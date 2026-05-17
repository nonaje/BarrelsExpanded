local LiquidTransferAction = require("actions/transfer/BarrEx_LiquidTransferAction")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
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
    if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
        return "TakeGasFromVehicle"
    end

    return "MixFluids"
end

function BarrEx_ExtractFromBarrelAction:getTransferSound()
    if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
        return "CanisterAddFuelSiphon"
    end

    return LiquidTransferAction.getTransferSound(self)
end

function BarrEx_ExtractFromBarrelAction:getFluidActionHandItems(liquidItem, toolItem)
    if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
        return nil, liquidItem
    end

    return LiquidTransferAction.getFluidActionHandItems(self, liquidItem, toolItem)
end

function BarrEx_ExtractFromBarrelAction:setupJobTracking()
    if self.liquidItem and type(self.liquidItem.setJobType) == "function" then
        if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
            self.liquidItem:setJobType(getText("ContextMenu_VehicleSiphonGas"))
        else
            self.liquidItem:setJobType(getText("ContextMenu_Fill"))
        end
    end
    if self.liquidItem and type(self.liquidItem.setJobDelta) == "function" then
        self.liquidItem:setJobDelta(0.0)
    end
end

function BarrEx_ExtractFromBarrelAction:clearJobTracking()
    if self.liquidItem and type(self.liquidItem.setJobDelta) == "function" then
        self.liquidItem:setJobDelta(0.0)
    end
end

function BarrEx_ExtractFromBarrelAction:update()
    if self.liquidItem and type(self.liquidItem.setJobDelta) == "function" then
        self.liquidItem:setJobDelta(self:getJobDelta())
    end

    LiquidTransferAction.update(self)
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
