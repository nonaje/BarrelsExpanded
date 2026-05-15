local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory = require("BarrEx_BarrelFactory")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

local activeTransfersByPlayer = {}
local activeTransfersByBarrel = {}

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

local function call(target, methodName, ...)
    if not target then return nil end

    local method = target[methodName]
    if type(method) ~= "function" then
        return nil
    end

    return method(target, ...)
end

local function notifyTransferRejected(player, mode, reason)
    if not player or type(sendServerCommand) ~= "function" then return end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_REJECTED, {
        mode = mode,
        reason = reason or "unknown",
    })
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

local function barrelMatchesArgs(barrel, args)
    if not barrel or not args then return false end

    if type(args.spriteName) == "string" and args.spriteName ~= "" then
        local spriteName = Utils.getSpriteName(barrel)
        if spriteName ~= args.spriteName then
            return false
        end
    end

    if type(args.barrelId) == "string" and args.barrelId ~= "" then
        local modData = call(barrel, "getModData")
        local storedId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
        if storedId == args.barrelId then
            return true
        end

        local barrelData = BarrEx_BarrelData.get(barrel)
        if barrelData and barrelData.id == args.barrelId then
            return true
        end

        return false
    end

    return true
end

--- @param args table|nil
--- @return IsoObject|nil
local function getBarrelFromArgs(args)
    if not args then return nil end
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then return nil end

    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(args.x, args.y, args.z)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    if type(args.objectIndex) == "number" and args.objectIndex >= 0 and args.objectIndex < objects:size() then
        local object = objects:get(args.objectIndex)
        if Utils.isExpandableBarrel(object) and barrelMatchesArgs(object, args) then
            return object
        end
    end

    -- Object indexes can shift in MP when square contents change. Fall back to
    -- scanning the square and validating the barrel id/sprite sent by the client.
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if Utils.isExpandableBarrel(object) and barrelMatchesArgs(object, args) then
            return object
        end
    end

    return nil
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
---@param checkTool boolean|nil
---@return boolean
local function validateSharedInteraction(barrel, player, requiredItems, checkTool)
    if not barrel or not player then return false end

    if not Utils.isPlayerInRange(player, barrel) then
        return false
    end

    if checkTool ~= false and not playerHasRequiredTool(player, requiredItems) then
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
---@param shouldTransmit boolean|nil
local function persistBarrel(barrel, barrelData, shouldTransmit)
    BarrEx_BarrelData.set(barrel, barrelData)
    if shouldTransmit and barrel then
        barrel:transmitModData()
    end
end

local function getPlayerTransferKey(player)
    if not player then return nil end

    if type(player.getOnlineID) == "function" then
        local onlineId = player:getOnlineID()
        if type(onlineId) == "number" and onlineId >= 0 then
            return onlineId
        end
    end

    return player
end

local function getBarrelLockKey(barrel, barrelData)
    if barrelData and type(barrelData.id) == "string" and barrelData.id ~= "" then
        return barrelData.id
    end

    return BarrEx_BarrelData.buildId(barrel)
end

local function syncTransferBarrel(transfer)
    if not transfer then return end

    local barrel = transfer.lastBarrel or getBarrelFromArgs(transfer.args)
    if barrel then
        barrel:transmitModData()
    end
end

local function releaseTransferLocks(playerKey, transfer)
    if not transfer then return end

    if transfer.barrelKey and activeTransfersByBarrel[transfer.barrelKey] == playerKey then
        activeTransfersByBarrel[transfer.barrelKey] = nil
    end
end

local function clearActiveTransfer(player, reason)
    local key = getPlayerTransferKey(player)
    if key == nil then return end

    local transfer = activeTransfersByPlayer[key]
    if not transfer then return end

    syncTransferBarrel(transfer)
    releaseTransferLocks(key, transfer)
    activeTransfersByPlayer[key] = nil

    log(string.format(
        "Transfer stopped: player=%s mode=%s moved=%.3f/%.3f reason=%s",
        tostring(player and player:getUsername() or "unknown"),
        transfer.mode or "unknown",
        transfer.movedAmount or 0,
        transfer.totalAmount or 0,
        reason or "cleared"
    ))
end

