local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")
local TransferRules = require("core/BarrEx_TransferRules")
local TransferSync = require("BarrEx_TransferSync")

---@class BarrEx_EmptyBarrelAction : BarrEx_BarrelActionBase
---@field barrel IsoObject
---@field sound integer|nil
---@field transferStarted boolean
---@field transferId string
---@field mode string
local BarrEx_EmptyBarrelAction = BarrEx_BarrelActionBase:derive("BarrEx_EmptyBarrelAction")

local function clamp01(value)
    local numericValue = tonumber(value) or 0
    if numericValue < 0 then return 0 end
    if numericValue > 1 then return 1 end
    return numericValue
end

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end

local function sendEmptyCommand(action, command, extraArgs, trackAction)
    if not action or not command then return false end

    local payload = action:buildBarrelPayload({
        transferId = action.transferId,
        mode = action.mode,
    })
    if not payload then return false end

    if type(extraArgs) == "table" then
        for key, value in pairs(extraArgs) do
            payload[key] = value
        end
    end

    sendClientCommand(Constant.NETWORK.MODULE, command, payload)

    if trackAction == true then
        local BarrelStateClient = require("BarrEx_BarrelStateClient")
        BarrelStateClient.trackAction(payload)
    end

    return true
end

function BarrEx_EmptyBarrelAction:getAnimName()
    if CharacterActionAnims and CharacterActionAnims.Pour then
        return CharacterActionAnims.Pour
    end
    return "fill_container_tap"
end

function BarrEx_EmptyBarrelAction:getSoundName()
    return "PourWaterIntoObject"
end

function BarrEx_EmptyBarrelAction:isValid()
    return self.barrel ~= nil
        and BarrEx_BarrelData.isRevealedRaw(self.barrel)
        and self:isBarrelInRange()
end

function BarrEx_EmptyBarrelAction:waitToStart()
    if self.barrel then
        self.character:faceThisObject(self.barrel)
    end
    return self.character:shouldBeTurning()
end

function BarrEx_EmptyBarrelAction:start()
    ISBaseTimedAction.start(self)

    self.transferStarted = sendEmptyCommand(
        self,
        Constant.NETWORK.START_EMPTY_BARREL,
        { progress = 0 },
        true
    )
    if self.transferStarted then
        TransferSync.registerAction(self.transferId, self.mode, self, self.barrel, nil)
        self.lastSentAnimationProgress = 0
        self.progressTicksSinceSync = 0
        sendEmptyCommand(self, Constant.NETWORK.UPDATE_EMPTY_BARREL_PROGRESS, { progress = 0 }, false)
    end

    self:setActionAnim(self:getAnimName())
    self:setOverrideHandModels(nil, nil)
    self.character:reportEvent("EventTakeWater")

    local soundName = self:getSoundName()
    if soundName then
        self.sound = self.character:playSound(soundName)
    end
end

function BarrEx_EmptyBarrelAction:update()
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
            if sendEmptyCommand(self, Constant.NETWORK.UPDATE_EMPTY_BARREL_PROGRESS, { progress = progress }, false) then
                self.lastSentAnimationProgress = progress
                self.progressTicksSinceSync = 0
            end
        end
    end

    if self.barrel then
        self.character:faceThisObject(self.barrel)
    end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    ISBaseTimedAction.update(self)
end

function BarrEx_EmptyBarrelAction:stop()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    if self.transferStarted then
        sendEmptyCommand(self, Constant.NETWORK.STOP_EMPTY_BARREL, { progress = clamp01(self:getJobDelta()) }, false)
        self.transferStarted = false
    end
    ISBaseTimedAction.stop(self)
end

function BarrEx_EmptyBarrelAction:perform()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    if self.transferStarted then
        sendEmptyCommand(self, Constant.NETWORK.COMPLETE_EMPTY_BARREL, { progress = 1 }, false)
        self.transferStarted = false
    end
    ISBaseTimedAction.perform(self)
end

---@param player IsoPlayer
---@param barrel IsoObject
---@return BarrEx_EmptyBarrelAction
function BarrEx_EmptyBarrelAction:new(player, barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    local amount = barrelData and barrelData.amount or 0
    local liquidType = barrelData and barrelData.liquidType or nil
    local maxTime = TransferRules.getTransferActionTime(amount, "empty", liquidType)
    local o = BarrEx_BarrelActionBase.new(self, player, barrel, "empty", nil, maxTime)
    ---@cast o BarrEx_EmptyBarrelAction
    o.mode = "empty"
    o.transferId = o.actionId
    o.transferStarted = false
    o.totalAmount = amount
    return o
end

return BarrEx_EmptyBarrelAction
