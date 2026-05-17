-- BarrEx_BarrelWorldService: barrel world-object lifecycle management.
--
-- Handles initialization and reconciliation on grid load. These are the
-- barrel's passive world-state concerns: creating and re-anchoring data on
-- IsoObjects without processing player actions.

local WorldUtils        = require("utils/BarrEx_WorldUtils")
local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory = require("BarrEx_BarrelFactory")
local Logger            = require("utils/BarrEx_Logger")

local BarrelWorldService = {}

local function log(message)
    Logger.info(message)
end

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

--- Initializes or re-anchors a barrel world-object that has just appeared.
--- Called both for new objects (OnObjectAdded) and reloaded squares (LoadGridsquare).
---@param worldObject IsoObject
local function reconcile(worldObject)
    if not WorldUtils.isExpandableBarrel(worldObject) then return end

    -- Single get() reused for existence check and reconcile to avoid redundant
    -- deserialization passes that exists() + reconcile() would produce.
    local barrelData = BarrEx_BarrelData.get(worldObject)

    if barrelData then
        BarrEx_BarrelData.ensureStableId(worldObject, barrelData)
        if BarrEx_BarrelData.set(worldObject, barrelData) then
            worldObject:transmitModData()
            log(string.format(
                "Barrel world state reconciled: id=%s amount=%d/%d weight=%.2f",
                barrelData.id or "unknown",
                barrelData.amount or 0,
                barrelData.capacity or 0,
                barrelData:getTotalWeight()
            ))
        end
        return
    end

    -- New barrel: generate random contents using the placement spawn profile.
    local spawnProfile = BarrEx_BarrelData.getSpawnProfile(worldObject) or Constant.BARREL_SPAWN_PROFILE.WORLD
    barrelData = BarrEx_BarrelFactory.createRandom(worldObject, { spawnProfile = spawnProfile })
    if BarrEx_BarrelData.set(worldObject, barrelData) then
        worldObject:transmitModData()
    end
    log(string.format(
        "Barrel auto-initialized: id=%s liquid=%s amount=%d/%d weight=%.2f",
        barrelData.id or "unknown",
        barrelData.liquidType or "none",
        barrelData.amount or 0,
        barrelData.capacity or 0,
        barrelData:getTotalWeight()
    ))
end

local function canUseWeightFastPath(worldObject)
    local modData = worldObject and worldObject:getModData() or nil
    if not modData then return false end

    local rawData = modData[Constant.MODDATA_KEYS.BARREL]
    local modDataId = modData[Constant.MODDATA_KEYS.BARREL_ID]
    local rawId = type(rawData) == "table" and rawData.id or nil

    return type(rawData) == "table"
        and type(modDataId) == "string" and modDataId ~= ""
        and type(rawId) == "string" and rawId ~= ""
        and type(modData[Constant.MODDATA_KEYS.BARREL_WEIGHT]) == "number"
end

-- ---------------------------------------------------------------------------
-- Public event handlers
-- ---------------------------------------------------------------------------

--- Events.OnObjectAdded handler.
---@param worldObject IsoObject
function BarrelWorldService.onObjectAdded(worldObject)
    reconcile(worldObject)
end

--- Events.LoadGridsquare handler.
--- Re-applies custom weight to every barrel on the square.  Falls back to full
--- reconcile only when no cached weight exists (first init or corrupted data).
---@param square IsoGridSquare
function BarrelWorldService.onLoadGridsquare(square)
    if not square then return end

    local objects = square:getObjects()
    if not objects then return end

    for i = 0, objects:size() - 1 do
        local worldObject = objects:get(i)
        if WorldUtils.isExpandableBarrel(worldObject) then
            if not canUseWeightFastPath(worldObject) or not BarrEx_BarrelData.reapplyWeight(worldObject) then
                reconcile(worldObject)
            end
        end
    end
end

return BarrelWorldService