---@param player IsoPlayer
---@param args table
---@param checkTool boolean|nil
---@return IsoObject|nil
---@return BarrEx_Barrel|nil
---@return InventoryItem|nil
---@return string|nil
---@return string|nil
local function resolvePourTransfer(player, args, checkTool)
    local barrel = getBarrelFromArgs(args)
    if not barrel then
        return nil, nil, nil, nil, "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, nil, nil, "barrel_unavailable"
    end

    if not validateSharedInteraction(barrel, player, Constant.POUR_REQUIRED_ITEMS, checkTool) then
        return nil, nil, nil, nil, "interaction_invalid"
    end

    if barrelData:isFull() then
        return nil, nil, nil, nil, "barrel_full"
    end

    local sourceItem = getItemFromArgs(player, args)
    if not sourceItem then
        return nil, nil, nil, nil, "source_not_found"
    end

    local sourceLiquidType = LiquidAdapter.getLiquidType(sourceItem)
    if not sourceLiquidType then
        return nil, nil, nil, nil, "source_liquid_missing"
    end

    if not LiquidAdapter.canProvide(sourceItem, sourceLiquidType) then
        return nil, nil, nil, nil, "source_cannot_provide"
    end

    if not barrelData:canAcceptLiquid(sourceLiquidType, 1) then
        return nil, nil, nil, nil, "incompatible_liquid"
    end

    return barrel, barrelData, sourceItem, sourceLiquidType, nil
end

---@param barrelData BarrEx_Barrel
---@param sourceItem InventoryItem
---@return number
local function getMaxPourAmount(barrelData, sourceItem)
    return math.max(math.min(LiquidAdapter.getAmount(sourceItem), barrelData:getFreeCapacity()), 0)
end

---@param barrel IsoObject
---@param barrelData BarrEx_Barrel
---@param sourceItem InventoryItem
---@param sourceLiquidType string
---@param requestedAmount number|nil
---@return number
---@return string|nil
---@return IsoObject|nil
local function applyPourTransfer(barrel, barrelData, sourceItem, sourceLiquidType, requestedAmount)
    local sourceAmount = LiquidAdapter.getAmount(sourceItem)
    local barrelFree = barrelData:getFreeCapacity()
    local transferAmount = math.max(math.min(sourceAmount, barrelFree, requestedAmount or math.huge), 0)

    if transferAmount <= 0 then
        return 0, "no_transferable_amount", barrel
    end

    local removed = LiquidAdapter.removeLiquid(sourceItem, transferAmount)
    if removed <= 0 then
        return 0, "source_remove_failed", barrel
    end

    local added = barrelData:addLiquid(sourceLiquidType, removed)
    if added <= 0 then
        LiquidAdapter.addLiquid(sourceItem, sourceLiquidType, removed)
        return 0, "barrel_add_failed", barrel
    end

    local overflow = removed - added
    if overflow > 0 then
        LiquidAdapter.addLiquid(sourceItem, sourceLiquidType, overflow)
    end

    persistBarrel(barrel, barrelData, false)
    return added, nil, barrel
end

---@param player IsoPlayer
---@param args table
---@param checkTool boolean|nil
---@return IsoObject|nil
---@return BarrEx_Barrel|nil
---@return InventoryItem|nil
---@return string|nil
---@return string|nil
local function resolveExtractTransfer(player, args, checkTool)
    local barrel = getBarrelFromArgs(args)
    if not barrel then
        return nil, nil, nil, nil, "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, nil, nil, "barrel_unavailable"
    end

    if not validateSharedInteraction(barrel, player, Constant.EXTRACT_REQUIRED_ITEMS, checkTool) then
        return nil, nil, nil, nil, "interaction_invalid"
    end

    if barrelData:isEmpty() then
        return nil, nil, nil, nil, "barrel_empty"
    end

    local targetItem = getItemFromArgs(player, args)
    if not targetItem then
        return nil, nil, nil, nil, "target_not_found"
    end

    local liquidType = barrelData.liquidType
    if type(liquidType) ~= "string" or Constant.LIQUID_TYPE[liquidType] == nil or liquidType == Constant.LIQUID_TYPE.EMPTY then
        return nil, nil, nil, nil, "invalid_barrel_liquid"
    end

    if not LiquidAdapter.canReceive(targetItem, liquidType) then
        return nil, nil, nil, nil, "target_cannot_receive"
    end

    return barrel, barrelData, targetItem, liquidType, nil
end

---@param barrelData BarrEx_Barrel
---@param targetItem InventoryItem
---@return number
local function getMaxExtractAmount(barrelData, targetItem)
    return math.max(math.min(barrelData.amount or 0, LiquidAdapter.getFreeCapacity(targetItem)), 0)
end

