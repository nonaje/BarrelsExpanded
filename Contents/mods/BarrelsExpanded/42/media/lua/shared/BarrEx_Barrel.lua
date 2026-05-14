local Constant = require("BarrEx_Constant")

---@class BarrEx_Barrel
---@field id string|nil
---@field liquidType string|nil
---@field amount number
---@field capacity number
local BarrEx_Barrel = {}

BarrEx_Barrel.__index = BarrEx_Barrel

---@param data table|nil
---@return BarrEx_Barrel
function BarrEx_Barrel:new(data)
    data = data or {}

    local instance = setmetatable({}, self)

    instance.id = data.id
    instance.liquidType = data.liquidType
    instance.amount = data.amount or 0
    instance.capacity = data.capacity or Constant.BARREL_DEFAULT_CAPACITY

    return instance
end

---@return boolean
function BarrEx_Barrel:isEmpty()
    return self.amount <= 0
end

---@return boolean
function BarrEx_Barrel:isFull()
    return self.amount >= self.capacity
end

---@return number
function BarrEx_Barrel:getFreeCapacity()
    return math.max(self.capacity - self.amount, 0)
end

---@param liquidType string
---@return boolean
function BarrEx_Barrel:canAcceptLiquid(liquidType)
    if Constant.LIQUID_TYPE[liquidType] == nil then
        return false
    end

    if self:isEmpty() then
        return true
    end

    return self.liquidType == liquidType
end

---@param liquidType string
---@param amount number
---@return number addedAmount
function BarrEx_Barrel:addLiquid(liquidType, amount)
    if amount <= 0 then
        return 0
    end

    if not self:canAcceptLiquid(liquidType) then
        return 0
    end

    local addedAmount = math.min(amount, self:getFreeCapacity())

    if addedAmount <= 0 then
        return 0
    end

    self.liquidType = liquidType
    self.amount = self.amount + addedAmount

    return addedAmount
end

---@param amount number
---@return number removedAmount
function BarrEx_Barrel:removeLiquid(amount)
    if amount <= 0 then
        return 0
    end

    local removedAmount = math.min(amount, self.amount)

    self.amount = self.amount - removedAmount

    if self.amount <= 0 then
        self.amount = 0
        self.liquidType = nil
    end

    return removedAmount
end

---@return table
function BarrEx_Barrel:toData()
    return {
        id = self.id,
        liquidType = self.liquidType,
        amount = self.amount,
        capacity = self.capacity,
    }
end

---@param data table
---@return BarrEx_Barrel
function BarrEx_Barrel:fromData(data)
    return BarrEx_Barrel:new(data)
end

return BarrEx_Barrel