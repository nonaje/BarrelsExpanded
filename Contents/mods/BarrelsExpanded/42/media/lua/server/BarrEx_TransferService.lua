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
local Notifier          = require("BarrEx_TransferNotifier")
local Logger            = require("utils/BarrEx_Logger")

local TransferService = {}

-- playerKey → transfer object for every in-progress transfer.
local activeTransfers = {}
local TRANSFER_EPSILON = 0.0001

local function log(message)
    Logger.info(message)
end

local function isValidTransferId(transferId)
    return (type(transferId) == "string" and transferId ~= "")
        or type(transferId) == "number"
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

local function logTransferRejected(player, mode, args, barrelData, reason)
    log(string.format(
        "Transfer start rejected: actionId=%s player=%s action=%s barrelId=%s revision=%s reason=%s",
        tostring(getActionId(args) or "unknown"),
        getPlayerName(player),
        tostring(mode or "unknown"),
        tostring((barrelData and barrelData.id) or (type(args) == "table" and args.barrelId) or "unknown"),
        tostring(barrelData and barrelData.revision or "unknown"),
        tostring(reason or "unknown")
    ))
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

    local barrel = transfer.lastBarrel or BarrelResolver.getBarrelFromArgs(transfer.args)
    if barrel then
        barrel:transmitModData()
    end
end

local function isTransferCompleted(transfer)
    return (tonumber(transfer and transfer.remainingAmount) or 0) <= TRANSFER_EPSILON
end

local function isWaitingForClientProgress(transfer)
    if not transfer or transfer.clientAnimationFinished then return false end
    return clamp01(transfer.clientProgress) < 1
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
    if isValidTransferId(transferId) and tostring(transfer.transferId) ~= tostring(transferId) then return false end
    return true
end

local function finishTransfer(playerKey, transfer, reason, notifyProgress)
    syncBarrel(transfer)

    if notifyProgress and transfer and transfer.player then
        Notifier.progress(transfer.player, transfer, true)
    end

    if transfer then
        LockService.release(playerKey, transfer.barrelKey)
    end
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

-- ---------------------------------------------------------------------------
-- Pour: validate + apply
-- ---------------------------------------------------------------------------

---@return IsoObject|nil, BarrEx_Barrel|nil, InventoryItem|nil, string|nil, string|nil
local function resolvePour(player, args, checkTool)
    local barrel, resolveReason = BarrelResolver.resolve(args)
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
    local barrel, resolveReason = BarrelResolver.resolve(args)
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
-- Tick advance
-- ---------------------------------------------------------------------------

--- Advances one step of the active transfer, routing to pour or extract.
--- Tool ownership is checked only at start; per-tick skips it for performance.
---@return number, string|nil, IsoObject|nil
local function advance(transfer, requestedAmount)
    if not transfer or not transfer.player then
        return 0, "missing_transfer", nil
    end

    if transfer.mode == "pour" then
        local barrel, barrelData, sourceItem, liquidType, reason =
            resolvePour(transfer.player, transfer.args, false)

        if not barrel or not barrelData or not sourceItem or not liquidType then
            return 0, reason, barrel
        end

        transfer.lastBarrel = barrel
        return applyPour(barrel, barrelData, sourceItem, liquidType, requestedAmount)
    end

    local barrel, barrelData, targetItem, liquidType, reason =
        resolveExtract(transfer.player, transfer.args, false)

    if not barrel or not barrelData or not targetItem or not liquidType then
        return 0, reason, barrel
    end

    transfer.lastBarrel = barrel
    return applyExtract(barrel, barrelData, targetItem, liquidType, requestedAmount)
end

-- ---------------------------------------------------------------------------
-- Internal stop (step failure / lock lost)
-- ---------------------------------------------------------------------------