---@param barrel IsoObject
---@param barrelData BarrEx_Barrel
---@param targetItem InventoryItem
---@param liquidType string
---@param requestedAmount number|nil
---@return number
---@return string|nil
---@return IsoObject|nil
local function applyExtractTransfer(barrel, barrelData, targetItem, liquidType, requestedAmount)
    local available = barrelData.amount
    local freeCapacity = LiquidAdapter.getFreeCapacity(targetItem)
    local transferAmount = math.max(math.min(available, freeCapacity, requestedAmount or math.huge), 0)

    if transferAmount <= 0 then
        return 0, "no_transferable_amount", barrel
    end

    local removed = barrelData:removeLiquid(transferAmount)
    if removed <= 0 then
        return 0, "barrel_remove_failed", barrel
    end

    local added = LiquidAdapter.addLiquid(targetItem, liquidType, removed)
    if added <= 0 then
        barrelData:addLiquid(liquidType, removed)
        return 0, "target_add_failed", barrel
    end

    local overflow = removed - added
    if overflow > 0 then
        barrelData:addLiquid(liquidType, overflow)
    end

    persistBarrel(barrel, barrelData, false)
    return added, nil, barrel
end

---@param player IsoPlayer
---@param mode string
---@param args table
local function startTransfer(player, mode, args)
    if not player or type(args) ~= "table" then return end

    local barrel, barrelData, item, liquidType, reason
    if mode == "pour" then
        barrel, barrelData, item, liquidType, reason = resolvePourTransfer(player, args, true)
    else
        barrel, barrelData, item, liquidType, reason = resolveExtractTransfer(player, args, true)
    end

    if not barrel or not barrelData or not item or not liquidType then
        log(string.format("Transfer start rejected: mode=%s reason=%s", mode, reason or "unknown"))
        notifyTransferRejected(player, mode, reason or "unknown")
        return
    end

    local totalAmount = 0
    if mode == "pour" then
        totalAmount = getMaxPourAmount(barrelData, item)
    else
        totalAmount = getMaxExtractAmount(barrelData, item)
    end
    if totalAmount <= 0 then
        log(string.format("Transfer start rejected: mode=%s reason=no_transferable_amount", mode))
        notifyTransferRejected(player, mode, "no_transferable_amount")
        return
    end

    local key = getPlayerTransferKey(player)
    if key == nil then return end

    if activeTransfersByPlayer[key] then
        clearActiveTransfer(player, "replaced_by_new_transfer")
    end

    local barrelKey = getBarrelLockKey(barrel, barrelData)
    if not barrelKey then
        log(string.format("Transfer start rejected: mode=%s reason=barrel_id_missing", mode))
        notifyTransferRejected(player, mode, "barrel_id_missing")
        return
    end

    local lockedBy = activeTransfersByBarrel[barrelKey]
    if lockedBy ~= nil and lockedBy ~= key then
        log(string.format("Transfer start rejected: mode=%s reason=barrel_locked id=%s", mode, barrelKey))
        notifyTransferRejected(player, mode, "barrel_locked")
        return
    end

    local totalTicks = math.max(Utils.getVanillaFluidActionTime(totalAmount), 1)
    local tickInterval = math.max(Constant.SERVER_TRANSFER_TICK_INTERVAL or 1, 1)

    local transfer = {
        player = player,
        mode = mode,
        args = args,
        liquidType = liquidType,
        barrelKey = barrelKey,
        lastBarrel = barrel,
        totalAmount = totalAmount,
        remainingAmount = totalAmount,
        movedAmount = 0,
        amountPerTick = totalAmount / totalTicks,
        tickInterval = tickInterval,
        ticksUntilStep = 0,
        ticksSinceSync = 0,
    }

    activeTransfersByPlayer[key] = transfer
    activeTransfersByBarrel[barrelKey] = key

    log(string.format(
        "Transfer started: player=%s mode=%s id=%s liquid=%s total=%.3f duration=%d interval=%d",
        tostring(player:getUsername()),
        mode,
        barrelData.id or "unknown",
        liquidType,
        totalAmount,
        totalTicks,
        tickInterval
    ))
end

---@param transfer table
---@param requestedAmount number|nil
---@return number
---@return string|nil
---@return IsoObject|nil
local function advanceTransfer(transfer, requestedAmount)
    if not transfer or not transfer.player then
        return 0, "missing_transfer", nil
    end

    -- Tool ownership is intentionally checked only at START. Per-tick validation
    -- keeps authoritative state cheap while still checking range, item and liquid compatibility.
    if transfer.mode == "pour" then
        local barrel, barrelData, sourceItem, liquidType, reason = resolvePourTransfer(transfer.player, transfer.args, false)
        if not barrel or not barrelData or not sourceItem or not liquidType then
            return 0, reason, barrel
        end

        transfer.lastBarrel = barrel
        return applyPourTransfer(barrel, barrelData, sourceItem, liquidType, requestedAmount)
    end

    local barrel, barrelData, targetItem, liquidType, reason = resolveExtractTransfer(transfer.player, transfer.args, false)
    if not barrel or not barrelData or not targetItem or not liquidType then
        return 0, reason, barrel
    end

    transfer.lastBarrel = barrel
    return applyExtractTransfer(barrel, barrelData, targetItem, liquidType, requestedAmount)
