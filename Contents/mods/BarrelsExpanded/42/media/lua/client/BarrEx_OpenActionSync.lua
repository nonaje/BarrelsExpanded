local BarrEx_BarrelData = require("BarrEx_BarrelData")

local OpenActionSync = {}

local activeActionsById = {}

local function matchesAction(entry, args)
    if not entry or type(args) ~= "table" then return false end

    if args.actionId and entry.actionId and tostring(args.actionId) ~= tostring(entry.actionId) then
        return false
    end

    if args.barrelId and entry.barrelId and args.barrelId ~= entry.barrelId then
        return false
    end

    return true
end

function OpenActionSync.registerAction(actionId, action, barrel)
    if not actionId or not action then return end

    activeActionsById[tostring(actionId)] = {
        action = action,
        actionId = tostring(actionId),
        barrelId = BarrEx_BarrelData.getId(barrel),
    }
end

function OpenActionSync.unregisterAction(actionId, action)
    if not actionId then return end

    local key = tostring(actionId)
    local entry = activeActionsById[key]
    if not entry then return end
    if action and entry.action ~= action then return end

    activeActionsById[key] = nil
end

function OpenActionSync.onActionResult(args)
    if type(args) ~= "table" or args.action ~= "open" or not args.actionId then return end

    local entry = activeActionsById[tostring(args.actionId)]
    if not matchesAction(entry, args) then return end

    local action = entry.action
    if not action then return end

    if args.accepted == true then
        if args.reason == "reserved" or args.openReserved == true then
            action.openReserved = true
            action.serverRejected = false
            return
        end

        action.serverCompleted = true
        return
    end

    action.serverRejected = true
    action.openReserved = false
end

return OpenActionSync
