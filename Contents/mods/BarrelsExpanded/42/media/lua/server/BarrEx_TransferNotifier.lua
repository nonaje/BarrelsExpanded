-- BarrEx_TransferNotifier: outbound network notifications for transfer lifecycle events.
--
-- Pure output layer: builds payloads and calls sendServerCommand.
-- No state, no world access, no business logic.

local Constant = require("BarrEx_Constant")
local StateService = require("BarrEx_BarrelStateService")

local Notifier = {}

local function getTransferId(source)
    if type(source) ~= "table" then return nil end
    if source.transferId then return source.transferId end
    if source.actionId then return source.actionId end
    if type(source.args) == "table" then
        return source.args.transferId or source.args.actionId
    end
    return nil
end

local function getBarrelId(source)
    if type(source) ~= "table" then return nil end
    if source.barrelId then return source.barrelId end
    if type(source.args) == "table" and source.args.barrelId then
        return source.args.barrelId
    end
    return source.barrelKey
end

local function getItemId(source)
    if type(source) ~= "table" then return nil end
    if source.itemId then return source.itemId end
    if type(source.args) == "table" then
        return source.args.itemId
    end
    return source.itemId
end

local function getSnapshot(source)
    if type(source) ~= "table" then return nil end
    if type(source.snapshot) == "table" then return source.snapshot end
    if type(source.closedSnapshot) == "table" then return source.closedSnapshot end
    return StateService.buildSnapshot(source.lastBarrel)
end

--- Notifies the client that its transfer request was rejected.
---@param player IsoPlayer
---@param mode string
---@param reason string|nil
---@param source table|nil
---@param options table|nil
function Notifier.rejected(player, mode, reason, source, options)
    if not player or type(sendServerCommand) ~= "function" then return end

    local snapshot = getSnapshot(source)

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_REJECTED, {
        actionId   = getTransferId(source),
        action     = mode,
        accepted   = false,
        transferId = getTransferId(source),
        mode       = mode,
        barrelId   = getBarrelId(source) or (snapshot and snapshot.barrelId),
        itemId     = getItemId(source),
        reason     = reason or "unknown",
        closedReason = type(source) == "table" and source.closedReason or nil,
        silent     = type(options) == "table" and options.silent == true,
        playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
        revision   = snapshot and snapshot.revision or nil,
        snapshot   = snapshot,
    })
end

--- Notifies the client that a transfer has started, including the authoritative duration
--- and total amount so the client can align its visual progress bar.
---@param player IsoPlayer
---@param transfer table
function Notifier.started(player, transfer)
    if not player or not transfer or type(sendServerCommand) ~= "function" then return end

    local snapshot = getSnapshot(transfer)

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_STARTED, {
        actionId    = getTransferId(transfer),
        action      = transfer.mode,
        accepted    = true,
        transferId   = getTransferId(transfer),
        mode        = transfer.mode,
        barrelId    = getBarrelId(transfer) or (snapshot and snapshot.barrelId),
        itemId      = getItemId(transfer),
        totalAmount = tonumber(transfer.totalAmount) or 0,
        actionTime  = tonumber(transfer.totalTicks) or 0,
        playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
        revision    = snapshot and snapshot.revision or nil,
        snapshot    = snapshot,
    })
end

--- Notifies the client of incremental or final transfer progress.
---@param player IsoPlayer
---@param transfer table
---@param completed boolean
function Notifier.progress(player, transfer, completed)
    if not player or not transfer or type(sendServerCommand) ~= "function" then return end

    local snapshot = getSnapshot(transfer)

    local totalAmount = tonumber(transfer.totalAmount) or 0
    local movedAmount = tonumber(transfer.movedAmount) or 0
    local progress    = 0

    if completed == true then
        progress = 1
    elseif totalAmount > 0 then
        progress = math.max(math.min(movedAmount / totalAmount, 1), 0)
    end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_PROGRESS, {
        actionId    = getTransferId(transfer),
        action      = transfer.mode,
        accepted    = true,
        transferId   = getTransferId(transfer),
        mode        = transfer.mode,
        barrelId    = getBarrelId(transfer) or (snapshot and snapshot.barrelId),
        itemId      = getItemId(transfer),
        movedAmount = movedAmount,
        totalAmount = totalAmount,
        progress    = progress,
        completed   = completed == true,
        closedReason = type(transfer) == "table" and transfer.closedReason or nil,
        playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
        revision    = snapshot and snapshot.revision or nil,
        snapshot    = snapshot,
    })
end

return Notifier
