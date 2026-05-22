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
local GeneratorUtils = require("utils/BarrEx_GeneratorUtils")

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
    -- Defensive: verify this pour is actually allowed before calculating amount.
    if not TransferRules.canPourIntoBarrel(barrelData, sourceItem) then
        return 0
    end
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
    if not TransferRules.canExtractFromBarrel(barrelData, targetItem) then
        return 0
    end

    return math.max(math.min(barrelData.amount or 0, LiquidAdapter.getFreeCapacity(targetItem)), 0)
end

-- ---------------------------------------------------------------------------
-- Empty rules (barrel -> world)
-- ---------------------------------------------------------------------------

--- Returns true when barrelData can currently be emptied.
--- Does NOT check player range.
---@param barrelData BarrEx_Barrel
---@return boolean
function TransferRules.canEmptyBarrel(barrelData)
    if not barrelData then return false end
    if not barrelData:isRevealed() then return false end
    if barrelData:isEmpty() then return false end

    local liquidType = barrelData.liquidType
    if type(liquidType) ~= "string" then return false end
    if LiquidConfig.LIQUID_TYPE[liquidType] == nil then return false end
    if liquidType == LiquidConfig.LIQUID_TYPE.EMPTY then return false end

    return true
end

--- Returns the maximum units discardable from barrelData.
---@param barrelData BarrEx_Barrel
---@return number
function TransferRules.getEmptyAmount(barrelData)
    if not TransferRules.canEmptyBarrel(barrelData) then
        return 0
    end

    return math.max(tonumber(barrelData.amount) or 0, 0)
end

-- ---------------------------------------------------------------------------
-- Barrel-to-barrel rules
-- ---------------------------------------------------------------------------

--- Returns true when liquid can move from one revealed barrel to another.
--- Does NOT check player range, locks, tools, or world-object identity.
---@param sourceBarrelData BarrEx_Barrel
---@param targetBarrelData BarrEx_Barrel
---@return boolean
function TransferRules.canTransferBetweenBarrels(sourceBarrelData, targetBarrelData)
    if not sourceBarrelData or not targetBarrelData then return false end
    if not sourceBarrelData:isRevealed() or not targetBarrelData:isRevealed() then return false end
    if sourceBarrelData:isEmpty() or targetBarrelData:isFull() then return false end

    local liquidType = sourceBarrelData.liquidType
    if type(liquidType) ~= "string" then return false end
    if LiquidConfig.LIQUID_TYPE[liquidType] == nil then return false end
    if liquidType == LiquidConfig.LIQUID_TYPE.EMPTY then return false end

    return targetBarrelData:canAcceptLiquid(liquidType, 1)
end

--- Returns the maximum units transferable from one barrel into another.
---@param sourceBarrelData BarrEx_Barrel
---@param targetBarrelData BarrEx_Barrel
---@return number
function TransferRules.getBarrelToBarrelAmount(sourceBarrelData, targetBarrelData)
    if not TransferRules.canTransferBetweenBarrels(sourceBarrelData, targetBarrelData) then
        return 0
    end

    return math.max(math.min(
        tonumber(sourceBarrelData.amount) or 0,
        targetBarrelData:getFreeCapacity()
    ), 0)
end

-- ---------------------------------------------------------------------------
-- Barrel-to-generator rules
-- ---------------------------------------------------------------------------

--- Returns true when a revealed gasoline barrel can refuel a generator.
--- Does NOT check player range, locks, tools, or world-object identity.
---@param sourceBarrelData BarrEx_Barrel
---@param generator IsoGenerator
---@return boolean
function TransferRules.canFuelGeneratorFromBarrel(sourceBarrelData, generator)
    if not sourceBarrelData or not GeneratorUtils.canReceiveFuel(generator) then return false end
    if not sourceBarrelData:isRevealed() or sourceBarrelData:isEmpty() then return false end
    if sourceBarrelData.liquidType ~= LiquidConfig.LIQUID_TYPE.GASOLINE then return false end

    return (tonumber(sourceBarrelData.amount) or 0) > 0
end

--- Returns the maximum units transferable from a gasoline barrel into a generator.
---@param sourceBarrelData BarrEx_Barrel
---@param generator IsoGenerator
---@return number
function TransferRules.getBarrelToGeneratorAmount(sourceBarrelData, generator)
    if not TransferRules.canFuelGeneratorFromBarrel(sourceBarrelData, generator) then
        return 0
    end

    return math.max(math.min(
        tonumber(sourceBarrelData.amount) or 0,
        GeneratorUtils.getFreeFuelCapacity(generator)
    ), 0)
end

