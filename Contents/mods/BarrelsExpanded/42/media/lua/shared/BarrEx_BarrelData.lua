local Constant    = require("BarrEx_Constant")
local BarrEx_Barrel = require("BarrEx_Barrel")
local SafeCall    = require("utils/BarrEx_SafeCall")

local BarrEx_BarrelData = {}

local call = SafeCall.call

--- @param rawData table|nil
--- @return BarrEx_Barrel|nil
function BarrEx_BarrelData.fromRawData(rawData)
    if type(rawData) ~= "table" then return nil end

    local emptyType = Constant.LIQUID_TYPE.EMPTY
    local liquidType = type(rawData.liquidType) == "string" and rawData.liquidType or emptyType
    if Constant.LIQUID_TYPE[liquidType] == nil then
        liquidType = emptyType
    end

    local capacity = tonumber(rawData.capacity) or Constant.BARREL_DEFAULT_CAPACITY or 0
    capacity = math.max(capacity, 0)

    local amount = tonumber(rawData.amount) or 0
    amount = math.max(amount, 0)

    if liquidType == emptyType then
        amount = 0
    elseif amount > capacity then
        amount = capacity
    end

    local barrelId = type(rawData.id) == "string" and rawData.id or nil
    local revealed = rawData.revealed == true
    local revision = math.max(math.floor(tonumber(rawData.revision) or 0), 0)

    return BarrEx_Barrel:new({
        id = barrelId,
        liquidType = liquidType,
        amount = amount,
        capacity = capacity,
        revealed = revealed,
        revision = revision,
    })
end

--- @param barrelData BarrEx_Barrel|table|nil
--- @return BarrEx_Barrel|nil
local function normalizeBarrelData(barrelData)
    if not barrelData then return nil end

    local data = barrelData.toData and barrelData:toData() or barrelData
    return BarrEx_BarrelData.fromRawData(data)
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

local function buildStableId(barrel)
    local square = barrel and barrel:getSquare() or nil
    local x = square and square:getX() or "x"
    local y = square and square:getY() or "y"
    local z = square and square:getZ() or "z"
    local timestamp = type(getTimestampMs) == "function" and getTimestampMs()
        or (type(getTimestamp) == "function" and getTimestamp() or (os and os.time and os.time() or 0))
    local random = type(ZombRand) == "function" and ZombRand(1000000000)
        or math.random(1000000000)

    return "BARR_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
        .. "_" .. tostring(timestamp) .. "_" .. tostring(random)
end

--- Increments the barrel data revision after a real authoritative mutation.
--- @param barrelData BarrEx_Barrel|nil
--- @return number
function BarrEx_BarrelData.bumpRevision(barrelData)
    if not barrelData then return 0 end

    local nextRevision = math.max(math.floor(tonumber(barrelData.revision) or 0), 0) + 1
    barrelData.revision = nextRevision
    return nextRevision
end

--- Ensures barrelData.id / modData[BARREL_ID] are a persistent barrel identity.
--- @param barrel IsoObject|nil
--- @param barrelData BarrEx_Barrel|table|nil
--- @return string|nil
--- @return boolean changed
function BarrEx_BarrelData.ensureStableId(barrel, barrelData)
    local modData = barrel and barrel:getModData() or nil
    local storedId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
    local dataId = barrelData and type(barrelData.id) == "string" and barrelData.id ~= "" and barrelData.id or nil

    local stableId = nil
    if type(storedId) == "string" and storedId ~= "" then
        stableId = storedId
    elseif dataId then
        stableId = dataId
    end
    local changed = false

    if not stableId then
        stableId = buildStableId(barrel)
        changed = true
    end

    if barrelData and barrelData.id ~= stableId then
        barrelData.id = stableId
        changed = true
    end

    if modData and modData[Constant.MODDATA_KEYS.BARREL_ID] ~= stableId then
        modData[Constant.MODDATA_KEYS.BARREL_ID] = stableId
        changed = true
    end

    return stableId, changed
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

    return BarrEx_BarrelData.fromRawData(raw)
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
--- instead of isRevealed() to avoid table allocation overhead.
--- @param barrel IsoObject|nil
--- @return boolean
function BarrEx_BarrelData.isRevealedRaw(barrel)
    if not barrel then return false end
    local modData = barrel:getModData()
    if not modData then return false end
    local raw = modData[Constant.MODDATA_KEYS.BARREL]
    if type(raw) ~= "table" then return false end
    return raw.revealed == true
