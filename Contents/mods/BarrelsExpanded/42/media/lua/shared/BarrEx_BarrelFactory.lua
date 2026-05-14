local Constant = require("BarrEx_Constant")
local BarrEx_Barrel = require("BarrEx_Barrel")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

local BarrEx_BarrelFactory = {}

local function getRandomLiquidType()
    local liquidTypes = {}

    for _, value in pairs(Constant.LIQUID_TYPE) do
        liquidTypes[#liquidTypes + 1] = value
    end

    if #liquidTypes == 0 then
        return nil
    end

    local index = ZombRand(1, #liquidTypes + 1)
    return liquidTypes[index]
end

--- Creates a new barrel instance with random contents.
--- @param barrel IsoObject|nil
--- @return BarrEx_Barrel
function BarrEx_BarrelFactory.createRandom(barrel)
    local capacity = Constant.BARREL_DEFAULT_CAPACITY
    local amount = ZombRand(1, capacity + 1)

    return BarrEx_Barrel:new({
        id = BarrEx_BarrelData.buildId(barrel),
        liquidType = getRandomLiquidType(),
        amount = amount,
        capacity = capacity,
    })
end

return BarrEx_BarrelFactory
