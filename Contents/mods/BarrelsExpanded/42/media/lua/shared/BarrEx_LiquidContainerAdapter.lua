local Constant  = require("BarrEx_Constant")
local SafeCall  = require("utils/BarrEx_SafeCall")

local Adapter = {}

local BARREL_TO_VANILLA_FLUID = {
    WATER = "Water",
    TAINTED_WATER = "TaintedWater",
    GASOLINE = "Petrol",
    BLEACH = "Bleach",
}

local VANILLA_TO_BARREL_FLUID = {
    water = Constant.LIQUID_TYPE.WATER,
    taintedwater = Constant.LIQUID_TYPE.TAINTED_WATER,
    petrol = Constant.LIQUID_TYPE.GASOLINE,
    gasoline = Constant.LIQUID_TYPE.GASOLINE,
    bleach = Constant.LIQUID_TYPE.BLEACH,
    cleaningliquid = Constant.LIQUID_TYPE.BLEACH,
}

local call = SafeCall.call

local function getItemFullType(item)
    if not item then return nil end
    return call(item, "getFullType")
end

local function isConfiguredCompatible(item, liquidType)
    if not item or not liquidType then return false end

    local byLiquid = Constant.COMPATIBLE_CONTAINERS[liquidType]
    if type(byLiquid) ~= "table" then
        return false
    end

    local fullType = getItemFullType(item)
    if type(fullType) ~= "string" then
        return false
    end

    return byLiquid[fullType] == true
end

local function mapVanillaFluidToBarrel(fluid)
    if not fluid then return nil end

    local fluidTypeString = call(fluid, "getFluidTypeString")
    if type(fluidTypeString) ~= "string" then
        return nil
    end

    local normalized = string.lower(string.gsub(fluidTypeString, "%s+", ""))
    return VANILLA_TO_BARREL_FLUID[normalized]
end

local function getFluidContainer(item)
    if not item then return nil end

    local container = call(item, "getFluidContainer")
    if container then return container end

    local worldItem = call(item, "getWorldItem")
    if worldItem then
        container = call(worldItem, "getFluidContainer")
        if container then return container end
    end

    return nil
end

local function hasDrainableFallback(item)
    if not item then return false end

    local hasUsedDeltaMethods = type(item.getUsedDelta) == "function" and type(item.setUsedDelta) == "function"
    local hasUseDelta = type(item.getUseDelta) == "function"
    return hasUsedDeltaMethods and hasUseDelta
end

local function getDrainableCapacity(item)
    local useDelta = tonumber(call(item, "getUseDelta")) or 0
    if useDelta <= 0 then
        return 0
    end

    return 1 / useDelta
end

local function syncItem(item)
    call(item, "syncItemFields")

    local container = call(item, "getContainer")
    call(container, "setDrawDirty", true)
end

local function findVanillaFluidObject(vanillaFluidName)
    if type(vanillaFluidName) ~= "string" then
        return nil
    end

    if Fluid and type(Fluid.Get) == "function" then
        local fluid = Fluid.Get(vanillaFluidName)
        if fluid then return fluid end
    end

    if FluidType and type(FluidType.FromNameLower) == "function" then
        local fluid = FluidType.FromNameLower(string.lower(vanillaFluidName))
        if fluid then return fluid end
    end

    return nil
end

function Adapter.isLiquidContainer(item)
    if not item then return false end

    if getFluidContainer(item) then
        return true
    end

    if hasDrainableFallback(item) then
        return true
    end

    -- Usar índice inverso para O(1) lookup en lugar de iterar sobre todas las compatibilidades.
    local fullType = getItemFullType(item)
    if type(fullType) ~= "string" then
        return false
    end

    return Constant.FULLTYPE_TO_LIQUIDS[fullType] ~= nil
end

function Adapter.getLiquidType(item)
    if not item then return nil end

    local container = getFluidContainer(item)
    if container then
        if call(container, "isEmpty") == true then
            return nil
        end

        local primary = call(container, "getPrimaryFluid")
        local mapped = mapVanillaFluidToBarrel(primary)
        if mapped then
            return mapped
        end
    end

    if hasDrainableFallback(item) then
        local amount = Adapter.getAmount(item)
        if amount <= 0 then
            return nil
        end

        local fullType = string.lower(getItemFullType(item) or "")
        if string.find(fullType, "petrol", 1, true) or string.find(fullType, "gas", 1, true) then
            return Constant.LIQUID_TYPE.GASOLINE
        end

        if string.find(fullType, "bleach", 1, true) then
            return Constant.LIQUID_TYPE.BLEACH
        end

        if string.find(fullType, "tainted", 1, true) then
            return Constant.LIQUID_TYPE.TAINTED_WATER
        end

        if string.find(fullType, "water", 1, true) then
            return Constant.LIQUID_TYPE.WATER
        end
    end

    return nil
end

function Adapter.getAmount(item)
    if not item then return 0 end

    local container = getFluidContainer(item)
    if container and type(container.getAmount) == "function" then
        return math.max(tonumber(container:getAmount()) or 0, 0)
    end

    if hasDrainableFallback(item) then
        local usedDelta = tonumber(call(item, "getUsedDelta")) or 0
        local capacity = getDrainableCapacity(item)
        if capacity <= 0 then return 0 end

        return math.max(usedDelta * capacity, 0)
    end

    return 0
end

function Adapter.getCapacity(item)
    if not item then return 0 end

    local container = getFluidContainer(item)
    if container and type(container.getCapacity) == "function" then
        return math.max(tonumber(container:getCapacity()) or 0, 0)
    end

    if hasDrainableFallback(item) then
        return math.max(getDrainableCapacity(item), 0)
    end

    return 0
