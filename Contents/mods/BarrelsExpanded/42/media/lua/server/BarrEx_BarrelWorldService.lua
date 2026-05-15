-- BarrEx_BarrelWorldService: barrel world-object lifecycle management.
--
-- Handles initialization, reconciliation on grid load, and the open-barrel
-- interaction.  These are the barrel's "world state" concerns: creating,
-- revealing and persisting barrel data on IsoObjects.

local Utils             = require("BarrEx_Utils")
local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory = require("BarrEx_BarrelFactory")
local BarrelResolver    = require("BarrEx_BarrelResolver")
local InteractionRules  = require("core/BarrEx_InteractionRules")

local BarrelWorldService = {}

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

--- Initializes or re-anchors a barrel world-object that has just appeared.
--- Called both for new objects (OnObjectAdded) and reloaded squares (LoadGridsquare).
---@param worldObject IsoObject
local function reconcile(worldObject)
    if not Utils.isExpandableBarrel(worldObject) then return end

    -- Single get() reused for existence check and reconcile to avoid redundant
    -- deserialization passes that exists() + reconcile() would produce.
    local barrelData = BarrEx_BarrelData.get(worldObject)

    if barrelData then
        -- Already initialized: re-anchor the position-based ID in case coordinates changed.
        barrelData.id = BarrEx_BarrelData.buildId(worldObject)
        BarrEx_BarrelData.set(worldObject, barrelData)
        worldObject:transmitModData()
        log(string.format(
            "Barrel world state reconciled: id=%s amount=%d/%d weight=%.2f",
            barrelData.id or "unknown",
            barrelData.amount or 0,
            barrelData.capacity or 0,
            barrelData:getTotalWeight()
        ))
        return
    end

    -- New barrel: generate random contents using the placement spawn profile.
    local spawnProfile = BarrEx_BarrelData.getSpawnProfile(worldObject) or Constant.BARREL_SPAWN_PROFILE.WORLD
    barrelData = BarrEx_BarrelFactory.createRandom(worldObject, { spawnProfile = spawnProfile })
    BarrEx_BarrelData.set(worldObject, barrelData)
    worldObject:transmitModData()
    log(string.format(
        "Barrel auto-initialized: id=%s liquid=%s amount=%d/%d weight=%.2f",
        barrelData.id or "unknown",
        barrelData.liquidType or "none",
        barrelData.amount or 0,
        barrelData.capacity or 0,
        barrelData:getTotalWeight()
    ))
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
        if Utils.isExpandableBarrel(worldObject) then
            if not BarrEx_BarrelData.reapplyWeight(worldObject) then
                reconcile(worldObject)
            else
                worldObject:transmitModData()
            end
        end
    end
end

--- Network command handler: opens a sealed barrel for the requesting player.
---@param player IsoPlayer
---@param args table
function BarrelWorldService.onOpenBarrel(player, args)
    local barrel = BarrelResolver.getBarrelFromArgs(args)
    if not barrel then return end

    if not Utils.isPlayerInRange(player, barrel) then
        log("Open rejected; player is too far from the barrel.")
        return
    end

    if not InteractionRules.playerHasRequiredTool(player, Constant.OPEN_BARREL_REQUIRED_ITEMS) then
        log("Open rejected; player does not have a required tool.")
        return
    end

    local barrelData = BarrEx_BarrelData.get(barrel)

    if not barrelData then
        -- Race condition: open command arrived before OnObjectAdded could auto-init.
        local spawnProfile = BarrEx_BarrelData.getSpawnProfile(barrel) or Constant.BARREL_SPAWN_PROFILE.WORLD
        barrelData = BarrEx_BarrelFactory.createRandom(barrel, { spawnProfile = spawnProfile })
        barrelData.revealed = true
        BarrEx_BarrelData.set(barrel, barrelData)
        barrel:transmitModData()
        log(string.format(
            "Barrel lazily initialized and revealed: id=%s liquid=%s amount=%d/%d weight=%.2f",
            barrelData.id or "unknown",
            barrelData.liquidType or "none",
            barrelData.amount or 0,
            barrelData.capacity or 0,
            BarrEx_BarrelData.getWeight(barrelData)
        ))
        return
    end

    if barrelData:isRevealed() then
        log("Open ignored; barrel already revealed: " .. (barrelData.id or "unknown"))
        return
    end

    barrelData.revealed = true
    BarrEx_BarrelData.set(barrel, barrelData)
    barrel:transmitModData()
    log(string.format(
        "Barrel revealed: id=%s liquid=%s amount=%d/%d weight=%.2f",
        barrelData.id or "unknown",
        barrelData.liquidType or "none",
        barrelData.amount or 0,
        barrelData.capacity or 0,
        BarrEx_BarrelData.getWeight(barrelData)
    ))
end

return BarrelWorldService
