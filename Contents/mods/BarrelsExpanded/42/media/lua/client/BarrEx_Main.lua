local Constant = require("BarrEx_Constant")
local BarrEx_MoveableSync = require("BarrEx_MoveableSync")
local BarrEx_TransferSync = require("BarrEx_TransferSync")
local Logger = require("utils/BarrEx_Logger")

local function log(message)
    Logger.info(message)
end

--- Map from rejection reason to translation key for transfer error messages.
--- All keys are defined in Translate/*/TransferMessages.json
local TRANSFER_REJECTION_KEY_MAP = {
    barrel_not_found = "UI_BarrEx_TransferRejection_BarrelNotFound",
    barrel_unavailable = "UI_BarrEx_TransferRejection_BarrelUnavailable",
    interaction_invalid = "UI_BarrEx_TransferRejection_InteractionInvalid",
    barrel_full = "UI_BarrEx_TransferRejection_BarrelFull",
    barrel_empty = "UI_BarrEx_TransferRejection_BarrelEmpty",
    source_not_found = "UI_BarrEx_TransferRejection_SourceNotFound",
    target_not_found = "UI_BarrEx_TransferRejection_TargetNotFound",
    source_liquid_missing = "UI_BarrEx_TransferRejection_SourceLiquidMissing",
    source_cannot_provide = "UI_BarrEx_TransferRejection_SourceCannotProvide",
    target_cannot_receive = "UI_BarrEx_TransferRejection_TargetCannotReceive",
    incompatible_liquid = "UI_BarrEx_TransferRejection_IncompatibleLiquid",
    invalid_barrel_liquid = "UI_BarrEx_TransferRejection_InvalidBarrelLiquid",
    no_transferable_amount = "UI_BarrEx_TransferRejection_NoTransferableAmount",
    barrel_locked = "UI_BarrEx_TransferRejection_BarrelLocked",
    barrel_id_missing = "UI_BarrEx_TransferRejection_BarrelIdMissing",
    barrel_lock_lost = "UI_BarrEx_TransferRejection_BarrelLockLost",
}

local function getLocalPlayerSafe()
    if type(getPlayer) == "function" then
        return getPlayer()
    end

    if type(getSpecificPlayer) == "function" then
        return getSpecificPlayer(0)
    end

    return nil
end

local function showPlayerMessage(message)
    local player = getLocalPlayerSafe()
    if not player or not message then return end

    if HaloTextHelper and type(HaloTextHelper.addText) == "function" then
        local ok = pcall(
            HaloTextHelper.addText,
            player,
            message,
            HaloTextHelper.getColorRed and HaloTextHelper.getColorRed() or nil
        )
        if ok then
            return
        end
    end

    if type(player.Say) == "function" then
        player:Say(message)
    end
end

local function onServerCommand(module, command, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.TRANSFER_STARTED then
        BarrEx_TransferSync.onTransferStarted(args)
        return
    end

    if command == Constant.NETWORK.TRANSFER_PROGRESS then
        BarrEx_TransferSync.onTransferProgress(args)
        return
    end

    if command == Constant.NETWORK.TRANSFER_REJECTED then
        local reason = type(args) == "table" and args.reason or "unknown"
        BarrEx_TransferSync.onTransferRejected(type(args) == "table" and args or nil)
        -- Look up translated message from TransferMessages.json files.
        local translationKey = TRANSFER_REJECTION_KEY_MAP[reason] or "UI_BarrEx_TransferRejection_Unknown"
        local message = type(getText) == "function" and getText(translationKey) or nil
        showPlayerMessage(message or getText("UI_BarrEx_TransferRejection_Unknown"))
    end
end

log("Mod Initialized!")

Events.OnGameStart.Add(function()
    log("Game Started")
end)

Events.OnServerCommand.Add(onServerCommand)
BarrEx_MoveableSync.start()
