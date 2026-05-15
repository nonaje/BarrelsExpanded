-- BarrEx_TransferRules: pure, deterministic rules for barrel liquid transfers.
--
-- This module is the single authoritative source for questions like:
--   "Can this item be poured into this barrel?"
--   "Can this barrel fill this container?"
--   "How much can be transferred?"
--   "How long should the action take?"
--
-- It contains NO player logic, NO networking, NO UI and NO side effects.
-- Both client (menu, timed actions) and server (validation, application)
-- should consult these rules to avoid duplication and divergence.
--
-- IMPORTANT: barrelData parameters are already-hydrated BarrEx_Barrel
-- objects; resolving world objects to barrel data is the caller's job.

local LiquidConfig   = require("config/BarrEx_LiquidConfig")
local TransferConfig = require("config/BarrEx_TransferConfig")
local LiquidAdapter  = require("BarrEx_LiquidContainerAdapter")

local TransferRules = {}

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

-- ---------------------------------------------------------------------------
-- Compatibility helpers
-- ---------------------------------------------------------------------------

--- Returns the barrel liquid type of the primary fluid in sourceItem, or nil.
---@param sourceItem InventoryItem
---@return string|nil
function TransferRules.getSourceLiquidType(sourceItem)
    return LiquidAdapter.getLiquidType(sourceItem)
end

--- Returns true when item is a configured compatible container for liquidType.
--- This checks only the static whitelist – it does NOT check whether the item
--- currently has free capacity or matching contents.
---@param item InventoryItem
---@param liquidType string
---@return boolean
function TransferRules.isContainerCompatibleWithLiquid(item, liquidType)
    if not item or not liquidType then return false end
    -- canReceive checks both the whitelist and that the item can accept the
    -- liquid type given its current contents, which is intentionally the
    -- narrower "will this work right now?" check we want for transfer gates.
    return LiquidAdapter.canReceive(item, liquidType)
end

-- ---------------------------------------------------------------------------
-- Pour rules (item -> barrel)
-- ---------------------------------------------------------------------------

--- Returns true when sourceItem can currently be poured into barrelData.
--- Does NOT check player range or tool requirements.
---@param barrelData BarrEx_Barrel
---@param sourceItem InventoryItem
---@return boolean
function TransferRules.canPourIntoBarrel(barrelData, sourceItem)
    if not barrelData or not sourceItem then return false end
    if not barrelData:isRevealed() then return false end
    if barrelData:isFull() then return false end

    local liquidType = LiquidAdapter.getLiquidType(sourceItem)
    if not liquidType then return false end

    if not LiquidAdapter.canProvide(sourceItem, liquidType) then return false end
    if not barrelData:canAcceptLiquid(liquidType, 1) then return false end

    return true
end

--- Returns the maximum units transferable from sourceItem into barrelData,
--- or 0 when the transfer is not possible.
---@param barrelData BarrEx_Barrel
---@param sourceItem InventoryItem
---@return number
function TransferRules.getPourAmount(barrelData, sourceItem)
    if not barrelData or not sourceItem then return 0 end
    return math.max(math.min(LiquidAdapter.getAmount(sourceItem), barrelData:getFreeCapacity()), 0)
end

-- ---------------------------------------------------------------------------
-- Extract rules (barrel -> item)
-- ---------------------------------------------------------------------------

--- Returns true when barrelData can currently fill targetItem.
--- Does NOT check player range or tool requirements.
---@param barrelData BarrEx_Barrel
---@param targetItem InventoryItem
---@return boolean
function TransferRules.canExtractFromBarrel(barrelData, targetItem)
    if not barrelData or not targetItem then return false end
    if not barrelData:isRevealed() then return false end
    if barrelData:isEmpty() then return false end

    local liquidType = barrelData.liquidType
    if type(liquidType) ~= "string" then return false end
    if LiquidConfig.LIQUID_TYPE[liquidType] == nil then return false end
    if liquidType == LiquidConfig.LIQUID_TYPE.EMPTY then return false end

    if not LiquidAdapter.canReceive(targetItem, liquidType) then return false end

    return true
end

--- Returns the maximum units extractable from barrelData into targetItem,
--- or 0 when the transfer is not possible.
---@param barrelData BarrEx_Barrel
---@param targetItem InventoryItem
---@return number
function TransferRules.getExtractAmount(barrelData, targetItem)
    if not barrelData or not targetItem then return 0 end
    return math.max(math.min(barrelData.amount or 0, LiquidAdapter.getFreeCapacity(targetItem)), 0)
end

-- ---------------------------------------------------------------------------
-- Transfer duration
-- ---------------------------------------------------------------------------

--- Returns the timed-action duration in ticks for a transfer of `amount` units.
--- Mirrors the vanilla formula scaled by TRANSFER_ACTION_TIME_MULTIPLIER.
---@param amount number|nil
---@return number
function TransferRules.getTransferActionTime(amount)
    local normalizedAmount = tonumber(amount) or 0
    local baseDuration = getVanillaMinTransferTime()

    if normalizedAmount > 0 then
        local vanillaDuration = normalizedAmount * getVanillaTransferTimePerUnit()
        if vanillaDuration > baseDuration then
            baseDuration = vanillaDuration
        end
    end

    local multiplier = tonumber(TransferConfig.ACTION_TIME_MULTIPLIER) or 1
    if multiplier <= 0 then
        multiplier = 1
    end

    return math.max(math.floor(baseDuration * multiplier), 1)
end

return TransferRules
