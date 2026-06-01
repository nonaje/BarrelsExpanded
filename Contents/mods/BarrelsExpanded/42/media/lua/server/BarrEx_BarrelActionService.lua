-- BarrEx_BarrelActionService: authoritative short barrel mutations.

local Constant              = require("BarrEx_Constant")
local BarrEx_BarrelData     = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory  = require("BarrEx_BarrelFactory")
local BarrelResolver        = require("BarrEx_BarrelResolver")
local InteractionRules      = require("core/BarrEx_InteractionRules")
local LockService           = require("BarrEx_BarrelLockService")
local StateService          = require("BarrEx_BarrelStateService")
local Notifier              = require("BarrEx_BarrelActionNotifier")
local Logger                = require("utils/BarrEx_Logger")

local ActionService = {}
local activeOpenActions = {}

local OPEN_LOCK_TIMEOUT_TICKS = math.max(
    (tonumber(Constant.OPEN_BARREL_ACTION_TIME) or 200)
        + ((tonumber(Constant.ACTION_ACK_TIMEOUT_TICKS) or 240) * 4),
    1200
)

local function log(message)
    Logger.info(message)
end

local function getAction(args, fallback)
    if type(args) == "table" and type(args.action) == "string" and args.action ~= "" then
        return args.action
    end
    return fallback
end

local function getActionId(args)
    if type(args) ~= "table" then return nil end
    return args.actionId or args.transferId
end

local function isValidActionId(actionId)
    local actionIdType = type(actionId)
    if actionIdType == "number" then return true end
    return actionIdType == "string" and actionId ~= ""
end

local function reject(player, action, reason, barrel, barrelData, args, extra)
    Notifier.result(player, action, false, reason, barrel, barrelData, args, extra)
    log(string.format(
        "Barrel action rejected: actionId=%s player=%s action=%s barrelId=%s revision=%s reason=%s",
        tostring(getActionId(args) or "unknown"),
        tostring(player and player:getUsername() or "unknown"),
        tostring(action or "unknown"),
        tostring((barrelData and barrelData.id) or (type(args) == "table" and args.barrelId) or "unknown"),
        tostring(barrelData and barrelData.revision or "unknown"),
        tostring(reason or "unknown")
    ))
end

local function accept(player, action, reason, barrel, barrelData, args, extra)
    Notifier.result(player, action, true, reason or "ok", barrel, barrelData, args, extra)
    log(string.format(
        "Barrel action accepted: actionId=%s player=%s action=%s barrelId=%s revision=%s reason=%s",
        tostring(getActionId(args) or "unknown"),
        tostring(player and player:getUsername() or "unknown"),
        tostring(action or "unknown"),
        tostring(barrelData and barrelData.id or "unknown"),
        tostring(barrelData and barrelData.revision or "unknown"),
        tostring(reason or "ok")
    ))
end

local function isWaterLike(liquidType)
    return liquidType == Constant.LIQUID_TYPE.WATER
        or liquidType == Constant.LIQUID_TYPE.TAINTED_WATER
end

local function getSoapFluidUseAmount()
    local v = ZomboidGlobals and ZomboidGlobals["CleanStainCleaningFluidAmount"]
    return type(v) == "number" and v or 0.0999
end

local function syncStats(player)
    if type(syncPlayerStats) == "function" and SyncPlayerStatsPacket then
        syncPlayerStats(player, SyncPlayerStatsPacket.Stat_Thirst)
    end
end

local function applyTaintedWaterSickness(player)
    if not player or not player.getStats then return end

    local stats = player:getStats()
    if not stats then return end
    if (tonumber(stats:get(CharacterStat.POISON)) or 0) >= 20 then return end
    if type(stats.getSickness) == "function" and (tonumber(stats:getSickness()) or 0) >= 0.3 then return end

    local basePoison = 10
    if CharacterTrait and type(player.hasTrait) == "function" then
        if player:hasTrait(CharacterTrait.IRON_GUT) then
            basePoison = 5
        elseif player:hasTrait(CharacterTrait.WEAK_STOMACH) then
            basePoison = 15
        end
    end

    stats:set(CharacterStat.POISON, math.min((tonumber(stats:get(CharacterStat.POISON)) or 0) + basePoison, 20))
    if type(sendDamage) == "function" then
        sendDamage(player)
    end
