local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local Logger = require("utils/BarrEx_Logger")

local BarrelStateClient = {}
local LOG_TAG = "[BarrelStateClient] "

local pendingSnapshotsById = {}
local pendingActionsById = {}
local lastRequestMsByKey = {}

local function nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    return (os and os.time and os.time() or 0) * 1000
end

local function getSnapshotKey(snapshot)
    if type(snapshot) ~= "table" then return nil end
    if type(snapshot.barrelId) == "string" and snapshot.barrelId ~= "" then
        return snapshot.barrelId
    end
    if type(snapshot.id) == "string" and snapshot.id ~= "" then
        return snapshot.id
    end
    if snapshot.x and snapshot.y and snapshot.z then
        return tostring(snapshot.x) .. ":" .. tostring(snapshot.y) .. ":" .. tostring(snapshot.z)
    end
    return nil
end

local function getSnapshotId(snapshot)
    if type(snapshot) ~= "table" then return nil end
    local snapshotId = snapshot.barrelId or snapshot.id
    if type(snapshotId) == "string" and snapshotId ~= "" then
        return snapshotId
    end
    return nil
end

local function getObjectBarrelId(object)
    return BarrEx_BarrelData.getId(object)
end

local function getActionKey(args)
    if type(args) ~= "table" then return nil end
    return args.actionId or args.transferId
end

local function clearPendingAction(args)
    local actionKey = getActionKey(args)
    if actionKey then
        pendingActionsById[actionKey] = nil
    end
end

local function snapshotMatchesObjectShape(snapshot, object)
    if not snapshot or not object or not WorldUtils.isExpandableBarrel(object) then return false end

    if type(snapshot.spriteName) == "string" and snapshot.spriteName ~= ""
        and WorldUtils.getSpriteName(object) ~= snapshot.spriteName
    then
        return false
    end

    return true
end

local function classifySquare(square, snapshot)
    local result = {
        total = 0,
        idCount = 0,
        noIdCount = 0,
        anyCandidate = nil,
        idCandidate = nil,
        noIdCandidate = nil,
    }

    if not square then return result end

    local objects = square:getObjects()
    if not objects then return result end

    local snapshotId = getSnapshotId(snapshot)
    local objectCount = objects:size()
    for i = 0, objectCount - 1 do
        local object = objects:get(i)
        if snapshotMatchesObjectShape(snapshot, object) then
            result.total = result.total + 1
            result.anyCandidate = object

            local objectId = getObjectBarrelId(object)
            if snapshotId and objectId == snapshotId then
                result.idCount = result.idCount + 1
                result.idCandidate = object
            elseif not objectId then
                result.noIdCount = result.noIdCount + 1
                result.noIdCandidate = object
            end
        end
    end

    return result
end

local function findBarrelOnExactSquare(square, snapshot)
    if not square then return nil, "square_unavailable" end

    local snapshotId = getSnapshotId(snapshot)
    local classified = classifySquare(square, snapshot)

    if snapshotId then
        if classified.idCount == 1 then
            return classified.idCandidate, nil
        end
        if classified.idCount > 1 then
            return nil, "ambiguous_barrel"
        end
        if classified.total == 1 and classified.noIdCount == 1 then
            return nil, "unique_unidentified_barrel", classified.noIdCandidate
        end
        if classified.total > 1 then
            return nil, "ambiguous_barrel"
        end
        return nil, "barrel_not_found"
    end

    if classified.total == 1 then
        return classified.anyCandidate, nil
    end
    if classified.total > 1 then
        return nil, "ambiguous_barrel"
    end

    return nil, "barrel_not_found"
end

local function findBarrelByIdOnSquare(square, snapshot)
    local snapshotId = getSnapshotId(snapshot)
    if not snapshotId or not square then return nil, nil end

    local objects = square:getObjects()
    if not objects then return nil, nil end

    local found = nil
    local foundCount = 0
    local objectCount = objects:size()
    for i = 0, objectCount - 1 do
        local object = objects:get(i)
        if snapshotMatchesObjectShape(snapshot, object) and getObjectBarrelId(object) == snapshotId then
            foundCount = foundCount + 1
            found = object
        end
    end

    if foundCount == 1 then return found, nil end
    if foundCount > 1 then return nil, "ambiguous_barrel" end
    return nil, nil
