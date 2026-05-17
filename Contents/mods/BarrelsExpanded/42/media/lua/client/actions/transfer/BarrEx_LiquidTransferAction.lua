local InventoryUtils = require("utils/BarrEx_InventoryUtils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local TransferRules = require("core/BarrEx_TransferRules")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local TransferSync = require("BarrEx_TransferSync")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")
local BarrelStateClient = require("BarrEx_BarrelStateClient")

---@class BarrEx_LiquidTransferAction : BarrEx_BarrelActionBase
---@field barrel IsoObject
---@field liquidItem InventoryItem The source (pour) or target (extract) item
---@field toolItem InventoryItem|nil
---@field sound integer|nil
---@field totalAmount number
---@field initialLiquidAmount number
---@field transferStarted boolean
---@field transferId string
---@field liquidItemId string|number|nil
---@field liquidItemFullType string|nil
---@field mode string "pour" or "extract"
local BarrEx_LiquidTransferAction = BarrEx_BarrelActionBase:derive("BarrEx_LiquidTransferAction")

local PROGRESS_EPSILON = 0.0001

-- ---------------------------------------------------------------------------
-- Private helpers (shared by subclasses)
-- ---------------------------------------------------------------------------

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

local function buildTransferId(player, barrel, item, mode)
    local modData = barrel and barrel:getModData() or nil
    local barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or "nobarrel"
    local itemId = item and item:getID() or "noitem"
    local playerId = player and type(player.getOnlineID) == "function" and player:getOnlineID() or "local"

    return tostring(mode)
        .. ":" .. tostring(playerId)
        .. ":" .. tostring(barrelId)
        .. ":" .. tostring(itemId)
        .. ":" .. tostring(getCurrentTimestamp())
        .. ":" .. tostring(getRandomSuffix())
end

local function clamp01(value)
    local numericValue = tonumber(value) or 0
    if numericValue < 0 then return 0 end
    if numericValue > 1 then return 1 end
    return numericValue
end

local function isStartTransferCommand(command)
    return command == Constant.NETWORK.START_POUR_INTO_BARREL
        or command == Constant.NETWORK.START_EXTRACT_FROM_BARREL
end

