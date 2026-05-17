local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")

---@class BarrEx_BarrelUseAction : BarrEx_BarrelActionBase
---@field barrel IsoObject
---@field command string
---@field payload table
---@field sound integer|nil
local BarrEx_BarrelUseAction = BarrEx_BarrelActionBase:derive("BarrEx_BarrelUseAction")

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
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
        and self:isBarrelInRange()
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

    local extraArgs = {}
    self:decoratePayload(extraArgs)
    self:sendBarrelCommand(self.command, extraArgs)

    ISBaseTimedAction.perform(self)
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param command string
---@param maxTime number
---@return BarrEx_BarrelUseAction
function BarrEx_BarrelUseAction:new(player, barrel, command, maxTime)
    local actionName = command
    if command == Constant.NETWORK.DRINK_FROM_BARREL then
        actionName = "drink"
    elseif command == Constant.NETWORK.WASH_FROM_BARREL then
        actionName = "wash"
    elseif command == Constant.NETWORK.EMPTY_BARREL then
        actionName = "empty"
    end

    ---@type BarrEx_BarrelActionBase
    local baseSelf = self
    local o = BarrEx_BarrelActionBase.new(baseSelf, player, barrel, actionName, command, maxTime)
    ---@cast o BarrEx_BarrelUseAction

    return o
end

return BarrEx_BarrelUseAction
