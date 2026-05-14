local Constant = require("BarrEx_Constant")
local BarrEx_Barrel = require("BarrEx_Barrel")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

local BarrEx_BarrelFactory = {}

-- Built once at module load; Constant.LIQUID_TYPE is a static table.
local liquidTypesList = {}
for _, value in pairs(Constant.LIQUID_TYPE) do
    liquidTypesList[#liquidTypesList + 1] = value
end

local function getRandomLiquidType()
    if #liquidTypesList == 0 then return nil end
    return liquidTypesList[ZombRand(1, #liquidTypesList + 1)]
end

--- Creates a new barrel instance with random contents.
--- @param barrel IsoObject|nil
--- @return BarrEx_Barrel
function BarrEx_BarrelFactory.createRandom(barrel)
    local capacity = Constant.BARREL_DEFAULT_CAPACITY
    local liquidType = getRandomLiquidType()
    -- If no liquid types are registered, produce an empty barrel so that
    -- amount stays consistent with the nil liquidType (fromRawData would
    -- zero it out anyway during normalization).
    local amount = liquidType and ZombRand(1, capacity + 1) or 0

    return BarrEx_Barrel:new({
        id = BarrEx_BarrelData.buildId(barrel),
        liquidType = liquidType,
        amount = amount,
        capacity = capacity,
        revealed = false,
    })
end

return BarrEx_BarrelFactory
