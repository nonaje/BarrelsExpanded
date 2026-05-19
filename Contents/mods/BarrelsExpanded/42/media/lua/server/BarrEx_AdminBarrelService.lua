-- BarrEx_AdminBarrelService: authoritative debug/admin barrel tools.

local Constant              = require("BarrEx_Constant")
local BarrEx_Barrel         = require("BarrEx_Barrel")
local BarrEx_BarrelData     = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory  = require("BarrEx_BarrelFactory")
local BarrelResolver        = require("BarrEx_BarrelResolver")
local LockService           = require("BarrEx_BarrelLockService")
local StateService          = require("BarrEx_BarrelStateService")
local Notifier              = require("BarrEx_BarrelActionNotifier")
local WorldUtils            = require("utils/BarrEx_WorldUtils")
local Logger                = require("utils/BarrEx_Logger")

local AdminBarrelService = {}

local ACTION_NAME = "adminBarrel"
local OPERATIONS = Constant.ADMIN_BARREL_OPERATION

local function getActionId(args)
    if type(args) ~= "table" then return nil end
    return args.actionId or args.transferId
end

local function getPlayerName(player)
    if player and type(player.getUsername) == "function" then
        return tostring(player:getUsername())
    end
    return "unknown"
end

local function isLocalDebugEnabled()
    if type(isDebugEnabled) == "function" and isDebugEnabled() then
        return true
    end

    local core = type(getCore) == "function" and getCore() or nil
    return core ~= nil and type(core.getDebug) == "function" and core:getDebug() == true
end

local function hasDebugCapability(player)
    if not player or not Capability or not Capability.UseDebugContextMenu then
        return false
    end

    local role = type(player.getRole) == "function" and player:getRole() or nil
    return role ~= nil
        and type(role.hasCapability) == "function"
        and role:hasCapability(Capability.UseDebugContextMenu) == true
end

local function hasPermission(player)
    if not player then return false end

    if type(isServer) == "function" and isServer() then
        if type(checkPermissions) == "function" and Capability and Capability.UseDebugContextMenu then
            local ok, allowed = pcall(checkPermissions, player, Capability.UseDebugContextMenu)
            if ok and allowed == true then return true end
        end

        return hasDebugCapability(player)
    end

    if type(isClient) == "function" and isClient() then
        return hasDebugCapability(player)
    end

    return isLocalDebugEnabled() or hasDebugCapability(player)
end

local function getOperation(args)
    if type(args) ~= "table" then return nil end
    return args.operation
end

local function isKnownOperation(operation)
    return operation == OPERATIONS.INSPECT
        or operation == OPERATIONS.REPAIR
        or operation == OPERATIONS.REVEAL
        or operation == OPERATIONS.EMPTY
        or operation == OPERATIONS.SET_LIQUID
        or operation == OPERATIONS.REROLL
end

local function logResult(player, args, accepted, reason, barrelData)
    Logger.info(string.format(
        "Admin barrel action %s: actionId=%s player=%s operation=%s barrelId=%s revision=%s reason=%s",
        accepted and "accepted" or "rejected",
        tostring(getActionId(args) or "unknown"),
        getPlayerName(player),
        tostring(getOperation(args) or "unknown"),
        tostring((barrelData and barrelData.id) or (type(args) == "table" and args.barrelId) or "unknown"),
        tostring(barrelData and barrelData.revision or "unknown"),
        tostring(reason or "unknown")
    ))
end

local function sendResult(player, args, accepted, reason, barrel, barrelData)
    Notifier.result(player, ACTION_NAME, accepted == true, reason, barrel, barrelData, args, {
        operation = getOperation(args),
    })
    logResult(player, args, accepted == true, reason, barrelData)
end

local function reject(player, args, reason, barrel, barrelData)
    sendResult(player, args, false, reason, barrel, barrelData)
end

local function accept(player, args, reason, barrel, barrelData)
    sendResult(player, args, true, reason or "ok", barrel, barrelData)
end

