-- BarrEx_BarrelResolver: resolves world barrel objects from client-sent identity args.
--
-- Object indexes are only hints in MP.  The authoritative server resolves by
-- barrel id first, then verifies objectIndex/sprite, then scans nearby squares.

local WorldUtils     = require("utils/BarrEx_WorldUtils")
local Constant       = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local SafeCall       = require("utils/BarrEx_SafeCall")

local BarrelResolver = {}

local call = SafeCall.call
local SEARCH_RADIUS = 1

local function getCellSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

local function getBarrelId(barrel)
    local modData = call(barrel, "getModData")
    local storedId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
    if type(storedId) == "string" and storedId ~= "" then
        return storedId
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    return barrelData and barrelData.id or nil
end

local function argsHaveBarrelId(args)
    return type(args and args.barrelId) == "string" and args.barrelId ~= ""
end

local function argsHaveSpriteName(args)
    return type(args and args.spriteName) == "string" and args.spriteName ~= ""
end

local function spriteMatchesArgs(barrel, args)
    if not argsHaveSpriteName(args) then return true end
    return WorldUtils.getSpriteName(barrel) == args.spriteName
end

local function idMatchesArgs(barrel, args)
    if not argsHaveBarrelId(args) then return true end
    return getBarrelId(barrel) == args.barrelId
end

--- Returns true when the barrel matches the id / sprite constraints in args.
---@param barrel IsoObject
---@param args table
---@return boolean
local function barrelMatchesArgs(barrel, args)
    if not barrel or not args then return false end

    return spriteMatchesArgs(barrel, args) and idMatchesArgs(barrel, args)
end

local function collectBarrelsOnSquare(square, args, requireId)
    local matches = {}
    if not square then return matches end

    local objects = square:getObjects()
    if not objects then return matches end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if WorldUtils.isExpandableBarrel(object)
            and spriteMatchesArgs(object, args)
            and (not requireId or idMatchesArgs(object, args))
        then
            matches[#matches + 1] = object
        end
    end

    return matches
end

local function chooseUnique(matches)
    if #matches == 1 then
        return matches[1], nil
    end
    if #matches > 1 then
        return nil, "ambiguous_barrel"
    end
    return nil, "barrel_not_found"
end

local function getIndexedBarrel(square, args)
    if not square or type(args.objectIndex) ~= "number" then return nil end

    local objects = square:getObjects()
    if not objects then return nil end
    if args.objectIndex < 0 or args.objectIndex >= objects:size() then return nil end

    local object = objects:get(args.objectIndex)
    if WorldUtils.isExpandableBarrel(object) and barrelMatchesArgs(object, args) then
        return object
    end

    return nil
end

local function collectNearbyMatches(args, requireId)
    local matches = {}

    for dx = -SEARCH_RADIUS, SEARCH_RADIUS do
        for dy = -SEARCH_RADIUS, SEARCH_RADIUS do
            if dx ~= 0 or dy ~= 0 then
                local square = getCellSquare(args.x + dx, args.y + dy, args.z)
                local squareMatches = collectBarrelsOnSquare(square, args, requireId)
                for i = 1, #squareMatches do
                    matches[#matches + 1] = squareMatches[i]
                end
            end
        end
    end

    return matches
end

--- Locates the barrel IsoObject described by client args.
---@param args table|nil
---@return IsoObject|nil
---@return string|nil
function BarrelResolver.resolve(args)
    if not args then return nil, "invalid_args" end
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then
        return nil, "invalid_args"
    end

    local square = getCellSquare(args.x, args.y, args.z)
    local hasId = argsHaveBarrelId(args)

    if hasId then
        local matches = collectBarrelsOnSquare(square, args, true)
        local barrel, reason = chooseUnique(matches)
        if barrel then return barrel, nil end
        if reason == "ambiguous_barrel" then return nil, reason end

        matches = collectNearbyMatches(args, true)
        return chooseUnique(matches)
    end

    local indexedBarrel = getIndexedBarrel(square, args)
    if indexedBarrel then return indexedBarrel, nil end

    local matches = collectBarrelsOnSquare(square, args, false)
    local barrel, reason = chooseUnique(matches)
    if barrel then return barrel, nil end
    if reason == "ambiguous_barrel" then return nil, reason end

    matches = collectNearbyMatches(args, false)
    return chooseUnique(matches)
end

--- Legacy-shaped helper for callers that only need the object.
---@param args table|nil
---@return IsoObject|nil
function BarrelResolver.getBarrelFromArgs(args)
    local barrel = BarrelResolver.resolve(args)
    return barrel
end

return BarrelResolver