local function sendTransferCommand(action, command, extraArgs)
    if not action or not command then return false end

    local itemId = action.liquidItemId
        or (action.liquidItem and action.liquidItem.getID and action.liquidItem:getID())
    local itemFullType = action.liquidItemFullType
        or (action.liquidItem and action.liquidItem.getFullType and action.liquidItem:getFullType())

    local inventory = action.character and action.character:getInventory() or nil
    local item = inventory and InventoryUtils.findInventoryItemStrict(inventory, itemId) or nil
    if item then
        itemId = item:getID()
        itemFullType = item:getFullType()
    elseif isStartTransferCommand(command) then
        return false
    end

    local payload = action:buildBarrelPayload({
        transferId = action.transferId,
        mode = action.mode,
        itemId = itemId,
        itemFullType = itemFullType,
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

    if isStartTransferCommand(command) then
        BarrelStateClient.trackAction(payload)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Protected API (for subclasses to override)
-- ---------------------------------------------------------------------------

--- Returns the estimated transfer amount. Subclasses must override.
---@param barrel IsoObject
---@param liquidItem InventoryItem
---@return number
function BarrEx_LiquidTransferAction:getEstimatedTransferAmount(barrel, liquidItem)
    return 0
end

--- Returns the initial amount of the liquid item (before transfer).
---@param liquidItem InventoryItem
---@return number
function BarrEx_LiquidTransferAction:getInitialLiquidAmount(liquidItem)
    return math.max(tonumber(LiquidAdapter.getAmount(liquidItem)) or 0, 0)
end

--- Returns the start command for the network message.
--- Subclasses must override.
---@return string
function BarrEx_LiquidTransferAction:getStartCommand()
    return ""
end

--- Returns the stop command for the network message.
--- Subclasses must override.
---@return string
function BarrEx_LiquidTransferAction:getStopCommand()
    return ""
end

--- Returns the complete command for the network message.
--- Subclasses must override.
---@return string
function BarrEx_LiquidTransferAction:getCompleteCommand()
    return ""
end

--- Returns the transfer mode ("pour" or "extract").
--- Subclasses must override.
---@return string
function BarrEx_LiquidTransferAction:getMode()
    return "unknown"
end

--- Syncs progress based on the change in liquid amount.
--- Subclasses can override to customize behavior.
function BarrEx_LiquidTransferAction:syncProgress()
    if not self.liquidItem then return end
    if (tonumber(self.totalAmount) or 0) <= 0 then return end

    local currentAmount = math.max(tonumber(LiquidAdapter.getAmount(self.liquidItem)) or 0, 0)

    -- For pour: movedAmount = initialAmount - currentAmount (liquid left container)
    -- For extract: movedAmount = currentAmount - initialAmount (liquid entered container)
    local movedAmount
    if self.mode == "pour" then
        movedAmount = math.max((tonumber(self.initialLiquidAmount) or 0) - currentAmount, 0)
    else
        movedAmount = math.max(currentAmount - (tonumber(self.initialLiquidAmount) or 0), 0)
    end

    local progress = math.max(math.min(movedAmount / self.totalAmount, 1), 0)

    if not self.serverProgress or progress > self.serverProgress then
        self.serverProgress = progress
    end

    if progress >= (1 - PROGRESS_EPSILON) then
        self.serverCompleted = true
        self.transferStarted = false
    end
end

--- Returns the animation name for this action.
---@return string
function BarrEx_LiquidTransferAction:getAnimName()
    return "fill_container_tap"
end

--- Returns the pour type (if any) for setting on the liquid item.
---@return string|nil
function BarrEx_LiquidTransferAction:getPourType()
    return nil
end

--- Returns the liquid type being moved by this action.
---@return string|nil
function BarrEx_LiquidTransferAction:getTransferLiquidType()
    if self.mode == "pour" then
        return LiquidAdapter.getLiquidType(self.liquidItem)
    end

    local barrelData = self.barrel and BarrEx_BarrelData.get(self.barrel) or nil
    return barrelData and barrelData.liquidType or nil
end

--- Returns the timed-action duration for this transfer.
---@return number
function BarrEx_LiquidTransferAction:getTransferActionTime()
    return TransferRules.getTransferActionTime(self.totalAmount, self.mode, self:getTransferLiquidType())
end

--- Returns the sound played by this transfer action.
---@return string
function BarrEx_LiquidTransferAction:getTransferSound()
    return getTransferSound(self:getTransferLiquidType())
end

--- Returns the tool requirement list for this transfer mode.
---@return table<string>
function BarrEx_LiquidTransferAction:getRequiredItems()
    if self.mode == "pour" then
        return Constant.POUR_REQUIRED_ITEMS
    end
    if self.mode == "extract" then
        return Constant.EXTRACT_REQUIRED_ITEMS
    end
    return {}
end

--- Sets up job-tracking fields on the liquid item (pour-specific).
--- Base implementation does nothing; subclasses can override.
function BarrEx_LiquidTransferAction:setupJobTracking()
end

--- Clears job-tracking fields on the liquid item (pour-specific).
--- Base implementation does nothing; subclasses can override.
function BarrEx_LiquidTransferAction:clearJobTracking()
end

-- ---------------------------------------------------------------------------
-- Public API (inherited by subclasses)
-- ---------------------------------------------------------------------------

---@param player IsoPlayer
---@param barrel IsoObject
---@param liquidItem InventoryItem
---@return BarrEx_LiquidTransferAction
function BarrEx_LiquidTransferAction:new(player, barrel, liquidItem)
    local mode = self.getMode and self:getMode() or "unknown"
    local o = BarrEx_BarrelActionBase.new(self, player, barrel, mode, nil, 1)
    ---@cast o BarrEx_LiquidTransferAction

    o.liquidItem = liquidItem
    o.mode = mode
    o.transferId = buildTransferId(player, barrel, liquidItem, o.mode)
    o.actionId = o.transferId
    o.liquidItemId = liquidItem and liquidItem:getID() or nil
    o.liquidItemFullType = liquidItem and liquidItem:getFullType() or nil
    o.totalAmount = o:getEstimatedTransferAmount(barrel, liquidItem)
    o.initialLiquidAmount = o:getInitialLiquidAmount(liquidItem)
    o.transferStarted = false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = math.max(o:getTransferActionTime(), 1)

    return o
end

function BarrEx_LiquidTransferAction:isValid()
    if not self.barrel or not self.liquidItem then return false end
    if not BarrEx_BarrelData.isRevealedRaw(self.barrel) then return false end
    if not PlayerUtils.isPlayerInRange(self.character, self.barrel) then return false end

    local inventory = self.character:getInventory()
    if not inventory then return false end

    if type(inventory.containsID) == "function" then
        return inventory:containsID(self.liquidItem:getID())
    end

    return inventory:contains(self.liquidItem)
end

function BarrEx_LiquidTransferAction:start()
    ISBaseTimedAction.start(self)

    self.toolItem = PlayerUtils.findFirstRequiredItem(self.character, self:getRequiredItems())
    self.transferStarted = sendTransferCommand(self, self:getStartCommand())
    if self.transferStarted then
        TransferSync.registerAction(self.transferId, self.mode, self, self.barrel, self.liquidItem)
        self.lastSentAnimationProgress = 0
        self.progressTicksSinceSync = 0
        sendTransferCommand(self, Constant.NETWORK.UPDATE_TRANSFER_PROGRESS, { progress = 0 })
    end

    self:setupJobTracking()

    local primaryHandItem, secondaryHandItem = self:getFluidActionHandItems(self.liquidItem, self.toolItem)
    self:setActionAnim(self:getAnimName())
    self:setOverrideHandModels(primaryHandItem, secondaryHandItem)
    self.sound = self.character:playSound(self:getTransferSound())
end

function BarrEx_LiquidTransferAction:update()
    self:syncProgress()
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
            if sendTransferCommand(self, Constant.NETWORK.UPDATE_TRANSFER_PROGRESS, { progress = progress }) then
                self.lastSentAnimationProgress = progress
                self.progressTicksSinceSync = 0
            end
        end
    end
    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.barrel)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BarrEx_LiquidTransferAction:stop()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    self:clearJobTracking()
    if self.transferStarted then
        sendTransferCommand(self, self:getStopCommand(), { progress = clamp01(self:getJobDelta()) })
        self.transferStarted = false
    end
    ISBaseTimedAction.stop(self)
end

function BarrEx_LiquidTransferAction:perform()
    stopSound(self)
    TransferSync.unregisterAction(self.transferId, self)
    self:clearJobTracking()
    local container = self.liquidItem and self.liquidItem:getContainer() or nil
    if container then
        container:setDrawDirty(true)
    end
    if self.transferStarted then
        sendTransferCommand(self, self:getCompleteCommand(), { progress = 1 })
        self.transferStarted = false
    end
    ISBaseTimedAction.perform(self)
end

--- Helper for subclasses to resolve hand model items.
---@param liquidItem InventoryItem|nil
---@param toolItem InventoryItem|nil
---@return InventoryItem|nil primaryHand
---@return InventoryItem|nil secondaryHand
function BarrEx_LiquidTransferAction:getFluidActionHandItems(liquidItem, toolItem)
    if not liquidItem then
        return toolItem, nil
    end

    local hasEatType = type(liquidItem.getEatType) == "function" and liquidItem:getEatType() ~= nil
    if hasEatType then
        return toolItem, liquidItem
    end

    return liquidItem, toolItem
end

return BarrEx_LiquidTransferAction
