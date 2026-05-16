local ContextConfig = require("config/BarrEx_ContextConfig")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local Text = require("context/BarrEx_ContextMenuText")

local Tooltips = {}

---@return ISToolTip
local function newTooltip()
    return ISInventoryPaneContextMenu.addToolTip()
end

---@param option table|nil
---@param message string|nil
function Tooltips.attachSimpleTooltip(option, message)
    if not option or not message then return end

    local tooltip = newTooltip()
    tooltip.description = message
    option.toolTip = tooltip
end

---@param option table|nil
function Tooltips.attachTooFarTooltip(option)
    Tooltips.attachSimpleTooltip(option, Text.translate(ContextConfig.TOOLTIP.TOO_FAR))
end

---@param option table|nil
---@param item InventoryItem|nil
function Tooltips.attachInventoryItemIcon(option, item)
    if not option or not item then return end

    option.itemForTexture = item

    if type(item.getTex) == "function" then
        option.iconTexture = item:getTex()
        return
    end

    if type(item.getTexture) == "function" then
        option.iconTexture = item:getTexture()
    end
end

---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
---@return string
local function buildRequiredItemsTooltipDescription(foundItems, missingItems)
    local lines = {
        Text.translate(ContextConfig.TOOLTIP.REQUIRED) .. " <LINE>",
        Text.translate(ContextConfig.TOOLTIP.ONE_OF) .. " <LINE>",
    }

    for _, itemType in ipairs(foundItems or {}) do
        lines[#lines + 1] = " <RGB:0,1,0> " .. Text.getItemDisplayName(itemType) .. " 1/1 <LINE>"
    end

    for _, itemType in ipairs(missingItems or {}) do
        lines[#lines + 1] = " <RGB:1,0,0> " .. Text.getItemDisplayName(itemType) .. " 1/1 <LINE>"
    end

    return table.concat(lines)
end

---@param option table|nil
---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
function Tooltips.attachRequiredItemsTooltip(option, foundItems, missingItems)
    if not option then return end

    local tooltip = newTooltip()
    tooltip.description = (tooltip.description or "") .. buildRequiredItemsTooltipDescription(foundItems, missingItems)
    option.toolTip = tooltip
end

---@param barrelData BarrEx_Barrel|nil
---@return string
local function buildBarrelInfoTooltipDescription(barrelData)
    if not barrelData then return "" end

    local amount = tonumber(barrelData.amount) or 0
    local capacity = tonumber(barrelData.capacity) or 0
    local percent = capacity > 0 and math.floor((amount / capacity) * 100) or 0

    return table.concat({
        Text.translate(ContextConfig.TOOLTIP.BARREL_CONTENTS) .. " <LINE>",
        " <RGB:1,1,1> " .. Text.translate(ContextConfig.TOOLTIP.LIQUID) .. " " .. Text.getLiquidDisplayName(barrelData.liquidType) .. " <LINE>",
        string.format(
            " <RGB:1,1,1> %s %.1f/%.1f <LINE>",
            Text.translate(ContextConfig.TOOLTIP.AMOUNT),
            amount,
            capacity
        ),
        string.format(
            " <RGB:1,1,1> %s %d%% <LINE>",
            Text.translate(ContextConfig.TOOLTIP.FILL_LEVEL),
            percent
        ),
        string.format(
            " <RGB:1,1,1> %s %.2f <LINE>",
            Text.translate(ContextConfig.TOOLTIP.WEIGHT),
            barrelData:getTotalWeight()
        ),
    })
end

---@param option table|nil
---@param barrelData BarrEx_Barrel|nil
function Tooltips.attachBarrelInfoTooltip(option, barrelData)
    if not option or not barrelData then return end

    local tooltip = newTooltip()
    tooltip.description = (tooltip.description or "") .. buildBarrelInfoTooltipDescription(barrelData)
    option.toolTip = tooltip
end

---@param option table|nil
function Tooltips.attachTaintedWaterTooltip(option)
    Tooltips.attachSimpleTooltip(option, " <RGB:1,0.5,0.5> " .. Text.translate("Tooltip_item_TaintedWater"))
end

---@param option table|nil
---@param freeCapacity number|nil
---@param capacity number|nil
function Tooltips.attachFuelCapacityTooltip(option, freeCapacity, capacity)
    if not option then return end

    local tooltip = newTooltip()
    tooltip.maxLineWidth = 512
    tooltip.description = Text.translate("ContextMenu_FuelCapacity")
        .. string.format("%d / %d", tonumber(freeCapacity) or 0, tonumber(capacity) or 0)
    option.toolTip = tooltip
end

---@param option table|nil
---@param item InventoryItem
---@param liquidType string|nil
function Tooltips.attachTransferTooltip(option, item, liquidType)
    if not option or not item then return end

    local tooltip = newTooltip()
    tooltip.description = table.concat({
        string.format(
            "<RGB:1,1,1> %s %s <LINE>",
            Text.translate(ContextConfig.TOOLTIP.LIQUID),
            Text.getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))
        ),
        string.format(
            "<RGB:1,1,1> %s %s/%s <LINE>",
            Text.translate(ContextConfig.TOOLTIP.CONTAINER_CAPACITY),
            Text.formatAmount(LiquidAdapter.getAmount(item)),
            Text.formatAmount(LiquidAdapter.getCapacity(item))
        ),
    })
    option.toolTip = tooltip
end

return Tooltips
