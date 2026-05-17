local LiquidAdapter   = require("BarrEx_LiquidContainerAdapter")
local TransferRules   = require("core/BarrEx_TransferRules")
local Text            = require("context/BarrEx_ContextMenuText")
local SafeCall        = require("utils/BarrEx_SafeCall")

local Inventory = {}
local call = SafeCall.call

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

        local nestedInventory = call(item, "getInventory")
        if nestedInventory then
            collectInventoryItems(nestedInventory, predicate, found)
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

    return collectInventoryItems(inventory, function(item)
        return TransferRules.isValidSourceItemForPour(item, barrelData)
    end)
end

---@param player IsoPlayer|nil
---@param barrelData BarrEx_Barrel|nil
---@return table<integer, InventoryItem>
function Inventory.collectTargetContainersForExtract(player, barrelData)
    local inventory = player and player:getInventory()
    if not inventory or not barrelData then return {} end

    return collectInventoryItems(inventory, function(item)
        return TransferRules.isValidTargetItemForExtract(item, barrelData)
    end)
end

---@param item InventoryItem|nil
---@return boolean
local function itemHasBloodOrDirt(item)
    if not item then return false end

    if call(item, "getItemAfterCleaning") then
        return true
    end

    if (tonumber(call(item, "getBloodLevel")) or 0) > 0 then
        return true
    end

    if (tonumber(call(item, "getDirtiness")) or 0) > 0 then
        return true
    end

    if instanceof and BloodClothingType and instanceof(item, "Clothing") and type(item.getBloodClothingType) == "function" then
        local coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        if coveredParts then
            for i = 0, coveredParts:size() - 1 do
                local part = coveredParts:get(i)
                if (tonumber(item:getBlood(part)) or 0) > 0
                    or (tonumber(item:getDirt(part)) or 0) > 0
                then
                    return true
                end
            end
        end
    end

    return false
end

---@param item InventoryItem|nil
---@return boolean
function Inventory.isCleanableBandageLikeItem(item)
    return item ~= nil and call(item, "getItemAfterCleaning") ~= nil
end

---@param item InventoryItem|nil
---@return number
function Inventory.getWashWaterRequired(item)
    if not item then return 0 end

    if ISWashClothing and type(ISWashClothing.GetRequiredWater) == "function" then
        return math.max(tonumber(ISWashClothing.GetRequiredWater(item)) or 0, 1)
    end

    return 1
end

---@param player IsoPlayer|nil
---@return number
function Inventory.getWashSelfWaterRequired(player)
    if not player then return 0 end

    if ISWashYourself and type(ISWashYourself.GetRequiredWater) == "function" then
        return math.max(tonumber(ISWashYourself.GetRequiredWater(player)) or 0, 0)
    end

    return 0
end

---@param player IsoPlayer|nil
---@return table<integer, InventoryItem>
function Inventory.collectWashableItems(player)
    local inventory = player and player:getInventory()
    if not inventory then return {} end

    return collectInventoryItems(inventory, function(item)
        return itemHasBloodOrDirt(item)
    end)
end

---@param items table<integer, InventoryItem>
---@return table<integer, table>
function Inventory.groupInventoryItemsByFullType(items)
    local groupedByFullType = {}
    local orderedGroups = {}

    local itemList = items or {}
    for i = 1, #itemList do
        local item = itemList[i]
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

        local groupItems = groupedByFullType[fullType].items
        groupItems[#groupItems + 1] = item
    end

    table.sort(orderedGroups, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return orderedGroups
end

return Inventory