end

local function findBarrel(snapshot)
    if type(snapshot) ~= "table" then return nil end
    if type(snapshot.x) ~= "number" or type(snapshot.y) ~= "number" or type(snapshot.z) ~= "number" then
        return nil, "invalid_args"
    end

    local cell = getCell()
    if not cell then return nil, "cell_unavailable" end

    local square = cell:getGridSquare(snapshot.x, snapshot.y, snapshot.z)
    local barrel, reason, unidentifiedFallback = findBarrelOnExactSquare(square, snapshot)
    if barrel then return barrel, nil end
    if reason == "ambiguous_barrel" then return nil, reason end

    if not getSnapshotId(snapshot) then
        return nil, reason
    end

    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                square = cell:getGridSquare(snapshot.x + dx, snapshot.y + dy, snapshot.z)
                barrel, reason = findBarrelByIdOnSquare(square, snapshot)
                if barrel then return barrel, nil end
                if reason == "ambiguous_barrel" then return nil, reason end
            end
        end
    end

    if unidentifiedFallback then
        return unidentifiedFallback, nil
    end

    return nil, reason or "barrel_not_found"
end

local function requestStateForSnapshot(snapshot, reason)
    if type(snapshot) ~= "table" then return false end
    if type(snapshot.x) ~= "number" or type(snapshot.y) ~= "number" or type(snapshot.z) ~= "number" then
        return false
    end

    local key = getSnapshotKey(snapshot)
    if not key then return false end

    local requestKey = "snapshot:" .. tostring(key)
    local cooldownMs = math.max(tonumber(Constant.STATE_REQUEST_COOLDOWN_TICKS) or 60, 1) * 50
    local current = nowMs()
    if lastRequestMsByKey[requestKey] and current - lastRequestMsByKey[requestKey] < cooldownMs then
        return false
    end
    lastRequestMsByKey[requestKey] = current

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.REQUEST_BARREL_STATE, {
        actionId = "state:snapshot:" .. tostring(key) .. ":" .. tostring(current),
        action = "state",
        x = snapshot.x,
        y = snapshot.y,
        z = snapshot.z,
        objectIndex = snapshot.objectIndex,
        barrelId = getSnapshotId(snapshot),
        clientRevision = tonumber(snapshot.revision) or 0,
        spriteName = snapshot.spriteName,
    })

    Logger.warn(LOG_TAG .. string.format(
        "Requested authoritative state after snapshot could not be applied: barrelId=%s revision=%s reason=%s",
        tostring(getSnapshotId(snapshot) or "unknown"),
        tostring(snapshot.revision or "unknown"),
        tostring(reason or "unknown")
    ))

    return true
end

function BarrelStateClient.applySnapshot(snapshot)
    if type(snapshot) ~= "table" then return false end

    local barrel, reason = findBarrel(snapshot)
    if not barrel then
        local key = getSnapshotKey(snapshot)
        if key then pendingSnapshotsById[key] = snapshot end
        if reason == "ambiguous_barrel" then
            Logger.warn(LOG_TAG .. string.format(
                "Pending ambiguous snapshot: barrelId=%s revision=%s x=%s y=%s z=%s",
                tostring(getSnapshotId(snapshot) or "unknown"),
                tostring(snapshot.revision or "unknown"),
                tostring(snapshot.x),
                tostring(snapshot.y),
                tostring(snapshot.z)
            ))
            requestStateForSnapshot(snapshot, reason)
        end
        return false
    end

    local currentData = BarrEx_BarrelData.get(barrel)
    local snapshotRevision = tonumber(snapshot.revision)
    local localRevision = currentData and tonumber(currentData.revision) or nil
    if snapshotRevision and localRevision and snapshotRevision < localRevision then
        local key = getSnapshotKey(snapshot)
        if key then pendingSnapshotsById[key] = nil end
        Logger.warn(LOG_TAG .. string.format(
            "Discarded stale snapshot: barrelId=%s snapshotRevision=%s localRevision=%s",
            tostring(getSnapshotId(snapshot) or getObjectBarrelId(barrel) or "unknown"),
            tostring(snapshotRevision),
            tostring(localRevision)
        ))
        return false
    end

    local barrelData = BarrEx_BarrelData.fromRawData({
        id = snapshot.barrelId or snapshot.id,
        liquidType = snapshot.liquidType,
        amount = snapshot.amount,
        capacity = snapshot.capacity,
        revealed = snapshot.revealed,
        revision = snapshot.revision,
    })
    if not barrelData then return false end

    BarrEx_BarrelData.set(barrel, barrelData)

    local key = getSnapshotKey(snapshot)
    if key then pendingSnapshotsById[key] = nil end

    if ISInventoryPage and type(ISInventoryPage.dirtyUI) == "function" then
        ISInventoryPage.dirtyUI()
    end

    return true
