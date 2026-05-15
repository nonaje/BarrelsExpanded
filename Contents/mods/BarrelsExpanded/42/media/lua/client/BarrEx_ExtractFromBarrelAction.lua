local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

---@class BarrEx_ExtractFromBarrelAction : ISBaseTimedAction
---@field barrel IsoObject
---@field targetItem InventoryItem
---@field toolItem InventoryItem|nil
---@field sound integer|nil
local BarrEx_ExtractFromBarrelAction = ISBaseTimedAction:derive("BarrEx_ExtractFromBarrelAction")

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param targetItem InventoryItem
---@return BarrEx_ExtractFromBarrelAction
function BarrEx_ExtractFromBarrelAction:new(player, barrel, targetItem)
    local o = ISBaseTimedAction.new(self, player)
    ---@cast o BarrEx_ExtractFromBarrelAction

    o.barrel = barrel
    o.targetItem = targetItem
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = Constant.EXTRACT_BARREL_ACTION_TIME

    setmetatable(o, self)
    self.__index = self

    return o
end

function BarrEx_ExtractFromBarrelAction:isValid()
    if not self.barrel or not self.targetItem then return false end
    if not BarrEx_BarrelData.isRevealedRaw(self.barrel) then return false end
    if not Utils.isPlayerInRange(self.character, self.barrel) then return false end

    local inventory = self.character:getInventory()
    if not inventory then return false end

    if type(inventory.containsID) == "function" then
        return inventory:containsID(self.targetItem:getID())
    end

    return inventory:contains(self.targetItem)
end

function BarrEx_ExtractFromBarrelAction:start()
    ISBaseTimedAction.start(self)

    self.toolItem = Utils.findFirstRequiredItem(self.character, Constant.EXTRACT_REQUIRED_ITEMS)
    local primaryHandItem, secondaryHandItem = Utils.getFluidActionHandItems(self.targetItem, self.toolItem)

    self:setActionAnim("MixFluids")
    self:setOverrideHandModels(primaryHandItem, secondaryHandItem)
    self.sound = self.character:playSound("TransferLiquid")
end

function BarrEx_ExtractFromBarrelAction:update()
    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.barrel)
end

function BarrEx_ExtractFromBarrelAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function BarrEx_ExtractFromBarrelAction:perform()
    stopSound(self)

    local inventory = self.character:getInventory()
    if not Utils.findInventoryItem(inventory, self.targetItem and self.targetItem:getID() or nil, self.targetItem and self.targetItem:getFullType() or nil) then
        ISBaseTimedAction.perform(self)
        return
    end

    local square = self.barrel and self.barrel:getSquare()
    if not square then
        ISBaseTimedAction.perform(self)
        return
    end

    local barrelData = BarrEx_BarrelData.get(self.barrel)
    local suggestedAmount = 0
    if barrelData then
        suggestedAmount = math.min(barrelData.amount or 0, LiquidAdapter.getFreeCapacity(self.targetItem))
    end

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.EXTRACT_FROM_BARREL, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = self.barrel:getObjectIndex(),
        itemId = self.targetItem:getID(),
        itemFullType = self.targetItem:getFullType(),
        suggestedAmount = suggestedAmount,
    })

    ISBaseTimedAction.perform(self)
end

return BarrEx_ExtractFromBarrelAction