end

local function consumeSoap(player)
    local inventory = player and player:getInventory()
    local soaps = inventory and inventory:getSoapList(nil, true) or nil
    if not soaps then return false end

    for i = 0, soaps:size() - 1 do
        local soap = soaps:get(i)
        if soap then
            if ComponentType and soap.hasComponent and soap:hasComponent(ComponentType.FluidContainer)
                and soap:getFluidContainer()
                and soap:getFluidContainer():getAmount() > 0
            then
                local amount = soap:getFluidContainer():getAmount() - getSoapFluidUseAmount()
                if amount <= 0.001 then
                    soap:getFluidContainer():Empty()
                else
                    soap:getFluidContainer():adjustAmount(amount)
                end
                if type(sendItemStats) == "function" then sendItemStats(soap) end
                return true
            elseif instanceof and instanceof(soap, "DrainableComboItem") and soap:getCurrentUses() > 0 then
                soap:UseAndSync()
                return true
            end
        end
    end

    return false
end

local function syncItem(player, item)
    if type(syncItemFields) == "function" then
        syncItemFields(player, item)
    elseif item and type(item.syncItemFields) == "function" then
        item:syncItemFields()
    end

    local container = item and type(item.getContainer) == "function" and item:getContainer() or nil
    if container and type(container.setDrawDirty) == "function" then
        container:setDrawDirty(true)
    end
end

local function syncPlayerVisuals(player)
    if type(sendHumanVisual) == "function" then sendHumanVisual(player) end
    if type(syncVisuals) == "function" then syncVisuals(player) end
    if player and type(player.updateHandEquips) == "function" then
        player:updateHandEquips()
    end
end

local function removeMakeup(player)
    if not player or not ItemBodyLocation then return end

    local inventory = player:getInventory()
    if not inventory then return end

    local locations = {
        ItemBodyLocation.MAKE_UP_FULL_FACE,
        ItemBodyLocation.MAKE_UP_EYES,
        ItemBodyLocation.MAKE_UP_EYES_SHADOW,
        ItemBodyLocation.MAKE_UP_LIPS,
    }

    for i = 1, #locations do
        local item = player:getWornItem(locations[i])
        if item then
            player:removeWornItem(item)
            inventory:Remove(item)
        end
    end
end

local function isCleanableBandageLikeItem(item)
    return item ~= nil
        and type(item.getItemAfterCleaning) == "function"
        and item:getItemAfterCleaning() ~= nil
end

local function replaceCleanedItem(player, item, itemAfterCleaning)
    local container = item and item:getContainer() or nil
    if not container then return false end

    local favorite = type(item.isFavorite) == "function" and item:isFavorite() or false
    local primary = player and type(player.isPrimaryHandItem) == "function" and player:isPrimaryHandItem(item) or false
    local secondary = player and type(player.isSecondaryHandItem) == "function" and player:isSecondaryHandItem(item) or false

    local newItem = container:AddItem(itemAfterCleaning)
    if not newItem then return false end

    if type(newItem.setFavorite) == "function" then
        newItem:setFavorite(favorite)
    end

    if type(sendReplaceItemInContainer) == "function" then
        sendReplaceItemInContainer(container, item, newItem)
    else
        if type(sendRemoveItemFromContainer) == "function" then
            sendRemoveItemFromContainer(container, item)
        end
        if type(sendAddItemToContainer) == "function" then
            sendAddItemToContainer(container, newItem)
        end
    end

    if primary and type(player.setPrimaryHandItem) == "function" then
        player:setPrimaryHandItem(newItem)
    end
    if secondary and type(player.setSecondaryHandItem) == "function" then
        player:setSecondaryHandItem(newItem)
    end
    if (primary or secondary) and type(sendEquip) == "function" then
        sendEquip(player)
    end

    container:Remove(item)

    return true
end

local function getWashWaterRequired(item)
    if isCleanableBandageLikeItem(item) then
        return 1
    end

    if item and ISWashClothing and type(ISWashClothing.GetRequiredWater) == "function" then
        return math.max(tonumber(ISWashClothing.GetRequiredWater(item)) or 0, 1)
    end

    return 1
end

