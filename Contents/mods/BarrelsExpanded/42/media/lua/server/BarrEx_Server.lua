-- BarrEx_Server: entry point — event registration and command routing only.
--
-- All logic has been extracted into focused server modules:
--   BarrEx_BarrelWorldService  – barrel initialization, reconciliation and open
--   BarrEx_TransferService     – transfer lifecycle, per-tick advance
--
-- This file must not contain business logic.

local Constant           = require("BarrEx_Constant")
local TransferService    = require("BarrEx_TransferService")
local BarrelWorldService = require("BarrEx_BarrelWorldService")

local function onClientCommand(module, command, player, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.OPEN_BARREL then
        BarrelWorldService.onOpenBarrel(player, args)
        return
    end

    if command == Constant.NETWORK.START_POUR_INTO_BARREL then
        TransferService.start(player, "pour", args)
        return
    end

    if command == Constant.NETWORK.STOP_POUR_INTO_BARREL then
        TransferService.stop(player, "client_stop")
        return
    end

    if command == Constant.NETWORK.COMPLETE_POUR_INTO_BARREL then
        TransferService.complete(player, "pour")
        return
    end

    if command == Constant.NETWORK.START_EXTRACT_FROM_BARREL then
        TransferService.start(player, "extract", args)
        return
    end

    if command == Constant.NETWORK.STOP_EXTRACT_FROM_BARREL then
        TransferService.stop(player, "client_stop")
        return
    end

    if command == Constant.NETWORK.COMPLETE_EXTRACT_FROM_BARREL then
        TransferService.complete(player, "extract")
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnObjectAdded.Add(BarrelWorldService.onObjectAdded)
Events.LoadGridsquare.Add(BarrelWorldService.onLoadGridsquare)
Events.OnTick.Add(TransferService.onTick)