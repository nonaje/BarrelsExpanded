local Constant = require("BarrEx_Constant")

local PlayerUtils = {}

---@param player IsoPlayer|nil
---@param barrel IsoObject|nil
---@return boolean
function PlayerUtils.isPlayerInRange(player, barrel)
    if not player or not barrel then return false end

    local square = barrel:getSquare()
    if not square then return false end

    local dx = math.abs(player:getX() - square:getX())
    local dy = math.abs(player:getY() - square:getY())

    return math.max(dx, dy) <= Constant.MAX_INTERACTION_DISTANCE
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
