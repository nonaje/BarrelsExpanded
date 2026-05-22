local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local TransferRules = require("core/BarrEx_TransferRules")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local GeneratorUtils = require("utils/BarrEx_GeneratorUtils")
local TransferSync = require("BarrEx_TransferSync")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")
local BarrelStateClient = require("BarrEx_BarrelStateClient")

---@class BarrEx_BarrelToGeneratorTransferAction : BarrEx_BarrelActionBase
---@field sourceBarrel IsoObject
---@field generator IsoGenerator
---@field transferStarted boolean
---@field transferId string
---@field mode string
---@field totalAmount number
---@field liquidType string|nil
---@field toolItem InventoryItem|nil
---@field lastSentAnimationProgress number|nil
---@field progressTicksSinceSync number|nil
---@field sound any
local BarrEx_BarrelToGeneratorTransferAction = BarrEx_BarrelActionBase:derive("BarrEx_BarrelToGeneratorTransferAction")

---@class BarrEx_BarrelEndpointPayload
---@field kind "barrel"
---@field x number
---@field y number
---@field z number
---@field objectIndex number|nil
---@field barrelId string|nil
---@field clientRevision number
---@field spriteName string|nil

---@class BarrEx_GeneratorEndpointPayload
---@field kind "generator"
---@field x number
---@field y number
---@field z number
---@field objectIndex number|nil

local MODE = "barrel_to_generator"

---@return integer
local function getCurrentTimestamp()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimestamp) == "function" then
        return getTimestamp()
    end
    return os and os.time and os.time() or 0
end

---@return integer
local function getRandomSuffix()
    if type(ZombRand) == "function" then
        return ZombRand(1000000)
    end
    return math.random(1000000)
end

---@param barrel IsoObject|nil
---@return string
local function getBarrelId(barrel)
    return BarrEx_BarrelData.getId(barrel) or "nobarrel"
end

---@param player IsoPlayer|nil
---@param sourceBarrel IsoObject
---@param generator IsoGenerator
---@return string
local function buildTransferId(player, sourceBarrel, generator)
    local playerId = player and type(player.getOnlineID) == "function" and player:getOnlineID() or "local"

    return MODE
        .. ":" .. tostring(playerId)
        .. ":" .. tostring(getBarrelId(sourceBarrel))
        .. ":" .. tostring(GeneratorUtils.getKey(generator) or "nogenerator")
        .. ":" .. tostring(getCurrentTimestamp())
        .. ":" .. tostring(getRandomSuffix())
end

---@param value number|string|nil
---@return number
local function clamp01(value)
    local numericValue = tonumber(value) or 0
    if numericValue < 0 then return 0 end
    if numericValue > 1 then return 1 end
    return numericValue
end

---@param barrel IsoObject|nil
---@return BarrEx_BarrelEndpointPayload|nil
local function buildBarrelEndpointPayload(barrel)
    if not barrel then return nil end

    local square = barrel:getSquare()
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

---@param generator IsoGenerator|nil
---@return BarrEx_GeneratorEndpointPayload|nil
local function buildGeneratorEndpointPayload(generator)
    local square = generator and generator:getSquare()
    if not square then return nil end

    return {
        kind = "generator",
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = GeneratorUtils.getObjectIndex(generator),
    }
end

---@param action BarrEx_BarrelToGeneratorTransferAction|nil
local function stopSound(action)
    if not action then return end

    local sound = action.sound
    local character = action.character
    if sound and character and character:getEmitter():isPlaying(sound) then
        character:stopOrTriggerSound(sound)
    end
end

---@param item InventoryItem|nil
---@return any
local function getStaticHandModel(item)
    if item and type(item.getStaticModel) == "function" then
        return item:getStaticModel()
    end

    return item
end

