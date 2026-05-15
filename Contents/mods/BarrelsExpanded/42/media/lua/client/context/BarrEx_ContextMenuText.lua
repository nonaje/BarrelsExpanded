local Constant = require("BarrEx_Constant")
local ContextConfig = require("config/BarrEx_ContextConfig")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

local Text = {}

local VANILLA_TEXT_KEYS = {
    FILL = { "ContextMenu_Fill" },
    FILL_ONE = { "ContextMenu_Fill_one", "ContextMenu_Fill_One", "ContextMenu_FillOne" },
    FILL_ALL = { "ContextMenu_Fill_all", "ContextMenu_Fill_All", "ContextMenu_FillAll" },
}

local FALLBACK_TEXT = {
    FILL = "Llenar",
    FILL_ONE = "Llenar uno",
    FILL_ALL = "Llenar todo",
}

---@param key string
---@return string
function Text.translate(key)
    return getText(key)
end

---@param key string
---@return string|nil
local function getTextIfExists(key)
    if not key then return nil end

    if type(getTextOrNull) == "function" then
        local text = getTextOrNull(key)
        if text and text ~= "" then
            return text
        end
    end

    local text = getText(key)
    if text and text ~= "" and text ~= key then
        return text
    end

    return nil
end

---@param keys table<integer, string>
---@param fallback string
---@return string
local function getFirstAvailableText(keys, fallback)
    for _, key in ipairs(keys or {}) do
        local text = getTextIfExists(key)
        if text then
            return text
        end
    end

    return fallback
end

---@return string
function Text.getVanillaFillText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL, FALLBACK_TEXT.FILL)
end

---@return string
function Text.getVanillaFillOneText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL_ONE, FALLBACK_TEXT.FILL_ONE)
end

---@return string
function Text.getVanillaFillAllText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL_ALL, FALLBACK_TEXT.FILL_ALL)
end

---@param amount number|nil
---@return string
function Text.formatAmount(amount)
    return string.format("%.1f", tonumber(amount) or 0)
end

---@param itemType string|nil
---@return string
function Text.getItemDisplayName(itemType)
    if not itemType or itemType == "" then return "" end

    local displayName = getItemNameFromFullType(itemType)
    if displayName and displayName ~= "" then
        return displayName
    end

    return itemType
end

---@param item InventoryItem|nil
---@return string
function Text.getInventoryItemFullType(item)
    if item and type(item.getFullType) == "function" then
        local fullType = item:getFullType()
        if fullType and fullType ~= "" then
            return fullType
        end
    end

    return tostring(item)
end

---@param item InventoryItem|nil
---@return string
function Text.getInventoryItemDisplayName(item)
    if not item then return "" end

    if type(item.getName) == "function" then
        local name = item:getName()
        if name and name ~= "" then return name end
    end

    if type(item.getDisplayName) == "function" then
        local displayName = item:getDisplayName()
        if displayName and displayName ~= "" then return displayName end
    end

    return Text.getItemDisplayName(Text.getInventoryItemFullType(item))
end

---@param liquidType string|nil
---@return string
function Text.getLiquidDisplayName(liquidType)
    if not liquidType or liquidType == Constant.LIQUID_TYPE.EMPTY then
        return Text.translate(ContextConfig.UI.EMPTY)
    end

    local translationKey = ContextConfig.UI["LIQUID_" .. liquidType]
    if translationKey then
        return Text.translate(translationKey)
    end

    return liquidType
end

---@param group table
---@return string
function Text.buildGroupedContainerLabel(group)
    local count = #(group.items or {})

    if count > 1 then
        return string.format("%s (%d)", group.label, count)
    end

    return group.label
end

---@param item InventoryItem
---@param liquidType string|nil
---@param transferAmount number
---@return string
function Text.buildPourContainerOptionLabel(item, liquidType, transferAmount)
    local amount = LiquidAdapter.getAmount(item)
    local capacity = LiquidAdapter.getCapacity(item)
    local liquidName = Text.getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))

    return string.format(
        "%s - %s %s/%s (%s %s)",
        Text.getInventoryItemDisplayName(item),
        liquidName,
        Text.formatAmount(amount),
        Text.formatAmount(capacity),
        Text.formatAmount(transferAmount),
        Text.translate(ContextConfig.TOOLTIP.TRANSFER_AMOUNT)
    )
end

return Text