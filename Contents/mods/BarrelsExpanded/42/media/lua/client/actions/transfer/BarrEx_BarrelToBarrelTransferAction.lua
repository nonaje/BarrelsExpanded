local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local TransferRules = require("core/BarrEx_TransferRules")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local TransferSync = require("BarrEx_TransferSync")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")
local BarrelStateClient = require("BarrEx_BarrelStateClient")

---@class BarrEx_BarrelToBarrelTransferAction : BarrEx_BarrelActionBase
---@field sourceBarrel IsoObject
---@field targetBarrel IsoObject
---@field transferStarted boolean
---@field transferId string
---@field mode string
---@field totalAmount number
---@field liquidType string|nil
local BarrEx_BarrelToBarrelTransferAction = BarrEx_BarrelActionBase:derive("BarrEx_BarrelToBarrelTransferAction")

local MODE = "barrel_to_barrel"

local function getCurrentTimestamp()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimestamp) == "function" then
        return getTimestamp()
    end
    return os and os.time and os.time() or 0
end

local function getRandomSuffix()
    if type(ZombRand) == "function" then
        return ZombRand(1000000)
    end
    return math.random(1000000)
end

local function getBarrelId(barrel)
    return BarrEx_BarrelData.getId(barrel) or "nobarrel"
end

local function buildTransferId(player, sourceBarrel, targetBarrel)
    local playerId = player and type(player.getOnlineID) == "function" and player:getOnlineID() or "local"

    return MODE
        .. ":" .. tostring(playerId)
        .. ":" .. tostring(getBarrelId(sourceBarrel))
        .. ":" .. tostring(getBarrelId(targetBarrel))
        .. ":" .. tostring(getCurrentTimestamp())
        .. ":" .. tostring(getRandomSuffix())
end

local function clamp01(value)
    local numericValue = tonumber(value) or 0
    if numericValue < 0 then return 0 end
    if numericValue > 1 then return 1 end
    return numericValue
end

local function buildEndpointPayload(barrel)
    local square = barrel and barrel:getSquare()
    if not square then return nil end

    local barrelData = BarrEx_BarrelData.get(barrel)
    local modData = barrel:getModData()
    return {
        kind = "barrel",
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = barrel:getObjectIndex(),
        barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or (barrelData and barrelData.id) or nil,
        clientRevision = barrelData and barrelData.revision or 0,
        spriteName = WorldUtils.getSpriteName(barrel),
    }
end

local function getTransferSound(liquidType)
    if liquidType == Constant.LIQUID_TYPE.WATER or liquidType == Constant.LIQUID_TYPE.TAINTED_WATER then
        return "PourWaterIntoObject"
    end
    return "TransferLiquid"
end

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end

local function sendEndpointCommand(action, command, extraArgs)
    if not action or not command then return false end

    local sourcePayload = buildEndpointPayload(action.sourceBarrel)
    local targetPayload = buildEndpointPayload(action.targetBarrel)
    if not sourcePayload or not targetPayload then
        return false
    end

    local payload = action:buildBarrelPayload({
        transferId = action.transferId,
        mode = action.mode,
        source = sourcePayload,
        target = targetPayload,
        targetBarrelId = targetPayload.barrelId,
    })
    if not payload then
        return false
    end

    if type(extraArgs) == "table" then
        for key, value in pairs(extraArgs) do
            payload[key] = value
        end
    end

    sendClientCommand(Constant.NETWORK.MODULE, command, payload)

    if command == Constant.NETWORK.START_ENDPOINT_TRANSFER then
        BarrelStateClient.trackAction(payload)
    end

    return true
end

function BarrEx_BarrelToBarrelTransferAction:isValid()
    if not self.sourceBarrel or not self.targetBarrel or self.sourceBarrel == self.targetBarrel then
        return false
    end
    if not PlayerUtils.isPlayerInRange(self.character, self.sourceBarrel) then
        return false
    end
    if not PlayerUtils.isPlayerInRange(self.character, self.targetBarrel) then
        return false
    end

    local sourceData = BarrEx_BarrelData.get(self.sourceBarrel)
    local targetData = BarrEx_BarrelData.get(self.targetBarrel)

    if not sourceData or not targetData then
        return false
    end

    return TransferRules.canTransferBetweenBarrels(sourceData, targetData)
