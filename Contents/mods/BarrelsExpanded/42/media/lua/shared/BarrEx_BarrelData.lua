local Constant = require("BarrEx_Constant")
local BarrEx_Barrel = require("BarrEx_Barrel")

local BarrEx_BarrelData = {}

local function call(target, methodName, ...)
    if not target then return nil end

    local method = target[methodName]
    if type(method) ~= "function" then
        return nil
    end

    return method(target, ...)
end

--- @param rawData table|nil
--- @param fallbackId string|nil
--- @return BarrEx_Barrel|nil
function BarrEx_BarrelData.fromRawData(rawData, fallbackId)
    if type(rawData) ~= "table" then return nil end

    local liquidType = rawData.liquidType
    if liquidType ~= nil and Constant.LIQUID_TYPE[liquidType] == nil then
        liquidType = nil
    end

    local capacity = tonumber(rawData.capacity) or Constant.BARREL_DEFAULT_CAPACITY or 0
    capacity = math.max(capacity, 0)

    local amount = tonumber(rawData.amount) or 0
    amount = math.max(amount, 0)

    if liquidType == nil then
        amount = 0
    elseif amount > capacity then
        amount = capacity
    end

    local barrelId = type(rawData.id) == "string" and rawData.id or fallbackId

    return BarrEx_Barrel:new({
        id = barrelId,
        liquidType = liquidType,
        amount = amount,
        capacity = capacity,
    })
end

--- @param barrelData BarrEx_Barrel|table|nil
--- @param fallbackId string|nil
--- @return BarrEx_Barrel|nil
local function normalizeBarrelData(barrelData, fallbackId)
    if not barrelData then return nil end

    local data = barrelData.toData and barrelData:toData() or barrelData
    return BarrEx_BarrelData.fromRawData(data, fallbackId)
end

--- @param modData table|nil
--- @param barrelData BarrEx_Barrel|nil
function BarrEx_BarrelData.writeToModData(modData, barrelData)
    if not modData or not barrelData then return end

    local serialized = barrelData:toData()
    modData[Constant.MODDATA_KEYS.BARREL] = serialized
    modData[Constant.MODDATA_KEYS.BARREL_ID] = serialized.id
    modData[Constant.MODDATA_KEYS.BARREL_WEIGHT] = barrelData:getTotalWeight()
end

--- @param barrelData BarrEx_Barrel|nil
--- @return number
function BarrEx_BarrelData.getWeight(barrelData)
    if not barrelData then
        return Constant.BARREL_EMPTY_WEIGHT or 0
    end

    return barrelData:getTotalWeight()
end

--- @param barrel IsoObject|nil
--- @param barrelData BarrEx_Barrel|nil
function BarrEx_BarrelData.applyWeight(barrel, barrelData)
    if not barrel then return end

    local weight = BarrEx_BarrelData.getWeight(barrelData)
    local modData = barrel:getModData()
    if modData then
        modData[Constant.MODDATA_KEYS.BARREL_WEIGHT] = weight
    end

    call(barrel, "setCustomWeight", true)
    call(barrel, "setWeight", weight)
end

--- @param item InventoryItem|nil
--- @param barrelData BarrEx_Barrel|nil
function BarrEx_BarrelData.applyWeightToItem(item, barrelData)
    if not item then return end

    local weight = BarrEx_BarrelData.getWeight(barrelData)
    call(item, "setCustomWeight", true)
    call(item, "setActualWeight", weight)
    call(item, "setWeight", weight)
end

--- Builds a stable ID for a barrel based on world position and object index.
--- @param barrel IsoObject|nil
--- @return string|nil
function BarrEx_BarrelData.buildId(barrel)
    if not barrel then return nil end

    local square = barrel:getSquare()
    if not square then return nil end

    local objectIndex = barrel:getObjectIndex()
    local x, y, z = square:getX(), square:getY(), square:getZ()

    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z) .. ":" .. tostring(objectIndex)
end

--- Reads the barrel data stored in modData.
--- @param barrel IsoObject|nil
--- @return BarrEx_Barrel|nil
function BarrEx_BarrelData.get(barrel)
    if not barrel then return nil end

    local modData = barrel:getModData()
    if not modData then return nil end

    return BarrEx_BarrelData.fromRawData(modData[Constant.MODDATA_KEYS.BARREL], BarrEx_BarrelData.buildId(barrel))
end

--- Returns whether the barrel already has persisted data.
--- @param barrel IsoObject|nil
--- @return boolean
function BarrEx_BarrelData.exists(barrel)
    return BarrEx_BarrelData.get(barrel) ~= nil
end

--- Writes barrel data into modData.
--- @param barrel IsoObject|nil
--- @param barrelData BarrEx_Barrel|nil
function BarrEx_BarrelData.set(barrel, barrelData)
    if not barrel or not barrelData then return end

    local modData = barrel:getModData()
    if not modData then return end

    local normalized = normalizeBarrelData(barrelData, BarrEx_BarrelData.buildId(barrel))
    if not normalized then return end

    BarrEx_BarrelData.writeToModData(modData, normalized)
    BarrEx_BarrelData.applyWeight(barrel, normalized)
end

--- @param barrel IsoObject|nil
--- @return BarrEx_Barrel|nil
function BarrEx_BarrelData.reconcileWorldObject(barrel)
    if not barrel then return nil end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then return nil end

    barrelData.id = BarrEx_BarrelData.buildId(barrel)
    BarrEx_BarrelData.set(barrel, barrelData)

    return barrelData
end

--- @param barrel IsoObject|nil
--- @param item InventoryItem|nil
--- @return BarrEx_Barrel|nil
function BarrEx_BarrelData.copyWorldDataToItem(barrel, item)
    if not barrel or not item then return nil end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData then return nil end

    local itemModData = call(item, "getModData")
    if not itemModData then return nil end

    BarrEx_BarrelData.writeToModData(itemModData, barrelData)
    BarrEx_BarrelData.applyWeightToItem(item, barrelData)

    return barrelData
end

return BarrEx_BarrelData