-- ---------------------------------------------------------------------------
-- Generic endpoint rules
-- ---------------------------------------------------------------------------

--- Returns the maximum units transferable between resolved endpoint objects.
---@param sourceEndpoint table|nil
---@param targetEndpoint table|nil
---@return number
function TransferRules.getEndpointTransferAmount(sourceEndpoint, targetEndpoint)
    if type(sourceEndpoint) ~= "table" or type(targetEndpoint) ~= "table" then
        return 0
    end

    return math.max(math.min(
        tonumber(sourceEndpoint.amount) or 0,
        tonumber(targetEndpoint.freeCapacity) or 0
    ), 0)
end

-- ---------------------------------------------------------------------------
-- Transfer duration
-- ---------------------------------------------------------------------------

--- Returns the timed-action duration in ticks for a transfer of `amount` units.
--- Gasoline mirrors the vehicle radial-menu actions: adding fuel moves faster
--- than siphoning while preserving the same progress-driven transfer duration.
---@param amount number|nil
---@param mode string|nil
---@param liquidType string|nil
---@return number
function TransferRules.getTransferActionTime(amount, mode, liquidType)
    local normalizedAmount = tonumber(amount) or 0
    local baseDuration = getVanillaMinTransferTime()

    if normalizedAmount > 0 then
        if liquidType == LiquidConfig.LIQUID_TYPE.GASOLINE and mode == "barrel_to_generator" then
            return math.max(math.floor(70 + (normalizedAmount * 50)), 1)
        end

        if mode == "empty" then
            local timePerUnit = tonumber(TransferConfig.EMPTY_ACTION_TIME_PER_UNIT) or 5
            if timePerUnit <= 0 then
                timePerUnit = 5
            end
            return math.max(math.floor(math.max(baseDuration, normalizedAmount * timePerUnit)), 1)
        end

        local timePerUnit = getVanillaTransferTimePerUnit()
        if liquidType == LiquidConfig.LIQUID_TYPE.GASOLINE then
            if mode == "pour" then
                timePerUnit = 25
            elseif mode == "extract" then
                timePerUnit = 50
            end
        end

        local vanillaDuration = normalizedAmount * timePerUnit
        if vanillaDuration > baseDuration then
            baseDuration = vanillaDuration
        end
    end

    if liquidType == LiquidConfig.LIQUID_TYPE.GASOLINE then
        return math.max(math.floor(baseDuration), 1)
    end

    local multiplier = tonumber(TransferConfig.ACTION_TIME_MULTIPLIER) or 1
    if multiplier <= 0 then
        multiplier = 1
    end

    return math.max(math.floor(baseDuration * multiplier), 1)
end

-- ---------------------------------------------------------------------------
-- Inventory item validation (shared with UI menu collection)
-- ---------------------------------------------------------------------------

--- Returns true when sourceItem is a valid liquid container for pouring into
--- barrelData. Used by both client UI (menu inventory collection) and server
--- validation logic to avoid duplication.
---@param sourceItem InventoryItem
---@param barrelData BarrEx_Barrel
---@return boolean
function TransferRules.isValidSourceItemForPour(sourceItem, barrelData)
    if not sourceItem or not barrelData then return false end
    if barrelData:isFull() then return false end

    -- Determine the liquid type the source must provide.
    -- If barrel is empty, source can provide any compatible type.
    -- If barrel has liquid, source must match that type.
    local expectedType = nil
    if not barrelData:isEmpty() then
        expectedType = barrelData.liquidType
    end

    if not LiquidAdapter.isLiquidContainer(sourceItem) then
        return false
    end

    if not LiquidAdapter.canProvide(sourceItem, expectedType) then
        return false
    end

    local sourceType = LiquidAdapter.getLiquidType(sourceItem)
    if not sourceType then
        return false
    end

    -- Verify there's actually something transferable.
    local transferAmount = TransferRules.getPourAmount(barrelData, sourceItem)
    if transferAmount <= 0 then
        return false
    end

    return barrelData:canAcceptLiquid(sourceType, transferAmount)
end

--- Returns true when targetItem is a valid liquid container for extracting
--- from barrelData. Used by both client UI (menu inventory collection) and
--- server validation logic to avoid duplication.
---@param targetItem InventoryItem
---@param barrelData BarrEx_Barrel
---@return boolean
function TransferRules.isValidTargetItemForExtract(targetItem, barrelData)
    if not targetItem or not barrelData then return false end
    if barrelData:isEmpty() then return false end

    if not LiquidAdapter.canReceive(targetItem, barrelData.liquidType) then
        return false
    end

    return LiquidAdapter.getFreeCapacity(targetItem) > 0
end

return TransferRules
