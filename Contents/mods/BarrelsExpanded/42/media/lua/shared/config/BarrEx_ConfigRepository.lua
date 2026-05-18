local ConfigKeys = require("config/BarrEx_ConfigKeys")
local StaticConfig = require("config/BarrEx_StaticConfig")

local ConfigRepository = {}

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_gmatch = string.gmatch
local string_match = string.match

local LIQUID_TYPE = StaticConfig.LIQUID_TYPE
local EMPTY_DISTRIBUTION = {
    [LIQUID_TYPE.EMPTY] = 100,
}

local DISTRIBUTION_KEYS = {
    INDUSTRIAL = {
        [LIQUID_TYPE.EMPTY] = ConfigKeys.INDUSTRIAL_WEIGHT_EMPTY,
        [LIQUID_TYPE.WATER] = ConfigKeys.INDUSTRIAL_WEIGHT_WATER,
        [LIQUID_TYPE.TAINTED_WATER] = ConfigKeys.INDUSTRIAL_WEIGHT_TAINTED_WATER,
        [LIQUID_TYPE.GASOLINE] = ConfigKeys.INDUSTRIAL_WEIGHT_GASOLINE,
        [LIQUID_TYPE.BLEACH] = ConfigKeys.INDUSTRIAL_WEIGHT_BLEACH,
    },
    MILITARY = {
        [LIQUID_TYPE.EMPTY] = ConfigKeys.MILITARY_WEIGHT_EMPTY,
        [LIQUID_TYPE.WATER] = ConfigKeys.MILITARY_WEIGHT_WATER,
        [LIQUID_TYPE.TAINTED_WATER] = ConfigKeys.MILITARY_WEIGHT_TAINTED_WATER,
        [LIQUID_TYPE.GASOLINE] = ConfigKeys.MILITARY_WEIGHT_GASOLINE,
        [LIQUID_TYPE.BLEACH] = ConfigKeys.MILITARY_WEIGHT_BLEACH,
    },
    CRAFTED = {
        [LIQUID_TYPE.EMPTY] = ConfigKeys.CRAFTED_WEIGHT_EMPTY,
        [LIQUID_TYPE.WATER] = ConfigKeys.CRAFTED_WEIGHT_WATER,
        [LIQUID_TYPE.TAINTED_WATER] = ConfigKeys.CRAFTED_WEIGHT_TAINTED_WATER,
        [LIQUID_TYPE.GASOLINE] = ConfigKeys.CRAFTED_WEIGHT_GASOLINE,
        [LIQUID_TYPE.BLEACH] = ConfigKeys.CRAFTED_WEIGHT_BLEACH,
    },
}

local function getSandboxRoot()
    if type(SandboxVars) ~= "table" then
        return nil
    end

    local root = SandboxVars[ConfigKeys.SANDBOX_NAMESPACE]
    if type(root) == "table" then
        return root
    end

    return nil
end

local function getSandboxValue(key)
    local root = getSandboxRoot()
    if root and root[key] ~= nil then
        return root[key]
    end

    local optionName = ConfigKeys.getSandboxOptionName(key)
    if type(SandboxVars) == "table" and SandboxVars[optionName] ~= nil then
        return SandboxVars[optionName]
    end

    return nil
end

local function clamp(value, metadata)
    if metadata.min ~= nil then
        value = math_max(value, metadata.min)
    end
    if metadata.max ~= nil then
        value = math_min(value, metadata.max)
    end
    return value
end

local function resolveSandboxValue(key, fallback)
    local metadata = StaticConfig.getMetadata(key)
    if not metadata or metadata.sandbox ~= true then
        return fallback
    end

    local value = getSandboxValue(key)
    if value == nil then
        return fallback
    end

    if metadata.type == "integer" then
        local numberValue = tonumber(value)
        if not numberValue then return fallback end
        return math_floor(clamp(numberValue, metadata))
    end

    if metadata.type == "double" then
        local numberValue = tonumber(value)
        if not numberValue then return fallback end
        return clamp(numberValue, metadata)
    end

    if metadata.type == "boolean" then
        if value == true or value == 1 or value == "true" then
            return true
        end
        return false
    end

    if metadata.type == "string" then
        return tostring(value)
    end

    return fallback
end

function ConfigRepository.get(key)
    local fallback = StaticConfig.get(key)
    return resolveSandboxValue(key, fallback)
end

function ConfigRepository.getNumber(key)
    local value = ConfigRepository.get(key)
    return tonumber(value) or tonumber(StaticConfig.get(key)) or 0
end

function ConfigRepository.getInteger(key)
    return math_floor(ConfigRepository.getNumber(key))
end

function ConfigRepository.getBoolean(key)
    return ConfigRepository.get(key) == true
end

function ConfigRepository.getTable(key)
    local value = ConfigRepository.get(key)
    if type(value) == "table" then
        return value
    end
    return {}
end

local function parseFullTypeList(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local items = {}
    local seen = {}

    for token in string_gmatch(text, "[^,;]+") do
        local itemType = string_match(token, "^%s*(.-)%s*$")
        if itemType ~= "" and string_match(itemType, "^[%w_]+%.[%w_]+$") and not seen[itemType] then
            seen[itemType] = true
            items[#items + 1] = itemType
        end
    end

    if #items == 0 then
        return nil
    end

    return items
end

function ConfigRepository.getOpenBarrelRequiredItems()
    local items = parseFullTypeList(ConfigRepository.get(ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS_TEXT))
    if items then
        return items
    end

    return ConfigRepository.getTable(ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS)
end

function ConfigRepository.getPourRequiredItems()
    if ConfigRepository.getBoolean(ConfigKeys.REQUIRE_FUNNEL_TO_POUR) then
        return ConfigRepository.getTable(ConfigKeys.POUR_REQUIRED_ITEMS)
    end

    return {}
end

function ConfigRepository.getExtractRequiredItems()
    if ConfigRepository.getBoolean(ConfigKeys.REQUIRE_HOSE_TO_EXTRACT) then
        return ConfigRepository.getTable(ConfigKeys.EXTRACT_REQUIRED_ITEMS)
    end

    return {}
end

function ConfigRepository.getLiquidDistribution(category, spawnProfile)
    if category == "CRAFTED" and spawnProfile == "PLAYER_CRAFTED" then
        return EMPTY_DISTRIBUTION
    end

    local keyByLiquidType = DISTRIBUTION_KEYS[category]
    if type(keyByLiquidType) ~= "table" then
        return EMPTY_DISTRIBUTION
    end

    local distribution = {}
    local totalWeight = 0

    for liquidType, key in pairs(keyByLiquidType) do
        local weight = ConfigRepository.getInteger(key)
        distribution[liquidType] = weight
        totalWeight = totalWeight + weight
    end

    if totalWeight <= 0 then
        return EMPTY_DISTRIBUTION
    end

    return distribution
end

return ConfigRepository
