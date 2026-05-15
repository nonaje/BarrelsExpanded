local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

local TransferSync = {}

local activeTransfersByMode = {}
local pendingStartsByMode = {}

local function clamp01(value)
    local numericValue = tonumber(value) or 0
    if numericValue < 0 then return 0 end
    if numericValue > 1 then return 1 end
    return numericValue
end

local function getBarrelId(barrel)
    if not barrel then return nil end

    local modData = barrel:getModData()
    return modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or BarrEx_BarrelData.buildId(barrel)
end

local function matchesTransfer(entry, args)
    if not entry or not args then return false end

    if args.barrelId and entry.barrelId and args.barrelId ~= entry.barrelId then
        return false
    end

    if args.itemId and entry.itemId and args.itemId ~= entry.itemId then
        return false
    end

    return true
end

function TransferSync.registerAction(mode, action, barrel, item)
    if not mode or not action then return end

    activeTransfersByMode[mode] = {
        action = action,
        barrelId = getBarrelId(barrel),
        itemId = item and item:getID() or nil,
    }

    action.serverProgress = 0
    action.serverCompleted = false

    local pendingStart = pendingStartsByMode[mode]
    if pendingStart and matchesTransfer(activeTransfersByMode[mode], pendingStart) then
        pendingStartsByMode[mode] = nil
        TransferSync.onTransferStarted(pendingStart)
    end
end

function TransferSync.unregisterAction(mode, action)
    if not mode then return end

    local entry = activeTransfersByMode[mode]
    if not entry then return end
    if action and entry.action ~= action then return end

    activeTransfersByMode[mode] = nil

    if action then
        action.serverProgress = nil
        action.serverCompleted = nil
    end
end

function TransferSync.onTransferProgress(args)
    if type(args) ~= "table" then return end

    local mode = args.mode
    local entry = mode and activeTransfersByMode[mode] or nil
    if not entry or not matchesTransfer(entry, args) then return end

    local action = entry.action
    if not action then return end

    action.serverProgress = clamp01(args.progress)
    if args.completed then
        action.serverCompleted = true
        action.transferStarted = false
    end
end

function TransferSync.onTransferStarted(args)
    if type(args) ~= "table" then return end

    local mode = args.mode
    local entry = mode and activeTransfersByMode[mode] or nil
    if not entry then
        if mode then
            pendingStartsByMode[mode] = args
        end
        return
    end

    if not matchesTransfer(entry, args) then
        pendingStartsByMode[mode] = args
        return
    end

    local action = entry.action
    if not action then return end

    local totalAmount = tonumber(args.totalAmount)
    if totalAmount and totalAmount > 0 then
        action.totalAmount = totalAmount
    end

    local actionTime = tonumber(args.actionTime)
    if actionTime and actionTime > 0 then
        action.maxTime = actionTime
    end
end

function TransferSync.onTransferRejected(mode)
    local entry = mode and activeTransfersByMode[mode] or nil
    if not entry or not entry.action then return end

    entry.action.serverCompleted = true
    entry.action.transferStarted = false
end

function TransferSync.beforeActionUpdate(action)
    if not action then return end

    local maxTime = math.max(tonumber(action.maxTime) or 0, 1)
    local currentTime = tonumber(action.currentTime) or 0

    if action.serverCompleted then
        action.currentTime = maxTime
        return
    end

    local serverProgress = tonumber(action.serverProgress)
    if not serverProgress then return end

    local syncedTime = maxTime * clamp01(serverProgress)
    if syncedTime > currentTime then
        action.currentTime = syncedTime
    end
end

return TransferSync