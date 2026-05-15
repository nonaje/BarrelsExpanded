local Constant = require("BarrEx_Constant")
local BarrEx_MoveableSync = require("BarrEx_MoveableSync")

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

local TRANSFER_REJECTION_MESSAGES = {
    barrel_not_found = "El barril ya no está disponible.",
    barrel_unavailable = "Primero tenés que abrir el barril.",
    interaction_invalid = "No podés hacer eso desde esta posición o sin la herramienta requerida.",
    barrel_full = "El barril está lleno.",
    barrel_empty = "El barril está vacío.",
    source_not_found = "No se encontró el recipiente de origen.",
    target_not_found = "No se encontró el recipiente de destino.",
    source_liquid_missing = "El recipiente no tiene líquido transferible.",
    source_cannot_provide = "Ese recipiente no puede verter ese líquido.",
    target_cannot_receive = "Ese recipiente no puede recibir ese líquido.",
    incompatible_liquid = "No se pueden mezclar líquidos distintos.",
    invalid_barrel_liquid = "El líquido del barril no es válido.",
    no_transferable_amount = "No hay cantidad transferible.",
    barrel_locked = "Otro jugador ya está usando este barril.",
    barrel_id_missing = "No se pudo validar el barril.",
    barrel_lock_lost = "La transferencia se interrumpió porque el barril cambió de estado.",
}

local function getLocalPlayerSafe()
    if type(getPlayer) == "function" then
        return getPlayer()
    end

    if type(getSpecificPlayer) == "function" then
        return getSpecificPlayer(0)
    end

    return nil
end

local function showPlayerMessage(message)
    local player = getLocalPlayerSafe()
    if not player or not message then return end

    if HaloTextHelper and type(HaloTextHelper.addText) == "function" then
        HaloTextHelper.addText(player, message, HaloTextHelper.getColorRed and HaloTextHelper.getColorRed() or nil)
        return
    end

    if type(player.Say) == "function" then
        player:Say(message)
    end
end

local function onServerCommand(module, command, args)
    if module ~= Constant.NETWORK.MODULE then return end

    if command == Constant.NETWORK.TRANSFER_REJECTED then
        local reason = type(args) == "table" and args.reason or "unknown"
        showPlayerMessage(TRANSFER_REJECTION_MESSAGES[reason] or "No se pudo iniciar la transferencia.")
    end
end

log("Mod Initialized!")

Events.OnGameStart.Add(function()
    log("Game Started")
end)

Events.OnServerCommand.Add(onServerCommand)
BarrEx_MoveableSync.start()
