-- BarrEx_TransferNotifier: outbound network notifications for transfer lifecycle events.
--
-- Pure output layer: builds payloads and calls sendServerCommand.
-- No state, no world access, no business logic.

local Constant = require("BarrEx_Constant")

local Notifier = {}

--- Notifies the client that its transfer request was rejected.
---@param player IsoPlayer
---@param mode string
---@param reason string|nil
function Notifier.rejected(player, mode, reason)
    if not player or type(sendServerCommand) ~= "function" then return end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_REJECTED, {
        mode   = mode,
        reason = reason or "unknown",
    })
end

--- Notifies the client that a transfer has started, including the authoritative duration
--- and total amount so the client can align its visual progress bar.
---@param player IsoPlayer
---@param transfer table
function Notifier.started(player, transfer)
    if not player or not transfer or type(sendServerCommand) ~= "function" then return end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.TRANSFER_STARTED, {
        mode        = transfer.mode,
        barrelId    = transfer.args and transfer.args.barrelId or transfer.barrelKey,
        itemId      = transfer.args and transfer.args.itemId or nil,
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
        mode        = transfer.mode,
        barrelId    = transfer.args and transfer.args.barrelId or transfer.barrelKey,
        itemId      = transfer.args and transfer.args.itemId or nil,
        movedAmount = movedAmount,
        totalAmount = totalAmount,
        progress    = progress,
        completed   = completed == true,
    })
end

return Notifier
