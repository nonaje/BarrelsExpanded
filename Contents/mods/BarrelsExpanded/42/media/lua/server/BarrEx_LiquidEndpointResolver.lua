-- BarrEx_LiquidEndpointResolver: resolves liquid endpoints for reusable transfers.
--
-- V1 registers world barrels and generators. Future adapters can add vehicle
-- fuel tanks, gas-station pumps, or persistent supply links without changing the transfer lifecycle.

local Constant          = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrelResolver    = require("BarrEx_BarrelResolver")
local InteractionRules  = require("core/BarrEx_InteractionRules")
local LockService       = require("BarrEx_BarrelLockService")
local StateService      = require("BarrEx_BarrelStateService")
local GeneratorUtils    = require("utils/BarrEx_GeneratorUtils")

local EndpointResolver = {}

EndpointResolver.KIND = {
    BARREL = "barrel",
    GENERATOR = "generator",
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

local function refreshGeneratorState(endpoint)
    local generator = type(endpoint) == "table" and endpoint.object or nil
    endpoint.liquidType = Constant.LIQUID_TYPE.GASOLINE
    endpoint.amount = GeneratorUtils.getFuel(generator)
    endpoint.capacity = GeneratorUtils.getMaxFuel(generator)
    endpoint.freeCapacity = GeneratorUtils.getFreeFuelCapacity(generator)
    return endpoint
end

local function generatorSnapshot(endpoint)
    local generator = type(endpoint) == "table" and endpoint.object or nil
    if not GeneratorUtils.isGenerator(generator) then return nil end

    local square = generator:getSquare()
    return {
        kind = EndpointResolver.KIND.GENERATOR,
        generatorKey = endpoint.key,
        liquidType = Constant.LIQUID_TYPE.GASOLINE,
        amount = GeneratorUtils.getFuel(generator),
        capacity = GeneratorUtils.getMaxFuel(generator),
        freeCapacity = GeneratorUtils.getFreeFuelCapacity(generator),
        fuelPercent = GeneratorUtils.getFuelPercent(generator),
        x = square and square:getX() or nil,
        y = square and square:getY() or nil,
        z = square and square:getZ() or nil,
        objectIndex = GeneratorUtils.getObjectIndex(generator),
    }
end

local function generatorSync(endpoint)
    GeneratorUtils.sync(type(endpoint) == "table" and endpoint.object or nil)
end

local function generatorPersist(endpoint, _bumpRevision, transmit)
    refreshGeneratorState(endpoint)
    if transmit == true then
        generatorSync(endpoint)
    end

    return generatorSnapshot(endpoint)
end

local function generatorCanProvide(_endpoint)
    return false
end

local function generatorCanReceive(endpoint, liquidType)
    if liquidType ~= Constant.LIQUID_TYPE.GASOLINE then return false end

    return GeneratorUtils.canReceiveFuel(type(endpoint) == "table" and endpoint.object or nil)
end

local function generatorRemoveLiquid(_endpoint, _amount)
    return 0
end

local function generatorAddLiquid(endpoint, liquidType, amount)
    if liquidType ~= Constant.LIQUID_TYPE.GASOLINE then return 0 end

    local added = GeneratorUtils.addFuel(type(endpoint) == "table" and endpoint.object or nil, amount)
    refreshGeneratorState(endpoint)
    return added
end

local function buildGeneratorEndpoint(generator, args, key)
    return refreshGeneratorState({
        kind = EndpointResolver.KIND.GENERATOR,
        key = key,
        object = generator,
        args = args,
        canProvide = generatorCanProvide,
        canReceive = generatorCanReceive,
        removeLiquid = generatorRemoveLiquid,
        addLiquid = generatorAddLiquid,
        persist = generatorPersist,
        sync = generatorSync,
        snapshot = generatorSnapshot,
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

local function getCellSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

local function resolveGenerator(player, args)
    if type(args) ~= "table" then
        return nil, "invalid_endpoint"
    end
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then
        return nil, "invalid_endpoint"
    end

    local generator, reason = GeneratorUtils.resolveOnSquare(getCellSquare(args.x, args.y, args.z), args)
    if not generator then
        if reason == "target_not_found" then
            return nil, "generator_not_found"
        end
        return nil, reason or "generator_not_found"
    end

    if not InteractionRules.validateInteraction(generator, player, {}, false) then
        return nil, "interaction_invalid"
    end

    local key = GeneratorUtils.getKey(generator)
    if not key then
        return nil, "generator_not_found"
    end

    return buildGeneratorEndpoint(generator, args, key), nil
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
    if kind == EndpointResolver.KIND.GENERATOR then
        return resolveGenerator(player, args)
    end
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
    if endpoint.kind == EndpointResolver.KIND.GENERATOR then
        refreshGeneratorState(endpoint)
    else
        refreshBarrelState(endpoint)
    end
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
    if endpoint.kind == EndpointResolver.KIND.GENERATOR then
        return generatorSnapshot(endpoint)
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
    if endpoint.kind == EndpointResolver.KIND.GENERATOR and endpoint.object then
        generatorSync(endpoint)
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
    if endpoint.kind == EndpointResolver.KIND.GENERATOR then
        return generatorPersist(endpoint, bumpRevision, transmit)
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
