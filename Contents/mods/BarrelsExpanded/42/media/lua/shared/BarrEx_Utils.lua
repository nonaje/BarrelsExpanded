local Constant = require("BarrEx_Constant")

local Utils = {}

local function call(target, methodName, ...)
    if not target then return nil end

    local method = target[methodName]
    if type(method) ~= "function" then
        return nil
    end

    return method(target, ...)
end

--- Returns the sprite name for an IsoObject, or nil when unavailable.
--- @param worldObject IsoObject|nil
--- @return string|nil
function Utils.getSpriteName(worldObject)
    if not worldObject then return nil end

    local sprite = worldObject:getSprite()
    if not sprite then return nil end

    local spriteName = sprite:getName()
    if not spriteName or spriteName == "" then return nil end

    return spriteName
end

--- Checks whether a world object is one of the supported barrel tiles.
--- @param worldObject IsoObject|nil
--- @return boolean
function Utils.isExpandableBarrel(worldObject)
    local spriteName = Utils.getSpriteName(worldObject)
    return spriteName ~= nil and Constant.BARREL_TILE_NAMES[spriteName] == true
end

--- Returns the barrel category based on sprite mapping.
--- @param worldObject IsoObject|nil
--- @return string|nil
function Utils.getBarrelCategory(worldObject)
    local spriteName = Utils.getSpriteName(worldObject)
    if not spriteName then return nil end

    local category = Constant.BARREL_TILE_NAME_TO_CATEGORY[spriteName]
    if category then return category end

    if Constant.BARREL_TILE_NAMES[spriteName] then
        return Constant.BARREL_TILE_CATEGORY.RURAL
    end

    return nil
end

--- Returns the first expandable barrel found in a square.
--- @param square IsoGridSquare|nil
--- @return IsoObject|nil
function Utils.findExpandableBarrelOnSquare(square)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if Utils.isExpandableBarrel(object) then
            return object
        end
    end

    return nil
end

--- Splits a list of item full types into found and missing items.
--- @param player IsoPlayer|nil
--- @param requiredItems table<string>|nil
--- @return boolean hasAnyRequiredItem
--- @return table<string> foundItems
--- @return table<string> missingItems
function Utils.getRequiredItemStatus(player, requiredItems)
    if not player or not requiredItems then
        return false, {}, {}
    end

    local foundItems = {}
    local missingItems = {}
    local foundCount = 0

    for _, itemType in ipairs(requiredItems) do
        if Utils.findFirstRequiredItem(player, { itemType }) then
            foundCount = foundCount + 1
            foundItems[#foundItems + 1] = itemType
        else
            missingItems[#missingItems + 1] = itemType
        end
    end

    return foundCount > 0, foundItems, missingItems
end

--- Returns the first required item found in the player's inventory.
--- @param player IsoPlayer|nil
--- @param requiredItems table<string>|nil
--- @return InventoryItem|nil
function Utils.findFirstRequiredItem(player, requiredItems)
    if not player or not requiredItems then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    for _, itemType in ipairs(requiredItems) do
        local item = inventory:getFirstTypeRecurse(itemType)
        if item then
            return item
        end
    end

    return nil
end

---@param inventory ItemContainer|nil
---@param itemId number
---@return InventoryItem|nil
local function findInventoryItemById(inventory, itemId)
    if not inventory then return nil end

    local items = inventory:getItems()
    if not items then return nil end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getID) == "function" and item:getID() == itemId then
            return item
        end

        local nestedInventory = call(item, "getInventory")
        if nestedInventory then
            local nestedItem = findInventoryItemById(nestedInventory, itemId)
            if nestedItem then
                return nestedItem
            end
        end
    end

    return nil
end

--- Resolves the specific inventory item selected by the client when possible.
--- Falls back to full type only when the item id lookup is unavailable.
--- @param inventory ItemContainer|nil
--- @param itemId number|nil
--- @param itemFullType string|nil
--- @return InventoryItem|nil
function Utils.findInventoryItem(inventory, itemId, itemFullType)
    if not inventory then return nil end

    if type(itemId) == "number" then
        local item = findInventoryItemById(inventory, itemId)
        if item then
            return item
        end
    end

    if type(itemFullType) == "string" and itemFullType ~= "" then
        return inventory:getFirstTypeRecurse(itemFullType)
    end

    return nil
end

--- Resolves which hand should display the main liquid container for vanilla-like pour poses.
--- Items with EatType are usually shown in the secondary hand during drink/pour actions.
--- @param mainItem InventoryItem|nil
--- @param supportItem InventoryItem|nil
--- @return InventoryItem|nil primaryHand
--- @return InventoryItem|nil secondaryHand
function Utils.getFluidActionHandItems(mainItem, supportItem)
    if not mainItem then
        return supportItem, nil
    end

    local hasEatType = type(mainItem.getEatType) == "function" and mainItem:getEatType() ~= nil
    if hasEatType then
        return supportItem, mainItem
    end

    return mainItem, supportItem
end

--- Backward-compatible wrapper.
function Utils.isPlayerHoldingAnyRequiredItem(player, requiredItems)
    return Utils.getRequiredItemStatus(player, requiredItems)
end

--- Returns true when the player is close enough to the barrel to interact with it.
--- Uses Chebyshev distance (tile-based max of dx/dy) against MAX_INTERACTION_DISTANCE.
--- @param player IsoPlayer|nil
--- @param barrel IsoObject|nil
--- @return boolean
function Utils.isPlayerInRange(player, barrel)
    if not player or not barrel then return false end

    local square = barrel:getSquare()
    if not square then return false end

    local dx = math.abs(player:getX() - square:getX())
    local dy = math.abs(player:getY() - square:getY())

    return math.max(dx, dy) <= Constant.MAX_INTERACTION_DISTANCE
end

--- @param player IsoPlayer|nil
--- @param requiredItems table<string>|nil
--- @return boolean hasAllRequiredItems
--- @return table<string> missingItems
function Utils.isPlayerHoldingAllRequiredItems(player, requiredItems)
    local _, _, missingItems = Utils.getRequiredItemStatus(player, requiredItems)
    return #missingItems == 0, missingItems
end

return Utils
