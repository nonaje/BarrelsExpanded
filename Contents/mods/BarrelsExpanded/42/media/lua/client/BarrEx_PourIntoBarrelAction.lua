local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

---@class BarrEx_PourIntoBarrelAction : ISBaseTimedAction
---@field barrel IsoObject
---@field sourceItem InventoryItem
---@field toolItem InventoryItem|nil
---@field sound integer|nil
local BarrEx_PourIntoBarrelAction = ISBaseTimedAction:derive("BarrEx_PourIntoBarrelAction")

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param sourceItem InventoryItem
---@return BarrEx_PourIntoBarrelAction
function BarrEx_PourIntoBarrelAction:new(player, barrel, sourceItem)
    local o = ISBaseTimedAction.new(self, player)
    ---@cast o BarrEx_PourIntoBarrelAction

    o.barrel = barrel
    o.sourceItem = sourceItem
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = Constant.POUR_BARREL_ACTION_TIME

    setmetatable(o, self)
    self.__index = self

    return o
end

function BarrEx_PourIntoBarrelAction:isValid()
    if not self.barrel or not self.sourceItem then return false end
    if not BarrEx_BarrelData.isRevealedRaw(self.barrel) then return false end
    if not Utils.isPlayerInRange(self.character, self.barrel) then return false end

    local inventory = self.character:getInventory()
    if not inventory then return false end

    if type(inventory.containsID) == "function" then
        return inventory:containsID(self.sourceItem:getID())
    end

    return inventory:contains(self.sourceItem)
end

function BarrEx_PourIntoBarrelAction:start()
    ISBaseTimedAction.start(self)

    self.toolItem = Utils.findFirstRequiredItem(self.character, Constant.POUR_REQUIRED_ITEMS)
    local primaryHandItem, secondaryHandItem = Utils.getFluidActionHandItems(self.sourceItem, self.toolItem)

    if type(self.sourceItem.getPourType) == "function" then
        self:setAnimVariable("PourType", self.sourceItem:getPourType())
    end

    self:setActionAnim("fill_container_tap")
    self:setOverrideHandModels(primaryHandItem, secondaryHandItem)
    self.sound = self.character:playSound("PourWaterIntoObject")
end

function BarrEx_PourIntoBarrelAction:update()
    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.barrel)
end

function BarrEx_PourIntoBarrelAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function BarrEx_PourIntoBarrelAction:perform()
    stopSound(self)

    local inventory = self.character:getInventory()
    if not Utils.findInventoryItem(inventory, self.sourceItem and self.sourceItem:getID() or nil, self.sourceItem and self.sourceItem:getFullType() or nil) then
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
        suggestedAmount = math.min(LiquidAdapter.getAmount(self.sourceItem), barrelData:getFreeCapacity())
    end

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.POUR_INTO_BARREL, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = self.barrel:getObjectIndex(),
        itemId = self.sourceItem:getID(),
        itemFullType = self.sourceItem:getFullType(),
        suggestedAmount = suggestedAmount,
    })

    ISBaseTimedAction.perform(self)
end

return BarrEx_PourIntoBarrelAction
