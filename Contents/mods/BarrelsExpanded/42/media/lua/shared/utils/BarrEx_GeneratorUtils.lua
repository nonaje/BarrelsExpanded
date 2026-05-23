local GeneratorUtils = {}
local FULL_FUEL_PERCENT = 100

---@class BarrEx_GeneratorEndpointArgs
---@field x number|nil
---@field y number|nil
---@field z number|nil
---@field objectIndex number|nil

---@param object any
---@return boolean
local function isTable(object)
    return type(object) == "table"
end

---@param object any
---@param className string
---@return boolean
local function isInstanceOf(object, className)
    if type(instanceof) ~= "function" then return false end
    if type(object) ~= "userdata" then return false end
    return instanceof(object, className) == true
end

---@param object any
---@param methodName string
---@return boolean
local function hasMethod(object, methodName)
    if not isTable(object) then return false end
    return type(object[methodName]) == "function"
end

---@param object any
---@return boolean
function GeneratorUtils.isGenerator(object)
    if isInstanceOf(object, "IsoGenerator") then
        return true
    end
    if not isTable(object) then return false end

    return hasMethod(object, "getFuel")
        and hasMethod(object, "setFuel")
        and hasMethod(object, "getMaxFuel")
        and hasMethod(object, "sync")
end

---@param generator IsoGenerator|nil
---@return number|nil
function GeneratorUtils.getObjectIndex(generator)
    if not GeneratorUtils.isGenerator(generator) then return nil end

    if isTable(generator) and type(generator.getObjectIndex) ~= "function" then return nil end

    local objectIndex = generator:getObjectIndex()
    if type(objectIndex) ~= "number" or objectIndex < 0 then return nil end
    return objectIndex
end

---@param generator IsoGenerator|nil
---@return boolean
function GeneratorUtils.isAvailable(generator)
    if not GeneratorUtils.isGenerator(generator) then return false end
    if not generator or not generator:getSquare() then return false end

    return GeneratorUtils.getObjectIndex(generator) ~= nil
end

---@param generator IsoGenerator|nil
---@return number
function GeneratorUtils.getFuel(generator)
    if not GeneratorUtils.isGenerator(generator) then return 0 end
    if not generator then return 0 end
    return math.max(tonumber(generator:getFuel()) or 0, 0)
end

---@param generator IsoGenerator|nil
---@return number
function GeneratorUtils.getMaxFuel(generator)
    if not GeneratorUtils.isGenerator(generator) then return 0 end
    if not generator then return 0 end
    return math.max(tonumber(generator:getMaxFuel()) or 0, 0)
end

---@param generator IsoGenerator|nil
---@return number
local function getRawFreeFuelCapacity(generator)
    return math.max(GeneratorUtils.getMaxFuel(generator) - GeneratorUtils.getFuel(generator), 0)
end

---@param generator IsoGenerator|nil
---@return number
function GeneratorUtils.getFreeFuelCapacity(generator)
    if GeneratorUtils.isFull(generator) then return 0 end
    return getRawFreeFuelCapacity(generator)
end

---@param generator IsoGenerator|nil
---@return number
function GeneratorUtils.getFuelPercent(generator)
    if not GeneratorUtils.isGenerator(generator) then return 0 end
    if not generator then return 0 end
    if type(generator.getFuelPercentage) == "function" then
        return math.max(math.min(tonumber(generator:getFuelPercentage()) or 0, 100), 0)
    end

    local maxFuel = GeneratorUtils.getMaxFuel(generator)
    if maxFuel <= 0 then return 0 end
    return math.max(math.min((GeneratorUtils.getFuel(generator) / maxFuel) * 100, 100), 0)
end

---@param generator IsoGenerator|nil
---@return number
function GeneratorUtils.getDisplayedFuelPercent(generator)
    return math.ceil(GeneratorUtils.getFuelPercent(generator))
end

