local Constant = require("BarrEx_Constant")

local Utils = {}

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

    local inventory = player:getInventory()
    if not inventory then
        return false, {}, {}
    end

    local foundItems = {}
    local missingItems = {}
    local foundCount = 0

    for _, itemType in ipairs(requiredItems) do
        if inventory:containsType(itemType) then
            foundCount = foundCount + 1
            foundItems[#foundItems + 1] = itemType
        else
            missingItems[#missingItems + 1] = itemType
        end
    end

    return foundCount > 0, foundItems, missingItems
end

--- Backward-compatible wrapper.
function Utils.isPlayerHoldingAnyRequiredItem(player, requiredItems)
    return Utils.getRequiredItemStatus(player, requiredItems)
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
