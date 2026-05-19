local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local ContextConfig = require("config/BarrEx_ContextConfig")
local Text = require("context/BarrEx_ContextMenuText")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local BarrelStateClient = require("BarrEx_BarrelStateClient")
local Logger = require("utils/BarrEx_Logger")

local AdminBarrelActions = {}

local ACTION_NAME = "adminBarrel"
local OPERATIONS = Constant.ADMIN_BARREL_OPERATION

local SET_LIQUID_TYPES = {
    Constant.LIQUID_TYPE.WATER,
    Constant.LIQUID_TYPE.TAINTED_WATER,
    Constant.LIQUID_TYPE.GASOLINE,
    Constant.LIQUID_TYPE.BLEACH,
}

local FILL_RATIOS = {
    0.25,
    0.50,
    1.00,
}

local function now()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    if type(getTimestamp) == "function" then return getTimestamp() end
    return os and os.time and os.time() or 0
end

local function randomSuffix()
    if type(ZombRand) == "function" then return ZombRand(1000000) end
    return math.random(1000000)
end

local function getPlayerId(player)
    if player and type(player.getOnlineID) == "function" then
        local onlineId = player:getOnlineID()
        if type(onlineId) == "number" and onlineId >= 0 then
            return onlineId
        end
    end

    return "local"
end

local function buildActionId(player, barrel, operation)
    local barrelId = BarrEx_BarrelData.getId(barrel) or "nobarrel"
    return ACTION_NAME
        .. ":" .. tostring(operation or "unknown")
        .. ":" .. tostring(getPlayerId(player))
        .. ":" .. tostring(barrelId)
        .. ":" .. tostring(now())
        .. ":" .. tostring(randomSuffix())
end

local function isLocalDebugEnabled()
    if type(isDebugEnabled) == "function" and isDebugEnabled() then
        return true
    end

    local core = type(getCore) == "function" and getCore() or nil
    return core ~= nil and type(core.getDebug) == "function" and core:getDebug() == true
end

local function hasDebugCapability(player)
    if not player or not Capability or not Capability.UseDebugContextMenu then
        return false
    end

    local role = type(player.getRole) == "function" and player:getRole() or nil
    return role ~= nil
        and type(role.hasCapability) == "function"
        and role:hasCapability(Capability.UseDebugContextMenu) == true
end

function AdminBarrelActions.canUse(player)
    if not player then return false end

    if type(isClient) == "function" and isClient() then
        return hasDebugCapability(player)
    end

    return isLocalDebugEnabled() or hasDebugCapability(player)
end

local function buildPayload(barrel, player, operation, extra)
    local square = barrel and barrel:getSquare()
    if not square then return nil end

    local barrelData = BarrEx_BarrelData.get(barrel)
    local payload = {
        actionId = buildActionId(player, barrel, operation),
        action = ACTION_NAME,
        operation = operation,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = type(barrel.getObjectIndex) == "function" and barrel:getObjectIndex() or nil,
        barrelId = BarrEx_BarrelData.getId(barrel),
        clientRevision = barrelData and barrelData.revision or 0,
        spriteName = WorldUtils.getSpriteName(barrel),
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end

    return payload
end

local function sendOperation(barrel, player, operation, extra)
    if not AdminBarrelActions.canUse(player) then return false end

    local payload = buildPayload(barrel, player, operation, extra)
    if not payload then return false end

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.ADMIN_BARREL_ACTION, payload)
    BarrelStateClient.trackAction(payload)
    return true
end

function AdminBarrelActions.onInspect(barrel, player)
    sendOperation(barrel, player, OPERATIONS.INSPECT)
end

function AdminBarrelActions.onRepair(barrel, player)
    sendOperation(barrel, player, OPERATIONS.REPAIR)
end

function AdminBarrelActions.onReveal(barrel, player)
    sendOperation(barrel, player, OPERATIONS.REVEAL)
end

function AdminBarrelActions.onEmpty(barrel, player)
    sendOperation(barrel, player, OPERATIONS.EMPTY)
end

function AdminBarrelActions.onReroll(barrel, player)
    sendOperation(barrel, player, OPERATIONS.REROLL)
end

function AdminBarrelActions.onSetLiquid(barrel, player, liquidType, fillRatio)
    sendOperation(barrel, player, OPERATIONS.SET_LIQUID, {
        liquidType = liquidType,
        fillRatio = fillRatio,
    })
end

local function addOperationOption(menu, translationKey, barrel, callback, player)
    return menu:addOption(Text.translate(translationKey), barrel, callback, player)
end

