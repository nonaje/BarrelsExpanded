-- BarrEx_TransferLocks: barrel/player transfer lock management.
--
-- A barrel can only be involved in one active transfer at a time.
-- This module owns the lock state tables and all acquire/release operations
-- so that the rest of the transfer logic never has to touch raw lock tables.

local BarrEx_BarrelData = require("BarrEx_BarrelData")
local Constant = require("BarrEx_Constant")

local TransferLocks = {}

-- barrelKey → playerKey: which player currently holds each barrel.
local byBarrel = {}

--- Returns a stable key identifying the player for lock tracking.
--- Prefers the numeric online ID in MP; falls back to the player object itself.
---@param player IsoPlayer
---@return any|nil
function TransferLocks.getPlayerKey(player)
    if not player then return nil end

    if type(player.getOnlineID) == "function" then
        local onlineId = player:getOnlineID()
        if type(onlineId) == "number" and onlineId >= 0 then
            return onlineId
        end
    end

    return player
end

--- Returns a stable string key identifying the barrel for lock tracking.
---@param barrel IsoObject
---@param barrelData BarrEx_Barrel|nil
---@return string|nil
function TransferLocks.getBarrelKey(barrel, barrelData)
    if barrelData and type(barrelData.id) == "string" and barrelData.id ~= "" then
        return barrelData.id
    end

    local modData = barrel and barrel:getModData() or nil
    local storedId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
    if type(storedId) == "string" and storedId ~= "" then
        return storedId
    end

    return BarrEx_BarrelData.buildLocatorId(barrel)
end

--- Tries to acquire the barrel lock for playerKey.
--- Returns false (without acquiring) when a different player already holds the lock.
---@param playerKey any
---@param barrelKey string
---@return boolean
function TransferLocks.acquire(playerKey, barrelKey)
    if not playerKey or not barrelKey then return false end

    local existing = byBarrel[barrelKey]
    if existing ~= nil and existing ~= playerKey then
        return false
    end

    byBarrel[barrelKey] = playerKey
    return true
end

--- Releases the barrel lock held by playerKey.
--- No-op when playerKey does not match the current holder.
---@param playerKey any
---@param barrelKey string|nil
function TransferLocks.release(playerKey, barrelKey)
    if barrelKey and byBarrel[barrelKey] == playerKey then
        byBarrel[barrelKey] = nil
    end
end

--- Returns the playerKey currently holding the barrel lock, or nil when unlocked.
---@param barrelKey string|nil
---@return any|nil
function TransferLocks.isLockedBy(barrelKey)
    if not barrelKey then return nil end
    return byBarrel[barrelKey]
end

return TransferLocks