local function washItem(player, item)
    if not item then return false end

    local itemAfterCleaning = type(item.getItemAfterCleaning) == "function" and item:getItemAfterCleaning() or nil
    if itemAfterCleaning then
        return replaceCleanedItem(player, item, itemAfterCleaning)
    end

    if instanceof and (instanceof(item, "Clothing") or instanceof(item, "InventoryContainer")) then
        local coveredParts = nil
        if BloodClothingType and type(item.getBloodClothingType) == "function" then
            coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        end
        if coveredParts then
            for i = 0, coveredParts:size() - 1 do
                local part = coveredParts:get(i)
                if (tonumber(item:getBlood(part)) or 0) > 0 then consumeSoap(player) end
                item:setBlood(part, 0)
                item:setDirt(part, 0)
            end
        end
        if instanceof(item, "Clothing") then
            if type(item.setWetness) == "function" then item:setWetness(100) end
            if type(item.setDirtiness) == "function" then item:setDirtiness(0) end
        end
    else
        if type(item.getBloodLevel) == "function" and (tonumber(item:getBloodLevel()) or 0) > 0 then
            consumeSoap(player)
        end
    end

    if type(item.setBloodLevel) == "function" then item:setBloodLevel(0) end
    if type(item.setDirtiness) == "function" then item:setDirtiness(0) end
    syncItem(player, item)
    syncPlayerVisuals(player)

    return true
end

local function resolveForAction(player, args, action)
    if not player or type(args) ~= "table" then
        return nil, nil, "invalid_args"
    end

    local barrel, reason = BarrelResolver.resolveStrict(args)
    if not barrel then
        return nil, nil, reason or "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if barrelData then
        BarrEx_BarrelData.ensureStableId(barrel, barrelData)
    end

    if action ~= "open" and (not barrelData or not barrelData:isRevealed()) then
        return barrel, barrelData, "barrel_unavailable"
    end

    return barrel, barrelData, nil
end

local function acquireLock(player, action, barrel, barrelData, args)
    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        return nil, nil, "invalid_player"
    end

    local barrelKey = LockService.getBarrelKey(barrel, barrelData)
    if not barrelKey then
        return nil, nil, "barrel_id_missing"
    end

    local acquired = LockService.acquire(playerKey, barrelKey, "short", type(args) == "table" and args.actionId or nil)
    if not acquired then
        return nil, nil, "barrel_locked"
    end

    return playerKey, barrelKey, nil
end

local function finishMutation(player, action, args, barrel, barrelData, changed, reason, extra)
    if changed then
        StateService.persist(barrel, barrelData, true)
    else
        StateService.persist(barrel, barrelData, false)
    end
    accept(player, action, reason or "ok", barrel, barrelData, args, extra)
end

local function runShortMutation(player, args, action, mutator)
    action = getAction(args, action)

    local barrel, barrelData, reason = resolveForAction(player, args, action)
    if not barrel then
        reject(player, action, reason, nil, nil, args)
        return
    end

    if not barrelData and action ~= "open" then
        reject(player, action, reason or "barrel_unavailable", barrel, barrelData, args)
        return
    end

    local playerKey, barrelKey, lockReason = acquireLock(player, action, barrel, barrelData, args)
    if not playerKey then
        reject(player, action, lockReason, barrel, barrelData, args)
        return
    end

    local ok, changed, finalReason, extra = pcall(mutator, barrel, barrelData)

    if not ok then
        LockService.release(playerKey, barrelKey)
        reject(player, action, "server_error", barrel, barrelData, args)
        Logger.error("Barrel action error: " .. tostring(changed))
        return
    end

    if changed == false then
        LockService.release(playerKey, barrelKey)
        reject(player, action, finalReason or "unknown", barrel, barrelData, args, extra)
        return
    end

    local finishOk, finishError = pcall(finishMutation, player, action, args, barrel, barrelData, changed == true, finalReason, extra)
    LockService.release(playerKey, barrelKey)
    if not finishOk then
        reject(player, action, "server_error", barrel, barrelData, args)
        Logger.error("Barrel action finish error: " .. tostring(finishError))
    end
end

local function getPlayerName(player)
    return tostring(player and player.getUsername and player:getUsername() or "unknown")
end

local function getActiveOpen(playerKey, actionId)
    local active = playerKey and activeOpenActions[playerKey] or nil
    if not active then return nil end
    if tostring(active.actionId) ~= tostring(actionId) then return nil end
    return active