end

--- Writes barrel data into modData.
--- Inlines writeToModData + applyWeight to eliminate a duplicate getModData()
--- Java call, a duplicate toData() allocation, and a duplicate getTotalWeight()
--- computation that the split call-chain would otherwise produce.
--- @param barrel IsoObject|nil
--- @param barrelData BarrEx_Barrel|nil
--- @return boolean changed
function BarrEx_BarrelData.set(barrel, barrelData)
    if not barrel or not barrelData then return false end

    local modData = barrel:getModData()
    if not modData then return false end

    local _, idChanged = BarrEx_BarrelData.ensureStableId(barrel, barrelData)
    local normalized = normalizeBarrelData(barrelData)
    if not normalized then return false end

    local serialized = normalized:toData()
    local weight = normalized:getTotalWeight()
    local existing = modData[Constant.MODDATA_KEYS.BARREL]
    local changed = idChanged == true
        or type(existing) ~= "table"
        or existing.id ~= serialized.id
        or existing.liquidType ~= serialized.liquidType
        or tonumber(existing.amount) ~= tonumber(serialized.amount)
        or tonumber(existing.capacity) ~= tonumber(serialized.capacity)
        or existing.revealed ~= serialized.revealed
        or tonumber(existing.revision) ~= tonumber(serialized.revision)
        or modData[Constant.MODDATA_KEYS.BARREL_ID] ~= serialized.id
        or modData[Constant.MODDATA_KEYS.BARREL_WEIGHT] ~= weight

    modData[Constant.MODDATA_KEYS.BARREL] = serialized
    modData[Constant.MODDATA_KEYS.BARREL_ID] = serialized.id
    modData[Constant.MODDATA_KEYS.BARREL_WEIGHT] = weight

    call(barrel, "setCustomWeight", true)
    call(barrel, "setWeight", weight)

    return changed
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

--- @param rawProfile string|nil
--- @return string|nil
local function normalizeSpawnProfile(rawProfile)
    if rawProfile == Constant.BARREL_SPAWN_PROFILE.WORLD then
        return Constant.BARREL_SPAWN_PROFILE.WORLD
    end

    if rawProfile == Constant.BARREL_SPAWN_PROFILE.PLAYER_CRAFTED then
        return Constant.BARREL_SPAWN_PROFILE.PLAYER_CRAFTED
    end

    return nil
end

--- @param modData table|nil
--- @param spawnProfile string|nil
function BarrEx_BarrelData.writeSpawnProfile(modData, spawnProfile)
    if not modData then return end

    local normalized = normalizeSpawnProfile(spawnProfile)
    if normalized then
        modData[Constant.MODDATA_KEYS.BARREL_SPAWN_PROFILE] = normalized
    else
        modData[Constant.MODDATA_KEYS.BARREL_SPAWN_PROFILE] = nil
    end
end

--- @param barrel IsoObject|nil
--- @return string|nil
function BarrEx_BarrelData.getSpawnProfile(barrel)
    if not barrel then return nil end

    local modData = barrel:getModData()
    if not modData then return nil end

    return normalizeSpawnProfile(modData[Constant.MODDATA_KEYS.BARREL_SPAWN_PROFILE])
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
    BarrEx_BarrelData.writeSpawnProfile(itemModData, Constant.BARREL_SPAWN_PROFILE.WORLD)
    BarrEx_BarrelData.applyWeightToItem(item, barrelData)

    return barrelData
end

return BarrEx_BarrelData
