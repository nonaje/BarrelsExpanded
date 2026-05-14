local Constant = require("BarrEx_Constant")

local Utils = {}

--- Checks if the given world object is an expandable barrel by verifying if its sprite name matches any of the predefined barrel tile names in the Constant module.
---@param worldObject IsoObject
---@return boolean
function Utils.isExpandableBarrel(worldObject)
    if not worldObject then return false end

    local okSprite, sprite = pcall(function()
        return worldObject:getSprite()
    end)

    if not okSprite then return false end

    if not sprite then return false end

    local okName, spriteName = pcall(function()
        return sprite:getName()
    end)

    if not okName then return false end

    if not spriteName or spriteName == "" then return false end

    return Constant.BARREL_TILE_NAMES[spriteName] == true
end

--- Checks if the player has ALL required items in their inventory.
--- Iterates through the requiredItems list and verifies that each item exists.
---
--- Returns:
--- - true and an empty table if all items are present.
--- - false and a table containing the missing item types otherwise.
---
--- Example:
--- local ok, missing = Utils.isPlayerHoldingAllRequiredItems(player, {
---     "Base.Hammer",
---     "Base.Saw"
--- })
---
--- @param player IsoPlayer The player whose inventory will be checked.
--- @param requiredItems table<string> List of item FullTypes to verify.
--- @return boolean success True if all required items are present.
--- @return table<string> missingItems List of missing item FullTypes.
function Utils.isPlayerHoldingAllRequiredItems(player, requiredItems)
    if not player or not requiredItems then
        return false, {}
    end

    local missingItems = {}
    local inventory = player:getInventory()

    for _, itemType in ipairs(requiredItems) do
        if not inventory:containsType(itemType) then
            table.insert(missingItems, itemType)
        end
    end

    return #missingItems == 0, missingItems
end

--- Checks if the player has AT LEAST ONE required item in their inventory.
--- Iterates through the requiredItems list and collects all matching items found.
---
--- Returns:
--- - true and a table containing the found item types if at least one item exists.
--- - false and an empty table otherwise.
---
--- Example:
--- local ok, found = Utils.isPlayerHoldingAnyRequiredItem(player, {
---     "Base.Hammer",
---     "Base.Saw"
--- })
---
--- @param player IsoPlayer The player whose inventory will be checked.
--- @param requiredItems table<string> List of item FullTypes to verify.
--- @return boolean success True if at least one required item is present.
--- @return table<string> foundItems List of found item FullTypes.
--- @return table<string> missingItems List of missing iteem FullTypes.
function Utils.isPlayerHoldingAnyRequiredItem(player, requiredItems)
    if not player or not requiredItems then
        return false, {}, {}
    end

    local foundItems = {}
    local missingItems = {}
    local inventory = player:getInventory()

    for _, itemType in ipairs(requiredItems) do
        if inventory:containsType(itemType) then
            table.insert(foundItems, itemType)
        else 
            table.insert(missingItems, itemType)
        end
    end

    return #foundItems > 0, foundItems, missingItems
end

return Utils