end

function BarrelStateClient.onBarrelState(args)
    if type(args) ~= "table" then return end
    clearPendingAction(args)
    BarrelStateClient.applySnapshot(args.snapshot)
end

function BarrelStateClient.onActionResult(args)
    if type(args) ~= "table" then return end
    clearPendingAction(args)
    BarrelStateClient.applySnapshot(args.snapshot)
end

function BarrelStateClient.trackAction(payload)
    local actionKey = getActionKey(payload)
    if not actionKey then return false end

    pendingActionsById[actionKey] = {
        sentAtMs = nowMs(),
        payload = payload,
    }
    return true
end

local function requestStateForPendingAction(actionKey, pending, current)
    local payload = pending and pending.payload or nil
    if type(payload) ~= "table" then return false end
    if type(payload.x) ~= "number" or type(payload.y) ~= "number" or type(payload.z) ~= "number" then
        return false
    end

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.REQUEST_BARREL_STATE, {
        actionId = "state:ack_timeout:" .. tostring(actionKey) .. ":" .. tostring(current),
        action = payload.action or payload.mode or "state",
        x = payload.x,
        y = payload.y,
        z = payload.z,
        objectIndex = payload.objectIndex,
        barrelId = payload.barrelId,
        clientRevision = payload.clientRevision,
        spriteName = payload.spriteName,
    })

    return true
end

function BarrelStateClient.onTick()
    local timeoutMs = math.max(tonumber(Constant.ACTION_ACK_TIMEOUT_TICKS) or 240, 1) * 50
    local current = nowMs()

    for actionKey, pending in pairs(pendingActionsById) do
        if current - (tonumber(pending.sentAtMs) or 0) >= timeoutMs then
            pendingActionsById[actionKey] = nil
            requestStateForPendingAction(actionKey, pending, current)
        end
    end
end

function BarrelStateClient.requestStateForBarrel(barrel, action)
    local square = barrel and barrel:getSquare()
    if not square then return false end

    local barrelId = BarrEx_BarrelData.getId(barrel)
    local key = barrelId or (tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ()))
    local cooldownMs = math.max(tonumber(Constant.STATE_REQUEST_COOLDOWN_TICKS) or 60, 1) * 50
    local current = nowMs()

    if lastRequestMsByKey[key] and current - lastRequestMsByKey[key] < cooldownMs then
        return false
    end
    lastRequestMsByKey[key] = current

    local barrelData = BarrEx_BarrelData.get(barrel)

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.REQUEST_BARREL_STATE, {
        actionId = "state:" .. tostring(key) .. ":" .. tostring(current),
        action = action or "state",
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = barrel:getObjectIndex(),
        barrelId = barrelId,
        clientRevision = barrelData and barrelData.revision or 0,
        spriteName = WorldUtils.getSpriteName(barrel),
    })

    return true
end

function BarrelStateClient.onLoadGridsquare(square)
    if not square then return end

    for key, snapshot in pairs(pendingSnapshotsById) do
        if snapshot
            and tonumber(snapshot.x) == square:getX()
            and tonumber(snapshot.y) == square:getY()
            and tonumber(snapshot.z) == square:getZ()
        then
            if BarrelStateClient.applySnapshot(snapshot) then
                pendingSnapshotsById[key] = nil
            end
        end
    end
end

return BarrelStateClient
