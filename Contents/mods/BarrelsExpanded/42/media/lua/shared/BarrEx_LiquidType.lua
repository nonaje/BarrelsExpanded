local Constant = require("BarrEx_Constant")

---@class BarrEx_LiquidType
---@field liquidType string
local BarrEx_LiquidType = {}

BarrEx_LiquidType.__index = BarrEx_LiquidType

---@param liquidType string
---@return BarrEx_LiquidType|nil
function BarrEx_LiquidType:new(liquidType)
    if not Constant.LIQUID_TYPE[liquidType] then
        return nil
    end

    local instance = setmetatable({}, self)

    instance.liquidType = liquidType

    return instance
end

return BarrEx_LiquidType