local function getFallbackBarrelKey(barrel, args)
    if not barrel then return nil end

    local square = barrel:getSquare()
    local x = square and square:getX() or (type(args) == "table" and args.x or nil)
    local y = square and square:getY() or (type(args) == "table" and args.y or nil)
    local z = square and square:getZ() or (type(args) == "table" and args.z or nil)
    local objectIndex = type(args) == "table" and args.objectIndex or nil
    if objectIndex == nil and type(barrel.getObjectIndex) == "function" then
        objectIndex = barrel:getObjectIndex()
    end

    local spriteName = type(args) == "table" and args.spriteName or nil
    spriteName = spriteName or WorldUtils.getSpriteName(barrel)

    if x == nil or y == nil or z == nil or objectIndex == nil then
        return nil
    end

    return "admin:init:"
        .. tostring(x) .. ":"
        .. tostring(y) .. ":"
        .. tostring(z) .. ":"
        .. tostring(objectIndex) .. ":"
        .. tostring(spriteName or "nosprite")
end

local function acquireMutationLock(player, barrel, barrelData, args)
    local playerKey = LockService.getPlayerKey(player)
    if playerKey == nil then
        return nil, nil, "invalid_player"
    end

    local barrelKey = LockService.getBarrelKey(barrel, barrelData) or getFallbackBarrelKey(barrel, args)
    if not barrelKey then
        return nil, nil, "barrel_id_missing"
    end

    local acquired = LockService.acquire(playerKey, barrelKey, "short", getActionId(args))
    if not acquired then
        return nil, nil, "barrel_locked"
    end

    return playerKey, barrelKey, nil
end

local function persistAndAccept(player, args, barrel, barrelData, bumpRevision, reason)
    if not StateService.persist(barrel, barrelData, bumpRevision == true) then
        reject(player, args, "barrel_unavailable", barrel, barrelData)
        return false
    end

    accept(player, args, reason or "ok", barrel, barrelData)
    return true
end

local function runMutation(player, args, barrel, barrelData, mutator)
    local playerKey, barrelKey, lockReason = acquireMutationLock(player, barrel, barrelData, args)
    if not playerKey then
        reject(player, args, lockReason, barrel, barrelData)
        return
    end

    local ok, resultData, bumpRevision, reason = pcall(mutator, barrel, barrelData)

    if not ok then
        LockService.release(playerKey, barrelKey)
        Logger.error("Admin barrel action error: " .. tostring(resultData))
        reject(player, args, "server_error", barrel, barrelData)
        return
    end

    if not resultData then
        LockService.release(playerKey, barrelKey)
        reject(player, args, reason or "barrel_unavailable", barrel, barrelData)
        return
    end

    local finishOk, finishError = pcall(persistAndAccept, player, args, barrel, resultData, bumpRevision == true, reason)
    LockService.release(playerKey, barrelKey)
    if not finishOk then
        Logger.error("Admin barrel action finish error: " .. tostring(finishError))
        reject(player, args, "server_error", barrel, resultData)
    end
end

local function getExistingOrDefaultCapacity(barrelData)
    local capacity = barrelData and tonumber(barrelData.capacity) or nil
    return math.max(capacity or Constant.BARREL_DEFAULT_CAPACITY or 0, 0)
end

local function getExistingRevision(barrelData)
    return math.max(math.floor(tonumber(barrelData and barrelData.revision) or 0), 0)
end

local function getExistingId(barrel, barrelData)
    local stableId = BarrEx_BarrelData.ensureStableId(barrel, barrelData)
    return stableId
end

local function getSpawnProfile(barrel)
    return BarrEx_BarrelData.getSpawnProfile(barrel) or Constant.BARREL_SPAWN_PROFILE.WORLD
end

local function makeEmptyData(barrel, barrelData)
    return BarrEx_Barrel:new({
        id = getExistingId(barrel, barrelData),
        liquidType = Constant.LIQUID_TYPE.EMPTY,
        amount = 0,
        capacity = getExistingOrDefaultCapacity(barrelData),
        revealed = true,
        revision = getExistingRevision(barrelData),
    })
end

local function makeSetLiquidData(barrel, barrelData, liquidType, fillRatio)
    if Constant.LIQUID_TYPE[liquidType] == nil then
        return nil, "invalid_liquid"
    end

    local capacity = getExistingOrDefaultCapacity(barrelData)
    local ratio = math.max(math.min(tonumber(fillRatio) or 0, 1), 0)
    local amount = capacity * ratio

    if liquidType == Constant.LIQUID_TYPE.EMPTY or amount <= 0 then
        liquidType = Constant.LIQUID_TYPE.EMPTY
        amount = 0
    end

    return BarrEx_Barrel:new({
        id = getExistingId(barrel, barrelData),
        liquidType = liquidType,
        amount = amount,
        capacity = capacity,
        revealed = true,
        revision = getExistingRevision(barrelData),
    })
