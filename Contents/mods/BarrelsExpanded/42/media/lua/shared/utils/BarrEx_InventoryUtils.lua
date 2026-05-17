local SafeCall = require("utils/BarrEx_SafeCall")

local InventoryUtils = {}

local call = SafeCall.call

local function isValidItemId(itemId)
    local itemIdType = type(itemId)
    return itemIdType == "number" or (itemIdType == "string" and itemId ~= "")
end

local function itemIdMatches(item, itemId)
    if not item or type(item.getID) ~= "function" then return false end

    local currentItemId = item:getID()
    return currentItemId == itemId or tostring(currentItemId) == tostring(itemId)
end

---@param inventory ItemContainer|nil
---@param itemId number|string
---@return InventoryItem|nil
function InventoryUtils.findInventoryItemById(inventory, itemId)
    if not inventory or not isValidItemId(itemId) then return nil end

    local items = inventory:getItems()
    if not items then return nil end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if itemIdMatches(item, itemId) then
            return item
        end

        local nestedInventory = call(item, "getInventory")
        if nestedInventory then
            local nestedItem = InventoryUtils.findInventoryItemById(nestedInventory, itemId)
            if nestedItem then
                return nestedItem
            end
        end
    end

    return nil
end

---@param inventory ItemContainer|nil
---@param itemFullType string|nil
---@return InventoryItem|nil
function InventoryUtils.findInventoryItemByFullType(inventory, itemFullType)
    if not inventory then return nil end
    if type(itemFullType) ~= "string" or itemFullType == "" then return nil end

    return inventory:getFirstTypeRecurse(itemFullType)
end

--- Resolves a specific inventory item by ID only. No full-type fallback.
---@param inventory ItemContainer|nil
---@param itemId number|string|nil
---@return InventoryItem|nil
function InventoryUtils.findInventoryItemStrict(inventory, itemId)
    if not isValidItemId(itemId) then return nil end

    local resolvedItemId = itemId
    ---@cast resolvedItemId string|number
    return InventoryUtils.findInventoryItemById(inventory, resolvedItemId)
end

--- Resolves a specific inventory item by ID when available, falling back to full type.
---@param inventory ItemContainer|nil
---@param itemId number|string|nil
---@param itemFullType string|nil
---@return InventoryItem|nil
function InventoryUtils.findInventoryItem(inventory, itemId, itemFullType)
    if not inventory then return nil end

    if isValidItemId(itemId) then
        local resolvedItemId = itemId
        ---@cast resolvedItemId string|number
        local item = InventoryUtils.findInventoryItemById(inventory, resolvedItemId)
        if item then
            return item
        end
    end

    return InventoryUtils.findInventoryItemByFullType(inventory, itemFullType)
end

return InventoryUtils