---@param action BarrEx_BarrelToGeneratorTransferAction|nil
---@param command string|nil
---@param extraArgs table|nil
---@return boolean
local function sendEndpointCommand(action, command, extraArgs)
    if not action or not command then return false end

    local sourcePayload = buildBarrelEndpointPayload(action.sourceBarrel)
    local targetPayload = buildGeneratorEndpointPayload(action.generator)
    if not sourcePayload or not targetPayload then
        return false
    end

    local payload = action:buildBarrelPayload({
        transferId = action.transferId,
        mode = action.mode,
        source = sourcePayload,
        target = targetPayload,
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

---@return boolean
function BarrEx_BarrelToGeneratorTransferAction:isValid()
    if not self.sourceBarrel or not GeneratorUtils.isAvailable(self.generator) then
        return false
    end
    if not PlayerUtils.isPlayerInRange(self.character, self.sourceBarrel) then
        return false
    end
    if not PlayerUtils.isPlayerInRange(self.character, self.generator) then
        return false
    end
    if not PlayerUtils.isObjectInRange(self.sourceBarrel, self.generator) then
        return false
    end

    local sourceData = BarrEx_BarrelData.get(self.sourceBarrel)
    if not sourceData then return false end

    return TransferRules.canFuelGeneratorFromBarrel(sourceData, self.generator)
end

---@return nil
function BarrEx_BarrelToGeneratorTransferAction:start()
    ISBaseTimedAction.start(self)

    self.toolItem = PlayerUtils.findFirstRequiredItem(self.character, Constant.EXTRACT_REQUIRED_ITEMS)
    self.transferStarted = sendEndpointCommand(self, Constant.NETWORK.START_ENDPOINT_TRANSFER, { progress = 0 })
    if self.transferStarted then
        TransferSync.registerAction(self.transferId, self.mode, self, self.sourceBarrel, nil)
        self.lastSentAnimationProgress = 0
        self.progressTicksSinceSync = 0
        sendEndpointCommand(self, Constant.NETWORK.UPDATE_TRANSFER_PROGRESS, { progress = 0 })
    end

    self:setActionAnim("refuelgascan")
    self:setOverrideHandModels(getStaticHandModel(self.toolItem), nil)
    self.sound = self.character:playSound("GeneratorAddFuel")
end

---@return nil
function BarrEx_BarrelToGeneratorTransferAction:update()
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
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

---@return nil
function BarrEx_BarrelToGeneratorTransferAction:stop()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    if self.transferStarted then
        sendEndpointCommand(self, Constant.NETWORK.STOP_ENDPOINT_TRANSFER, { progress = clamp01(self:getJobDelta()) })
        self.transferStarted = false
    end
    ISBaseTimedAction.stop(self)
end

---@return nil
function BarrEx_BarrelToGeneratorTransferAction:perform()
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
---@param generator IsoGenerator
---@return BarrEx_BarrelToGeneratorTransferAction
function BarrEx_BarrelToGeneratorTransferAction:new(player, sourceBarrel, generator)
    local sourceData = BarrEx_BarrelData.get(sourceBarrel)
    ---@cast sourceData BarrEx_Barrel
    local liquidType = sourceData and sourceData.liquidType or nil
    local totalAmount = TransferRules.getBarrelToGeneratorAmount(sourceData, generator)
    local maxTime = TransferRules.getTransferActionTime(totalAmount, MODE, liquidType)
    local o = BarrEx_BarrelActionBase.new(self, player, sourceBarrel, MODE, nil, maxTime)
    ---@cast o BarrEx_BarrelToGeneratorTransferAction

    o.sourceBarrel = sourceBarrel
    o.generator = generator
    o.mode = MODE
    o.transferId = buildTransferId(player, sourceBarrel, generator)
    o.actionId = o.transferId
    o.totalAmount = totalAmount
    o.liquidType = liquidType
    o.transferStarted = false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = math.max(tonumber(maxTime) or 1, 1)

    return o
end

return BarrEx_BarrelToGeneratorTransferAction
