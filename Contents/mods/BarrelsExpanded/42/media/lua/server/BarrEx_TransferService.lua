-- BarrEx_TransferService: server-authoritative transfer lifecycle orchestration.
--
-- Owns the active-transfer state, drives the per-tick loop, and applies
-- the actual liquid mutations.  The server is the only authority for changing
-- barrel or item contents; this module is the sole place that calls addLiquid /
-- removeLiquid and writes back to modData.
--
-- Collaborators (injected via require, no globals):
--   BarrelResolver   – locates IsoObjects from client args
--   LockService      – barrel lock acquire / release
--   Notifier         – outbound sendServerCommand wrappers
--   InteractionRules – tool and range validation
--   TransferRules    – pure amount calculations (shared with client)

local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter     = require("BarrEx_LiquidContainerAdapter")
local TransferRules     = require("core/BarrEx_TransferRules")
local InteractionRules  = require("core/BarrEx_InteractionRules")
local BarrelResolver    = require("BarrEx_BarrelResolver")
local LockService       = require("BarrEx_BarrelLockService")
local StateService      = require("BarrEx_BarrelStateService")
local Notifier          = require("BarrEx_TransferNotifier")
local EndpointResolver  = require("BarrEx_LiquidEndpointResolver")
local Logger            = require("utils/BarrEx_Logger")
local PlayerUtils       = require("utils/BarrEx_PlayerUtils")

local TransferService = {}

-- playerKey → transfer object for every in-progress transfer.
local activeTransfers = {}
-- playerKey → transferId → immutable-ish closed transfer reply.
local closedTransfers = {}
local CLOSED_TRANSFER_CACHE_LIMIT = 8
local TRANSFER_EPSILON = 0.0001
local BARREL_TO_BARREL_MODE = "barrel_to_barrel"
local BARREL_TO_GENERATOR_MODE = "barrel_to_generator"
local ENDPOINT_TRANSFER_MODES = {
    [BARREL_TO_BARREL_MODE] = true,
    [BARREL_TO_GENERATOR_MODE] = true,
}

local function log(message)
    Logger.info(message)
end

local function isValidTransferId(transferId)
    return (type(transferId) == "string" and transferId ~= "")
        or type(transferId) == "number"
end

local function isEndpointTransferMode(mode)
    return ENDPOINT_TRANSFER_MODES[mode] == true
end

local function clamp01(value)
    local numericValue = tonumber(value) or 0
    if numericValue < 0 then return 0 end
    if numericValue > 1 then return 1 end
    return numericValue
end

local function getActionId(args)
    if type(args) ~= "table" then return nil end
    return args.actionId or args.transferId
end

local function getPlayerName(player)
    return tostring(player and player:getUsername() or "unknown")
end

local function getTransferRevision(transfer)
    if transfer and transfer.sourceEndpoint and transfer.sourceEndpoint.data then
        return transfer.sourceEndpoint.data.revision or "unknown"
    end

    local barrelData = transfer and transfer.lastBarrel and BarrEx_BarrelData.get(transfer.lastBarrel) or nil
    return barrelData and barrelData.revision or "unknown"
end

local function buildNotifySource(args, barrel, barrelData)
    if type(args) ~= "table" then return nil end

    return {
        args = args,
        transferId = args.transferId or args.actionId,
        mode = args.mode,
        barrelId = (barrelData and barrelData.id) or args.barrelId,
        itemId = args.itemId,
        lastBarrel = barrel,
    }
end

local function buildEndpointNotifySource(args, sourceEndpoint, targetEndpoint)
    if type(args) ~= "table" then return nil end

    local sourceSnapshot = EndpointResolver.snapshot(sourceEndpoint)
    local targetSnapshot = EndpointResolver.snapshot(targetEndpoint)

    return {
        args = args,
        transferId = args.transferId or args.actionId,
        mode = args.mode or BARREL_TO_BARREL_MODE,
        barrelId = sourceEndpoint and sourceEndpoint.barrelId or nil,
        targetBarrelId = targetEndpoint and targetEndpoint.barrelId or nil,
        lastBarrel = sourceEndpoint and sourceEndpoint.object or nil,
        sourceEndpoint = sourceEndpoint,
        targetEndpoint = targetEndpoint,
        snapshot = sourceSnapshot,
        sourceSnapshot = sourceSnapshot,
        targetSnapshot = targetSnapshot,
    }
end

local function logTransferRejected(player, mode, args, barrelData, reason)
    log(string.format(
        "Transfer command rejected: actionId=%s player=%s action=%s barrelId=%s revision=%s reason=%s",
        tostring(getActionId(args) or "unknown"),
        getPlayerName(player),
        tostring(mode or "unknown"),
        tostring((barrelData and barrelData.id) or (type(args) == "table" and args.barrelId) or "unknown"),
        tostring(barrelData and barrelData.revision or "unknown"),
        tostring(reason or "unknown")
    ))
end

local function buildCommandSource(mode, transferId)
    return {
        actionId = transferId,
        transferId = transferId,
        mode = mode,
    }
end

-- ---------------------------------------------------------------------------
-- Internal persistence helpers
-- ---------------------------------------------------------------------------

local function persistBarrel(barrel, barrelData, shouldTransmit, bumpRevision)
    if bumpRevision == true then
        BarrEx_BarrelData.bumpRevision(barrelData)
    end
    BarrEx_BarrelData.set(barrel, barrelData)
    if shouldTransmit and barrel then
        barrel:transmitModData()
    end
end

local function syncBarrel(transfer)
    if not transfer then return end

    if transfer.sourceEndpoint or transfer.targetEndpoint then
        EndpointResolver.sync(transfer.sourceEndpoint)
        EndpointResolver.sync(transfer.targetEndpoint)
        return
    end

    local barrel = transfer.lastBarrel or BarrelResolver.getBarrelFromArgs(transfer.args)
    if barrel then
        barrel:transmitModData()
    end
end

local function releaseTransferLocks(playerKey, transfer)
    if not transfer then return end
    if transfer.lockKeys then
        LockService.releaseMany(playerKey, transfer.lockKeys)
        return
    end

    LockService.release(playerKey, transfer.barrelKey)
