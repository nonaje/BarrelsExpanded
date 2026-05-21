-- BarrEx_LiquidEndpointResolver: resolves liquid endpoints for reusable transfers.
--
-- V1 registers only world barrels. Future adapters can add generators, vehicle
-- fuel tanks, or persistent supply links without changing the transfer lifecycle.

local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrelResolver    = require("BarrEx_BarrelResolver")
local InteractionRules  = require("core/BarrEx_InteractionRules")
local LockService       = require("BarrEx_BarrelLockService")
local StateService      = require("BarrEx_BarrelStateService")

local EndpointResolver = {}

EndpointResolver.KIND = {
    BARREL = "barrel",
}

local function isValidLiquidType(liquidType)
    return type(liquidType) == "string"
        and Constant.LIQUID_TYPE[liquidType] ~= nil
        and liquidType ~= Constant.LIQUID_TYPE.EMPTY
end

local function refreshBarrelState(endpoint)
    local barrelData = type(endpoint) == "table" and endpoint.data or nil
    endpoint.liquidType = barrelData and barrelData.liquidType or nil
    endpoint.amount = math.max(tonumber(barrelData and barrelData.amount) or 0, 0)
    endpoint.capacity = math.max(tonumber(barrelData and barrelData.capacity) or 0, 0)
    endpoint.freeCapacity = barrelData and barrelData:getFreeCapacity() or 0
    return endpoint
end

local function barrelSnapshot(endpoint)
    return StateService.buildSnapshot(endpoint.object, endpoint.data)
end

local function barrelSync(endpoint)
    if endpoint.object then
        endpoint.object:transmitModData()
    end
end

local function barrelPersist(endpoint, bumpRevision, transmit)
    if not endpoint.object or not endpoint.data then return nil end

    if bumpRevision == true then
        BarrEx_BarrelData.bumpRevision(endpoint.data)
    end

    BarrEx_BarrelData.set(endpoint.object, endpoint.data)
    refreshBarrelState(endpoint)

    if transmit == true then
        endpoint.object:transmitModData()
    end

    return barrelSnapshot(endpoint)
end

local function barrelCanProvide(endpoint)
    local barrelData = type(endpoint) == "table" and endpoint.data or nil
    if not barrelData or not barrelData:isRevealed() or barrelData:isEmpty() then
        return false
    end

    return isValidLiquidType(barrelData.liquidType)
end

local function barrelCanReceive(endpoint, liquidType)
    local barrelData = type(endpoint) == "table" and endpoint.data or nil
    if not barrelData or not barrelData:isRevealed() or barrelData:isFull() then
        return false
    end
    if not isValidLiquidType(liquidType) then
        return false
    end

    return barrelData:canAcceptLiquid(liquidType, 1)
end

local function barrelRemoveLiquid(endpoint, amount)
    local barrelData = type(endpoint) == "table" and endpoint.data or nil
    if not barrelData then return 0 end

    local removed = barrelData:removeLiquid(amount)
    refreshBarrelState(endpoint)
    return removed
end

local function barrelAddLiquid(endpoint, liquidType, amount)
    local barrelData = type(endpoint) == "table" and endpoint.data or nil
    if not barrelData then return 0 end

    local added = barrelData:addLiquid(liquidType, amount)
    refreshBarrelState(endpoint)
    return added
end

local function buildBarrelEndpoint(barrel, barrelData, args, key)
    return refreshBarrelState({
        kind = EndpointResolver.KIND.BARREL,
        key = key,
        barrelId = barrelData.id,
        object = barrel,
        data = barrelData,
        args = args,
        canProvide = barrelCanProvide,
        canReceive = barrelCanReceive,
        removeLiquid = barrelRemoveLiquid,
        addLiquid = barrelAddLiquid,
        persist = barrelPersist,
        sync = barrelSync,
        snapshot = barrelSnapshot,
    })
end

local function resolveBarrel(player, args)
    local barrel, resolveReason = BarrelResolver.resolveStrict(args)
    if not barrel then
        return nil, resolveReason or "barrel_not_found"
    end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, "barrel_unavailable"
    end

    if not InteractionRules.validateInteraction(barrel, player, {}, false) then
        return nil, "interaction_invalid"
    end

    local key = LockService.getBarrelKey(barrel, barrelData)
    if not key then
        return nil, "barrel_id_missing"
    end

    return buildBarrelEndpoint(barrel, barrelData, args, key), nil
end

