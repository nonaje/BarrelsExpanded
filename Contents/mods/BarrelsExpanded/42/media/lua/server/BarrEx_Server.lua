-- BarrEx_Server: entry point — event registration and command routing only.
--
-- All logic has been extracted into focused server modules:
--   BarrEx_BarrelWorldService   – barrel initialization and reconciliation
--   BarrEx_BarrelActionService  – short authoritative barrel mutations
--   BarrEx_BarrelStateService   – state request/reply snapshots
--   BarrEx_TransferService     – transfer lifecycle, per-tick advance
--
-- This file must not contain business logic.

local Constant           = require("BarrEx_Constant")
local TransferService    = require("BarrEx_TransferService")
local BarrelWorldService = require("BarrEx_BarrelWorldService")
local BarrelActionService = require("BarrEx_BarrelActionService")
local BarrelStateService = require("BarrEx_BarrelStateService")
local MoveableSync       = require("BarrEx_MoveableSync")

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        BarrelActionService.open(player, args)
        return
    end

    if command == Constant.NETWORK.START_POUR_INTO_BARREL then
        TransferService.start(player, "pour", args)
        return
    end

    if command == Constant.NETWORK.STOP_POUR_INTO_BARREL then
        if not args or not args.transferId then return end
        TransferService.stop(player, "pour", args and args.transferId, "client_stop")
        return
    end

    if command == Constant.NETWORK.COMPLETE_POUR_INTO_BARREL then
        if not args or not args.transferId then return end
        TransferService.complete(player, "pour", args and args.transferId)
        return
    end

    if command == Constant.NETWORK.UPDATE_TRANSFER_PROGRESS then
        TransferService.updateProgress(player, args)
        return
    end

    if command == Constant.NETWORK.START_EXTRACT_FROM_BARREL then
        TransferService.start(player, "extract", args)
        return
    end

    if command == Constant.NETWORK.STOP_EXTRACT_FROM_BARREL then
        if not args or not args.transferId then return end
        TransferService.stop(player, "extract", args and args.transferId, "client_stop")
        return
    end

    if command == Constant.NETWORK.COMPLETE_EXTRACT_FROM_BARREL then
        if not args or not args.transferId then return end
        TransferService.complete(player, "extract", args and args.transferId)
        return
    end

    if command == Constant.NETWORK.DRINK_FROM_BARREL then
        BarrelActionService.drink(player, args)
        return
    end

    if command == Constant.NETWORK.WASH_FROM_BARREL then
        BarrelActionService.wash(player, args)
        return
    end

    if command == Constant.NETWORK.EMPTY_BARREL then
        BarrelActionService.empty(player, args)
        return
    end

    if command == Constant.NETWORK.REQUEST_BARREL_STATE then
        BarrelStateService.onRequest(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnObjectAdded.Add(BarrelWorldService.onObjectAdded)
Events.LoadGridsquare.Add(BarrelWorldService.onLoadGridsquare)
Events.OnTick.Add(TransferService.onTick)
MoveableSync.start()
