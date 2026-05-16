-- BarrEx_TransferNotifier: outbound network notifications for transfer lifecycle events.
--
-- Pure output layer: builds payloads and calls sendServerCommand.
-- No state, no world access, no business logic.

local Constant = require("BarrEx_Constant")

local Notifier = {}

local function getTransferId(source)
    if type(source) ~= "table" then return nil end
    if source.transferId then return source.transferId end
    if type(source.args) == "table" then
        return source.args.transferId
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

--- Notifies the client that its transfer request was rejected.
---@param player IsoPlayer
---@param mode string
---@param reason string|nil
---@param source table|nil
function Notifier.rejected(player, mode, reason, source)
    if not player or type(sendServerCommand) ~= "function" then return end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_REJECTED, {
        transferId = getTransferId(source),
        mode       = mode,
        barrelId   = getBarrelId(source),
        itemId     = getItemId(source),
        reason     = reason or "unknown",
    })
end

--- Notifies the client that a transfer has started, including the authoritative duration
--- and total amount so the client can align its visual progress bar.
---@param player IsoPlayer
---@param transfer table
function Notifier.started(player, transfer)
    if not player or not transfer or type(sendServerCommand) ~= "function" then return end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_STARTED, {
        transferId   = getTransferId(transfer),
        mode        = transfer.mode,
        barrelId    = getBarrelId(transfer),
        itemId      = getItemId(transfer),
        totalAmount = tonumber(transfer.totalAmount) or 0,
        actionTime  = tonumber(transfer.totalTicks) or 0,
    })
end

--- Notifies the client of incremental or final transfer progress.
---@param player IsoPlayer
---@param transfer table
---@param completed boolean
function Notifier.progress(player, transfer, completed)
    if not player or not transfer or type(sendServerCommand) ~= "function" then return end

    local totalAmount = tonumber(transfer.totalAmount) or 0
    local movedAmount = tonumber(transfer.movedAmount) or 0
    local progress    = completed and 1 or 0

    if totalAmount > 0 then
        progress = math.max(math.min(movedAmount / totalAmount, 1), 0)
    end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_PROGRESS, {
        transferId   = getTransferId(transfer),
        mode        = transfer.mode,
        barrelId    = getBarrelId(transfer),
        itemId      = getItemId(transfer),
        movedAmount = movedAmount,
        totalAmount = totalAmount,
        progress    = progress,
        completed   = completed == true,
    })
end

return Notifier
