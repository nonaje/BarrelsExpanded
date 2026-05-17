local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_BarrelActionBase = require("actions/BarrEx_BarrelActionBase")
local BarrelStateClient = require("BarrEx_BarrelStateClient")
local OpenActionSync = require("BarrEx_OpenActionSync")
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

local function setActionCurrentTime(action, time)
    if not action then return end

    if type(action.setCurrentTime) == "function" and action.action then
        action:setCurrentTime(time)
    else
        action.currentTime = time
    end
end

local function sendOpenCommand(action, command, track)
    if not action or not command then return false end

    local payload = action:buildBarrelPayload()
    if not payload then return false end

    sendClientCommand(Constant.NETWORK.MODULE, command, payload)
    if track == true then
        BarrelStateClient.trackAction(payload)
    end
    return true
end

--- @param player IsoPlayer
--- @param barrel IsoObject
--- @param tool InventoryItem
--- @return BarrEx_OpenBarrelAction
function BarrEx_OpenBarrelAction:new(player, barrel, tool)
    local o = BarrEx_BarrelActionBase.new(self, player, barrel, "open", Constant.NETWORK.START_OPEN_BARREL, Constant.OPEN_BARREL_ACTION_TIME)
    ---@cast o BarrEx_OpenBarrelAction

    o.tool = tool
    o.openReserved = false
    o.serverRejected = false
    o.serverCompleted = false
    o.stopRequested = false
    o.reserveWaitTicks = 0
    o.stopOnWalk = true
    o.stopOnRun = true

    return o
end

function BarrEx_OpenBarrelAction:isValid()
    if self.serverRejected then return false end
    -- Allow nil barrelData: the barrel may not have synced from the server yet
    -- (race condition on multiplayer chunk load). The server handles lazy init.
    -- isRevealedRaw avoids full deserialization every tick.
    if BarrEx_BarrelData.isRevealedRaw(self.barrel) then return false end
    if not PlayerUtils.isPlayerInRange(self.character, self.barrel) then return false end
    return true
end

function BarrEx_OpenBarrelAction:start()
    ISBaseTimedAction.start(self)
    OpenActionSync.registerAction(self.actionId, self, self.barrel)
    if not sendOpenCommand(self, Constant.NETWORK.START_OPEN_BARREL, true) then
        self.serverRejected = true
    end

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
    if self.serverRejected then
        if not self.stopRequested then
            self.stopRequested = true
            if type(self.forceStop) == "function" then
                self:forceStop()
            else
                self:stop()
            end
        end
        return
    end

    if not self.openReserved then
        self.reserveWaitTicks = (tonumber(self.reserveWaitTicks) or 0) + 1
        if self.reserveWaitTicks >= math.max(tonumber(Constant.ACTION_ACK_TIMEOUT_TICKS) or 240, 1) then
            self.serverRejected = true
            return
        end
        setActionCurrentTime(self, 0)
    end

    self.character:faceThisObject(self.barrel)
    self.character:setPrimaryHandItem(self.tool)
end

function BarrEx_OpenBarrelAction:stop()
    self.character:ClearVariable("LootPosition")
    if self.openReserved and not self.serverCompleted and not self.serverRejected then
        sendOpenCommand(self, Constant.NETWORK.CANCEL_OPEN_BARREL, false)
    end
    OpenActionSync.unregisterAction(self.actionId, self)
    ISBaseTimedAction.stop(self)
end

function BarrEx_OpenBarrelAction:perform()
    self.character:ClearVariable("LootPosition")
    local barrel = self.barrel

    if BarrEx_BarrelData.isRevealedRaw(barrel) then
        log("Open ignored; barrel already revealed.")
        OpenActionSync.unregisterAction(self.actionId, self)
        ISBaseTimedAction.perform(self)
        return
    end

    if self.openReserved and not self.serverRejected then
        self.serverCompleted = true
        sendOpenCommand(self, Constant.NETWORK.COMPLETE_OPEN_BARREL, false)
    end
    OpenActionSync.unregisterAction(self.actionId, self)
    ISBaseTimedAction.perform(self)
end

return BarrEx_OpenBarrelAction
