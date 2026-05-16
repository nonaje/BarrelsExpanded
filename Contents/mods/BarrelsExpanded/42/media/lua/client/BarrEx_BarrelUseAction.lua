local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local WorldUtils = require("utils/BarrEx_WorldUtils")

---@class BarrEx_BarrelUseAction : ISBaseTimedAction
---@field barrel IsoObject
---@field command string
---@field payload table
---@field sound integer|nil
local BarrEx_BarrelUseAction = ISBaseTimedAction:derive("BarrEx_BarrelUseAction")

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end

---@param barrel IsoObject|nil
---@return table|nil
local function buildBarrelPayload(barrel)
    local square = barrel and barrel:getSquare()
    if not square then return nil end

    local modData = barrel:getModData()
    return {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = barrel:getObjectIndex(),
        barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or BarrEx_BarrelData.buildId(barrel),
        spriteName = WorldUtils.getSpriteName(barrel),
    }
end

function BarrEx_BarrelUseAction:getAnimName()
    return "fill_container_tap"
end

function BarrEx_BarrelUseAction:getSoundName()
    return nil
end

function BarrEx_BarrelUseAction:decoratePayload(payload)
end

function BarrEx_BarrelUseAction:isValid()
    return self.barrel ~= nil
        and self.command ~= nil
        and BarrEx_BarrelData.isRevealedRaw(self.barrel)
        and PlayerUtils.isPlayerInRange(self.character, self.barrel)
end

function BarrEx_BarrelUseAction:waitToStart()
    if self.barrel then
        self.character:faceThisObject(self.barrel)
    end
    return self.character:shouldBeTurning()
end

function BarrEx_BarrelUseAction:start()
    ISBaseTimedAction.start(self)
    self:setActionAnim(self:getAnimName())
    self:setOverrideHandModels(nil, nil)
    self.character:reportEvent("EventTakeWater")

    local soundName = self:getSoundName()
    if soundName then
        self.sound = self.character:playSound(soundName)
    end
end

function BarrEx_BarrelUseAction:update()
    if self.barrel then
        self.character:faceThisObject(self.barrel)
    end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    ISBaseTimedAction.update(self)
end

function BarrEx_BarrelUseAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function BarrEx_BarrelUseAction:perform()
    stopSound(self)

    local payload = buildBarrelPayload(self.barrel)
    if payload then
        self:decoratePayload(payload)
        sendClientCommand(Constant.NETWORK.MODULE, self.command, payload)
    end

    ISBaseTimedAction.perform(self)
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param command string
---@param maxTime number
---@return BarrEx_BarrelUseAction
function BarrEx_BarrelUseAction:new(player, barrel, command, maxTime)
    local o = ISBaseTimedAction.new(self, player)
    ---@cast o BarrEx_BarrelUseAction

    o.barrel = barrel
    o.command = command
    o.maxTime = math.max(tonumber(maxTime) or 1, 1)
    o.stopOnWalk = true
    o.stopOnRun = true

    setmetatable(o, self)
    self.__index = self

    return o
end

return BarrEx_BarrelUseAction
