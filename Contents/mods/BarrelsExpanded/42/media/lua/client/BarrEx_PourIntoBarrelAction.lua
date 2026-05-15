local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

---@class BarrEx_PourIntoBarrelAction : ISBaseTimedAction
---@field barrel IsoObject
---@field sourceItem InventoryItem
---@field toolItem InventoryItem|nil
---@field sound integer|nil
---@field totalAmount number
---@field sentAmount number
local BarrEx_PourIntoBarrelAction = ISBaseTimedAction:derive("BarrEx_PourIntoBarrelAction")

local function stopSound(action)
    if action.sound and action.character and action.character:getEmitter():isPlaying(action.sound) then
        action.character:stopOrTriggerSound(action.sound)
    end
end


local function getTransferSound(liquidType)
    if liquidType == Constant.LIQUID_TYPE.WATER or liquidType == Constant.LIQUID_TYPE.TAINTED_WATER then
        return "PourWaterIntoObject"
    end

    return "TransferLiquid"
end

local function getEstimatedPourAmount(barrel, sourceItem)
    if not barrel or not sourceItem then return 0 end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then return 0 end

    return math.max(math.min(LiquidAdapter.getAmount(sourceItem), barrelData:getFreeCapacity()), 0)
end

local function sendTransferCommand(action, command)
    if not action or not command then return false end

    local inventory = action.character:getInventory()
    local item = Utils.findInventoryItem(
        inventory,
        action.sourceItem and action.sourceItem:getID() or nil,
        action.sourceItem and action.sourceItem:getFullType() or nil
    )
    if not item then
        return false
    end

    local square = action.barrel and action.barrel:getSquare()
    if not square then
        return false
    end

    local modData = action.barrel:getModData()

    sendClientCommand(Constant.NETWORK.MODULE, command, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = action.barrel:getObjectIndex(),
        barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or BarrEx_BarrelData.buildId(action.barrel),
        spriteName = Utils.getSpriteName(action.barrel),
        itemId = item:getID(),
        itemFullType = item:getFullType(),
    })

    return true
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
    o.totalAmount = getEstimatedPourAmount(barrel, sourceItem)
    o.transferStarted = false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = Utils.getVanillaFluidActionTime(o.totalAmount)

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
    self.transferStarted = sendTransferCommand(self, Constant.NETWORK.START_POUR_INTO_BARREL)
    if self.sourceItem and type(self.sourceItem.setJobType) == "function" then
        self.sourceItem:setJobType(getText("IGUI_JobType_PourOut"))
    end
    if self.sourceItem and type(self.sourceItem.setJobDelta) == "function" then
        self.sourceItem:setJobDelta(0.0)
    end
    local primaryHandItem, secondaryHandItem = Utils.getFluidActionHandItems(self.sourceItem, self.toolItem)

    if type(self.sourceItem.getPourType) == "function" then
        self:setAnimVariable("PourType", self.sourceItem:getPourType())
    end

    self:setActionAnim("fill_container_tap")
    self:setOverrideHandModels(primaryHandItem, secondaryHandItem)
    self.sound = self.character:playSound(getTransferSound(LiquidAdapter.getLiquidType(self.sourceItem)))
end

function BarrEx_PourIntoBarrelAction:update()
    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.barrel)
    if self.sourceItem and type(self.sourceItem.setJobDelta) == "function" then
        self.sourceItem:setJobDelta(self:getJobDelta())
    end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BarrEx_PourIntoBarrelAction:stop()
    stopSound(self)
    if self.sourceItem and type(self.sourceItem.setJobDelta) == "function" then
        self.sourceItem:setJobDelta(0.0)
    end
    if self.transferStarted then
        sendTransferCommand(self, Constant.NETWORK.STOP_POUR_INTO_BARREL)
        self.transferStarted = false
    end
    ISBaseTimedAction.stop(self)
end

function BarrEx_PourIntoBarrelAction:perform()
    stopSound(self)
    if self.sourceItem and type(self.sourceItem.setJobDelta) == "function" then
        self.sourceItem:setJobDelta(0.0)
    end
    local container = self.sourceItem and self.sourceItem:getContainer() or nil
    if container then
        container:setDrawDirty(true)
    end
    if self.transferStarted then
        sendTransferCommand(self, Constant.NETWORK.COMPLETE_POUR_INTO_BARREL)
        self.transferStarted = false
    end
    ISBaseTimedAction.perform(self)
end

return BarrEx_PourIntoBarrelAction
