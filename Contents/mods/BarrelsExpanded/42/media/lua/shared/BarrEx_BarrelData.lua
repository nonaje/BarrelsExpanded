local Constant = require("BarrEx_Constant")
local BarrEx_Barrel = require("BarrEx_Barrel")

local BarrEx_BarrelData = {}

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

    local data = modData[Constant.MODDATA_KEYS.BARREL]
    if not data then return nil end

    return BarrEx_Barrel:fromData(data)
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

    modData[Constant.MODDATA_KEYS.BARREL] = barrelData:toData()
end

return BarrEx_BarrelData
