local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local BarrelStateClient = require("BarrEx_BarrelStateClient")

---@class BarrEx_BarrelActionBase : ISBaseTimedAction
---@field barrel IsoObject
---@field actionName string
---@field command string|nil
---@field actionId string
local BarrEx_BarrelActionBase = ISBaseTimedAction:derive("BarrEx_BarrelActionBase")

local function getCurrentTimestamp()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    if type(getTimestamp) == "function" then return getTimestamp() end
    return os and os.time and os.time() or 0
end

local function getRandomSuffix()
    if type(ZombRand) == "function" then return ZombRand(1000000) end
    return math.random(1000000)
end

local function buildActionId(player, barrel, actionName)
    local modData = barrel and barrel:getModData() or nil
    local barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or "nobarrel"
    local playerId = player and type(player.getOnlineID) == "function" and player:getOnlineID() or "local"

    return tostring(actionName or "action")
        .. ":" .. tostring(playerId)
        .. ":" .. tostring(barrelId)
        .. ":" .. tostring(getCurrentTimestamp())
        .. ":" .. tostring(getRandomSuffix())
end

function BarrEx_BarrelActionBase:getClientRevision()
    local barrelData = self.barrel and BarrEx_BarrelData.get(self.barrel) or nil
    return barrelData and barrelData.revision or 0
end

function BarrEx_BarrelActionBase:buildBarrelPayload(extraArgs)
    local square = self.barrel and self.barrel:getSquare()
    if not square then return nil end

    local modData = self.barrel:getModData()
    local payload = {
        actionId = self.actionId,
        action = self.actionName,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = self.barrel:getObjectIndex(),
        barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil,
        clientRevision = self:getClientRevision(),
        spriteName = WorldUtils.getSpriteName(self.barrel),
    }

    if type(extraArgs) == "table" then
        for key, value in pairs(extraArgs) do
            payload[key] = value
        end
    end

    return payload
end

function BarrEx_BarrelActionBase:sendBarrelCommand(command, extraArgs)
    local payload = self:buildBarrelPayload(extraArgs)
    if not payload then return false end

    local resolvedCommand = command or self.command
    if not resolvedCommand then return false end
    sendClientCommand(Constant.NETWORK.MODULE, resolvedCommand, payload)
    if resolvedCommand ~= Constant.NETWORK.REQUEST_BARREL_STATE then
        BarrelStateClient.trackAction(payload)
    end
    return true
end

function BarrEx_BarrelActionBase:requestBarrelState(extraArgs)
    return self:sendBarrelCommand(Constant.NETWORK.REQUEST_BARREL_STATE, extraArgs)
end

function BarrEx_BarrelActionBase:isBarrelInRange()
    return self.barrel ~= nil and PlayerUtils.isPlayerInRange(self.character, self.barrel)
end

function BarrEx_BarrelActionBase:new(player, barrel, actionName, command, maxTime)
    local o = ISBaseTimedAction.new(self, player)
    ---@cast o BarrEx_BarrelActionBase

    o.barrel = barrel
    o.actionName = actionName or "unknown"
    o.command = command
    o.actionId = buildActionId(player, barrel, actionName)
    o.maxTime = math.max(tonumber(maxTime) or 1, 1)
    o.stopOnWalk = true
    o.stopOnRun = true

    setmetatable(o, self)
    self.__index = self

    return o
end

return BarrEx_BarrelActionBase
