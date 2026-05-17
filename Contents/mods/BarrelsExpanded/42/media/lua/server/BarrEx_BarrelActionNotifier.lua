-- BarrEx_BarrelActionNotifier: common server -> client action/state messages.

local Constant     = require("BarrEx_Constant")
local StateService = require("BarrEx_BarrelStateService")

local Notifier = {}

local function getActionId(source)
    if type(source) ~= "table" then return nil end
    return source.actionId or source.transferId
end

local function getActionName(action, source)
    if action then return action end
    if type(source) ~= "table" then return nil end
    return source.action or source.mode
end

local function getBarrelId(source, snapshot)
    if snapshot and snapshot.barrelId then return snapshot.barrelId end
    if type(source) ~= "table" then return nil end
    return source.barrelId or source.barrelKey
end

---@param player IsoPlayer
---@param action string
---@param accepted boolean
---@param reason string|nil
---@param barrel IsoObject|nil
---@param barrelData BarrEx_Barrel|nil
---@param source table|nil
---@param extra table|nil
function Notifier.result(player, action, accepted, reason, barrel, barrelData, source, extra)
    if not player or type(sendServerCommand) ~= "function" then return end

    local snapshot = StateService.buildSnapshot(barrel, barrelData)
    local payload = {
        actionId = getActionId(source),
        action = getActionName(action, source) or "unknown",
        accepted = accepted == true,
        reason = reason or (accepted and "ok" or "unknown"),
        barrelId = getBarrelId(source, snapshot),
        playerOnlineId = type(player.getOnlineID) == "function" and player:getOnlineID() or nil,
        revision = snapshot and snapshot.revision or nil,
        snapshot = snapshot,
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end

    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.BARREL_ACTION_RESULT, payload)
end

---@param player IsoPlayer
---@param barrel IsoObject|nil
---@param barrelData BarrEx_Barrel|nil
---@param source table|nil
function Notifier.state(player, barrel, barrelData, source)
    StateService.sendState(player, barrel, barrelData, source)
end

return Notifier
