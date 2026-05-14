local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

---@class BarrEx_OpenBarrelAction : ISBaseTimedAction
---@field barrel IsoObject
---@field tool InventoryItem
---@field anim string
---@field maxTime number
---@field stopOnWalk boolean
---@field stopOnRun boolean
local BarrEx_OpenBarrelAction = ISBaseTimedAction:derive("BarrEx_OpenBarrelAction")

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

--- @param player IsoPlayer
--- @param barrel IsoObject
--- @param tool InventoryItem
--- @return BarrEx_OpenBarrelAction
function BarrEx_OpenBarrelAction:new(player, barrel, tool)
    local o = ISBaseTimedAction.new(self, player)
    ---@cast o BarrEx_OpenBarrelAction

    o.barrel = barrel
    o.tool = tool
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = Constant.OPEN_BARREL_ACTION_TIME

    setmetatable(o, self)
    self.__index = self

    return o
end

function BarrEx_OpenBarrelAction:isValid()
    if BarrEx_BarrelData.exists(self.barrel) then return false end
    if not Utils.isPlayerInRange(self.character, self.barrel) then return false end
    return true
end

function BarrEx_OpenBarrelAction:start()
    ISBaseTimedAction.start(self)
    local square = self.barrel:getSquare()
    if square then
        self.character:faceLocation(square:getX(), square:getY())
    end
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:setPrimaryHandItem(self.tool)
end

function BarrEx_OpenBarrelAction:update()
    ISBaseTimedAction.update(self)
    self.character:faceThisObject(self.barrel)
    self.character:setPrimaryHandItem(self.tool)
end

function BarrEx_OpenBarrelAction:stop()
    self.character:ClearVariable("LootPosition")
    ISBaseTimedAction.stop(self)
end

function BarrEx_OpenBarrelAction:perform()
    self.character:ClearVariable("LootPosition")
    local barrel = self.barrel

    if BarrEx_BarrelData.exists(barrel) then
        log("Open ignored; barrel already initialized.")
        ISBaseTimedAction.perform(self)
        return
    end

    local square = barrel:getSquare()
    if not square then
        ISBaseTimedAction.perform(self)
        return
    end

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.OPEN_BARREL, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = barrel:getObjectIndex()
    })

    local ticks = 0
    local function onTick()
        ticks = ticks + 1

        local barrelData = BarrEx_BarrelData.get(barrel)
        if barrelData then
            local liquidType = barrelData.liquidType or "EMPTY"
            log(string.format(
                "Barrel data synced: id=%s, liquid=%s, amount=%d/%d",
                barrelData.id or "N/A",
                liquidType,
                barrelData.amount,
                barrelData.capacity
            ))
            Events.OnTick.Remove(onTick)
            return
        end

        if ticks >= Constant.BARREL_DATA_POLL_TICKS then
            log("Barrel data not available yet.")
            Events.OnTick.Remove(onTick)
        end
    end

    Events.OnTick.Add(onTick)
    ISBaseTimedAction.perform(self)
end

return BarrEx_OpenBarrelAction
