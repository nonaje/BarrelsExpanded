local Constant = require("BarrEx_Constant")
local BarrEx_MoveableSync = require("BarrEx_MoveableSync")
local BarrEx_TransferSync = require("BarrEx_TransferSync")
local InventoryUtils = require("utils/BarrEx_InventoryUtils")
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
    client_progress_timeout = "UI_BarrEx_TransferRejection_ClientProgressTimeout",
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

local function getAckPlayer(args)
    local playerOnlineId = type(args) == "table" and args.playerOnlineId or nil
    if playerOnlineId and type(getPlayerByOnlineID) == "function" then
        local player = getPlayerByOnlineID(playerOnlineId)
        if player then
            return player
        end
    end

    return getLocalPlayerSafe()
end

local function clearWashableItemVisuals(item)
    if not item then return end

    if instanceof and (instanceof(item, "Clothing") or instanceof(item, "InventoryContainer")) then
        local coveredParts = nil
        if BloodClothingType and type(item.getBloodClothingType) == "function" then
            coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        end
        if coveredParts then
            for i = 0, coveredParts:size() - 1 do
                local part = coveredParts:get(i)
                if type(item.setBlood) == "function" then item:setBlood(part, 0) end
                if type(item.setDirt) == "function" then item:setDirt(part, 0) end
            end
        end
        if instanceof(item, "Clothing") then
            if type(item.setWetness) == "function" then item:setWetness(100) end
            if type(item.setDirtiness) == "function" then item:setDirtiness(0) end
        end
    end

    if type(item.setBloodLevel) == "function" then item:setBloodLevel(0) end
    if type(item.setDirtiness) == "function" then item:setDirtiness(0) end

    local container = type(item.getContainer) == "function" and item:getContainer() or nil
    if container and type(container.setDrawDirty) == "function" then
        container:setDrawDirty(true)
    end
    if ISInventoryPage and type(ISInventoryPage.dirtyUI) == "function" then
        ISInventoryPage.dirtyUI()
    end
end

local function applyCharacterVisualRefresh(player)
    if type(syncVisuals) == "function" then
        syncVisuals(player)
    end
    if type(player.updateHandEquips) == "function" then
        player:updateHandEquips()
    end
end

local function refreshWashItem(player, args)
    local inventory = player and player:getInventory()
    if not inventory then return end

    log(string.format(
        "Wash item ACK received: id=%s idType=%s fullType=%s",
        tostring(args.itemId),
        type(args.itemId),
        tostring(args.itemFullType)
    ))

    local item = InventoryUtils.findInventoryItemStrict(inventory, args.itemId)
    if not item then
        log(string.format(
            "Wash item local refresh skipped: item not found id=%s idType=%s fullType=%s",
            tostring(args.itemId),
            type(args.itemId),
            tostring(args.itemFullType)
        ))
        return
    end

    local primary = type(player.isPrimaryHandItem) == "function" and player:isPrimaryHandItem(item) or false
    local secondary = type(player.isSecondaryHandItem) == "function" and player:isSecondaryHandItem(item) or false

    clearWashableItemVisuals(item)
    applyCharacterVisualRefresh(player)

    if primary and type(player.setPrimaryHandItem) == "function" then
        player:setPrimaryHandItem(item)
    end
    if secondary and type(player.setSecondaryHandItem) == "function" then
        player:setSecondaryHandItem(item)
    end

    if type(player.resetModel) == "function" then
        player:resetModel()
    end
    if type(triggerEvent) == "function" then
        triggerEvent("OnClothingUpdated", player)
    end

    log(string.format(
        "Wash item local refresh applied: id=%s fullType=%s",
        tostring(args.itemId),
        tostring(type(item.getFullType) == "function" and item:getFullType() or args.itemFullType)
    ))
end

local function refreshWashSelf(player, args)
    local washedBodyParts = type(args) == "table" and args.washedBodyParts or nil
    local visual = player and player:getHumanVisual()

    if type(washedBodyParts) ~= "table" or #washedBodyParts == 0 or not visual then
        log("Wash self local refresh received without body-part metadata.")
    else
        for i = 1, #washedBodyParts do
            local partIndex = tonumber(washedBodyParts[i])
            if partIndex and BloodBodyPartType and type(BloodBodyPartType.FromIndex) == "function" then
                local part = BloodBodyPartType.FromIndex(partIndex)
                if part then
                    visual:setBlood(part, 0)
                    visual:setDirt(part, 0)
                end
            end
        end

        log(string.format("Wash self local refresh applied: parts=%d", #washedBodyParts))
    end

    if type(player.resetModelNextFrame) == "function" then
        player:resetModelNextFrame()
    end
    if type(triggerEvent) == "function" then
        triggerEvent("OnClothingUpdated", player)
    end
end

local function refreshWashVisuals(args)
    if type(args) ~= "table" then return end

    local action = args.action
    local washMode = args.washMode
    if action ~= "wash_item" and action ~= "wash_self"
        and washMode ~= "item" and washMode ~= "self"
    then
        return
    end

    local player = getAckPlayer(args)
    if not player then return end

    if action == "wash_item" or washMode == "item" then
        refreshWashItem(player, args)
        return
    end

    refreshWashSelf(player, args)
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

    if command == Constant.NETWORK.BARREL_USE_COMPLETED then
        refreshWashVisuals(args)
        log(string.format(
            "Barrel use action completed on server: action=%s barrel=%s amount=%.2f",
            type(args) == "table" and args.action or "unknown",
            type(args) == "table" and args.barrelId or "unknown",
            type(args) == "table" and args.amount or 0
        ))
    end
end

log("Mod Initialized!")

Events.OnGameStart.Add(function()
    log("Game Started")
end)

Events.OnServerCommand.Add(onServerCommand)
BarrEx_MoveableSync.start()