local function addSetLiquidSubMenu(adminMenu, setLiquidOption, barrel, player)
    local setLiquidMenu = adminMenu:getNew(adminMenu)
    adminMenu:addSubMenu(setLiquidOption, setLiquidMenu)

    for i = 1, #SET_LIQUID_TYPES do
        local liquidType = SET_LIQUID_TYPES[i]
        local liquidOption = setLiquidMenu:addOption(
            Text.withSubMenuShortcut(Text.getLiquidDisplayName(liquidType)),
            nil,
            nil
        )
        local liquidMenu = setLiquidMenu:getNew(setLiquidMenu)
        setLiquidMenu:addSubMenu(liquidOption, liquidMenu)

        for j = 1, #FILL_RATIOS do
            local ratio = FILL_RATIOS[j]
            local percent = tostring(math.floor(ratio * 100))
            local label = Text.translate(ContextConfig.CONTEXT_MENU.ADMIN_FILL_PERCENT, percent)
            liquidMenu:addOption(label, barrel, AdminBarrelActions.onSetLiquid, player, liquidType, ratio)
        end
    end
end

---@param subMenu ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
function AdminBarrelActions.addSubMenu(subMenu, barrel, player)
    if not subMenu or not barrel or not AdminBarrelActions.canUse(player) then return end

    local adminOption = subMenu:addOption(
        Text.withSubMenuShortcut(Text.translate(ContextConfig.CONTEXT_MENU.ADMIN_DEBUG)),
        nil,
        nil
    )
    local adminMenu = subMenu:getNew(subMenu)
    subMenu:addSubMenu(adminOption, adminMenu)

    addOperationOption(adminMenu, ContextConfig.CONTEXT_MENU.ADMIN_INSPECT, barrel, AdminBarrelActions.onInspect, player)
    addOperationOption(adminMenu, ContextConfig.CONTEXT_MENU.ADMIN_REPAIR, barrel, AdminBarrelActions.onRepair, player)
    addOperationOption(adminMenu, ContextConfig.CONTEXT_MENU.ADMIN_REVEAL_INIT, barrel, AdminBarrelActions.onReveal, player)
    addOperationOption(adminMenu, ContextConfig.CONTEXT_MENU.ADMIN_EMPTY, barrel, AdminBarrelActions.onEmpty, player)

    local setLiquidOption = adminMenu:addOption(
        Text.withSubMenuShortcut(Text.translate(ContextConfig.CONTEXT_MENU.ADMIN_SET_LIQUID)),
        nil,
        nil
    )
    addSetLiquidSubMenu(adminMenu, setLiquidOption, barrel, player)

    addOperationOption(adminMenu, ContextConfig.CONTEXT_MENU.ADMIN_REROLL, barrel, AdminBarrelActions.onReroll, player)
end

local function logSnapshot(args)
    local snapshot = type(args) == "table" and args.snapshot or nil
    if type(snapshot) ~= "table" then
        Logger.info(string.format(
            "Admin barrel result: accepted=%s operation=%s reason=%s barrelId=%s",
            tostring(type(args) == "table" and args.accepted == true),
            tostring(type(args) == "table" and args.operation or "unknown"),
            tostring(type(args) == "table" and args.reason or "unknown"),
            tostring(type(args) == "table" and args.barrelId or "unknown")
        ))
        return
    end

    Logger.info(string.format(
        "Admin barrel snapshot: accepted=%s operation=%s reason=%s barrelId=%s revealed=%s liquid=%s amount=%s capacity=%s weight=%s revision=%s x=%s y=%s z=%s objectIndex=%s sprite=%s",
        tostring(args.accepted == true),
        tostring(args.operation or "unknown"),
        tostring(args.reason or "unknown"),
        tostring(snapshot.barrelId or snapshot.id or "unknown"),
        tostring(snapshot.revealed == true),
        tostring(snapshot.liquidType or "unknown"),
        tostring(snapshot.amount or 0),
        tostring(snapshot.capacity or 0),
        tostring(snapshot.weight or 0),
        tostring(snapshot.revision or "unknown"),
        tostring(snapshot.x or "unknown"),
        tostring(snapshot.y or "unknown"),
        tostring(snapshot.z or "unknown"),
        tostring(snapshot.objectIndex or "unknown"),
        tostring(snapshot.spriteName or "unknown")
    ))
end

function AdminBarrelActions.onActionResult(args)
    if type(args) ~= "table" or args.action ~= ACTION_NAME then
        return false
    end

    logSnapshot(args)
    return true
end

return AdminBarrelActions
