local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory = require("BarrEx_BarrelFactory")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

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
--- @param requiredItems table<string>
--- @return boolean
local function playerHasRequiredTool(player, requiredItems)
    local inventory = player:getInventory()
    if not inventory then return false end

    for _, itemType in ipairs(requiredItems) do
        if Utils.findInventoryItem(inventory, nil, itemType) then
            return true
        end
    end

    return false
end

---@param player IsoPlayer
---@param args table|nil
---@return InventoryItem|nil
local function getItemFromArgs(player, args)
    if not player or type(args) ~= "table" then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    return Utils.findInventoryItem(inventory, args.itemId, args.itemFullType)
end

---@param barrel IsoObject|nil
---@param player IsoPlayer|nil
---@param requiredItems table<string>
---@return boolean
local function validateSharedInteraction(barrel, player, requiredItems)
    if not barrel or not player then return false end

    if not Utils.isPlayerInRange(player, barrel) then
        return false
    end

    if not playerHasRequiredTool(player, requiredItems) then
        return false
    end

    return true
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

    if not playerHasRequiredTool(player, Constant.OPEN_BARREL_REQUIRED_ITEMS) then
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

---@param barrel IsoObject
---@param barrelData BarrEx_Barrel
local function persistBarrel(barrel, barrelData)
    BarrEx_BarrelData.set(barrel, barrelData)
    barrel:transmitModData()
end

---@param player IsoPlayer
---@param args table
local function onPourIntoBarrel(player, args)
    local barrel = getBarrelFromArgs(args)
    if not barrel then
        log("Pour rejected; barrel was not found from command args.")
        return
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        log("Pour rejected; barrel is closed or missing data.")
        return
    end

    if not validateSharedInteraction(barrel, player, Constant.POUR_REQUIRED_ITEMS) then
        log("Pour rejected; failed shared interaction validation.")
        return
    end

    if barrelData:isFull() then
        log("Pour rejected; barrel is full.")
        return
    end

    local sourceItem = getItemFromArgs(player, args)
    if not sourceItem then
        log("Pour rejected; source item not found in player inventory.")
        return
    end

    local sourceLiquidType = LiquidAdapter.getLiquidType(sourceItem)
    if not sourceLiquidType then
        log("Pour rejected; source item has no recognized liquid.")
        return
    end

    if not LiquidAdapter.canProvide(sourceItem, sourceLiquidType) then
        log("Pour rejected; source item cannot provide the requested liquid.")
        return
    end

    if not barrelData:canAcceptLiquid(sourceLiquidType, 1) then
        log("Pour rejected; liquid type is incompatible with barrel contents.")
        return
    end

    local sourceAmount = LiquidAdapter.getAmount(sourceItem)
    local barrelFree = barrelData:getFreeCapacity()
    local transferAmount = math.max(math.min(sourceAmount, barrelFree), 0)

    if transferAmount <= 0 then
        log("Pour rejected; no transferable amount.")
        return
    end

    local removed = LiquidAdapter.removeLiquid(sourceItem, transferAmount)
    if removed <= 0 then
        log("Pour rejected; could not remove liquid from source item.")
        return
    end

    local added = barrelData:addLiquid(sourceLiquidType, removed)
    if added <= 0 then
        -- Restore source item when barrel add fails unexpectedly.
        LiquidAdapter.addLiquid(sourceItem, sourceLiquidType, removed)
        log("Pour rejected; barrel add returned zero.")
        return
    end

    local overflow = removed - added
    if overflow > 0 then
        LiquidAdapter.addLiquid(sourceItem, sourceLiquidType, overflow)
    end

    persistBarrel(barrel, barrelData)
    log(string.format(
        "Pour applied: id=%s liquid=%s moved=%.3f amount=%.3f/%.3f weight=%.2f",
        barrelData.id or "unknown",
        sourceLiquidType,
        added,
        barrelData.amount or 0,
        barrelData.capacity or 0,
        BarrEx_BarrelData.getWeight(barrelData)
    ))
end

---@param player IsoPlayer
---@param args table
local function onExtractFromBarrel(player, args)
    local barrel = getBarrelFromArgs(args)
    if not barrel then
        log("Extract rejected; barrel was not found from command args.")
        return
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        log("Extract rejected; barrel is closed or missing data.")
        return
    end

    if not validateSharedInteraction(barrel, player, Constant.EXTRACT_REQUIRED_ITEMS) then
        log("Extract rejected; failed shared interaction validation.")
        return
    end

    if barrelData:isEmpty() then
        log("Extract rejected; barrel is empty.")
        return
    end

    local targetItem = getItemFromArgs(player, args)
    if not targetItem then
        log("Extract rejected; target item not found in player inventory.")
        return
    end

    local liquidType = barrelData.liquidType
    if type(liquidType) ~= "string" or Constant.LIQUID_TYPE[liquidType] == nil or liquidType == Constant.LIQUID_TYPE.EMPTY then
        log("Extract rejected; barrel liquid type is invalid.")
        return
    end

    if not LiquidAdapter.canReceive(targetItem, liquidType) then
        log("Extract rejected; target item cannot receive this liquid type.")
        return
    end

    local available = barrelData.amount
    local freeCapacity = LiquidAdapter.getFreeCapacity(targetItem)
    local transferAmount = math.max(math.min(available, freeCapacity), 0)

    if transferAmount <= 0 then
        log("Extract rejected; no transferable amount.")
        return
    end

    local removed = barrelData:removeLiquid(transferAmount)
    if removed <= 0 then
        log("Extract rejected; could not remove liquid from barrel.")
        return
    end

    local added = LiquidAdapter.addLiquid(targetItem, liquidType, removed)
    if added <= 0 then
        -- Restore barrel when item add fails unexpectedly.
        barrelData:addLiquid(liquidType, removed)
        log("Extract rejected; could not add liquid to target item.")
        return
    end

    local overflow = removed - added
    if overflow > 0 then
        barrelData:addLiquid(liquidType, overflow)
    end

    persistBarrel(barrel, barrelData)
    log(string.format(
        "Extract applied: id=%s liquid=%s moved=%.3f amount=%.3f/%.3f weight=%.2f",
        barrelData.id or "unknown",
        liquidType,
        added,
        barrelData.amount or 0,
        barrelData.capacity or 0,
        BarrEx_BarrelData.getWeight(barrelData)
    ))
end

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        onOpenBarrel(player, args)
        return
    end

    if command == Constant.NETWORK.POUR_INTO_BARREL then
        onPourIntoBarrel(player, args)
        return
    end

    if command == Constant.NETWORK.EXTRACT_FROM_BARREL then
        onExtractFromBarrel(player, args)
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
