local SafeCall = require("utils/BarrEx_SafeCall")

local InventoryUtils = {}

local call = SafeCall.call

---@param inventory ItemContainer|nil
---@param itemId number
---@return InventoryItem|nil
function InventoryUtils.findInventoryItemById(inventory, itemId)
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
---@param itemId number|nil
---@return InventoryItem|nil
function InventoryUtils.findInventoryItemStrict(inventory, itemId)
    if type(itemId) ~= "number" then return nil end
    return InventoryUtils.findInventoryItemById(inventory, itemId)
end

--- Resolves a specific inventory item by ID when available, falling back to full type.
---@param inventory ItemContainer|nil
---@param itemId number|nil
---@param itemFullType string|nil
---@return InventoryItem|nil
function InventoryUtils.findInventoryItem(inventory, itemId, itemFullType)
    if not inventory then return nil end

    if type(itemId) == "number" then
        local item = InventoryUtils.findInventoryItemById(inventory, itemId)
        if item then
            return item
        end
    end

    return InventoryUtils.findInventoryItemByFullType(inventory, itemFullType)
end

return InventoryUtils
