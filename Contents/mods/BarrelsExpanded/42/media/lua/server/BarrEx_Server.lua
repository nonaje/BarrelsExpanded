local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelFactory = require("BarrEx_BarrelFactory")

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

--- @param args table|nil
--- @return IsoObject|nil
local function getBarrelFromArgs(args)
    if not args then return nil end
    if args.x == nil or args.y == nil or args.z == nil or args.objectIndex == nil then return nil end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    if args.objectIndex < 0 or args.objectIndex >= objects:size() then
        return nil
    end

    local object = objects:get(args.objectIndex)
    if not Utils.isExpandableBarrel(object) then return nil end

    return object
end

--- @param player IsoPlayer
--- @param args table
local function onOpenBarrel(player, args)
    local barrel = getBarrelFromArgs(args)
    if not barrel then return end

    local barrelData = BarrEx_BarrelFactory.createRandom(barrel)
    BarrEx_BarrelData.set(barrel, barrelData)

    barrel:transmitModData()
    log("Barrel opened: " .. (barrelData.id or "unknown"))
end

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        onOpenBarrel(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
