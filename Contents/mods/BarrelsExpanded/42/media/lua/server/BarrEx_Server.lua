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

    -- New barrel with no data (world-spawned). Auto-initialize so its weight
    -- is real from the moment the player encounters it.
    barrelData = BarrEx_BarrelFactory.createRandom(worldObject)
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

    local square = getCell():getGridSquare(args.x, args.y, args.z)
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
        barrelData = BarrEx_BarrelFactory.createRandom(barrel)
        barrelData.revealed = true
        BarrEx_BarrelData.set(barrel, barrelData)
        barrel:transmitModData()
        log("Barrel lazily initialized and revealed: " .. (barrelData.id or "unknown"))
        log("Liquid type: " .. (barrelData.liquidType or "none"))
        log(string.format("Amount: %d/%d", barrelData.amount or 0, barrelData.capacity or 0))
        log(string.format("Weight: %.2f", BarrEx_BarrelData.getWeight(barrelData)))
        return
    end

    if barrelData:isRevealed() then
        barrel:transmitModData()
        log("Open ignored; barrel already revealed: " .. (barrelData.id or "unknown"))
        return
    end

    barrelData.revealed = true
    BarrEx_BarrelData.set(barrel, barrelData)
    barrel:transmitModData()
    log("Barrel revealed: " .. (barrelData.id or "unknown"))
    log("Liquid type: " .. (barrelData.liquidType or "none"))
    log(string.format("Amount: %d/%d", barrelData.amount or 0, barrelData.capacity or 0))
    log(string.format("Weight: %.2f", BarrEx_BarrelData.getWeight(barrelData)))
end

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        onOpenBarrel(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnObjectAdded.Add(reconcilePlacedBarrel)
