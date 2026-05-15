local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_OpenBarrelAction = require("BarrEx_OpenBarrelAction")
local BarrEx_PourIntoBarrelAction = require("BarrEx_PourIntoBarrelAction")
local BarrEx_ExtractFromBarrelAction = require("BarrEx_ExtractFromBarrelAction")

local Actions = {}

---@param message string
local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
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
    for _, itemType in ipairs(Constant.OPEN_BARREL_REQUIRED_ITEMS) do
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

    ISTimedActionQueue.add(BarrEx_PourIntoBarrelAction:new(player, barrel, sourceItem))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param targetItem InventoryItem
function Actions.onExtractFromBarrel(barrel, player, targetItem)
    if not barrel or not player or not targetItem then return end

    ISTimedActionQueue.add(BarrEx_ExtractFromBarrelAction:new(player, barrel, targetItem))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param targetItems table<integer, InventoryItem>
function Actions.onExtractAllFromBarrel(barrel, player, targetItems)
    if not barrel or not player or not targetItems then return end

    for _, item in ipairs(targetItems) do
        if item then
            ISTimedActionQueue.add(BarrEx_ExtractFromBarrelAction:new(player, barrel, item))
        end
    end
end

return Actions