---@param player IsoPlayer
---@param args table|nil
---@return table|nil
---@return string|nil
function EndpointResolver.resolve(player, args)
    if type(args) ~= "table" then
        return nil, "invalid_endpoint"
    end

    local kind = args.kind or EndpointResolver.KIND.BARREL
    if kind ~= EndpointResolver.KIND.BARREL then
        return nil, "unsupported_endpoint"
    end

    return resolveBarrel(player, args)
end

---@param player IsoPlayer
---@param endpoint table|nil
---@return table|nil
---@return string|nil
function EndpointResolver.refresh(player, endpoint)
    if type(endpoint) ~= "table" then
        return nil, "invalid_endpoint"
    end

    local refreshed, reason = EndpointResolver.resolve(player, endpoint.args)
    if not refreshed then
        return nil, reason
    end

    if endpoint.key and refreshed.key ~= endpoint.key then
        return nil, "endpoint_mismatch"
    end

    endpoint.object = refreshed.object
    endpoint.data = refreshed.data
    endpoint.barrelId = refreshed.barrelId
    endpoint.key = refreshed.key
    refreshBarrelState(endpoint)
    return endpoint, nil
end

---@param endpoint table|nil
---@return table|nil
function EndpointResolver.snapshot(endpoint)
    if type(endpoint) ~= "table" then return nil end
    if type(endpoint.snapshot) == "function" then
        return endpoint.snapshot(endpoint)
    end
    if endpoint.kind == EndpointResolver.KIND.BARREL then
        return barrelSnapshot(endpoint)
    end
    return nil
end

---@param endpoint table|nil
function EndpointResolver.sync(endpoint)
    if type(endpoint) ~= "table" then return end
    if type(endpoint.sync) == "function" then
        endpoint.sync(endpoint)
        return
    end
    if endpoint.kind == EndpointResolver.KIND.BARREL and endpoint.object then
        barrelSync(endpoint)
    end
end

---@param endpoint table|nil
---@param bumpRevision boolean|nil
---@param transmit boolean|nil
---@return table|nil
function EndpointResolver.persist(endpoint, bumpRevision, transmit)
    if type(endpoint) ~= "table" then return nil end
    if type(endpoint.persist) == "function" then
        return endpoint.persist(endpoint, bumpRevision, transmit)
    end
    if endpoint.kind ~= EndpointResolver.KIND.BARREL then return nil end
    if not endpoint.object or not endpoint.data then return nil end

    return barrelPersist(endpoint, bumpRevision, transmit)
end

---@param endpoint table|nil
---@return string|nil
function EndpointResolver.getLiquidType(endpoint)
    if type(endpoint) ~= "table" then return nil end
    return endpoint.liquidType
end

---@param endpoint table|nil
---@return number
function EndpointResolver.getAmount(endpoint)
    return math.max(tonumber(type(endpoint) == "table" and endpoint.amount) or 0, 0)
end

---@param endpoint table|nil
---@return number
function EndpointResolver.getCapacity(endpoint)
    return math.max(tonumber(type(endpoint) == "table" and endpoint.capacity) or 0, 0)
end

---@param endpoint table|nil
---@return number
function EndpointResolver.getFreeCapacity(endpoint)
    return math.max(tonumber(type(endpoint) == "table" and endpoint.freeCapacity) or 0, 0)
end

---@param endpoint table|nil
---@return boolean
function EndpointResolver.canProvide(endpoint)
    if type(endpoint) ~= "table" then return false end
    if type(endpoint.canProvide) == "function" then
        return endpoint.canProvide(endpoint)
    end

    return false
end

---@param endpoint table|nil
---@param liquidType string|nil
---@return boolean
function EndpointResolver.canReceive(endpoint, liquidType)
    if type(endpoint) ~= "table" then return false end
    if type(endpoint.canReceive) == "function" then
        return endpoint.canReceive(endpoint, liquidType)
    end

    return false
end

---@param endpoint table|nil
---@param amount number|nil
---@return number
function EndpointResolver.removeLiquid(endpoint, amount)
    if type(endpoint) ~= "table" then return 0 end
    if type(endpoint.removeLiquid) == "function" then
        return endpoint.removeLiquid(endpoint, amount)
    end
    return 0
end

---@param endpoint table|nil
---@param liquidType string|nil
---@param amount number|nil
---@return number
function EndpointResolver.addLiquid(endpoint, liquidType, amount)
    if type(endpoint) ~= "table" then return 0 end
    if type(endpoint.addLiquid) == "function" then
        return endpoint.addLiquid(endpoint, liquidType, amount)
    end
    return 0
end

return EndpointResolver