end

function Adapter.getFreeCapacity(item)
    local capacity = Adapter.getCapacity(item)
    local amount = Adapter.getAmount(item)
    return math.max(capacity - amount, 0)
end

function Adapter.hasLiquid(item)
    return Adapter.getAmount(item) > 0
end

function Adapter.isEmpty(item)
    return Adapter.getAmount(item) <= 0
end

function Adapter.canReceive(item, liquidType)
    if not item then return false end
    if Constant.LIQUID_TYPE[liquidType] == nil then return false end
    if liquidType == Constant.LIQUID_TYPE.EMPTY then return false end
    if not Adapter.isLiquidContainer(item) then return false end
    if not isConfiguredCompatible(item, liquidType) then return false end

    local free = Adapter.getFreeCapacity(item)
    if free <= 0 then return false end

    local currentType = Adapter.getLiquidType(item)
    if not currentType then
        return true
    end

    return currentType == liquidType
end

function Adapter.canProvide(item, liquidType)
    if not item then return false end
    if not Adapter.isLiquidContainer(item) then return false end
    if not Adapter.hasLiquid(item) then return false end

    local currentType = Adapter.getLiquidType(item)
    if not currentType then
        return false
    end

    if not isConfiguredCompatible(item, currentType) then
        return false
    end

    if liquidType and currentType ~= liquidType then
        return false
    end

    return true
end

function Adapter.getTransferableAmount(source, target)
    if not source or not target then return 0 end

    local sourceAmount = Adapter.getAmount(source)
    local targetFree = Adapter.getFreeCapacity(target)
    return math.max(math.min(sourceAmount, targetFree), 0)
end

function Adapter.removeLiquid(item, amount)
    if not item or amount <= 0 then return 0 end

    local before = Adapter.getAmount(item)
    if before <= 0 then return 0 end

    local toRemove = math.min(amount, before)
    local container = getFluidContainer(item)

    if container then
        local targetAmount = math.max(before - toRemove, 0)

        -- Prefer semantic API calls first. In B42-like fluid containers,
        -- adjustAmount can be ambiguous across wrappers/modded objects, so keep it
        -- as a last-resort delta fallback instead of treating it as an absolute setter.
        if type(container.removeFluid) == "function" then
            container:removeFluid(toRemove, false)
        elseif type(container.setAmount) == "function" then
            container:setAmount(targetAmount)
        elseif targetAmount <= 0 and type(container.Empty) == "function" then
            container:Empty()
        elseif type(container.adjustAmount) == "function" then
            container:adjustAmount(-toRemove)
        end

        syncItem(item)
        local after = Adapter.getAmount(item)
        return math.max(before - after, 0)
    end

    if hasDrainableFallback(item) then
        local capacity = Adapter.getCapacity(item)
        if capacity <= 0 then return 0 end

        local afterAmount = math.max(before - toRemove, 0)
        local usedDelta = math.max(math.min(afterAmount / capacity, 1), 0)
        call(item, "setUsedDelta", usedDelta)
        syncItem(item)

        local after = Adapter.getAmount(item)
        return math.max(before - after, 0)
    end

    return 0
end

function Adapter.addLiquid(item, liquidType, amount)
    if not item or amount <= 0 then return 0 end
    if Constant.LIQUID_TYPE[liquidType] == nil then return 0 end
    if liquidType == Constant.LIQUID_TYPE.EMPTY then return 0 end

    local before = Adapter.getAmount(item)
    local capacity = Adapter.getCapacity(item)
    if capacity <= 0 then return 0 end

    local free = math.max(capacity - before, 0)
    if free <= 0 then return 0 end

    local toAdd = math.min(amount, free)
    local currentType = Adapter.getLiquidType(item)
    if currentType and currentType ~= liquidType then
        return 0
    end

    if not isConfiguredCompatible(item, liquidType) then
        return 0
    end

    local container = getFluidContainer(item)
    if container then
        local vanillaFluidName = BARREL_TO_VANILLA_FLUID[liquidType]
        local vanillaFluidObject = findVanillaFluidObject(vanillaFluidName)

        local beforeAmount = Adapter.getAmount(item)

        if type(container.addFluid) == "function" then
            if vanillaFluidObject then
                container:addFluid(vanillaFluidObject, toAdd)
            elseif vanillaFluidName then
                container:addFluid(vanillaFluidName, toAdd)
            end
        end

        local afterAmount = Adapter.getAmount(item)

        -- Fallback to direct amount adjustment when addFluid did not apply.
        -- Prefer setAmount when present; use adjustAmount only as a delta fallback.
        if afterAmount <= beforeAmount then
            local targetAmount = math.min(beforeAmount + toAdd, capacity)
            if type(container.setAmount) == "function" then
                container:setAmount(targetAmount)
            elseif type(container.adjustAmount) == "function" then
                container:adjustAmount(toAdd)
            end
        end

        syncItem(item)
        local after = Adapter.getAmount(item)
        return math.max(after - before, 0)
    end

    if hasDrainableFallback(item) then
        local targetAmount = math.min(before + toAdd, capacity)
        local usedDelta = math.max(math.min(targetAmount / capacity, 1), 0)
        call(item, "setUsedDelta", usedDelta)
        syncItem(item)

        local after = Adapter.getAmount(item)
        return math.max(after - before, 0)
    end

    return 0
end

return Adapter
