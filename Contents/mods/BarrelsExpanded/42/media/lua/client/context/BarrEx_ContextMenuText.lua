local Constant = require("BarrEx_Constant")
local ContextConfig = require("config/BarrEx_ContextConfig")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

local Text = {}

local VANILLA_TEXT_KEYS = {
    FILL = { "ContextMenu_Fill" },
    FILL_ONE = { "ContextMenu_Fill_one", "ContextMenu_Fill_One", "ContextMenu_FillOne" },
    FILL_ALL = { "ContextMenu_Fill_all", "ContextMenu_Fill_All", "ContextMenu_FillAll" },
    TAKE_GAS = { "ContextMenu_TakeGasFromPump" },
    DRINK = { "ContextMenu_Drink" },
    WASH = { "ContextMenu_Wash" },
    YOURSELF = { "ContextMenu_Yourself" },
    WASH_ALL_CLOTHING = { "ContextMenu_WashAllClothing" },
    EMPTY = { "Fluid_Empty" },
    INFO = { "Fluid_Show_Info" },
}

local FALLBACK_TEXT = {
    FILL = "Llenar",
    FILL_ONE = "Llenar uno",
    FILL_ALL = "Llenar todo",
    TAKE_GAS = "Llenar gasolina",
    DRINK = "Beber",
    WASH = "Lavar",
    YOURSELF = "A ti mismo",
    WASH_ALL_CLOTHING = "Toda la ropa",
    EMPTY = "Vaciar",
    INFO = "Informacion del barril",
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

---@return string
function Text.getVanillaTakeGasText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.TAKE_GAS, FALLBACK_TEXT.TAKE_GAS)
end

---@return string
function Text.getVanillaDrinkText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.DRINK, FALLBACK_TEXT.DRINK)
end

---@return string
function Text.getVanillaWashText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.WASH, FALLBACK_TEXT.WASH)
end

---@return string
function Text.getVanillaYourselfText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.YOURSELF, FALLBACK_TEXT.YOURSELF)
end

---@return string
function Text.getVanillaWashAllClothingText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.WASH_ALL_CLOTHING, FALLBACK_TEXT.WASH_ALL_CLOTHING)
end

---@return string
function Text.getVanillaEmptyText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.EMPTY, FALLBACK_TEXT.EMPTY)
end

---@return string
function Text.getVanillaInfoText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.INFO, FALLBACK_TEXT.INFO)
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
---@return string
function Text.buildPourContainerOptionLabel(item, liquidType)
    local liquidName = Text.getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))

    return string.format(
        "%s - %s",
        Text.getInventoryItemDisplayName(item),
        liquidName
    )
end

return Text
