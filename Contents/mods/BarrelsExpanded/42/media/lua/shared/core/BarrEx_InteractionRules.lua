-- BarrEx_InteractionRules: pure shared predicates for player-barrel interactions.
--
-- Lives in shared/ so client (ContextMenu, timed actions) and server (validation)
-- can consult the same rules without duplicating logic.
-- No networking, no world state, no side effects.

local InventoryUtils = require("utils/BarrEx_InventoryUtils")
local PlayerUtils = require("utils/BarrEx_PlayerUtils")

local InteractionRules = {}

--- Returns true when the player has at least one item from requiredItems in their inventory.
---@param player IsoPlayer
---@param requiredItems table<string>
---@return boolean
function InteractionRules.playerHasRequiredTool(player, requiredItems)
    if not player then return false end

    local inventory = player:getInventory()
    if not inventory then return false end

    for i = 1, #requiredItems do
        local itemType = requiredItems[i]
        if InventoryUtils.findInventoryItem(inventory, nil, itemType) then
            return true
        end
    end

    return false
end

--- Retrieves the item matching args.itemId / args.itemFullType from the player's inventory.
---@param player IsoPlayer
---@param args table|nil
---@return InventoryItem|nil
function InteractionRules.getItemFromArgs(player, args)
    if not player or type(args) ~= "table" then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    return InventoryUtils.findInventoryItem(inventory, args.itemId, args.itemFullType)
end

--- Retrieves the exact item matching args.itemId from the player's inventory.
--- Intended for server-authoritative mutations; intentionally has no full-type fallback.
---@param player IsoPlayer
---@param args table|nil
---@return InventoryItem|nil
function InteractionRules.getItemFromArgsStrict(player, args)
    if not player or type(args) ~= "table" then return nil end
    local itemIdType = type(args.itemId)
    if itemIdType ~= "number" and itemIdType ~= "string" then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    return InventoryUtils.findInventoryItemStrict(inventory, args.itemId)
end

--- Returns true when the player is in range of barrel and (optionally) has the required tool.
--- checkTool defaults to true; pass false to skip the tool check (e.g. in per-tick validation).
---@param barrel IsoObject
---@param player IsoPlayer
---@param requiredItems table<string>
---@param checkTool boolean|nil
---@return boolean
function InteractionRules.validateInteraction(barrel, player, requiredItems, checkTool)
    if not barrel or not player then return false end

    if not PlayerUtils.isPlayerInRange(player, barrel) then
        return false
    end

    if checkTool ~= false and not InteractionRules.playerHasRequiredTool(player, requiredItems) then
        return false
    end

    return true
end

return InteractionRules
