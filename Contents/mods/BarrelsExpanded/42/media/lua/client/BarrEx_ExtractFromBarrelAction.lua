local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

---@class BarrEx_ExtractFromBarrelAction : ISBaseTimedAction
---@field barrel IsoObject
---@field targetItem InventoryItem
---@field toolItem InventoryItem|nil
---@field sound integer|nil
---@field totalAmount number
---@field sentAmount number
local BarrEx_ExtractFromBarrelAction = ISBaseTimedAction:derive("BarrEx_ExtractFromBarrelAction")

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end

local function getEstimatedExtractAmount(barrel, targetItem)
    if not barrel or not targetItem then return 0 end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then return 0 end

    return math.max(math.min(barrelData.amount or 0, LiquidAdapter.getFreeCapacity(targetItem)), 0)
end

local function sendTransferCommand(action, command)
    if not action or not command then return false end

    local inventory = action.character:getInventory()
    local item = Utils.findInventoryItem(
        inventory,
        action.targetItem and action.targetItem:getID() or nil,
        action.targetItem and action.targetItem:getFullType() or nil
    )
    if not item then
        return false
    end

    local square = action.barrel and action.barrel:getSquare()
    if not square then
        return false
    end

    sendClientCommand(Constant.NETWORK.MODULE, command, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = action.barrel:getObjectIndex(),
        itemId = item:getID(),
        itemFullType = item:getFullType(),
    })

    return true
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
    o.totalAmount = getEstimatedExtractAmount(barrel, targetItem)
    o.transferStarted = false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = Utils.getVanillaFluidActionTime(o.totalAmount)

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
    self.transferStarted = sendTransferCommand(self, Constant.NETWORK.START_EXTRACT_FROM_BARREL)
    local primaryHandItem, secondaryHandItem = Utils.getFluidActionHandItems(self.targetItem, self.toolItem)

    self:setActionAnim("MixFluids")
    self:setOverrideHandModels(primaryHandItem, secondaryHandItem)
    self.sound = self.character:playSound("TransferLiquid")
end

function BarrEx_ExtractFromBarrelAction:update()
    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.barrel)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BarrEx_ExtractFromBarrelAction:stop()
    stopSound(self)
    if self.transferStarted then
        sendTransferCommand(self, Constant.NETWORK.STOP_EXTRACT_FROM_BARREL)
        self.transferStarted = false
    end
    ISBaseTimedAction.stop(self)
end

function BarrEx_ExtractFromBarrelAction:perform()
    stopSound(self)
    if self.transferStarted then
        sendTransferCommand(self, Constant.NETWORK.COMPLETE_EXTRACT_FROM_BARREL)
        self.transferStarted = false
    end
    ISBaseTimedAction.perform(self)
end

return BarrEx_ExtractFromBarrelAction
