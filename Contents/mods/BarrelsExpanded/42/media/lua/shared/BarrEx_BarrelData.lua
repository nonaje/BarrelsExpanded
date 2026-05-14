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

    -- Backward compat: if 'revealed' is absent the data was written by the old system,
    -- which only stored data for already-opened barrels. Treat nil as true.
    local revealed
    if rawData.revealed == nil then
        revealed = true
    else
        revealed = rawData.revealed == true
    end

    return BarrEx_Barrel:new({
        id = barrelId,
        liquidType = liquidType,
        amount = amount,
        capacity = capacity,
        revealed = revealed,
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

    local raw = modData[Constant.MODDATA_KEYS.BARREL]
    if type(raw) ~= "table" then return nil end

    -- Only compute the expensive buildId (4 Java calls) when the stored id is
    -- absent or invalid. In normal operation the id is always present, so this
    -- avoids 4 redundant Java bridge calls on the hot get() path.
    local fallbackId = type(raw.id) ~= "string" and BarrEx_BarrelData.buildId(barrel) or nil
    return BarrEx_BarrelData.fromRawData(raw, fallbackId)
end

--- Returns whether the barrel's contents have been revealed to the player.
--- @param barrel IsoObject|nil
--- @return boolean
function BarrEx_BarrelData.isRevealed(barrel)
    local barrelData = BarrEx_BarrelData.get(barrel)
    return barrelData ~= nil and barrelData:isRevealed()
end

--- Fast check of the revealed flag without full deserialization.
--- Use this in hot paths (called every game tick or every cursor frame)
--- instead of isRevealed() to avoid the buildId + table allocation overhead.
--- Backward compat: absent 'revealed' key means old opened barrel data.
--- @param barrel IsoObject|nil
--- @return boolean
function BarrEx_BarrelData.isRevealedRaw(barrel)
    if not barrel then return false end
    local modData = barrel:getModData()
    if not modData then return false end
    local raw = modData[Constant.MODDATA_KEYS.BARREL]
    if type(raw) ~= "table" then return false end
    if raw.revealed == nil then return true end
    return raw.revealed == true
end

--- Writes barrel data into modData.
--- Inlines writeToModData + applyWeight to eliminate a duplicate getModData()
--- Java call, a duplicate toData() allocation, and a duplicate getTotalWeight()
--- computation that the split call-chain would otherwise produce.
--- @param barrel IsoObject|nil
--- @param barrelData BarrEx_Barrel|nil
function BarrEx_BarrelData.set(barrel, barrelData)
    if not barrel or not barrelData then return end

    local modData = barrel:getModData()
    if not modData then return end

    -- Only compute the expensive buildId (4 Java calls) when barrelData.id is
    -- absent or invalid. In the common path the id is already set by the caller.
    local fallbackId = type(barrelData.id) ~= "string" and BarrEx_BarrelData.buildId(barrel) or nil
    local normalized = normalizeBarrelData(barrelData, fallbackId)
    if not normalized then return end

    local serialized = normalized:toData()
    local weight = normalized:getTotalWeight()

    modData[Constant.MODDATA_KEYS.BARREL] = serialized
    modData[Constant.MODDATA_KEYS.BARREL_ID] = serialized.id
    modData[Constant.MODDATA_KEYS.BARREL_WEIGHT] = weight

    call(barrel, "setCustomWeight", true)
    call(barrel, "setWeight", weight)
end

--- Re-applies the cached weight to the Java world object without deserializing barrel data.
--- Custom weights do not persist across game sessions; call this after a square reloads
--- from disk to restore the correct weight on the IsoObject.
--- Returns true when the cached weight was found and applied, false when the barrel
--- has no cached weight (caller should fall back to a full reconcile).
--- @param barrel IsoObject|nil
--- @return boolean
function BarrEx_BarrelData.reapplyWeight(barrel)
    if not barrel then return false end

    local modData = barrel:getModData()
    if not modData then return false end

    local weight = modData[Constant.MODDATA_KEYS.BARREL_WEIGHT]
    if type(weight) ~= "number" then return false end

    call(barrel, "setCustomWeight", true)
    call(barrel, "setWeight", weight)
    return true
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
