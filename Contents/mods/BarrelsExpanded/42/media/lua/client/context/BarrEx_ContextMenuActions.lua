require "TimedActions/ISInventoryTransferAction"
require "ISUI/ISInventoryPaneContextMenu"

local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_OpenBarrelAction = require("BarrEx_OpenBarrelAction")
local BarrEx_PourIntoBarrelAction = require("BarrEx_PourIntoBarrelAction")
local BarrEx_ExtractFromBarrelAction = require("BarrEx_ExtractFromBarrelAction")
local BarrEx_DrinkFromBarrelAction = require("BarrEx_DrinkFromBarrelAction")
local BarrEx_WashFromBarrelAction = require("BarrEx_WashFromBarrelAction")
local BarrEx_EmptyBarrelAction = require("BarrEx_EmptyBarrelAction")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local Logger = require("utils/BarrEx_Logger")

local Actions = {}

---@param message string
local function log(message)
    Logger.info(message)
end

local function queueMoveToPlayerInventory(player, item)
    if not player or not item then return end

    local sourceContainer = item:getContainer()
    local playerInventory = player:getInventory()
    if sourceContainer and playerInventory and sourceContainer ~= playerInventory then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, sourceContainer, playerInventory))
    end
end

local function queueWalkToBarrel(player, barrel)
    if not player or not barrel then return false end
    if luautils and type(luautils.walkAdjObject) == "function" then
        return luautils.walkAdjObject(player, barrel, true, true)
    end
    return true
end

local function queueEquip(player, item, primary, twoHands)
    if not player or not item then return end

    queueMoveToPlayerInventory(player, item)
    ISInventoryPaneContextMenu.equipWeapon(item, primary == true, twoHands == true, player:getPlayerNum())
end

local function queuePourAction(barrel, player, sourceItem)
    queueWalkToBarrel(player, barrel)
    queueEquip(player, sourceItem, true, false)
    ISTimedActionQueue.add(BarrEx_PourIntoBarrelAction:new(player, barrel, sourceItem))
end

local function queueExtractAction(barrel, player, targetItem)
    local hose = PlayerUtils.findFirstRequiredItem(player, Constant.EXTRACT_REQUIRED_ITEMS)

    queueWalkToBarrel(player, barrel)
    queueEquip(player, targetItem, false, false)
    if hose then
        queueEquip(player, hose, true, false)
    end
    ISTimedActionQueue.add(BarrEx_ExtractFromBarrelAction:new(player, barrel, targetItem))
end

---@param barrel IsoObject
---@param player IsoPlayer
function Actions.onOpenBarrel(barrel, player)
    if not barrel or not player then return end
    if BarrEx_BarrelData.isRevealedRaw(barrel) then
        log("Open ignored; barrel already revealed.")
        return
    end

    local inventory = player:getInventory()
    if not inventory then return end

    local tool = nil
    for i = 1, #Constant.OPEN_BARREL_REQUIRED_ITEMS do
        local itemType = Constant.OPEN_BARREL_REQUIRED_ITEMS[i]
        tool = inventory:getFirstTypeRecurse(itemType)
        if tool then break end
    end

    if not tool then return end

    ISTimedActionQueue.add(BarrEx_OpenBarrelAction:new(player, barrel, tool))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param sourceItem InventoryItem
function Actions.onPourIntoBarrel(barrel, player, sourceItem)
    if not barrel or not player or not sourceItem then return end

    queuePourAction(barrel, player, sourceItem)
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param targetItem InventoryItem
function Actions.onExtractFromBarrel(barrel, player, targetItem)
    if not barrel or not player or not targetItem then return end

    queueExtractAction(barrel, player, targetItem)
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param targetItems table<integer, InventoryItem>
function Actions.onExtractAllFromBarrel(barrel, player, targetItems)
    if not barrel or not player or not targetItems then return end

    for i = 1, #targetItems do
        local item = targetItems[i]
        if item then
            queueExtractAction(barrel, player, item)
        end
    end
end

---@param barrel IsoObject
---@param player IsoPlayer
function Actions.onDrinkFromBarrel(barrel, player)
    if not barrel or not player then return end

    ISTimedActionQueue.add(BarrEx_DrinkFromBarrelAction:new(player, barrel))
end

---@param barrel IsoObject
---@param player IsoPlayer
function Actions.onWashSelfFromBarrel(barrel, player)
    if not barrel or not player then return end

    ISTimedActionQueue.add(BarrEx_WashFromBarrelAction:new(player, barrel, "self", nil))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param item InventoryItem
function Actions.onWashItemFromBarrel(barrel, player, item)
    if not barrel or not player or not item then return end

    ISTimedActionQueue.add(BarrEx_WashFromBarrelAction:new(player, barrel, "item", item))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param items table<integer, InventoryItem>
function Actions.onWashAllFromBarrel(barrel, player, items)
    if not barrel or not player or not items then return end

    for _, item in ipairs(items) do
        if item then
            ISTimedActionQueue.add(BarrEx_WashFromBarrelAction:new(player, barrel, "item", item))
        end
    end
end

---@param barrel IsoObject
---@param player IsoPlayer
function Actions.onEmptyBarrel(barrel, player)
    if not barrel or not player then return end

    ISTimedActionQueue.add(BarrEx_EmptyBarrelAction:new(player, barrel))
end

return Actions