end

local function releaseOpen(playerKey, active, reason)
    if not active then return end

    LockService.release(playerKey, active.barrelKey)
    if activeOpenActions[playerKey] == active then
        activeOpenActions[playerKey] = nil
    end

    log(string.format(
        "Open reservation released: actionId=%s player=%s barrelId=%s reason=%s",
        tostring(active.actionId or "unknown"),
        getPlayerName(active.player),
        tostring(active.barrelKey or "unknown"),
        tostring(reason or "released")
    ))
end

local function replaceActiveOpen(playerKey, reason)
    local active = playerKey and activeOpenActions[playerKey] or nil
    if active then
        releaseOpen(playerKey, active, reason or "replaced_by_new_open")
    end
end

local function getOrCreateOpenData(barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    if barrelData then
        local _, idChanged = BarrEx_BarrelData.ensureStableId(barrel, barrelData)
        local stateChanged = BarrEx_BarrelData.set(barrel, barrelData)
        if idChanged or stateChanged then
            barrel:transmitModData()
        end
        return barrelData
    end

    local spawnProfile = BarrEx_BarrelData.getSpawnProfile(barrel) or Constant.BARREL_SPAWN_PROFILE.WORLD
    barrelData = BarrEx_BarrelFactory.createRandom(barrel, { spawnProfile = spawnProfile })
    StateService.persist(barrel, barrelData, false)
    return barrelData
end

---@param player IsoPlayer
---@param args table|nil
function ActionService.startOpen(player, args)
    local action = getAction(args, "open")
    if type(args) ~= "table" then
        reject(player, action, "invalid_args", nil, nil, args)
        return
    end

    if not isValidActionId(args.actionId) then
        reject(player, action, "missing_transfer_id", nil, nil, args)
        return
    end

    local barrel, barrelData, reason = resolveForAction(player, args, action)
    if not barrel then
        reject(player, action, reason, nil, nil, args)
        return
    end

    if not InteractionRules.validateInteraction(barrel, player, Constant.OPEN_BARREL_REQUIRED_ITEMS, true) then
        reject(player, action, "interaction_invalid", barrel, barrelData, args)
        return
    end

    barrelData = getOrCreateOpenData(barrel)

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        reject(player, action, "invalid_player", barrel, barrelData, args)
        return
    end

    local barrelKey = LockService.getBarrelKey(barrel, barrelData)
    if not barrelKey then
        reject(player, action, "barrel_id_missing", barrel, barrelData, args)
        return
    end

    local active = getActiveOpen(playerKey, args.actionId)
    if active and active.barrelKey == barrelKey then
        active.ticks = 0
        accept(player, action, "reserved", barrel, barrelData, args, { openReserved = true })
        return
    end

    replaceActiveOpen(playerKey, "replaced_by_new_open")

    if not LockService.acquire(playerKey, barrelKey, "long", args.actionId) then
        reject(player, action, "barrel_locked", barrel, barrelData, args)
        return
    end

    activeOpenActions[playerKey] = {
        player = player,
        actionId = tostring(args.actionId),
        args = args,
        barrelKey = barrelKey,
        lastBarrel = barrel,
        barrelData = barrelData,
        ticks = 0,
    }

    accept(player, action, "reserved", barrel, barrelData, args, { openReserved = true })
end

---@param player IsoPlayer
---@param args table|nil
function ActionService.cancelOpen(player, args)
    if type(args) ~= "table" or not isValidActionId(args.actionId) then return end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then return end

    local active = getActiveOpen(playerKey, args.actionId)
    if not active then return end

    local barrel = active.lastBarrel
    local barrelData = active.barrelData or BarrEx_BarrelData.get(barrel)
    releaseOpen(playerKey, active, "client_cancel")
    accept(player, getAction(args, "open"), "cancelled", barrel, barrelData, args)
end

---@param player IsoPlayer
---@param args table|nil
function ActionService.completeOpen(player, args)
    local action = getAction(args, "open")
    if type(args) ~= "table" then
        reject(player, action, "invalid_args", nil, nil, args)
        return
    end

    if not isValidActionId(args.actionId) then
        reject(player, action, "missing_transfer_id", nil, nil, args)
        return
    end

    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        reject(player, action, "invalid_player", nil, nil, args)
        return
    end

    local active = getActiveOpen(playerKey, args.actionId)
    if not active then
        log(string.format(
            "Open completion received without active reservation; using validated fallback: actionId=%s player=%s",
            tostring(args.actionId or "unknown"),
            getPlayerName(player)
        ))
        ActionService.open(player, args)
        return
    end

    local barrel, barrelData, reason = resolveForAction(player, args, action)
    if not barrel then
        releaseOpen(playerKey, active, reason or "barrel_not_found")
        reject(player, action, reason or "barrel_not_found", active.lastBarrel, active.barrelData, args)
        return
    end

    barrelData = BarrEx_BarrelData.get(barrel) or active.barrelData
    if not barrelData then
        releaseOpen(playerKey, active, "barrel_unavailable")
        reject(player, action, "barrel_unavailable", barrel, barrelData, args)
        return
    end
    BarrEx_BarrelData.ensureStableId(barrel, barrelData)

    local barrelKey = LockService.getBarrelKey(barrel, barrelData)
    if barrelKey ~= active.barrelKey then
        releaseOpen(playerKey, active, "barrel_mismatch")
        reject(player, action, "transfer_mismatch", barrel, barrelData, args)
        return
    end

    if LockService.isLockedBy(barrelKey) ~= playerKey then
        activeOpenActions[playerKey] = nil
        reject(player, action, "barrel_lock_lost", barrel, barrelData, args)
        return
    end

    if not InteractionRules.validateInteraction(barrel, player, Constant.OPEN_BARREL_REQUIRED_ITEMS, true) then
        releaseOpen(playerKey, active, "interaction_invalid")
        reject(player, action, "interaction_invalid", barrel, barrelData, args)
        return
    end

    local changed = false
    local resultReason = "already_open"
    if not barrelData:isRevealed() then
        barrelData.revealed = true
        changed = true
        resultReason = "ok"
    end

    local finishOk, finishError = pcall(finishMutation, player, action, args, barrel, barrelData, changed, resultReason)
    releaseOpen(playerKey, active, resultReason)
    if not finishOk then
        reject(player, action, "server_error", barrel, barrelData, args)
        Logger.error("Barrel open finish error: " .. tostring(finishError))
    end
end

function ActionService.open(player, args)
    local action = getAction(args, "open")
    local barrel, barrelData, reason = resolveForAction(player, args, action)
    if not barrel then
        reject(player, action, reason, nil, nil, args)
        return
    end

    if not InteractionRules.validateInteraction(barrel, player, Constant.OPEN_BARREL_REQUIRED_ITEMS, true) then
        reject(player, action, "interaction_invalid", barrel, barrelData, args)
        return
    end

    if not barrelData then
        local spawnProfile = BarrEx_BarrelData.getSpawnProfile(barrel) or Constant.BARREL_SPAWN_PROFILE.WORLD
        barrelData = BarrEx_BarrelFactory.createRandom(barrel, { spawnProfile = spawnProfile })
    end

    local playerKey, barrelKey, lockReason = acquireLock(player, action, barrel, barrelData, args)
    if not playerKey then
        reject(player, action, lockReason, barrel, barrelData, args)
        return
    end

    local changed = false
    local resultReason = "already_open"
    if not barrelData:isRevealed() then
        barrelData.revealed = true
        changed = true
        resultReason = "ok"
    end

    local finishOk, finishError = pcall(finishMutation, player, action, args, barrel, barrelData, changed, resultReason)
    LockService.release(playerKey, barrelKey)
    if not finishOk then
        reject(player, action, "server_error", barrel, barrelData, args)
        Logger.error("Barrel open finish error: " .. tostring(finishError))
    end
end

function ActionService.drink(player, args)
    runShortMutation(player, args, "drink", function(barrel, barrelData)
        if not InteractionRules.validateInteraction(barrel, player, {}, false) then
            return false, "interaction_invalid"
        end
        if barrelData:isEmpty() then return false, "barrel_empty" end
        if not isWaterLike(barrelData.liquidType) then return false, "not_drinkable" end

        local stats = player:getStats()
        if not stats or (tonumber(stats:get(CharacterStat.THIRST)) or 0) <= 0.01 then
            return false, "not_thirsty"
        end

        local liquidType = barrelData.liquidType
        local removed = barrelData:removeLiquid(math.min(Constant.BARREL_DRINK_AMOUNT or 0.12, barrelData.amount or 0))
        if removed <= 0 then return false, "barrel_empty" end

        stats:remove(CharacterStat.THIRST, Constant.BARREL_DRINK_THIRST or 0.1)
        syncStats(player)

        if liquidType == Constant.LIQUID_TYPE.TAINTED_WATER then
            applyTaintedWaterSickness(player)
        end

        return true, "ok"
    end)
end

function ActionService.wash(player, args)
    runShortMutation(player, args, "wash", function(barrel, barrelData)
        if not InteractionRules.validateInteraction(barrel, player, {}, false) then
            return false, "interaction_invalid"
        end
        if barrelData:isEmpty() then return false, "barrel_empty" end
        if not isWaterLike(barrelData.liquidType) then return false, "not_washable" end

        local washMode = type(args) == "table" and args.washMode or "self"
        if washMode == "item" then
            local item = InteractionRules.getItemFromArgsStrict(player, args)
            if not item then return false, "target_not_found" end

            if barrelData.liquidType == Constant.LIQUID_TYPE.TAINTED_WATER
                and isCleanableBandageLikeItem(item)
            then
                return false, "tainted_water_cannot_clean_bandage"
            end

            local waterRequired = getWashWaterRequired(item)
            if (tonumber(barrelData.amount) or 0) < waterRequired then
                return false, "insufficient_water"
            end

            if not washItem(player, item) then
                return false, "item_mutation_failed"
            end

            barrelData:removeLiquid(waterRequired)
            return true, "ok", {
                washMode = "item",
                itemId = args.itemId,
                itemFullType = args.itemFullType,
            }
        end

        local visual = player:getHumanVisual()
        if not visual then return false, "visual_unavailable" end

        local availableUnits = math.floor((tonumber(barrelData.amount) or 0) / (Constant.BARREL_WASH_UNIT_AMOUNT or 1))
        if availableUnits <= 0 then return false, "insufficient_water" end

        local waterUsed = 0
        local washedBodyParts = {}
        for i = 1, BloodBodyPartType.MAX:index() do
            if waterUsed >= availableUnits then break end

            local partIndex = i - 1
            local part = BloodBodyPartType.FromIndex(partIndex)
            local blood = tonumber(visual:getBlood(part)) or 0
            local dirt = tonumber(visual:getDirt(part)) or 0
            if blood + dirt > 0 then
                if blood > 0 then consumeSoap(player) end
                visual:setBlood(part, 0)
                visual:setDirt(part, 0)
                waterUsed = waterUsed + 1
                washedBodyParts[#washedBodyParts + 1] = partIndex
            end
        end

        if waterUsed <= 0 then return false, "nothing_to_wash" end

        removeMakeup(player)
        syncPlayerVisuals(player)
        barrelData:removeLiquid(waterUsed * (Constant.BARREL_WASH_UNIT_AMOUNT or 1))

        return true, "ok", {
            washMode = "self",
            washedBodyParts = washedBodyParts,
        }
    end)
end

function ActionService.empty(player, args)
    runShortMutation(player, args, "empty", function(barrel, barrelData)
        if not InteractionRules.validateInteraction(barrel, player, {}, false) then
            return false, "interaction_invalid"
        end
        if barrelData:isEmpty() then return false, "barrel_empty" end

        local removed = barrelData:removeLiquid(barrelData.amount or 0)
        if removed <= 0 then return false, "barrel_empty" end

        return true, "ok"
    end)
end

--- Releases abandoned open reservations when the completing/cancel command never
--- arrives from the client.
function ActionService.onTick()
    local expiredPlayerKeys = nil
    for playerKey, active in pairs(activeOpenActions) do
        active.ticks = (tonumber(active.ticks) or 0) + 1
        if active.ticks >= OPEN_LOCK_TIMEOUT_TICKS then
            expiredPlayerKeys = expiredPlayerKeys or {}
            expiredPlayerKeys[#expiredPlayerKeys + 1] = playerKey
        end
    end

    if not expiredPlayerKeys then return end
    for i = 1, #expiredPlayerKeys do
        local playerKey = expiredPlayerKeys[i]
        releaseOpen(playerKey, activeOpenActions[playerKey], "timeout")
    end
end

return ActionService