---@param generator IsoGenerator|nil
---@return boolean
function GeneratorUtils.isFull(generator)
    if not GeneratorUtils.isGenerator(generator) then return false end
    if GeneratorUtils.getDisplayedFuelPercent(generator) >= FULL_FUEL_PERCENT then return true end
    return getRawFreeFuelCapacity(generator) <= 0
end

---@param generator IsoGenerator|nil
---@return boolean
function GeneratorUtils.canReceiveFuel(generator)
    return GeneratorUtils.isAvailable(generator)
        and not GeneratorUtils.isFull(generator)
        and GeneratorUtils.getFreeFuelCapacity(generator) > 0
end

---@param generator IsoGenerator|nil
---@param amount number|nil
---@return number
function GeneratorUtils.addFuel(generator, amount)
    if not GeneratorUtils.canReceiveFuel(generator) then return 0 end
    if not generator then return 0 end

    local added = math.max(math.min(
        tonumber(amount) or 0,
        GeneratorUtils.getFreeFuelCapacity(generator)
    ), 0)
    if added <= 0 then return 0 end

    generator:setFuel(GeneratorUtils.getFuel(generator) + added)

    return added
end

---@param generator IsoGenerator|nil
function GeneratorUtils.sync(generator)
    if generator and GeneratorUtils.isGenerator(generator) and type(generator.sync) == "function" then
        generator:sync()
    end
end

---@param found table<integer, IsoGenerator>
---@param seen table<any, boolean>
---@param object any
local function appendGenerator(found, seen, object)
    if not GeneratorUtils.isGenerator(object) or seen[object] then return end

    seen[object] = true
    found[#found + 1] = object
end

---@param objects any
---@param found table<integer, IsoGenerator>
---@param seen table<any, boolean>
local function collectFromJavaList(objects, found, seen)
    if not objects then return end

    for i = 0, objects:size() - 1 do
        appendGenerator(found, seen, objects:get(i))
    end
end

---@param square IsoGridSquare|nil
---@param found table<integer, IsoGenerator>|nil
---@param seen table|nil
---@return table<integer, IsoGenerator>
function GeneratorUtils.collectGeneratorsOnSquare(square, found, seen)
    found = found or {}
    seen = seen or {}

    if not square then return found end

    collectFromJavaList(square:getSpecialObjects(), found, seen)
    collectFromJavaList(square:getObjects(), found, seen)

    return found
end

---@param generator IsoGenerator|nil
---@param args BarrEx_GeneratorEndpointArgs|nil
---@return boolean
function GeneratorUtils.matchesArgs(generator, args)
    if not GeneratorUtils.isAvailable(generator) then return false end
    if type(args) ~= "table" then return true end

    if type(args.objectIndex) == "number"
        and GeneratorUtils.getObjectIndex(generator) ~= args.objectIndex
    then
        return false
    end

    return true
end

---@param square IsoGridSquare|nil
---@param args BarrEx_GeneratorEndpointArgs|nil
---@return IsoGenerator|nil
---@return string|nil
function GeneratorUtils.resolveOnSquare(square, args)
    if not square then return nil, "target_not_found" end

    local generators = GeneratorUtils.collectGeneratorsOnSquare(square)
    local matches = {}
    for i = 1, #generators do
        local generator = generators[i]
        if GeneratorUtils.matchesArgs(generator, args) then
            matches[#matches + 1] = generator
        end
    end

    if #matches == 1 then return matches[1], nil end
    if #matches > 1 then return nil, "ambiguous_generator" end
    return nil, "target_not_found"
end

---@param generator IsoGenerator|nil
---@return string|nil
function GeneratorUtils.getKey(generator)
    if not GeneratorUtils.isAvailable(generator) then return nil end
    if not generator then return nil end

    local square = generator:getSquare()
    if not square then return nil end

    return "generator:"
        .. tostring(square:getX())
        .. ":" .. tostring(square:getY())
        .. ":" .. tostring(square:getZ())
        .. ":" .. tostring(GeneratorUtils.getObjectIndex(generator))
end

return GeneratorUtils
