local ContextConfig = require("config/BarrEx_ContextConfig")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local Constant = require("BarrEx_Constant")
local Text = require("context/BarrEx_ContextMenuText")

local Tooltips = {}

Tooltips.COLORS = {
    TEXT = "<RGB:1,1,1>",
    MUTED = "<RGB:0.75,0.75,0.75>",
    HEADER = "<RGB:0.9,0.9,0.9>",
    GOOD = "<RGB:0.35,1,0.35>",
    BAD = "<RGB:1,0.35,0.35>",
    WARN = "<RGB:1,0.65,0.25>",
}

local DEFAULT_MAX_LINE_WIDTH = 512
local LINE_BREAK = " <LINE>"

local REASON_TOOLTIP_KEYS = {
    barrel_empty = ContextConfig.TOOLTIP.BARREL_EMPTY,
    barrel_full = ContextConfig.TOOLTIP.BARREL_FULL,
    barrel_unavailable = ContextConfig.TOOLTIP.BARREL_UNAVAILABLE,
    not_drinkable = ContextConfig.TOOLTIP.NOT_DRINKABLE,
    not_washable = ContextConfig.TOOLTIP.NOT_WASHABLE,
    not_thirsty = ContextConfig.TOOLTIP.NOT_THIRSTY,
    nothing_to_wash = ContextConfig.TOOLTIP.NOTHING_TO_WASH,
}

local MAX_COMPATIBLE_CONTAINER_LINES = 8

---@return ISToolTip
local function newTooltip()
    return ISInventoryPaneContextMenu.addToolTip()
end

local TooltipBuilder = {}
TooltipBuilder.__index = TooltipBuilder

---@param color string|nil
---@param text string|number|nil
---@return string
local function buildLine(color, text)
    return " " .. (color or Tooltips.COLORS.TEXT) .. " " .. tostring(text or "") .. LINE_BREAK
end

---@return table
function Tooltips.newBuilder()
    return setmetatable({ lines = {}, maxLineWidth = DEFAULT_MAX_LINE_WIDTH }, TooltipBuilder)
end

