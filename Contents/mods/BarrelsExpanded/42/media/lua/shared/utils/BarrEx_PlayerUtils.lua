local Constant = require("BarrEx_Constant")

local PlayerUtils = {}

local function getObjectSquare(object)
    if not object then return nil end
    if type(object.getSquare) == "function" then
        local square = object:getSquare()
        if square then return square end
    end
    if type(object.getCurrentSquare) == "function" then
        return object:getCurrentSquare()
    end
    return nil
end

---@param first any
---@param second any
---@return number
function PlayerUtils.getObjectDistance(first, second)
    local firstSquare = getObjectSquare(first)
    local secondSquare = getObjectSquare(second)
    if not firstSquare or not secondSquare then return math.huge end
    if firstSquare:getZ() ~= secondSquare:getZ() then return math.huge end

    local dx = math.abs(firstSquare:getX() - secondSquare:getX())
    local dy = math.abs(firstSquare:getY() - secondSquare:getY())
    return math.max(dx, dy)
end

---@param first any
---@param second any
---@param maxDistance number|nil
---@return boolean
function PlayerUtils.isObjectInRange(first, second, maxDistance)
    return PlayerUtils.getObjectDistance(first, second) <= (tonumber(maxDistance) or Constant.MAX_INTERACTION_DISTANCE)
end

---@param player IsoPlayer|nil
---@param barrel IsoObject|nil
---@return boolean
function PlayerUtils.isPlayerInRange(player, barrel)
    return PlayerUtils.isObjectInRange(player, barrel, Constant.MAX_INTERACTION_DISTANCE)
end

---@param player IsoPlayer|nil
---@param requiredItems table<string>|nil
---@return InventoryItem|nil
function PlayerUtils.findFirstRequiredItem(player, requiredItems)
    if not player or not requiredItems then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    for i = 1, #requiredItems do
        local itemType = requiredItems[i]
        local item = inventory:getFirstTypeRecurse(itemType)
        if item then
            return item
        end
    end

    return nil
end

---@param player IsoPlayer|nil
---@param requiredItems table<string>|nil
---@return boolean hasAnyRequiredItem
---@return table<string> foundItems
---@return table<string> missingItems
function PlayerUtils.getRequiredItemStatus(player, requiredItems)
    if not player or not requiredItems then
        return false, {}, {}
    end

    local foundItems = {}
    local missingItems = {}
    if #requiredItems == 0 then
        return true, foundItems, missingItems
    end

    local foundCount = 0
    local inventory = player:getInventory()
    if not inventory then
        return false, foundItems, missingItems
    end

    for i = 1, #requiredItems do
        local itemType = requiredItems[i]
        if inventory:getFirstTypeRecurse(itemType) then
            foundCount = foundCount + 1
            foundItems[#foundItems + 1] = itemType
        else
            missingItems[#missingItems + 1] = itemType
        end
    end

    return foundCount > 0, foundItems, missingItems
end

---@param player IsoPlayer|nil
---@param requiredItems table<string>|nil
---@return boolean hasAnyRequiredItem
---@return table<string> foundItems
---@return table<string> missingItems
function PlayerUtils.isPlayerHoldingAnyRequiredItem(player, requiredItems)
    return PlayerUtils.getRequiredItemStatus(player, requiredItems)
end

---@param player IsoPlayer|nil
---@param requiredItems table<string>|nil
---@return boolean
---@return table<string> missingItems
function PlayerUtils.isPlayerHoldingAllRequiredItems(player, requiredItems)
    local _, _, missingItems = PlayerUtils.getRequiredItemStatus(player, requiredItems)
    return #missingItems == 0, missingItems
end

return PlayerUtils
