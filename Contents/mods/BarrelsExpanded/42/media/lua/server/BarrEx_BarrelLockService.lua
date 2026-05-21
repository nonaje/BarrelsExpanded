-- BarrEx_BarrelLockService: shared lock ownership for all barrel mutations.

local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

local LockService = {}

local byBarrel = {}

local function normalizeKeys(barrelKeys)
    local keys = {}
    local seen = {}

    if type(barrelKeys) ~= "table" then
        return keys
    end

    for i = 1, #barrelKeys do
        local key = barrelKeys[i]
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

---@param player IsoPlayer
---@return any|nil
function LockService.getPlayerKey(player)
    if not player then return nil end

    if type(player.getOnlineID) == "function" then
        local onlineId = player:getOnlineID()
        if type(onlineId) == "number" and onlineId >= 0 then
            return onlineId
        end
    end

    return player
end

---@param barrel IsoObject
---@param barrelData BarrEx_Barrel|nil
---@return string|nil
function LockService.getBarrelKey(barrel, barrelData)
    if barrelData then
        BarrEx_BarrelData.ensureStableId(barrel, barrelData)
        if type(barrelData.id) == "string" and barrelData.id ~= "" then
            return barrelData.id
        end
    end

    local modData = barrel and barrel:getModData() or nil
    local storedId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
    if type(storedId) == "string" and storedId ~= "" then
        return storedId
    end

    return nil
end

---@param playerKey any
---@param barrelKey string
---@param mode string
---@param actionId string|number|nil
---@return boolean
---@return table|nil
function LockService.acquire(playerKey, barrelKey, mode, actionId)
    if not playerKey or not barrelKey then return false, nil end

    local existing = byBarrel[barrelKey]
    if existing ~= nil then
        return false, existing
    end

    byBarrel[barrelKey] = {
        playerKey = playerKey,
        mode = mode or "short",
        actionId = actionId,
    }
    return true, byBarrel[barrelKey]
end

---@param playerKey any
---@param barrelKeys table<integer, string>
---@param mode string
---@param actionId string|number|nil
---@return boolean
---@return table|nil
---@return string|nil
function LockService.acquireMany(playerKey, barrelKeys, mode, actionId)
    if not playerKey then return false, nil, nil end

    local keys = normalizeKeys(barrelKeys)
    if #keys == 0 then return false, nil, nil end

    local acquired = {}
    for i = 1, #keys do
        local key = keys[i]
        local ok, existing = LockService.acquire(playerKey, key, mode, actionId)
        if not ok then
            for j = 1, #acquired do
                LockService.release(playerKey, acquired[j])
            end
            return false, existing, key
        end
        acquired[#acquired + 1] = key
    end

    return true, keys, nil
end

---@param playerKey any
---@param barrelKey string|nil
function LockService.release(playerKey, barrelKey)
    if not barrelKey then return end

    local existing = byBarrel[barrelKey]
    if existing and existing.playerKey == playerKey then
        byBarrel[barrelKey] = nil
    end
end

---@param playerKey any
---@param barrelKeys table<integer, string>|nil
function LockService.releaseMany(playerKey, barrelKeys)
    local keys = normalizeKeys(barrelKeys)
    for i = 1, #keys do
        LockService.release(playerKey, keys[i])
    end
end

---@param barrelKey string|nil
---@return any|nil
function LockService.isLockedBy(barrelKey)
    local existing = barrelKey and byBarrel[barrelKey] or nil
    return existing and existing.playerKey or nil
end

---@param playerKey any
---@param barrelKeys table<integer, string>|nil
---@return boolean
function LockService.isLockedByAll(playerKey, barrelKeys)
    if not playerKey then return false end

    local keys = normalizeKeys(barrelKeys)
    if #keys == 0 then return false end

    for i = 1, #keys do
        if LockService.isLockedBy(keys[i]) ~= playerKey then
            return false
        end
    end

    return true
end

---@param barrelKey string|nil
---@return table|nil
function LockService.getLock(barrelKey)
    if not barrelKey then return nil end
    return byBarrel[barrelKey]
end

return LockService