end

local function isTransferLockedBy(playerKey, transfer)
    if not transfer then return false end
    if transfer.lockKeys then
        return LockService.isLockedByAll(playerKey, transfer.lockKeys)
    end

    return LockService.isLockedBy(transfer.barrelKey) == playerKey
end

local function isTransferCompleted(transfer)
    return (tonumber(transfer and transfer.remainingAmount) or 0) <= TRANSFER_EPSILON
end

local function isWaitingForClientProgress(transfer)
    if not transfer then return false end
    return clamp01(transfer.pendingClientProgress or transfer.clientProgress) < 1
end

local function hasPendingProgress(transfer)
    if not transfer then return false end

    local pendingProgress = clamp01(transfer.pendingClientProgress or transfer.clientProgress)
    local appliedProgress = clamp01(transfer.appliedProgress)
    return pendingProgress > appliedProgress + TRANSFER_EPSILON
end

local function isClientProgressStale(transfer)
    local staleTicks = math.max(tonumber(Constant.SERVER_TRANSFER_STALE_TICKS) or 0, 0)
    if staleTicks <= 0 or not isWaitingForClientProgress(transfer) then
        return false
    end

    transfer.ticksSinceClientProgress = (transfer.ticksSinceClientProgress or 0) + 1
    return transfer.ticksSinceClientProgress > staleTicks
end

local function transferMatches(transfer, mode, transferId)
    if not transfer then return false end
    if mode and transfer.mode ~= mode then return false end
    if not isValidTransferId(transferId) then return false end
    return tostring(transfer.transferId) == tostring(transferId)
end

local function getTransferItemId(transfer)
    if type(transfer) ~= "table" then return nil end
    if transfer.itemId then return transfer.itemId end
    if type(transfer.args) == "table" then
        return transfer.args.itemId
    end
    return nil
end

local function itemIdMatches(item, itemId)
    if not item or type(item.getID) ~= "function" then return false end
    local currentItemId = item:getID()
    return currentItemId == itemId or tostring(currentItemId) == tostring(itemId)
end

local function itemFullTypeMatches(item, itemFullType)
    if not itemFullType or itemFullType == "" then return true end
    if not item or type(item.getFullType) ~= "function" then return false end
    return item:getFullType() == itemFullType
end

local function inventoryContainsCachedItem(player, item, inventory)
    if not player or not item or type(item.getID) ~= "function" then return false end

    inventory = inventory or player:getInventory()
    if not inventory then return false end

    if type(inventory.containsID) == "function" then
        return inventory:containsID(item:getID()) == true
    end

    if type(inventory.contains) == "function" then
        return inventory:contains(item) == true
    end

    return false
end

local function barrelMatchesTransfer(barrel, transfer)
    if not barrel or not transfer then return false end

    local barrelId = transfer.barrelId
    if not barrelId then return true end

    return tostring(BarrEx_BarrelData.getId(barrel)) == tostring(barrelId)
end

local function getClosedBucket(playerKey, create)
    if not playerKey then return nil end

    local bucket = closedTransfers[playerKey]
    if not bucket and create == true then
        bucket = {
            items = {},
            order = {},
        }
        closedTransfers[playerKey] = bucket
    end
    return bucket
end

local function enforceClosedCacheLimit(bucket)
    if not bucket or not bucket.order or not bucket.items then return end

    while #bucket.order > CLOSED_TRANSFER_CACHE_LIMIT do
        local expiredTransferId = table.remove(bucket.order, 1)
        if expiredTransferId then
            bucket.items[expiredTransferId] = nil
        end
    end
end