end

local function operationInspect(player, args, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then
        reject(player, args, "barrel_unavailable", barrel, nil)
        return
    end

    Logger.info(string.format(
        "Admin barrel snapshot: actionId=%s barrelId=%s revealed=%s liquid=%s amount=%s capacity=%s revision=%s",
        tostring(getActionId(args) or "unknown"),
        tostring(barrelData.id or "unknown"),
        tostring(barrelData.revealed == true),
        tostring(barrelData.liquidType or "unknown"),
        tostring(barrelData.amount or 0),
        tostring(barrelData.capacity or 0),
        tostring(barrelData.revision or 0)
    ))
    accept(player, args, "ok", barrel, barrelData)
end

local function operationRepair(player, args, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    runMutation(player, args, barrel, barrelData, function(targetBarrel, currentData)
        if not currentData then
            return nil, false, "barrel_unavailable"
        end

        BarrEx_BarrelData.ensureStableId(targetBarrel, currentData)
        return currentData, false, "repaired"
    end)
end

local function operationReveal(player, args, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    runMutation(player, args, barrel, barrelData, function(targetBarrel, currentData)
        local nextData = currentData
        if not nextData then
            nextData = BarrEx_BarrelFactory.createRandom(targetBarrel, {
                spawnProfile = getSpawnProfile(targetBarrel),
            })
        end

        BarrEx_BarrelData.ensureStableId(targetBarrel, nextData)
        nextData.revealed = true
        return nextData, true, "revealed"
    end)
end

local function operationEmpty(player, args, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    runMutation(player, args, barrel, barrelData, function(targetBarrel, currentData)
        return makeEmptyData(targetBarrel, currentData), true, "emptied"
    end)
end

local function operationSetLiquid(player, args, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    runMutation(player, args, barrel, barrelData, function(targetBarrel, currentData)
        local nextData, reason = makeSetLiquidData(targetBarrel, currentData, args.liquidType, args.fillRatio)
        if not nextData then
            return nil, false, reason
        end

        return nextData, true, "liquid_set"
    end)
end

local function operationReroll(player, args, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    runMutation(player, args, barrel, barrelData, function(targetBarrel, currentData)
        local nextData = BarrEx_BarrelFactory.createRandom(targetBarrel, {
            spawnProfile = getSpawnProfile(targetBarrel),
        })

        if currentData then
            nextData.revealed = currentData.revealed == true
            nextData.revision = getExistingRevision(currentData)
        end

        BarrEx_BarrelData.ensureStableId(targetBarrel, nextData)
        return nextData, true, "rerolled"
    end)
end

---@param player IsoPlayer
---@param args table|nil
function AdminBarrelService.handle(player, args)
    if type(args) ~= "table" then
        reject(player, args, "invalid_args", nil, nil)
        return
    end

    if not hasPermission(player) then
        reject(player, args, "permission_denied", nil, nil)
        return
    end

    local operation = getOperation(args)
    if not isKnownOperation(operation) then
        reject(player, args, "invalid_operation", nil, nil)
        return
    end

    local barrel, reason = BarrelResolver.resolveStrict(args)
    if not barrel then
        reject(player, args, reason or "barrel_not_found", nil, nil)
        return
    end

    if operation == OPERATIONS.INSPECT then
        operationInspect(player, args, barrel)
        return
    end

    if operation == OPERATIONS.REPAIR then
        operationRepair(player, args, barrel)
        return
    end

    if operation == OPERATIONS.REVEAL then
        operationReveal(player, args, barrel)
        return
    end

    if operation == OPERATIONS.EMPTY then
        operationEmpty(player, args, barrel)
        return
    end

    if operation == OPERATIONS.SET_LIQUID then
        operationSetLiquid(player, args, barrel)
        return
    end

    if operation == OPERATIONS.REROLL then
        operationReroll(player, args, barrel)
    end
end

return AdminBarrelService
