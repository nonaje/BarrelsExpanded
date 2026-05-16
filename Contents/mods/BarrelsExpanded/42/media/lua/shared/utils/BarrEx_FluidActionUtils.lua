local TransferConfig  = require("config/BarrEx_TransferConfig")
local TransferRules   = require("core/BarrEx_TransferRules")

local FluidActionUtils = {}

local function getVanillaTransferTimePerUnit()
    if ISFluidUtil and type(ISFluidUtil.getTransferActionTimePerLiter) == "function" then
        local timePerUnit = tonumber(ISFluidUtil.getTransferActionTimePerLiter())
        if timePerUnit and timePerUnit > 0 then
            return timePerUnit
        end
    end

    return 50
end

local function getVanillaMinTransferTime()
    if ISFluidUtil and type(ISFluidUtil.getMinTransferActionTime) == "function" then
        local minTime = tonumber(ISFluidUtil.getMinTransferActionTime())
        if minTime and minTime > 0 then
            return minTime
        end
    end

    return 10
end

--- Mirrors vanilla fluid transfer duration.
---@param amount number|nil
---@return number
function FluidActionUtils.getVanillaFluidActionTime(amount)
    local normalizedAmount = tonumber(amount) or 0
    local resolvedMinTime = getVanillaMinTransferTime()

    if normalizedAmount <= 0 then
        return resolvedMinTime
    end

    local duration = normalizedAmount * getVanillaTransferTimePerUnit()
    if duration < resolvedMinTime then
        return resolvedMinTime
    end

    return duration
end

--- Transfer duration scaled by ACTION_TIME_MULTIPLIER.
--- DEPRECATED: Use TransferRules.getTransferActionTime() directly (same logic, no duplication).
--- Kept for backward compatibility only.
---@param amount number|nil
---@return number
function FluidActionUtils.getFluidTransferActionTime(amount)
    return TransferRules.getTransferActionTime(amount)
end

--- Resolves primary/secondary hand assignment for vanilla-like pour animations.
--- Items with EatType are shown in the secondary hand during pour actions.
---@param mainItem InventoryItem|nil
---@param supportItem InventoryItem|nil
---@return InventoryItem|nil primaryHand
---@return InventoryItem|nil secondaryHand
function FluidActionUtils.getFluidActionHandItems(mainItem, supportItem)
    if not mainItem then
        return supportItem, nil
    end

    local hasEatType = type(mainItem.getEatType) == "function" and mainItem:getEatType() ~= nil
    if hasEatType then
        return supportItem, mainItem
    end

    return mainItem, supportItem
end

return FluidActionUtils