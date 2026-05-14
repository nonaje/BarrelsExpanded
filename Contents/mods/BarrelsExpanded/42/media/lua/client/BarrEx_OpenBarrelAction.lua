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
    -- Allow nil barrelData: the barrel may not have synced from the server yet
    -- (race condition on multiplayer chunk load). The server handles lazy init.
    -- isRevealedRaw avoids full deserialization (no buildId + table alloc) every tick.
    if BarrEx_BarrelData.isRevealedRaw(self.barrel) then return false end
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

    if BarrEx_BarrelData.isRevealedRaw(barrel) then
        log("Open ignored; barrel already revealed.")
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

        if BarrEx_BarrelData.isRevealedRaw(barrel) then
            -- Full get() only on success, not every tick while waiting.
            local barrelData = BarrEx_BarrelData.get(barrel)
            if barrelData then
                log(string.format(
                    "Barrel revealed and synced: id=%s liquid=%s amount=%d/%d",
                    barrelData.id or "N/A",
                    barrelData.liquidType or "none",
                    barrelData.amount,
                    barrelData.capacity
                ))
            end
            Events.OnTick.Remove(onTick)
            return
        end

        if ticks >= Constant.BARREL_DATA_POLL_TICKS then
            log("Barrel reveal not confirmed yet.")
            Events.OnTick.Remove(onTick)
        end
    end

    Events.OnTick.Add(onTick)
    ISBaseTimedAction.perform(self)
end

return BarrEx_OpenBarrelAction