local function stopByKey(playerKey, transfer, reason, notify)
    syncBarrel(transfer)
    LockService.release(playerKey, transfer.barrelKey)
    activeTransfers[playerKey] = nil

    if notify and transfer and transfer.player then
        Notifier.rejected(transfer.player, transfer.mode or "unknown", reason or "step_failed", transfer)
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

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Validates, locks, and starts a new transfer for the player.
---@param player IsoPlayer
---@param mode string "pour" | "extract"
---@param args table
function TransferService.start(player, mode, args)
    if not player then return end
    if type(args) ~= "table" then
        logTransferRejected(player, mode, nil, nil, "invalid_args")
        Notifier.rejected(player, mode, "invalid_args", nil)
        return
    end

    if not isValidTransferId(args.transferId) then
        logTransferRejected(player, mode, args, nil, "missing_transfer_id")
        Notifier.rejected(player, mode, "missing_transfer_id", args)
        return
    end

    local barrel, barrelData, item, liquidType, reason

    if mode == "pour" then
        barrel, barrelData, item, liquidType, reason = resolvePour(player, args, true)
    else
        barrel, barrelData, item, liquidType, reason = resolveExtract(player, args, true)
    end

    if not barrel or not barrelData or not item or not liquidType then
        logTransferRejected(player, mode, args, barrelData, reason or "unknown")
        Notifier.rejected(player, mode, reason or "unknown", buildNotifySource(args, barrel, barrelData))
        return
    end

    local totalAmount = mode == "pour"
        and TransferRules.getPourAmount(barrelData, item)
        or  TransferRules.getExtractAmount(barrelData, item)

    if totalAmount <= 0 then
        logTransferRejected(player, mode, args, barrelData, "no_transferable_amount")
        Notifier.rejected(player, mode, "no_transferable_amount", buildNotifySource(args, barrel, barrelData))
        return
    end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        logTransferRejected(player, mode, args, barrelData, "invalid_player")
        Notifier.rejected(player, mode, "invalid_player", buildNotifySource(args, barrel, barrelData))
        return
    end

    -- Replace any existing transfer for this player.
    if activeTransfers[playerKey] then
        TransferService.stop(player, nil, nil, "replaced_by_new_transfer")
    end

    local barrelKey = LockService.getBarrelKey(barrel, barrelData)
    if not barrelKey then
        logTransferRejected(player, mode, args, barrelData, "barrel_id_missing")
        Notifier.rejected(player, mode, "barrel_id_missing", buildNotifySource(args, barrel, barrelData))
        return
    end

    if not LockService.acquire(playerKey, barrelKey, "long", args.transferId) then
        logTransferRejected(player, mode, args, barrelData, "barrel_locked")
        Notifier.rejected(player, mode, "barrel_locked", buildNotifySource(args, barrel, barrelData))
        return
    end

    local totalTicks   = math.max(TransferRules.getTransferActionTime(totalAmount, mode, liquidType), 1)
    local tickInterval = math.max(Constant.SERVER_TRANSFER_TICK_INTERVAL or 1, 1)

    local transfer = {
        player          = player,
        transferId      = tostring(args.transferId),
        mode            = mode,
        args            = args,
        liquidType      = liquidType,
        barrelKey       = barrelKey,
        lastBarrel      = barrel,
        totalAmount     = totalAmount,
        remainingAmount = totalAmount,
        movedAmount     = 0,
        totalTicks      = totalTicks,
        clientProgress  = clamp01(args.progress),
        serverTicksElapsed = 0,
        tickInterval    = tickInterval,
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

--- Updates the latest client animation progress for an active transfer.
--- This throttles liquid movement to the visual timed action; server elapsed time,
--- validation and mutation remain authoritative.
---@param player IsoPlayer
---@param args table|nil
function TransferService.updateProgress(player, args)
    if not player or type(args) ~= "table" then return end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then return end

    local transfer = activeTransfers[playerKey]
    if not transferMatches(transfer, args.mode, args.transferId) then return end

    transfer.clientProgress = math.max(tonumber(transfer.clientProgress) or 0, clamp01(args.progress))
    transfer.ticksSinceClientProgress = 0
end

--- Stops the player's active transfer (client-initiated or replaced by a new one).
---@param player IsoPlayer
---@param mode string|nil
---@param transferId string|number|nil
---@param reason string|nil
function TransferService.stop(player, mode, transferId, reason)
    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then return end

    local transfer = activeTransfers[playerKey]
    if not transfer then return end
    if not transferMatches(transfer, mode, transferId) then return end

    syncBarrel(transfer)
    LockService.release(playerKey, transfer.barrelKey)
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
--- The client only reports animation completion; the server still decides when
--- the liquid movement has actually finished.
---@param player IsoPlayer
---@param mode string
---@param transferId string|number|nil
function TransferService.complete(player, mode, transferId)
    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then return end

    local transfer = activeTransfers[playerKey]
    if not transferMatches(transfer, mode, transferId) then return end

    transfer.clientProgress = 1
    transfer.ticksSinceClientProgress = 0

    if not isTransferCompleted(transfer) then
        transfer.clientAnimationFinished = true
        log(string.format(
            "Transfer client animation finished: player=%s mode=%s transferId=%s moved=%.3f/%.3f remaining=%.3f",
            tostring(player:getUsername()),
            mode,
            transfer.transferId or "unknown",
            transfer.movedAmount or 0,
            transfer.totalAmount or 0,
            transfer.remainingAmount or 0
        ))
        return
    end

    finishTransfer(playerKey, transfer, "client_complete_after_server_finished", false)
end

--- Per-tick handler: advances all active transfers by one step interval.
--- Registered as Events.OnTick in BarrEx_Server.
function TransferService.onTick()
    for playerKey, transfer in pairs(activeTransfers) do
        transfer.serverTicksElapsed = (transfer.serverTicksElapsed or 0) + 1

        -- Abort if lock was taken by another player between steps.
        if LockService.isLockedBy(transfer.barrelKey) ~= playerKey then
            stopByKey(playerKey, transfer, "barrel_lock_lost", true)
        elseif isClientProgressStale(transfer) then
            stopByKey(playerKey, transfer, "client_progress_timeout", true)
        else
            transfer.ticksUntilStep = (transfer.ticksUntilStep or transfer.tickInterval or 1) - 1

            if transfer.ticksUntilStep <= 0 then
                transfer.ticksUntilStep = transfer.tickInterval

                local serverProgress = clamp01((transfer.serverTicksElapsed or 0) / math.max(transfer.totalTicks or 1, 1))
                local targetProgress = math.min(clamp01(transfer.clientProgress), serverProgress)
                local targetMovedAmount = (transfer.totalAmount or 0) * targetProgress
                local requestedAmount = math.min(
                    transfer.remainingAmount or 0,
                    math.max(targetMovedAmount - (transfer.movedAmount or 0), 0)
                )
                if requestedAmount > TRANSFER_EPSILON then
                    local wholeUnits = math.floor(requestedAmount)
                    if wholeUnits >= 1 then
                        requestedAmount = 1
                    elseif targetProgress >= 1 then
                        requestedAmount = transfer.remainingAmount or 0
                    else
                        requestedAmount = 0
                    end
                end

                if requestedAmount <= TRANSFER_EPSILON then
                    if isTransferCompleted(transfer) then
                        finishTransfer(playerKey, transfer, "server_transfer_finished", true)
                    end
                else
                    local ok, movedAmount, reason, barrel = pcall(advance, transfer, requestedAmount)
                    if not ok then
                        Logger.error("Transfer advance error: " .. tostring(movedAmount))
                        stopByKey(playerKey, transfer, "server_error", true)
                    else
                        if barrel then
                            transfer.lastBarrel = barrel
                        end

                        if movedAmount <= 0 then
                            stopByKey(playerKey, transfer, reason or "step_failed", true)
                        else
                            transfer.movedAmount     = transfer.movedAmount + movedAmount
                            transfer.remainingAmount = math.max((transfer.remainingAmount or 0) - movedAmount, 0)
                            transfer.ticksSinceSync  = (transfer.ticksSinceSync or 0) + (transfer.tickInterval or 1)

                            if isTransferCompleted(transfer) then
                                finishTransfer(playerKey, transfer, "server_transfer_finished", true)
                            elseif transfer.ticksSinceSync >= math.max(Constant.SERVER_TRANSFER_SYNC_INTERVAL or 10, 1) then
                                syncBarrel(transfer)
                                Notifier.progress(transfer.player, transfer, false)
                                transfer.ticksSinceSync = 0
                            end
                        end
                    end
                end
            end
        end
    end
end

return TransferService
