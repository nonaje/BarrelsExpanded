local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local WorldUtils = require("utils/BarrEx_WorldUtils")

local BarrelStateClient = {}

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

local function snapshotMatchesObject(snapshot, object)
    if not snapshot or not object or not WorldUtils.isExpandableBarrel(object) then return false end

    if type(snapshot.spriteName) == "string" and snapshot.spriteName ~= ""
        and WorldUtils.getSpriteName(object) ~= snapshot.spriteName
    then
        return false
    end

    local snapshotId = snapshot.barrelId or snapshot.id
    if type(snapshotId) == "string" and snapshotId ~= "" then
        local modData = object:getModData()
        local objectId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
        return objectId == nil or objectId == "" or objectId == snapshotId
    end

    return true
end

local function findBarrelOnSquare(square, snapshot)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    if type(snapshot.objectIndex) == "number"
        and snapshot.objectIndex >= 0
        and snapshot.objectIndex < objects:size()
    then
        local object = objects:get(snapshot.objectIndex)
        if snapshotMatchesObject(snapshot, object) then
            return object
        end
    end

    local found = nil
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if snapshotMatchesObject(snapshot, object) then
            if found then return nil end
            found = object
        end
    end

    return found
end

local function findBarrel(snapshot)
    if type(snapshot) ~= "table" then return nil end
    if type(snapshot.x) ~= "number" or type(snapshot.y) ~= "number" or type(snapshot.z) ~= "number" then
        return nil
    end

    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(snapshot.x, snapshot.y, snapshot.z)
    local barrel = findBarrelOnSquare(square, snapshot)
    if barrel then return barrel end

    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                square = cell:getGridSquare(snapshot.x + dx, snapshot.y + dy, snapshot.z)
                barrel = findBarrelOnSquare(square, snapshot)
                if barrel then return barrel end
            end
        end
    end

    return nil
end

function BarrelStateClient.applySnapshot(snapshot)
    if type(snapshot) ~= "table" then return false end

    local barrel = findBarrel(snapshot)
    if not barrel then
        local key = getSnapshotKey(snapshot)
        if key then pendingSnapshotsById[key] = snapshot end
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

    local modData = barrel:getModData()
    local barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil
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