end

---@param player IsoPlayer
---@param mode string
local function completeTransfer(player, mode)
    local key = getPlayerTransferKey(player)
    if key == nil then return end

    local transfer = activeTransfersByPlayer[key]
    if not transfer or transfer.mode ~= mode then return end

    -- Do not move the remaining amount here. The server has already been moving
    -- liquid progressively on OnTick; COMPLETE is just the authoritative close signal.
    syncTransferBarrel(transfer)
    releaseTransferLocks(key, transfer)
    activeTransfersByPlayer[key] = nil

    log(string.format(
        "Transfer completed: player=%s mode=%s moved=%.3f/%.3f",
        tostring(player:getUsername()),
        mode,
        transfer.movedAmount or 0,
        transfer.totalAmount or 0
    ))
end

local function stopTransferByKey(key, transfer, reason, notify)
    syncTransferBarrel(transfer)
    releaseTransferLocks(key, transfer)
    activeTransfersByPlayer[key] = nil

    if notify and transfer and transfer.player then
        notifyTransferRejected(transfer.player, transfer.mode or "unknown", reason or "step_failed")
    end

    log(string.format(
        "Transfer interrupted: player=%s mode=%s moved=%.3f/%.3f reason=%s",
        tostring(transfer and transfer.player and transfer.player:getUsername() or "unknown"),
        transfer and transfer.mode or "unknown",
        transfer and transfer.movedAmount or 0,
        transfer and transfer.totalAmount or 0,
        reason or "step_failed"
    ))
end

local function onServerTick()
    for key, transfer in pairs(activeTransfersByPlayer) do
        if transfer.barrelKey and activeTransfersByBarrel[transfer.barrelKey] ~= key then
            stopTransferByKey(key, transfer, "barrel_lock_lost", true)
        else
            transfer.ticksUntilStep = (transfer.ticksUntilStep or transfer.tickInterval or 1) - 1
            if transfer.ticksUntilStep <= 0 then
                transfer.ticksUntilStep = transfer.tickInterval

                local requestedAmount = math.min(
                    transfer.remainingAmount or 0,
                    math.max((transfer.amountPerTick or 0) * (transfer.tickInterval or 1), 0)
                )
                if requestedAmount <= 0 then
                    syncTransferBarrel(transfer)
                    releaseTransferLocks(key, transfer)
                    activeTransfersByPlayer[key] = nil
                else
                    local movedAmount, reason, barrel = advanceTransfer(transfer, requestedAmount)
                    if barrel then
                        transfer.lastBarrel = barrel
                    end

                    if movedAmount <= 0 then
                        stopTransferByKey(key, transfer, reason or "step_failed", true)
                    else
                        transfer.movedAmount = transfer.movedAmount + movedAmount
                        transfer.remainingAmount = math.max((transfer.remainingAmount or 0) - movedAmount, 0)
                        transfer.ticksSinceSync = (transfer.ticksSinceSync or 0) + (transfer.tickInterval or 1)

                        if transfer.remainingAmount <= 0 then
                            syncTransferBarrel(transfer)
                            releaseTransferLocks(key, transfer)
                            activeTransfersByPlayer[key] = nil
                            log(string.format(
                                "Transfer finished: player=%s mode=%s moved=%.3f/%.3f",
                                tostring(transfer.player and transfer.player:getUsername() or "unknown"),
                                transfer.mode or "unknown",
                                transfer.movedAmount or 0,
                                transfer.totalAmount or 0
                            ))
                        elseif transfer.ticksSinceSync >= math.max(Constant.SERVER_TRANSFER_SYNC_INTERVAL or 10, 1) then
                            syncTransferBarrel(transfer)
                            transfer.ticksSinceSync = 0
                        end
                    end
                end
            end
        end
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        onOpenBarrel(player, args)
        return
    end

    if command == Constant.NETWORK.START_POUR_INTO_BARREL then
        startTransfer(player, "pour", args)
        return
    end

    if command == Constant.NETWORK.STOP_POUR_INTO_BARREL then
        clearActiveTransfer(player, "client_stop")
        return
    end

    if command == Constant.NETWORK.COMPLETE_POUR_INTO_BARREL then
        completeTransfer(player, "pour")
        return
    end

    if command == Constant.NETWORK.START_EXTRACT_FROM_BARREL then
        startTransfer(player, "extract", args)
        return
    end

    if command == Constant.NETWORK.STOP_EXTRACT_FROM_BARREL then
        clearActiveTransfer(player, "client_stop")
        return
    end

    if command == Constant.NETWORK.COMPLETE_EXTRACT_FROM_BARREL then
        completeTransfer(player, "extract")
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
Events.OnTick.Add(onServerTick)
