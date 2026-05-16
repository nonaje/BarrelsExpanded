local Constant = require("BarrEx_Constant")
local ContextConfig = require("config/BarrEx_ContextConfig")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

local Text = {}

local VANILLA_TEXT_KEYS = {
    FILL = { "ContextMenu_Fill" },
    FILL_ONE = { "ContextMenu_Fill_one", "ContextMenu_Fill_One", "ContextMenu_FillOne" },
    FILL_ALL = { "ContextMenu_Fill_all", "ContextMenu_Fill_All", "ContextMenu_FillAll" },
    DRINK = { "ContextMenu_Drink" },
    WASH = { "ContextMenu_Wash" },
    YOURSELF = { "ContextMenu_Yourself" },
    WASH_ALL_CLOTHING = { "ContextMenu_WashAllClothing" },
}

local FALLBACK_TEXT_KEYS = {
    FILL = ContextConfig.CONTEXT_MENU.FALLBACK_FILL,
    FILL_ONE = ContextConfig.CONTEXT_MENU.FALLBACK_FILL_ONE,
    FILL_ALL = ContextConfig.CONTEXT_MENU.FALLBACK_FILL_ALL,
    DRINK = ContextConfig.CONTEXT_MENU.FALLBACK_DRINK,
    WASH = ContextConfig.CONTEXT_MENU.FALLBACK_WASH,
    YOURSELF = ContextConfig.CONTEXT_MENU.FALLBACK_YOURSELF,
    WASH_ALL_CLOTHING = ContextConfig.CONTEXT_MENU.FALLBACK_WASH_ALL_CLOTHING,
    EMPTY = ContextConfig.CONTEXT_MENU.FALLBACK_EMPTY,
    INFO = ContextConfig.CONTEXT_MENU.FALLBACK_INFO,
}

---@param key string
---@return string
function Text.translate(key, ...)
    return getText(key, ...)
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
---@param fallbackKey string
---@return string
local function getFirstAvailableText(keys, fallbackKey)
    for i = 1, #(keys or {}) do
        local key = keys[i]
        local text = getTextIfExists(key)
        if text then
            return text
        end
    end

    return Text.translate(fallbackKey)
end

---@return string
function Text.getVanillaFillText()
    return Text.translate(FALLBACK_TEXT_KEYS.FILL)
end

---@return string
function Text.getVanillaFillOneText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL_ONE, FALLBACK_TEXT_KEYS.FILL_ONE)
end

---@return string
function Text.getVanillaFillAllText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL_ALL, FALLBACK_TEXT_KEYS.FILL_ALL)
end

---@return string
function Text.getVanillaTakeGasText()
    return Text.getVanillaFillText()
end

---@return string
function Text.getVanillaDrinkText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.DRINK, FALLBACK_TEXT_KEYS.DRINK)
end

---@return string
function Text.getVanillaWashText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.WASH, FALLBACK_TEXT_KEYS.WASH)
end

---@return string
function Text.getVanillaYourselfText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.YOURSELF, FALLBACK_TEXT_KEYS.YOURSELF)
end

---@return string
function Text.getVanillaWashAllClothingText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.WASH_ALL_CLOTHING, FALLBACK_TEXT_KEYS.WASH_ALL_CLOTHING)
end

---@return string
function Text.getVanillaEmptyText()
    return Text.translate(FALLBACK_TEXT_KEYS.EMPTY)
end

---@return string
function Text.getVanillaInfoText()
    return Text.translate(FALLBACK_TEXT_KEYS.INFO)
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
        return Text.translate(ContextConfig.CONTEXT_MENU.GROUPED_CONTAINER, group.label, tostring(count))
    end

    return group.label
end

---@param item InventoryItem
---@param liquidType string|nil
---@return string
function Text.buildPourContainerOptionLabel(item, liquidType)
    local liquidName = Text.getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))

    return Text.translate(
        ContextConfig.CONTEXT_MENU.POUR_CONTAINER,
        Text.getInventoryItemDisplayName(item),
        liquidName
    )
end

return Text
