local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")
local Logger = require("utils/BarrEx_Logger")

---@class BarrEx_OpenBarrelAction : ISBaseTimedAction
---@field barrel IsoObject
---@field tool InventoryItem
---@field anim string
---@field maxTime number
---@field stopOnWalk boolean
---@field stopOnRun boolean
local BarrEx_OpenBarrelAction = BarrEx_BarrelActionBase:derive("BarrEx_OpenBarrelAction")

local function log(message)
    Logger.info(message)
end

--- @param player IsoPlayer
--- @param barrel IsoObject
--- @param tool InventoryItem
--- @return BarrEx_OpenBarrelAction
function BarrEx_OpenBarrelAction:new(player, barrel, tool)
    local o = BarrEx_BarrelActionBase.new(self, player, barrel, "open", Constant.NETWORK.OPEN_BARREL, Constant.OPEN_BARREL_ACTION_TIME)
    ---@cast o BarrEx_OpenBarrelAction

    o.tool = tool
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end

function BarrEx_OpenBarrelAction:isValid()
    -- Allow nil barrelData: the barrel may not have synced from the server yet
    -- (race condition on multiplayer chunk load). The server handles lazy init.
    -- isRevealedRaw avoids full deserialization every tick.
    if BarrEx_BarrelData.isRevealedRaw(self.barrel) then return false end
    if not PlayerUtils.isPlayerInRange(self.character, self.barrel) then return false end
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

    self:sendBarrelCommand(Constant.NETWORK.OPEN_BARREL)
    ISBaseTimedAction.perform(self)
end

return BarrEx_OpenBarrelAction
