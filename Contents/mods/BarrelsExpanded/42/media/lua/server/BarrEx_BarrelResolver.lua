-- BarrEx_BarrelResolver: resolves world barrel objects from client-sent coordinate args.
--
-- Barrel lookup is its own concern: client args contain coordinates and object index,
-- but object indexes shift in MP when squares change.  This module encapsulates the
-- fallback scan logic in one place.

local WorldUtils     = require("utils/BarrEx_WorldUtils")
local Constant       = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local SafeCall       = require("utils/BarrEx_SafeCall")

local BarrelResolver = {}

local call = SafeCall.call

local function isStableBarrelId(barrelId)
    return type(barrelId) == "string" and string.sub(barrelId, 1, 5) == "BARR_"
end

--- Returns true when the barrel matches the id / sprite constraints in args.
---@param barrel IsoObject
---@param args table
---@return boolean
local function barrelMatchesArgs(barrel, args)
    if not barrel or not args then return false end

    if type(args.spriteName) == "string" and args.spriteName ~= "" then
        local spriteName = WorldUtils.getSpriteName(barrel)
        if spriteName ~= args.spriteName then
            return false
        end
    end

    if type(args.barrelId) == "string" and args.barrelId ~= "" then
        local modData = call(barrel, "getModData")
        local storedId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
        if storedId == args.barrelId then
            return true
        end

        local barrelData = BarrEx_BarrelData.get(barrel)
        if barrelData and barrelData.id == args.barrelId then
            return true
        end

        if BarrEx_BarrelData.buildLocatorId(barrel) == args.barrelId then
            return true
        end

        return not isStableBarrelId(args.barrelId)
    end

    return true
end

--- Locates the barrel IsoObject described by client args.
--- First tries the objectIndex hint for performance; falls back to a full square scan
--- to handle index shifts in MP.
---@param args table|nil
---@return IsoObject|nil
function BarrelResolver.getBarrelFromArgs(args)
    if not args then return nil end
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then return nil end

    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(args.x, args.y, args.z)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    if type(args.objectIndex) == "number" and args.objectIndex >= 0 and args.objectIndex < objects:size() then
        local object = objects:get(args.objectIndex)
        if WorldUtils.isExpandableBarrel(object) and barrelMatchesArgs(object, args) then
            return object
        end
    end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if WorldUtils.isExpandableBarrel(object) and barrelMatchesArgs(object, args) then
            return object
        end
    end

    return nil
end

return BarrelResolver
