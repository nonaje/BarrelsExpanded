local LiquidTransferAction = require("actions/transfer/BarrEx_LiquidTransferAction")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local TransferRules = require("core/BarrEx_TransferRules")

---@class BarrEx_PourIntoBarrelAction : BarrEx_LiquidTransferAction
local BarrEx_PourIntoBarrelAction = LiquidTransferAction:derive("BarrEx_PourIntoBarrelAction")

function BarrEx_PourIntoBarrelAction:getEstimatedTransferAmount(barrel, sourceItem)
    if not barrel or not sourceItem then return 0 end
    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then return 0 end
    return TransferRules.getPourAmount(barrelData, sourceItem)
end

function BarrEx_PourIntoBarrelAction:getStartCommand()
    return Constant.NETWORK.START_POUR_INTO_BARREL
end

function BarrEx_PourIntoBarrelAction:getStopCommand()
    return Constant.NETWORK.STOP_POUR_INTO_BARREL
end

function BarrEx_PourIntoBarrelAction:getCompleteCommand()
    return Constant.NETWORK.COMPLETE_POUR_INTO_BARREL
end

function BarrEx_PourIntoBarrelAction:getMode()
    return "pour"
end

function BarrEx_PourIntoBarrelAction:getAnimName()
    if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
        return "refuelgascan"
    end

    return "fill_container_tap"
end

function BarrEx_PourIntoBarrelAction:getTransferSound()
    if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
        return "VehicleAddFuelFromCanister"
    end

    return LiquidTransferAction.getTransferSound(self)
end

function BarrEx_PourIntoBarrelAction:getFluidActionHandItems(liquidItem, toolItem)
    if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
        return liquidItem, nil
    end

    return LiquidTransferAction.getFluidActionHandItems(self, liquidItem, toolItem)
end

function BarrEx_PourIntoBarrelAction:getPourType()
    if self.liquidItem and type(self.liquidItem.getPourType) == "function" then
        return self.liquidItem:getPourType()
    end
    return nil
end

function BarrEx_PourIntoBarrelAction:setupJobTracking()
    if self.liquidItem and type(self.liquidItem.setJobType) == "function" then
        if self:getTransferLiquidType() == Constant.LIQUID_TYPE.GASOLINE then
            self.liquidItem:setJobType(getText("ContextMenu_VehicleAddGas"))
        else
            self.liquidItem:setJobType(getText("IGUI_JobType_PourOut"))
        end
    end
    if self.liquidItem and type(self.liquidItem.setJobDelta) == "function" then
        self.liquidItem:setJobDelta(0.0)
    end
end

function BarrEx_PourIntoBarrelAction:clearJobTracking()
    if self.liquidItem and type(self.liquidItem.setJobDelta) == "function" then
        self.liquidItem:setJobDelta(0.0)
    end
end

function BarrEx_PourIntoBarrelAction:update()
    if self.liquidItem and type(self.liquidItem.setJobDelta) == "function" then
        self.liquidItem:setJobDelta(self:getJobDelta())
    end
    LiquidTransferAction.update(self)
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param sourceItem InventoryItem
---@return BarrEx_PourIntoBarrelAction
function BarrEx_PourIntoBarrelAction:new(player, barrel, sourceItem)
    local o = LiquidTransferAction.new(self, player, barrel, sourceItem)
    ---@cast o BarrEx_PourIntoBarrelAction
    return o
end

return BarrEx_PourIntoBarrelAction