end

function BarrEx_BarrelToBarrelTransferAction:start()
    ISBaseTimedAction.start(self)

    self.transferStarted = sendEndpointCommand(self, Constant.NETWORK.START_ENDPOINT_TRANSFER, { progress = 0 })
    if self.transferStarted then
        TransferSync.registerAction(self.transferId, self.mode, self, self.sourceBarrel, nil)
        self.lastSentAnimationProgress = 0
        self.progressTicksSinceSync = 0
        sendEndpointCommand(self, Constant.NETWORK.UPDATE_TRANSFER_PROGRESS, { progress = 0 })
    end

    self:setActionAnim("fill_container_tap")
    self:setOverrideHandModels(nil, nil)
    self.sound = self.character:playSound(getTransferSound(self.liquidType))
end

function BarrEx_BarrelToBarrelTransferAction:update()
    TransferSync.beforeActionUpdate(self)

    if self.transferStarted then
        local progress = clamp01(self:getJobDelta())
        self.progressTicksSinceSync = (self.progressTicksSinceSync or 0) + 1

        local interval = math.max(tonumber(Constant.CLIENT_TRANSFER_PROGRESS_INTERVAL) or 5, 1)
        local epsilon = math.max(tonumber(Constant.CLIENT_TRANSFER_PROGRESS_EPSILON) or 0.01, 0)
        local lastProgress = tonumber(self.lastSentAnimationProgress) or 0
        local shouldSendProgress = self.progressTicksSinceSync >= interval
            or progress >= 1
            or progress - lastProgress >= epsilon

        if shouldSendProgress then
            if sendEndpointCommand(self, Constant.NETWORK.UPDATE_TRANSFER_PROGRESS, { progress = progress }) then
                self.lastSentAnimationProgress = progress
                self.progressTicksSinceSync = 0
            end
        end
    end

    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.sourceBarrel)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BarrEx_BarrelToBarrelTransferAction:stop()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    if self.transferStarted then
        sendEndpointCommand(self, Constant.NETWORK.STOP_ENDPOINT_TRANSFER, { progress = clamp01(self:getJobDelta()) })
        self.transferStarted = false
    end
    ISBaseTimedAction.stop(self)
end

function BarrEx_BarrelToBarrelTransferAction:perform()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    if self.transferStarted then
        sendEndpointCommand(self, Constant.NETWORK.COMPLETE_ENDPOINT_TRANSFER, { progress = 1 })
        self.transferStarted = false
    end
    ISBaseTimedAction.perform(self)
end

---@param player IsoPlayer
---@param sourceBarrel IsoObject
---@param targetBarrel IsoObject
---@return BarrEx_BarrelToBarrelTransferAction
function BarrEx_BarrelToBarrelTransferAction:new(player, sourceBarrel, targetBarrel)
    local sourceData = BarrEx_BarrelData.get(sourceBarrel)
    local targetData = BarrEx_BarrelData.get(targetBarrel)
    ---@cast sourceData BarrEx_Barrel
    ---@cast targetData BarrEx_Barrel
    local liquidType = sourceData and sourceData.liquidType or nil
    local totalAmount = TransferRules.getBarrelToBarrelAmount(sourceData, targetData)
    local maxTime = TransferRules.getTransferActionTime(totalAmount, MODE, liquidType)
    local o = BarrEx_BarrelActionBase.new(self, player, sourceBarrel, MODE, nil, maxTime)
    ---@cast o BarrEx_BarrelToBarrelTransferAction

    o.sourceBarrel = sourceBarrel
    o.targetBarrel = targetBarrel
    o.mode = MODE
    o.transferId = buildTransferId(player, sourceBarrel, targetBarrel)
    o.actionId = o.transferId
    o.totalAmount = totalAmount
    o.liquidType = liquidType
    o.transferStarted = false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = math.max(tonumber(maxTime) or 1, 1)

    return o
end

return BarrEx_BarrelToBarrelTransferAction
