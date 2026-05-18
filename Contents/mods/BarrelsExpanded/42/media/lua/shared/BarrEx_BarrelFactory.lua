local Constant = require("BarrEx_Constant")
local BarrEx_Barrel = require("BarrEx_Barrel")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local ConfigRepository = require("config/BarrEx_ConfigRepository")
local WorldUtils = require("utils/BarrEx_WorldUtils")

local BarrEx_BarrelFactory = {}
local compiledDistributions = {}

local function getDistribution(category, spawnProfile)
    if category == Constant.BARREL_TILE_CATEGORY.INDUSTRIAL then
        return ConfigRepository.getLiquidDistribution(category, spawnProfile)
    end

    if category == Constant.BARREL_TILE_CATEGORY.MILITARY then
        return ConfigRepository.getLiquidDistribution(category, spawnProfile)
    end

    if category == Constant.BARREL_TILE_CATEGORY.CRAFTED then
        return ConfigRepository.getLiquidDistribution(category, spawnProfile)
    end

    return ConfigRepository.getLiquidDistribution(nil, spawnProfile)
end

local function compileDistribution(distribution)
    if type(distribution) ~= "table" then
        return nil
    end

    local entries = {}
    local totalWeight = 0
    local sortedLiquidTypes = {}

    for liquidType, _ in pairs(distribution) do
        sortedLiquidTypes[#sortedLiquidTypes + 1] = liquidType
    end

    table.sort(sortedLiquidTypes)

    for i = 1, #sortedLiquidTypes do
        local liquidType = sortedLiquidTypes[i]
        local weight = distribution[liquidType]
        local normalizedWeight = tonumber(weight) or 0
        if Constant.LIQUID_TYPE[liquidType] and normalizedWeight > 0 then
            totalWeight = totalWeight + normalizedWeight
            entries[#entries + 1] = {
                liquidType = liquidType,
                cumulative = totalWeight,
            }
        end
    end

    if totalWeight <= 0 or #entries == 0 then
        return nil
    end

    return {
        entries = entries,
        totalWeight = totalWeight,
    }
end

local function getCompiledDistribution(distribution)
    local compiled = compiledDistributions[distribution]
    if compiled ~= nil then
        return compiled
    end

    compiled = compileDistribution(distribution)
    compiledDistributions[distribution] = compiled or false
    if compiledDistributions[distribution] == false then
        return nil
    end

    return compiled
end

local function getWeightedRandomLiquidType(distribution)
    local compiled = getCompiledDistribution(distribution)
    if not compiled then
        return Constant.LIQUID_TYPE.EMPTY
    end

    local roll = ZombRand(1, compiled.totalWeight + 1)
    for i = 1, #compiled.entries do
        local entry = compiled.entries[i]
        if roll <= entry.cumulative then
            return entry.liquidType
        end
    end

    return Constant.LIQUID_TYPE.EMPTY
end

--- Creates a new barrel instance with random contents.
--- @param barrel IsoObject|nil
--- @param options table|nil
--- @return BarrEx_Barrel
function BarrEx_BarrelFactory.createRandom(barrel, options)
    options = options or {}

    local spawnProfile = options.spawnProfile or Constant.BARREL_SPAWN_PROFILE.WORLD
    local category = options.category or WorldUtils.getBarrelCategory(barrel)
    local distribution = getDistribution(category, spawnProfile)

    local capacity = Constant.BARREL_DEFAULT_CAPACITY
    local liquidType = getWeightedRandomLiquidType(distribution)
    local amount = liquidType == Constant.LIQUID_TYPE.EMPTY and 0 or ZombRand(1, capacity + 1)

    return BarrEx_Barrel:new({
        id = BarrEx_BarrelData.ensureStableId(barrel, nil),
        liquidType = liquidType,
        amount = amount,
        capacity = capacity,
        revealed = false,
    })
end

return BarrEx_BarrelFactory