---@param text string|number|nil
---@return table
function TooltipBuilder:header(text)
    self.lines[#self.lines + 1] = buildLine(Tooltips.COLORS.HEADER, text)
    return self
end

---@param text string|number|nil
---@param color string|nil
---@return table
function TooltipBuilder:line(text, color)
    self.lines[#self.lines + 1] = buildLine(color or Tooltips.COLORS.TEXT, text)
    return self
end

---@param label string|nil
---@param value string|number|nil
---@param valueColor string|nil
---@return table
function TooltipBuilder:keyValue(label, value, valueColor)
    self.lines[#self.lines + 1] = buildLine(valueColor or Tooltips.COLORS.TEXT, tostring(label or "") .. " " .. tostring(value or ""))
    return self
end

---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
---@return table
function TooltipBuilder:requiredItems(foundItems, missingItems)
    self:header(Text.translate(ContextConfig.TOOLTIP.REQUIRED))
        :line(Text.translate(ContextConfig.TOOLTIP.ONE_OF), Tooltips.COLORS.MUTED)

    local found = foundItems or {}
    for i = 1, #found do
        self:line(
            Text.translate(ContextConfig.TOOLTIP.ITEM_REQUIREMENT, Text.getItemDisplayName(found[i]), "1", "1"),
            Tooltips.COLORS.GOOD
        )
    end

    local missing = missingItems or {}
    for i = 1, #missing do
        self:line(
            Text.translate(ContextConfig.TOOLTIP.ITEM_REQUIREMENT, Text.getItemDisplayName(missing[i]), "0", "1"),
            Tooltips.COLORS.BAD
        )
    end

    return self
end

---@param label string|nil
---@param current number|nil
---@param maximum number|nil
---@return table
function TooltipBuilder:amount(label, current, maximum)
    return self:keyValue(
        label,
        string.format("%.1f/%.1f", tonumber(current) or 0, tonumber(maximum) or 0)
    )
end

---@param width number|nil
---@return table
function TooltipBuilder:width(width)
    self.maxLineWidth = width or DEFAULT_MAX_LINE_WIDTH
    return self
end

---@return string
function TooltipBuilder:description()
    return table.concat(self.lines)
end

---@param option table|nil
---@return ISToolTip|nil
function TooltipBuilder:attach(option)
    if not option then return nil end

    local tooltip = newTooltip()
    tooltip.maxLineWidth = self.maxLineWidth or DEFAULT_MAX_LINE_WIDTH
    tooltip.description = self:description()
    option.toolTip = tooltip
    return tooltip
end

---@param option table|nil
---@param message string|nil
function Tooltips.attachSimpleTooltip(option, message)
    if not option or not message then return end

    Tooltips.newBuilder()
        :line(message)
        :attach(option)
end

---@param option table|nil
function Tooltips.attachTooFarTooltip(option)
    Tooltips.attachSimpleTooltip(option, Text.translate(ContextConfig.TOOLTIP.TOO_FAR))
end

---@param option table|nil
---@param reason string|nil
function Tooltips.attachReasonTooltip(option, reason)
    if not option or not reason then return end

    if reason == "too_far" then
        Tooltips.attachTooFarTooltip(option)
        return
    end

    local translationKey = REASON_TOOLTIP_KEYS[reason]
    if translationKey then
        Tooltips.attachSimpleTooltip(option, Text.translate(translationKey))
    end
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
    return Tooltips.newBuilder()
        :requiredItems(foundItems, missingItems)
        :description()
end

---@param option table|nil
---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
function Tooltips.attachRequiredItemsTooltip(option, foundItems, missingItems)
    if not option then return end

    local tooltip = newTooltip()
    tooltip.maxLineWidth = DEFAULT_MAX_LINE_WIDTH
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

    return Tooltips.newBuilder()
        :header(Text.translate(ContextConfig.TOOLTIP.BARREL_CONTENTS))
        :keyValue(Text.translate(ContextConfig.TOOLTIP.LIQUID), Text.getLiquidDisplayName(barrelData.liquidType))
        :amount(Text.translate(ContextConfig.TOOLTIP.AMOUNT), amount, capacity)
        :keyValue(Text.translate(ContextConfig.TOOLTIP.FILL_LEVEL), string.format("%d%%", percent))
        :keyValue(Text.translate(ContextConfig.TOOLTIP.WEIGHT), string.format("%.2f", barrelData:getTotalWeight()))
        :description()
end

---@param option table|nil
---@param barrelData BarrEx_Barrel|nil
function Tooltips.attachBarrelInfoTooltip(option, barrelData)
    if not option or not barrelData then return end

    local tooltip = newTooltip()
    tooltip.maxLineWidth = DEFAULT_MAX_LINE_WIDTH
    tooltip.description = (tooltip.description or "") .. buildBarrelInfoTooltipDescription(barrelData)
    option.toolTip = tooltip
end

---@param option table|nil
function Tooltips.attachTaintedWaterTooltip(option)
    Tooltips.newBuilder()
        :line(Text.translate(ContextConfig.TOOLTIP.TAINTED_WATER), Tooltips.COLORS.WARN)
        :attach(option)
end

---@param builder table
---@param liquidType string|nil
local function appendCompatibleContainers(builder, liquidType)
    local containers = liquidType and Constant.COMPATIBLE_CONTAINERS[liquidType] or nil
    if type(containers) ~= "table" then return end

    builder:header(Text.translate(ContextConfig.TOOLTIP.COMPATIBLE_CONTAINERS))

    local fullTypes = {}
    for fullType, _ in pairs(containers) do
        fullTypes[#fullTypes + 1] = fullType
    end
    table.sort(fullTypes, function(a, b)
        return Text.getItemDisplayName(a) < Text.getItemDisplayName(b)
    end)

    local count = 0
    for i = 1, #fullTypes do
        local fullType = fullTypes[i]
        count = count + 1
        if count <= MAX_COMPATIBLE_CONTAINER_LINES then
            builder:line(Text.getItemDisplayName(fullType), Tooltips.COLORS.MUTED)
        end
    end

    if count > MAX_COMPATIBLE_CONTAINER_LINES then
        builder:line("...", Tooltips.COLORS.MUTED)
    end
end

---@param builder table
---@param reason string|nil
local function appendReasonStatus(builder, reason)
    local translationKey = REASON_TOOLTIP_KEYS[reason]
    if translationKey then
        builder:header(Text.translate(ContextConfig.TOOLTIP.STATUS))
            :line(Text.translate(translationKey), Tooltips.COLORS.BAD)
    end
end

---@param option table|nil
---@param reason string|nil
function Tooltips.attachActionUnavailableTooltip(option, reason)
    if not option or not reason then return end

    local builder = Tooltips.newBuilder()
    appendReasonStatus(builder, reason)
    builder:attach(option)
end

---@param option table|nil
---@param availability table
function Tooltips.attachFillRequirementsTooltip(option, availability)
    if not option or not availability then return end

    local builder = Tooltips.newBuilder()
    appendReasonStatus(builder, availability.fillReason)

    local liquidType = availability.liquidType
    if liquidType and liquidType ~= Constant.LIQUID_TYPE.EMPTY then
        builder:keyValue(
            Text.translate(ContextConfig.TOOLTIP.CURRENT_LIQUID),
            Text.getLiquidDisplayName(liquidType)
        )
    end

    builder:requiredItems(availability.fillFoundItems, availability.fillMissingItems)

    if availability.fillReason == "no_target_items" then
        builder:line(Text.translate(ContextConfig.TOOLTIP.NEED_CONTAINER_WITH_SPACE), Tooltips.COLORS.WARN)
        appendCompatibleContainers(builder, liquidType)
    end

    builder:attach(option)
end

---@param option table|nil
---@param availability table
---@param barrelData BarrEx_Barrel|nil
function Tooltips.attachPourRequirementsTooltip(option, availability, barrelData)
    if not option or not availability then return end

    local builder = Tooltips.newBuilder()
    appendReasonStatus(builder, availability.pourReason)
    builder:requiredItems(availability.pourFoundItems, availability.pourMissingItems)

    local liquidType = barrelData and barrelData.liquidType or nil
    if liquidType and liquidType ~= Constant.LIQUID_TYPE.EMPTY then
        builder:keyValue(
            Text.translate(ContextConfig.TOOLTIP.CURRENT_LIQUID),
            Text.getLiquidDisplayName(liquidType)
        )
        builder:line(Text.translate(ContextConfig.TOOLTIP.NEED_MATCHING_LIQUID), Tooltips.COLORS.WARN)
        appendCompatibleContainers(builder, liquidType)
    elseif availability.pourReason == "no_source_items" then
        builder:line(Text.translate(ContextConfig.TOOLTIP.NEED_CONTAINER_WITH_LIQUID), Tooltips.COLORS.WARN)
    end

    builder:attach(option)
end

---@param option table|nil
---@param freeCapacity number|nil
---@param capacity number|nil
function Tooltips.attachFuelCapacityTooltip(option, freeCapacity, capacity)
    if not option then return end

    Tooltips.newBuilder()
        :keyValue(
            Text.translate(ContextConfig.TOOLTIP.FUEL_CAPACITY),
            string.format("%d / %d", tonumber(freeCapacity) or 0, tonumber(capacity) or 0)
        )
        :attach(option)
end

---@param option table|nil
---@param item InventoryItem
---@param liquidType string|nil
function Tooltips.attachTransferTooltip(option, item, liquidType)
    if not option or not item then return end

    Tooltips.newBuilder()
        :keyValue(
            Text.translate(ContextConfig.TOOLTIP.LIQUID),
            Text.getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))
        )
        :keyValue(
            Text.translate(ContextConfig.TOOLTIP.CONTAINER_CAPACITY),
            Text.formatAmount(LiquidAdapter.getAmount(item)) .. "/" .. Text.formatAmount(LiquidAdapter.getCapacity(item))
        )
        :attach(option)
end

return Tooltips
