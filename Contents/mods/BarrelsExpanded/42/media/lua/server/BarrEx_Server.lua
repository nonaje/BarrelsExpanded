local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory = require("BarrEx_BarrelFactory")

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

local function reconcilePlacedBarrel(worldObject)
    if not Utils.isExpandableBarrel(worldObject) then return end

    -- Single get() call reused for both the existence check and the reconcile logic,
    -- avoiding the triple deserialization that exists() + reconcileWorldObject() would cause.
    local barrelData = BarrEx_BarrelData.get(worldObject)

    if barrelData then
        -- Barrel already has data (placed from inventory or loaded from save).
        -- Re-anchor the position-based ID in case coordinates changed.
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

    -- New barrel with no data. Use explicit placement profile when available
    -- to distinguish crafted-world from player-placed crafted barrels.
    local spawnProfile = BarrEx_BarrelData.getSpawnProfile(worldObject) or Constant.BARREL_SPAWN_PROFILE.WORLD
    barrelData = BarrEx_BarrelFactory.createRandom(worldObject, {
        spawnProfile = spawnProfile,
    })
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

--- @param args table|nil
--- @return IsoObject|nil
local function getBarrelFromArgs(args)
    if not args then return nil end
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" or type(args.objectIndex) ~= "number" then return nil end

    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(args.x, args.y, args.z)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    if args.objectIndex < 0 or args.objectIndex >= objects:size() then
        return nil
    end

    local object = objects:get(args.objectIndex)
    if not Utils.isExpandableBarrel(object) then return nil end

    return object
end

--- Returns true if the player has at least one of the required tools in their inventory.
--- @param player IsoPlayer
--- @return boolean
local function playerHasRequiredTool(player)
    local inventory = player:getInventory()
    if not inventory then return false end

    for _, itemType in ipairs(Constant.OPEN_BARREL_REQUIRED_ITEMS) do
        if inventory:containsType(itemType) then
            return true
        end
    end

    return false
end

--- @param player IsoPlayer
--- @param args table
local function onOpenBarrel(player, args)
    local barrel = getBarrelFromArgs(args)
    if not barrel then return end

    if not Utils.isPlayerInRange(player, barrel) then
        log("Open rejected; player is too far from the barrel.")
        return
    end

    if not playerHasRequiredTool(player) then
        log("Open rejected; player does not have a required tool.")
        return
    end

    local barrelData = BarrEx_BarrelData.get(barrel)

    if not barrelData then
        -- Race condition: open command arrived before OnObjectAdded could auto-init.
        -- Create and reveal in a single set() call to avoid a redundant write.
        local spawnProfile = BarrEx_BarrelData.getSpawnProfile(barrel) or Constant.BARREL_SPAWN_PROFILE.WORLD

        barrelData = BarrEx_BarrelFactory.createRandom(barrel, {
            spawnProfile = spawnProfile,
        })
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

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        onOpenBarrel(player, args)
    end
end

-- Re-scan every barrel in a square when it is loaded from disk.
-- Events.OnObjectAdded only fires for newly-generated world objects (first visit).
-- Previously-saved squares reload their objects without re-firing OnObjectAdded,
-- so barrels in those squares would never be initialized or have their weight
-- re-applied. This handler fills that gap.
local function onLoadGridsquare(square)
    if not square then return end

    local objects = square:getObjects()
    if not objects then return end

    for i = 0, objects:size() - 1 do
        local worldObject = objects:get(i)
        if Utils.isExpandableBarrel(worldObject) then
            -- Fast path: re-apply the pre-computed weight stored in modData.
            -- Avoids a full normalize+serialize+buildId cycle for every barrel
            -- that already has valid data. Falls back to full reconcile only
            -- when no cached weight exists (first-time init or corrupted data).
            if not BarrEx_BarrelData.reapplyWeight(worldObject) then
                reconcilePlacedBarrel(worldObject)  -- also calls transmitModData
            else
                worldObject:transmitModData()  -- sync client after weight re-applied
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnObjectAdded.Add(reconcilePlacedBarrel)
Events.LoadGridsquare.Add(onLoadGridsquare)
