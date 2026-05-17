-- BarrEx_BarrelStateService: authoritative barrel snapshots and state replies.

local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrelResolver    = require("BarrEx_BarrelResolver")
local WorldUtils        = require("utils/BarrEx_WorldUtils")
local Logger            = require("utils/BarrEx_Logger")

local BarrelStateService = {}

local function log(message)
    Logger.info(message)
end

local function getActionId(source)
    if type(source) ~= "table" then return nil end
    return source.actionId or source.transferId
end

local function getActionName(source)
    if type(source) ~= "table" then return nil end
    return source.action or source.mode
end

---@param barrel IsoObject|nil
---@param barrelData BarrEx_Barrel|nil
---@return table|nil
function BarrelStateService.buildSnapshot(barrel, barrelData)
    if not barrel then return nil end

    barrelData = barrelData or BarrEx_BarrelData.get(barrel)
    if not barrelData then return nil end

    local square = barrel:getSquare()
    return {
        id = barrelData.id,
        barrelId = barrelData.id,
        revision = math.max(math.floor(tonumber(barrelData.revision) or 0), 0),
        revealed = barrelData.revealed == true,
        liquidType = barrelData.liquidType,
        amount = tonumber(barrelData.amount) or 0,
        capacity = tonumber(barrelData.capacity) or 0,
        weight = barrelData:getTotalWeight(),
        x = square and square:getX() or nil,
        y = square and square:getY() or nil,
        z = square and square:getZ() or nil,
        objectIndex = type(barrel.getObjectIndex) == "function" and barrel:getObjectIndex() or nil,
        spriteName = WorldUtils.getSpriteName(barrel),
    }
end

---@param barrel IsoObject|nil
---@param barrelData BarrEx_Barrel|nil
---@param bumpRevision boolean|nil
---@return table|nil
function BarrelStateService.persist(barrel, barrelData, bumpRevision)
    if not barrel or not barrelData then return nil end

    if bumpRevision == true then
        BarrEx_BarrelData.bumpRevision(barrelData)
    end

    BarrEx_BarrelData.set(barrel, barrelData)
    barrel:transmitModData()
    return BarrelStateService.buildSnapshot(barrel, barrelData)
end

---@param player IsoPlayer
---@param barrel IsoObject|nil
---@param barrelData BarrEx_Barrel|nil
---@param source table|nil
function BarrelStateService.sendState(player, barrel, barrelData, source)
    if not player or type(sendServerCommand) ~= "function" then return end

    local snapshot = BarrelStateService.buildSnapshot(barrel, barrelData)
    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.BARREL_STATE, {
        actionId = getActionId(source),
        action = getActionName(source) or "state",
        accepted = snapshot ~= nil,
        reason = snapshot and "ok" or "barrel_unavailable",
        barrelId = snapshot and snapshot.barrelId or (type(source) == "table" and source.barrelId or nil),
        playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
        revision = snapshot and snapshot.revision or nil,
        snapshot = snapshot,
    })
end

---@param player IsoPlayer
---@param args table|nil
function BarrelStateService.onRequest(player, args)
    if not player then return end
    if type(args) ~= "table" then
        if type(sendServerCommand) == "function" then
            sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.BARREL_STATE, {
                accepted = false,
                reason = "invalid_args",
                playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
            })
        end
        log("Barrel state request rejected: invalid_args")
        return
    end

    local barrel, reason = BarrelResolver.resolve(args)
    if not barrel then
        if type(sendServerCommand) == "function" then
            sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.BARREL_STATE, {
                actionId = getActionId(args),
                action = getActionName(args) or "state",
                accepted = false,
                reason = reason or "barrel_not_found",
                barrelId = args.barrelId,
                playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
            })
        end
        log("Barrel state request rejected: " .. tostring(reason or "barrel_not_found"))
        return
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if barrelData then
        BarrEx_BarrelData.ensureStableId(barrel, barrelData)
        BarrEx_BarrelData.set(barrel, barrelData)
    end

    BarrelStateService.sendState(player, barrel, barrelData, args)
end

return BarrelStateService
