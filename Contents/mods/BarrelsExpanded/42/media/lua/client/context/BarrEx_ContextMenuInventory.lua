local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local Text = require("context/BarrEx_ContextMenuText")

local Inventory = {}

---@param item InventoryItem
---@param barrelData BarrEx_Barrel
---@return number
function Inventory.getPourTransferAmount(item, barrelData)
    if not item or not barrelData then return 0 end

    local amount = tonumber(LiquidAdapter.getAmount(item)) or 0
    local freeCapacity = tonumber(barrelData:getFreeCapacity()) or 0

    return math.max(math.min(amount, freeCapacity), 0)
end

---@param inventory ItemContainer|nil
---@param predicate fun(item: InventoryItem): boolean
---@param found table<integer, InventoryItem>|nil
---@return table<integer, InventoryItem>
local function collectInventoryItems(inventory, predicate, found)
    found = found or {}
    if not inventory then return found end

    local items = inventory:getItems()
    if not items then return found end

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if item and predicate(item) then
            found[#found + 1] = item
        end

        local getInventory = item and item["getInventory"] or nil
        if type(getInventory) == "function" then
            collectInventoryItems(getInventory(item), predicate, found)
        end
    end

    return found
end

---@param player IsoPlayer|nil
---@param barrelData BarrEx_Barrel|nil
---@return table<integer, InventoryItem>
function Inventory.collectSourceContainersForPour(player, barrelData)
    local inventory = player and player:getInventory()
    if not inventory or not barrelData then return {} end
    if barrelData:isFull() then return {} end

    local expectedType = nil
    if not barrelData:isEmpty() then
        expectedType = barrelData.liquidType
    end

    return collectInventoryItems(inventory, function(item)
        if not LiquidAdapter.isLiquidContainer(item) then
            return false
        end

        if not LiquidAdapter.canProvide(item, expectedType) then
            return false
        end

        local sourceType = LiquidAdapter.getLiquidType(item)
        if not sourceType then
            return false
        end

        local transferAmount = Inventory.getPourTransferAmount(item, barrelData)

        return transferAmount > 0 and barrelData:canAcceptLiquid(sourceType, transferAmount)
    end)
end

---@param player IsoPlayer|nil
---@param barrelData BarrEx_Barrel|nil
---@return table<integer, InventoryItem>
function Inventory.collectTargetContainersForExtract(player, barrelData)
    local inventory = player and player:getInventory()
    if not inventory or not barrelData then return {} end
    if barrelData:isEmpty() then return {} end

    return collectInventoryItems(inventory, function(item)
        return LiquidAdapter.canReceive(item, barrelData.liquidType)
            and LiquidAdapter.getFreeCapacity(item) > 0
    end)
end

---@param items table<integer, InventoryItem>
---@return table<integer, table>
function Inventory.groupInventoryItemsByFullType(items)
    local groupedByFullType = {}
    local orderedGroups = {}

    for _, item in ipairs(items or {}) do
        local fullType = Text.getInventoryItemFullType(item)

        if not groupedByFullType[fullType] then
            groupedByFullType[fullType] = {
                fullType = fullType,
                label = Text.getInventoryItemDisplayName(item),
                iconItem = item,
                items = {},
            }

            orderedGroups[#orderedGroups + 1] = groupedByFullType[fullType]
        end

        table.insert(groupedByFullType[fullType].items, item)
    end

    table.sort(orderedGroups, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return orderedGroups
end

return Inventory