local function cacheClosedTransfer(playerKey, transfer, reason, rejected, notified)
    if not playerKey or not transfer or not isValidTransferId(transfer.transferId) then return nil end

    local transferId = tostring(transfer.transferId)
    local sourceSnapshot = transfer.sourceSnapshot or EndpointResolver.snapshot(transfer.sourceEndpoint)
    local targetSnapshot = transfer.targetSnapshot or EndpointResolver.snapshot(transfer.targetEndpoint)
    local snapshot = transfer.snapshot or sourceSnapshot or StateService.buildSnapshot(transfer.lastBarrel)
    local closedTransfer = {
        player = transfer.player,
        transferId = transferId,
        actionId = transferId,
        mode = transfer.mode,
        args = transfer.args,
        barrelId = transfer.barrelKey or (snapshot and snapshot.barrelId),
        targetBarrelId = transfer.targetBarrelId or (targetSnapshot and targetSnapshot.barrelId),
        itemId = getTransferItemId(transfer),
        lastBarrel = transfer.lastBarrel,
        snapshot = snapshot,
        sourceSnapshot = sourceSnapshot,
        targetSnapshot = targetSnapshot,
        totalAmount = tonumber(transfer.totalAmount) or 0,
        movedAmount = tonumber(transfer.movedAmount) or 0,
        remainingAmount = tonumber(transfer.remainingAmount) or 0,
        closedReason = reason or (rejected == true and "step_failed" or "server_transfer_finished"),
        closedRejected = rejected == true,
        notified = notified == true,
    }

    local bucket = getClosedBucket(playerKey, true)
    if not bucket or not bucket.items or not bucket.order then
        return closedTransfer
    end

    if not bucket.items[transferId] then
        bucket.order[#bucket.order + 1] = transferId
    end
    bucket.items[transferId] = closedTransfer
    enforceClosedCacheLimit(bucket)
    return closedTransfer
end

local function finishTransfer(playerKey, transfer, reason, notifyProgress)
    syncBarrel(transfer)

    local closedTransfer = cacheClosedTransfer(
        playerKey,
        transfer,
        reason or "server_transfer_finished",
        false,
        notifyProgress == true
    )

    if notifyProgress and transfer and transfer.player then
        Notifier.progress(transfer.player, closedTransfer or transfer, true)
    end

    releaseTransferLocks(playerKey, transfer)
    activeTransfers[playerKey] = nil

    log(string.format(
        "Transfer finished: actionId=%s player=%s action=%s barrelId=%s revision=%s moved=%.3f/%.3f reason=%s",
        tostring(transfer and transfer.transferId or "unknown"),
        getPlayerName(transfer and transfer.player),
        transfer and transfer.mode or "unknown",
        transfer and transfer.barrelKey or "unknown",
        tostring(getTransferRevision(transfer)),
        transfer and transfer.movedAmount or 0,
        transfer and transfer.totalAmount or 0,
        reason or "server_transfer_finished"
    ))
end

local function getClosedTransfer(playerKey, mode, transferId)
    if not isValidTransferId(transferId) then return nil end

    local bucket = getClosedBucket(playerKey, false)
    local transfer = bucket and bucket.items and bucket.items[tostring(transferId)] or nil
    if transfer
        and (not mode or transfer.mode == mode)
        and tostring(transfer.transferId) == tostring(transferId)
    then
        return transfer
    end
    return nil
end

local function notifyClosedTransfer(player, transfer)
    if not player or not transfer then return false end

    if transfer.closedRejected == true then
        local silent = transfer.notified == true
        Notifier.rejected(player, transfer.mode or "unknown", transfer.closedReason or "step_failed", transfer, {
            silent = silent,
        })
    else
        Notifier.progress(player, transfer, true)
    end
    transfer.notified = true
    return true
end

-- ---------------------------------------------------------------------------
-- Pour: validate + apply
-- ---------------------------------------------------------------------------

---@return IsoObject|nil, BarrEx_Barrel|nil, InventoryItem|nil, string|nil, string|nil
local function resolvePour(player, args, checkTool)
    local barrel, resolveReason = BarrelResolver.resolveStrict(args)
    if not barrel then
        return nil, nil, nil, nil, resolveReason or "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, nil, nil, "barrel_unavailable"
    end

    if not InteractionRules.validateInteraction(barrel, player, Constant.POUR_REQUIRED_ITEMS, checkTool) then
        return nil, nil, nil, nil, "interaction_invalid"
    end

    if barrelData:isFull() then
        return nil, nil, nil, nil, "barrel_full"
    end

    local sourceItem = InteractionRules.getItemFromArgsStrict(player, args)
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

---@return number, string|nil, IsoObject|nil
local function applyPour(barrel, barrelData, sourceItem, sourceLiquidType, requestedAmount)
    local sourceAmount    = LiquidAdapter.getAmount(sourceItem)
    local barrelFree      = barrelData:getFreeCapacity()
    local transferAmount  = math.max(math.min(sourceAmount, barrelFree, requestedAmount or math.huge), 0)

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

    persistBarrel(barrel, barrelData, false, true)
    return added, nil, barrel
end

-- ---------------------------------------------------------------------------
-- Extract: validate + apply
-- ---------------------------------------------------------------------------

---@return IsoObject|nil, BarrEx_Barrel|nil, InventoryItem|nil, string|nil, string|nil
local function resolveExtract(player, args, checkTool)
    local barrel, resolveReason = BarrelResolver.resolveStrict(args)
    if not barrel then
        return nil, nil, nil, nil, resolveReason or "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, nil, nil, "barrel_unavailable"
    end

    if not InteractionRules.validateInteraction(barrel, player, Constant.EXTRACT_REQUIRED_ITEMS, checkTool) then
        return nil, nil, nil, nil, "interaction_invalid"
    end

    if barrelData:isEmpty() then
        return nil, nil, nil, nil, "barrel_empty"
    end

    local targetItem = InteractionRules.getItemFromArgsStrict(player, args)
    if not targetItem then
        return nil, nil, nil, nil, "target_not_found"
    end

    local liquidType = barrelData.liquidType
    if type(liquidType) ~= "string"
        or Constant.LIQUID_TYPE[liquidType] == nil
        or liquidType == Constant.LIQUID_TYPE.EMPTY
    then
        return nil, nil, nil, nil, "invalid_barrel_liquid"
    end

    if not LiquidAdapter.canReceive(targetItem, liquidType) then
        return nil, nil, nil, nil, "target_cannot_receive"
    end

    return barrel, barrelData, targetItem, liquidType, nil
end

---@return number, string|nil, IsoObject|nil
local function applyExtract(barrel, barrelData, targetItem, liquidType, requestedAmount)
    local available      = barrelData.amount
    local freeCapacity   = LiquidAdapter.getFreeCapacity(targetItem)
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

    persistBarrel(barrel, barrelData, false, true)
    return added, nil, barrel
end

-- ---------------------------------------------------------------------------
-- Empty: validate + apply
-- ---------------------------------------------------------------------------

---@return IsoObject|nil, BarrEx_Barrel|nil, string|nil, string|nil
local function resolveEmpty(player, args)
    local barrel, resolveReason = BarrelResolver.resolveStrict(args)
    if not barrel then
        return nil, nil, nil, resolveReason or "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, nil, "barrel_unavailable"
    end

    if not InteractionRules.validateInteraction(barrel, player, {}, false) then
        return nil, nil, nil, "interaction_invalid"
    end

    if not TransferRules.canEmptyBarrel(barrelData) then
        return nil, nil, nil, "barrel_empty"
    end

    return barrel, barrelData, barrelData.liquidType, nil
end

---@return number, string|nil, IsoObject|nil
local function applyEmpty(barrel, barrelData, requestedAmount)
    local available = tonumber(barrelData and barrelData.amount) or 0
    local transferAmount = math.max(math.min(available, requestedAmount or math.huge), 0)

    if transferAmount <= 0 then
        return 0, "no_transferable_amount", barrel
    end

    local removed = barrelData:removeLiquid(transferAmount)
    if removed <= 0 then
        return 0, "barrel_remove_failed", barrel
    end

    persistBarrel(barrel, barrelData, false, true)
    return removed, nil, barrel
end

-- ---------------------------------------------------------------------------
-- Endpoint transfer: validate + apply
-- ---------------------------------------------------------------------------

---@return table|nil, table|nil, string|nil, string|nil
local function resolveEndpointTransfer(player, args)
    if type(args) ~= "table" then
        return nil, nil, nil, "invalid_args"
    end

    local sourceEndpoint, sourceReason = EndpointResolver.resolve(player, args.source)
    if not sourceEndpoint then
        return nil, nil, nil, sourceReason or "source_not_found"
    end

    local targetEndpoint, targetReason = EndpointResolver.resolve(player, args.target)
    if not targetEndpoint then
        return sourceEndpoint, nil, nil, targetReason or "target_not_found"
    end

    if sourceEndpoint.key == targetEndpoint.key then
        return sourceEndpoint, targetEndpoint, nil, "same_endpoint"
    end

    if args.mode == BARREL_TO_BARREL_MODE then
        if sourceEndpoint.kind ~= EndpointResolver.KIND.BARREL
            or targetEndpoint.kind ~= EndpointResolver.KIND.BARREL
        then
            return sourceEndpoint, targetEndpoint, nil, "endpoint_mismatch"
        end
    elseif args.mode == BARREL_TO_GENERATOR_MODE then
        if sourceEndpoint.kind ~= EndpointResolver.KIND.BARREL
            or targetEndpoint.kind ~= EndpointResolver.KIND.GENERATOR
        then
            return sourceEndpoint, targetEndpoint, nil, "endpoint_mismatch"
        end
    end

    if args.mode == BARREL_TO_GENERATOR_MODE
        and not InteractionRules.playerHasRequiredTool(player, Constant.EXTRACT_REQUIRED_ITEMS)
    then
        return sourceEndpoint, targetEndpoint, nil, "interaction_invalid"
    end

    if isEndpointTransferMode(args.mode)
        and not PlayerUtils.isObjectInRange(sourceEndpoint.object, targetEndpoint.object)
    then
        return sourceEndpoint, targetEndpoint, nil, "interaction_invalid"
    end

    if not EndpointResolver.canProvide(sourceEndpoint) then
        local sourceLiquidType = EndpointResolver.getLiquidType(sourceEndpoint)
        if not sourceLiquidType or sourceLiquidType == Constant.LIQUID_TYPE.EMPTY then
            return sourceEndpoint, targetEndpoint, nil, "source_liquid_missing"
        end
        return sourceEndpoint, targetEndpoint, nil, "source_cannot_provide"
    end

    local liquidType = EndpointResolver.getLiquidType(sourceEndpoint)
    if not EndpointResolver.canReceive(targetEndpoint, liquidType) then
        if targetEndpoint.data and targetEndpoint.data:isFull() then
            return sourceEndpoint, targetEndpoint, liquidType, "barrel_full"
        end
        if targetEndpoint.kind == EndpointResolver.KIND.GENERATOR then
            if EndpointResolver.getFreeCapacity(targetEndpoint) <= 0 then
                return sourceEndpoint, targetEndpoint, liquidType, "generator_full"
            end
            if liquidType ~= Constant.LIQUID_TYPE.GASOLINE then
                return sourceEndpoint, targetEndpoint, liquidType, "generator_requires_gasoline"
            end
            return sourceEndpoint, targetEndpoint, liquidType, "target_cannot_receive"
        end
        return sourceEndpoint, targetEndpoint, liquidType, "incompatible_liquid"
    end

    return sourceEndpoint, targetEndpoint, liquidType, nil
end

---@return table|nil, table|nil, string|nil, string|nil
local function resolveActiveEndpointContext(transfer)
    local sourceEndpoint, sourceReason = EndpointResolver.refresh(transfer.player, transfer.sourceEndpoint)
    if not sourceEndpoint then
        return nil, nil, nil, sourceReason or "source_not_found"
    end

    local targetEndpoint, targetReason = EndpointResolver.refresh(transfer.player, transfer.targetEndpoint)
    if not targetEndpoint then
        return sourceEndpoint, nil, nil, targetReason or "target_not_found"
    end

    if sourceEndpoint.key == targetEndpoint.key then
        return sourceEndpoint, targetEndpoint, nil, "same_endpoint"
    end

    if isEndpointTransferMode(transfer.mode)
        and not PlayerUtils.isObjectInRange(sourceEndpoint.object, targetEndpoint.object)
    then
        return sourceEndpoint, targetEndpoint, nil, "interaction_invalid"
    end

    if not EndpointResolver.canProvide(sourceEndpoint) then
        return sourceEndpoint, targetEndpoint, nil, "source_liquid_missing"
    end

    local liquidType = EndpointResolver.getLiquidType(sourceEndpoint)
    if liquidType ~= transfer.liquidType then
        return sourceEndpoint, targetEndpoint, nil, "incompatible_liquid"
    end

    if not EndpointResolver.canReceive(targetEndpoint, liquidType) then
        if targetEndpoint.data and targetEndpoint.data:isFull() then
            return sourceEndpoint, targetEndpoint, liquidType, "barrel_full"
        end
        if targetEndpoint.kind == EndpointResolver.KIND.GENERATOR then
            if EndpointResolver.getFreeCapacity(targetEndpoint) <= 0 then
                return sourceEndpoint, targetEndpoint, liquidType, "generator_full"
            end
            if liquidType ~= Constant.LIQUID_TYPE.GASOLINE then
                return sourceEndpoint, targetEndpoint, liquidType, "generator_requires_gasoline"
            end
            return sourceEndpoint, targetEndpoint, liquidType, "target_cannot_receive"
        end
        return sourceEndpoint, targetEndpoint, liquidType, "incompatible_liquid"
    end

    return sourceEndpoint, targetEndpoint, liquidType, nil
end

local function getTargetAddFailedReason(endpoint)
    if endpoint and endpoint.kind == EndpointResolver.KIND.GENERATOR then
        return "generator_add_failed"
    end

    return "target_add_failed"
end

---@return number, string|nil, IsoObject|nil
local function applyEndpointTransfer(transfer, requestedAmount)
    local sourceEndpoint, targetEndpoint, liquidType, reason = resolveActiveEndpointContext(transfer)
    if reason then
        return 0, reason, sourceEndpoint and sourceEndpoint.object or nil
    end
    if not sourceEndpoint or not targetEndpoint or not liquidType then
        return 0, reason, sourceEndpoint and sourceEndpoint.object or nil
    end

    local available = EndpointResolver.getAmount(sourceEndpoint)
    local freeCapacity = EndpointResolver.getFreeCapacity(targetEndpoint)
    local transferAmount = math.max(math.min(available, freeCapacity, requestedAmount or math.huge), 0)

    if transferAmount <= 0 then
        return 0, "no_transferable_amount", sourceEndpoint.object
    end

    local removed = EndpointResolver.removeLiquid(sourceEndpoint, transferAmount)
    if removed <= 0 then
        return 0, "source_remove_failed", sourceEndpoint.object
    end

    local added = EndpointResolver.addLiquid(targetEndpoint, liquidType, removed)
    if added <= 0 then
        EndpointResolver.addLiquid(sourceEndpoint, liquidType, removed)
        return 0, getTargetAddFailedReason(targetEndpoint), sourceEndpoint.object
    end

    local overflow = removed - added
    if overflow > 0 then
        EndpointResolver.addLiquid(sourceEndpoint, liquidType, overflow)
    end

    transfer.sourceEndpoint = sourceEndpoint
    transfer.targetEndpoint = targetEndpoint
    transfer.lastBarrel = sourceEndpoint.object
    transfer.sourceSnapshot = EndpointResolver.persist(sourceEndpoint, true, false)
    transfer.targetSnapshot = EndpointResolver.persist(targetEndpoint, true, false)
    transfer.snapshot = transfer.sourceSnapshot

    return added, nil, sourceEndpoint.object
end

local function resolveActiveBarrel(transfer)
    if not transfer then
        return nil, nil, "missing_transfer"
    end

    local barrel = transfer.lastBarrel
    if not barrelMatchesTransfer(barrel, transfer) then
        barrel = nil
    end

    if not barrel then
        local reason
        barrel, reason = BarrelResolver.resolveStrict(transfer.args)
        if not barrel then
            return nil, nil, reason or "barrel_not_found"
        end
        if not barrelMatchesTransfer(barrel, transfer) then
            return nil, nil, "barrel_not_found"
        end
        transfer.lastBarrel = barrel
        transfer.barrelData = nil
    end

    local barrelData = transfer.barrelData
    if not barrelData then
        barrelData = BarrEx_BarrelData.get(barrel)
        transfer.barrelData = barrelData
    end

    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, "barrel_unavailable"
    end

    if transfer.barrelId and barrelData.id ~= transfer.barrelId then
        return nil, nil, "barrel_not_found"
    end

    return barrel, barrelData, nil
end

local function resolveActiveItem(transfer, missingReason)
    if not transfer or transfer.mode == "empty" then return nil, nil end

    local item = transfer.item
    if item
        and itemIdMatches(item, transfer.itemId)
        and itemFullTypeMatches(item, transfer.itemFullType)
        and inventoryContainsCachedItem(transfer.player, item, transfer.inventory)
    then
        return item, nil
    end

    item = InteractionRules.getItemFromArgsStrict(transfer.player, transfer.args)
    if not item then
        return nil, missingReason or "source_not_found"
    end
    if not itemIdMatches(item, transfer.itemId) or not itemFullTypeMatches(item, transfer.itemFullType) then
        return nil, missingReason or "source_not_found"
    end

    transfer.item = item
    return item, nil
end

local function resolveActiveContext(transfer)
    local barrel, barrelData, reason = resolveActiveBarrel(transfer)
    if not barrel or not barrelData then
        return nil, nil, nil, nil, reason
    end

    if not InteractionRules.validateInteraction(barrel, transfer.player, {}, false) then
        return nil, nil, nil, nil, "interaction_invalid"
    end

    if transfer.mode == "empty" then
        if not TransferRules.canEmptyBarrel(barrelData) then
            return nil, nil, nil, nil, "barrel_empty"
        end
        return barrel, barrelData, nil, barrelData.liquidType, nil
    end

    if transfer.mode == "pour" then
        if barrelData:isFull() then
            return nil, nil, nil, nil, "barrel_full"
        end

        local sourceItem, itemReason = resolveActiveItem(transfer, "source_not_found")
        if not sourceItem then
            return nil, nil, nil, nil, itemReason
        end

        local sourceLiquidType = LiquidAdapter.getLiquidType(sourceItem)
        if not sourceLiquidType then
            return nil, nil, nil, nil, "source_liquid_missing"
        end
        if sourceLiquidType ~= transfer.liquidType then
            return nil, nil, nil, nil, "incompatible_liquid"
        end
        if not LiquidAdapter.canProvide(sourceItem, sourceLiquidType) then
            return nil, nil, nil, nil, "source_cannot_provide"
        end
        if not barrelData:canAcceptLiquid(sourceLiquidType, 1) then
            return nil, nil, nil, nil, "incompatible_liquid"
        end

        return barrel, barrelData, sourceItem, sourceLiquidType, nil
    end

    if barrelData:isEmpty() then
        return nil, nil, nil, nil, "barrel_empty"
    end

    local liquidType = barrelData.liquidType
    if type(liquidType) ~= "string"
        or Constant.LIQUID_TYPE[liquidType] == nil
        or liquidType == Constant.LIQUID_TYPE.EMPTY
        or liquidType ~= transfer.liquidType
    then
        return nil, nil, nil, nil, "invalid_barrel_liquid"
    end

    local targetItem, itemReason = resolveActiveItem(transfer, "target_not_found")
    if not targetItem then
        return nil, nil, nil, nil, itemReason
    end
    if not LiquidAdapter.canReceive(targetItem, liquidType) then
        return nil, nil, nil, nil, "target_cannot_receive"
    end

    return barrel, barrelData, targetItem, liquidType, nil
end

-- ---------------------------------------------------------------------------
-- Tick advance
-- ---------------------------------------------------------------------------

--- Advances one step of the active transfer, routing to pour or extract.
--- Tool ownership is checked only at start; per-tick skips it for performance.
---@return number, string|nil, IsoObject|nil
local function advance(transfer, requestedAmount)
    if not transfer or not transfer.player then
        return 0, "missing_transfer", nil
    end

    if isEndpointTransferMode(transfer.mode) then
        return applyEndpointTransfer(transfer, requestedAmount)
    end

    local barrel, barrelData, item, liquidType, reason = resolveActiveContext(transfer)
    if not barrel or not barrelData or (transfer.mode ~= "empty" and not item) or not liquidType then
        return 0, reason, barrel
    end

    transfer.lastBarrel = barrel
    transfer.barrelData = barrelData

    if transfer.mode == "pour" then
        return applyPour(barrel, barrelData, item, liquidType, requestedAmount)
    end

    if transfer.mode == "empty" then
        return applyEmpty(barrel, barrelData, requestedAmount)
    end

    return applyExtract(barrel, barrelData, item, liquidType, requestedAmount)
end

-- ---------------------------------------------------------------------------
-- Internal stop (step failure / lock lost)
-- ---------------------------------------------------------------------------

local function stopByKey(playerKey, transfer, reason, notify)
    syncBarrel(transfer)
    local closedTransfer = cacheClosedTransfer(playerKey, transfer, reason or "step_failed", true, notify == true)
    releaseTransferLocks(playerKey, transfer)
    activeTransfers[playerKey] = nil

    if notify and transfer and transfer.player then
        Notifier.rejected(transfer.player, transfer.mode or "unknown", reason or "step_failed", closedTransfer or transfer)
    end

    log(string.format(
        "Transfer interrupted: actionId=%s player=%s action=%s barrelId=%s revision=%s moved=%.3f/%.3f reason=%s",
        tostring(transfer and transfer.transferId or "unknown"),
        getPlayerName(transfer and transfer.player),
        transfer and transfer.mode or "unknown",
        transfer and transfer.barrelKey or "unknown",
        tostring(getTransferRevision(transfer)),
        transfer and transfer.movedAmount or 0,
        transfer and transfer.totalAmount or 0,
        reason or "step_failed"
    ))
end

local function applyPendingProgress(playerKey, transfer, forceClose)
    if not playerKey or not transfer then return false end

    if not isTransferLockedBy(playerKey, transfer) then
        stopByKey(playerKey, transfer, "barrel_lock_lost", true)
        return true
    end

    local pendingProgress = clamp01(transfer.pendingClientProgress or transfer.clientProgress)
    local appliedProgress = clamp01(transfer.appliedProgress)
    if forceClose == true then
        pendingProgress = 1
    elseif pendingProgress < appliedProgress then
        pendingProgress = appliedProgress
    end

    transfer.pendingClientProgress = pendingProgress
    transfer.clientProgress = math.max(clamp01(transfer.clientProgress), pendingProgress)

    local totalAmount = tonumber(transfer.totalAmount) or 0
    local targetMovedAmount = totalAmount * pendingProgress
    local requestedAmount = math.min(
        transfer.remainingAmount or 0,
        math.max(targetMovedAmount - (transfer.movedAmount or 0), 0)
    )

    if requestedAmount <= TRANSFER_EPSILON then
        if forceClose == true or isTransferCompleted(transfer) then
            local reason = "server_transfer_finished"
            if forceClose == true then
                reason = isTransferCompleted(transfer) and "client_complete" or "client_complete_partial"
            end
            finishTransfer(playerKey, transfer, reason, true)
            return true
        end
        return false
    end

    local ok, movedAmount, reason, barrel = pcall(advance, transfer, requestedAmount)
    if not ok then
        Logger.error("Transfer advance error: " .. tostring(movedAmount))
        stopByKey(playerKey, transfer, "server_error", true)
        return true
    end

    if barrel then
        transfer.lastBarrel = barrel
    end

    if movedAmount <= 0 then
        stopByKey(playerKey, transfer, reason or "step_failed", true)
        return true
    end

    transfer.movedAmount     = (transfer.movedAmount or 0) + movedAmount
    transfer.remainingAmount = math.max((transfer.remainingAmount or 0) - movedAmount, 0)
    transfer.appliedProgress = totalAmount > 0
        and math.max(appliedProgress, math.min(transfer.movedAmount / totalAmount, 1))
        or 1
    transfer.ticksSinceSync  = (transfer.ticksSinceSync or 0) + (transfer.tickInterval or 1)

    if forceClose == true then
        finishTransfer(
            playerKey,
            transfer,
            isTransferCompleted(transfer) and "client_complete" or "client_complete_partial",
            true
        )
        return true
    end

    if isTransferCompleted(transfer) then
        finishTransfer(playerKey, transfer, "server_transfer_finished", true)
        return true
    end

    if transfer.ticksSinceSync >= math.max(transfer.syncInterval or Constant.SERVER_TRANSFER_SYNC_INTERVAL or 10, 1) then
        syncBarrel(transfer)
        Notifier.progress(transfer.player, transfer, false)
        transfer.ticksSinceSync = 0
    end

    return false
end

local function stopActiveForPlayer(playerKey, reason, notifyProgress)
    local transfer = activeTransfers[playerKey]
    if not transfer then return false end

    syncBarrel(transfer)
    local closedTransfer = cacheClosedTransfer(
        playerKey,
        transfer,
        reason or "cleared",
        false,
        notifyProgress == true
    )

    if notifyProgress and transfer.player then
        Notifier.progress(transfer.player, closedTransfer or transfer, true)
    end

    releaseTransferLocks(playerKey, transfer)
    activeTransfers[playerKey] = nil

    log(string.format(
        "Transfer stopped internally: actionId=%s player=%s action=%s barrelId=%s revision=%s moved=%.3f/%.3f reason=%s",
        tostring(transfer.transferId or "unknown"),
        getPlayerName(transfer.player),
        transfer.mode or "unknown",
        transfer.barrelKey or "unknown",
        tostring(getTransferRevision(transfer)),
        transfer.movedAmount or 0,
        transfer.totalAmount or 0,
        reason or "cleared"
    ))

    return true
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Validates, locks, and starts a new transfer for the player.
---@param player IsoPlayer
---@param mode string "pour" | "extract" | "empty"
---@param args table
function TransferService.start(player, mode, args)
    if not player then return end
    if type(args) ~= "table" then
        logTransferRejected(player, mode, nil, nil, "invalid_args")
        Notifier.rejected(player, mode, "invalid_args", nil)
        return
    end

    if not isValidTransferId(args.transferId) then
        TransferService.reject(player, mode, "missing_transfer_id", args)
        return
    end

    local barrel, barrelData, item, liquidType, reason
    local sourceEndpoint, targetEndpoint
    local endpointTransfer = isEndpointTransferMode(mode)

    if endpointTransfer then
        sourceEndpoint, targetEndpoint, liquidType, reason = resolveEndpointTransfer(player, args)
        if sourceEndpoint then
            barrel = sourceEndpoint.object
            barrelData = sourceEndpoint.data
        end
    elseif mode == "pour" then
        barrel, barrelData, item, liquidType, reason = resolvePour(player, args, true)
    elseif mode == "extract" then
        barrel, barrelData, item, liquidType, reason = resolveExtract(player, args, true)
    elseif mode == "empty" then
        barrel, barrelData, liquidType, reason = resolveEmpty(player, args)
    else
        TransferService.reject(player, mode or "unknown", "unknown_transfer_mode", args)
        return
    end

    local notifySource = endpointTransfer
        and buildEndpointNotifySource(args, sourceEndpoint, targetEndpoint)
        or buildNotifySource(args, barrel, barrelData)

    if reason then
        logTransferRejected(player, mode, args, barrelData, reason)
        Notifier.rejected(player, mode, reason, notifySource)
        return
    end

    if not barrel or not barrelData or (mode ~= "empty" and not endpointTransfer and not item) or not liquidType then
        logTransferRejected(player, mode, args, barrelData, reason or "unknown")
        Notifier.rejected(player, mode, reason or "unknown", notifySource)
        return
    end

    local totalAmount
    if endpointTransfer then
        totalAmount = TransferRules.getEndpointTransferAmount(sourceEndpoint, targetEndpoint)
    elseif mode == "pour" then
        totalAmount = TransferRules.getPourAmount(barrelData, item)
    elseif mode == "extract" then
        totalAmount = TransferRules.getExtractAmount(barrelData, item)
    else
        totalAmount = TransferRules.getEmptyAmount(barrelData)
    end

    if totalAmount <= 0 then
        logTransferRejected(player, mode, args, barrelData, "no_transferable_amount")
        Notifier.rejected(player, mode, "no_transferable_amount", notifySource)
        return
    end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        logTransferRejected(player, mode, args, barrelData, "invalid_player")
        Notifier.rejected(player, mode, "invalid_player", notifySource)
        return
    end

    -- Replace any existing transfer for this player.
    if activeTransfers[playerKey] then
        stopActiveForPlayer(playerKey, "replaced_by_new_transfer", true)
    end

    local barrelKey = endpointTransfer and sourceEndpoint.key or LockService.getBarrelKey(barrel, barrelData)
    if not barrelKey then
        logTransferRejected(player, mode, args, barrelData, "barrel_id_missing")
        Notifier.rejected(player, mode, "barrel_id_missing", notifySource)
        return
    end

    local lockKeys = endpointTransfer
        and { sourceEndpoint.key, targetEndpoint.key }
        or nil
    local lockAcquired = false
    if endpointTransfer then
        lockAcquired = LockService.acquireMany(playerKey, lockKeys, "long", args.transferId)
    else
        lockAcquired = LockService.acquire(playerKey, barrelKey, "long", args.transferId)
    end

    if not lockAcquired then
        logTransferRejected(player, mode, args, barrelData, "barrel_locked")
        Notifier.rejected(player, mode, "barrel_locked", notifySource)
        return
    end

    local totalTicks   = math.max(TransferRules.getTransferActionTime(totalAmount, mode, liquidType), 1)
    local tickInterval = math.max(Constant.SERVER_TRANSFER_TICK_INTERVAL or 1, 1)
    local syncInterval = mode == "empty"
        and tickInterval
        or math.max(Constant.SERVER_TRANSFER_SYNC_INTERVAL or 10, 1)

    local transfer = {
        player          = player,
        transferId      = tostring(args.transferId),
        mode            = mode,
        args            = args,
        liquidType      = liquidType,
        barrelKey       = barrelKey,
        barrelId        = barrelData.id,
        targetBarrelId  = targetEndpoint and targetEndpoint.barrelId or nil,
        lockKeys        = lockKeys,
        lastBarrel      = barrel,
        barrelData      = barrelData,
        sourceEndpoint  = sourceEndpoint,
        targetEndpoint  = targetEndpoint,
        sourceSnapshot  = EndpointResolver.snapshot(sourceEndpoint),
        targetSnapshot  = EndpointResolver.snapshot(targetEndpoint),
        inventory       = (mode ~= "empty" and not endpointTransfer) and player:getInventory() or nil,
        item            = endpointTransfer and nil or item,
        itemId          = (mode ~= "empty" and not endpointTransfer) and (item and item:getID() or args.itemId) or nil,
        itemFullType    = (mode ~= "empty" and not endpointTransfer) and (item and item:getFullType() or args.itemFullType) or nil,
        totalAmount     = totalAmount,
        remainingAmount = totalAmount,
        movedAmount     = 0,
        totalTicks      = totalTicks,
        clientProgress  = clamp01(args.progress),
        pendingClientProgress = clamp01(args.progress),
        appliedProgress = 0,
        serverTicksElapsed = 0,
        tickInterval    = tickInterval,
        syncInterval    = syncInterval,
        ticksUntilStep  = 0,
        ticksSinceSync  = 0,
        ticksSinceClientProgress = 0,
    }

    activeTransfers[playerKey] = transfer
    Notifier.started(player, transfer)

    log(string.format(
        "Transfer started: actionId=%s player=%s action=%s barrelId=%s revision=%s reason=ok liquid=%s total=%.3f duration=%d interval=%d",
        tostring(getActionId(args) or "unknown"),
        getPlayerName(player),
        tostring(mode),
        barrelData.id or "unknown",
        tostring(barrelData.revision or 0),
        liquidType,
        totalAmount,
        totalTicks,
        tickInterval
    ))
end

--- Sends a standard transfer rejection for malformed lifecycle commands.
---@param player IsoPlayer
---@param mode string|nil
---@param reason string
---@param args table|nil
function TransferService.reject(player, mode, reason, args)
    if not player then return end

    logTransferRejected(player, mode, args, nil, reason)
    Notifier.rejected(player, mode or (type(args) == "table" and args.mode) or "unknown", reason, buildNotifySource(args, nil, nil))
end

--- Updates the latest client animation progress for an active transfer.
--- Progress packets are cheap bookkeeping; server ticks apply the pending delta.
---@param player IsoPlayer
---@param args table|nil
function TransferService.updateProgress(player, args)
    if not player or type(args) ~= "table" then return end
    if not isValidTransferId(args.transferId) then return end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then return end

    local transfer = activeTransfers[playerKey]
    if not transferMatches(transfer, args.mode, args.transferId) then return end

    local progress = clamp01(args.progress)
    local previousPendingProgress = tonumber(transfer.pendingClientProgress) or 0
    transfer.clientProgress = math.max(tonumber(transfer.clientProgress) or 0, progress)
    if progress > previousPendingProgress then
        transfer.pendingClientProgress = progress
        if progress > (tonumber(transfer.appliedProgress) or 0) + TRANSFER_EPSILON then
            transfer.ticksUntilStep = 0
        end
    end
    transfer.ticksSinceClientProgress = 0
end

--- Stops the player's active transfer (client-initiated or replaced by a new one).
---@param player IsoPlayer
---@param mode string|nil
---@param transferId string|number|nil
---@param reason string|nil
function TransferService.stop(player, mode, transferId, reason)
    if not isValidTransferId(transferId) then
        TransferService.reject(player, mode or "unknown", "missing_transfer_id", buildCommandSource(mode, transferId))
        return
    end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        TransferService.reject(player, mode or "unknown", "invalid_player", buildCommandSource(mode, transferId))
        return
    end

    local transfer = activeTransfers[playerKey]
    if not transfer then
        transfer = getClosedTransfer(playerKey, mode, transferId)
        if not notifyClosedTransfer(player, transfer) then
            TransferService.reject(player, mode or "unknown", "transfer_not_active", buildCommandSource(mode, transferId))
        end
        return
    end
    if not transferMatches(transfer, mode, transferId) then
        local closedTransfer = getClosedTransfer(playerKey, mode, transferId)
        if not notifyClosedTransfer(player, closedTransfer) then
            TransferService.reject(player, mode or transfer.mode or "unknown", "transfer_mismatch", buildCommandSource(mode, transferId))
        end
        return
    end

    syncBarrel(transfer)
    local closedTransfer = cacheClosedTransfer(playerKey, transfer, reason or "cleared", false, true)
    Notifier.progress(player, closedTransfer or transfer, true)
    releaseTransferLocks(playerKey, transfer)
    activeTransfers[playerKey] = nil

    log(string.format(
        "Transfer stopped: actionId=%s player=%s action=%s barrelId=%s revision=%s moved=%.3f/%.3f reason=%s",
        tostring(transfer.transferId or "unknown"),
        getPlayerName(player),
        transfer.mode or "unknown",
        transfer.barrelKey or "unknown",
        tostring(getTransferRevision(transfer)),
        transfer.movedAmount or 0,
        transfer.totalAmount or 0,
        reason or "cleared"
    ))
end

--- Marks a transfer as complete on the authoritative close signal from the client.
--- Completion raises pending progress to 1 and applies the remaining validated
--- delta immediately, so liquid movement does not continue after the animation.
---@param player IsoPlayer
---@param mode string
---@param transferId string|number|nil
function TransferService.complete(player, mode, transferId)
    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        TransferService.reject(player, mode or "unknown", "invalid_player", buildCommandSource(mode, transferId))
        return
    end

    if not isValidTransferId(transferId) then
        TransferService.reject(player, mode or "unknown", "missing_transfer_id", buildCommandSource(mode, transferId))
        return
    end

    local transfer = activeTransfers[playerKey]
    if not transfer then
        transfer = getClosedTransfer(playerKey, mode, transferId)
        if not notifyClosedTransfer(player, transfer) then
            TransferService.reject(player, mode or "unknown", "transfer_not_active", buildCommandSource(mode, transferId))
        end
        return
    end
    if not transferMatches(transfer, mode, transferId) then
        local closedTransfer = getClosedTransfer(playerKey, mode, transferId)
        if not notifyClosedTransfer(player, closedTransfer) then
            TransferService.reject(player, mode or transfer.mode or "unknown", "transfer_mismatch", buildCommandSource(mode, transferId))
        end
        return
    end

    transfer.clientProgress = 1
    transfer.pendingClientProgress = 1
    transfer.ticksSinceClientProgress = 0

    log(string.format(
        "Transfer client animation finished: player=%s mode=%s transferId=%s moved=%.3f/%.3f remaining=%.3f",
        tostring(player:getUsername()),
        mode,
        transfer.transferId or "unknown",
        transfer.movedAmount or 0,
        transfer.totalAmount or 0,
        transfer.remainingAmount or 0
    ))

    applyPendingProgress(playerKey, transfer, true)
end

--- Per-tick handler: advances all active transfers by one step interval.
--- Registered as Events.OnTick in BarrEx_Server.
function TransferService.onTick()
    for playerKey, transfer in pairs(activeTransfers) do
        transfer.serverTicksElapsed = (transfer.serverTicksElapsed or 0) + 1

        if isClientProgressStale(transfer) then
            stopByKey(playerKey, transfer, "client_progress_timeout", true)
        elseif hasPendingProgress(transfer) then
            transfer.ticksUntilStep = (transfer.ticksUntilStep or transfer.tickInterval or 1) - 1

            if transfer.ticksUntilStep <= 0 then
                transfer.ticksUntilStep = transfer.tickInterval
                applyPendingProgress(playerKey, transfer, false)
            end
        end
    end
end

return TransferService
