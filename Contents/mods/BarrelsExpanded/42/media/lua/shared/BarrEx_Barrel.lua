local Constant = require("BarrEx_Constant")

---@class BarrEx_Barrel
---@field id string|nil
---@field liquidType string|nil
---@field amount number
---@field capacity number
---@field revealed boolean
local BarrEx_Barrel = {}
local EMPTY_AMOUNT_EPSILON = 0.0001

BarrEx_Barrel.__index = BarrEx_Barrel

---@param data table|nil
---@return BarrEx_Barrel
function BarrEx_Barrel:new(data)
    data = data or {}

    local instance = setmetatable({}, self)
    local emptyType = Constant.LIQUID_TYPE.EMPTY

    instance.id = data.id
    instance.liquidType = data.liquidType or emptyType
    instance.amount = tonumber(data.amount) or 0
    instance.capacity = tonumber(data.capacity) or Constant.BARREL_DEFAULT_CAPACITY
    instance.revealed = data.revealed == true

    if instance.capacity < 0 then
        instance.capacity = 0
    end

    if Constant.LIQUID_TYPE[instance.liquidType] == nil then
        instance.liquidType = emptyType
    end

    if instance.amount < 0 then
        instance.amount = 0
    end

    if instance.amount <= EMPTY_AMOUNT_EPSILON then
        instance.liquidType = emptyType
        instance.amount = 0
    elseif instance.liquidType == emptyType or instance.capacity <= 0 then
        instance.liquidType = emptyType
        instance.amount = 0
    elseif instance.amount > instance.capacity then
        instance.amount = instance.capacity
    end

    return instance
end

---@return boolean
function BarrEx_Barrel:isEmpty()
    return self.amount <= EMPTY_AMOUNT_EPSILON or self.liquidType == Constant.LIQUID_TYPE.EMPTY
end

---@return boolean
function BarrEx_Barrel:isRevealed()
    return self.revealed == true
end

---@return boolean
function BarrEx_Barrel:isFull()
    return self.amount >= self.capacity
end

---@return number
function BarrEx_Barrel:getFreeCapacity()
    return math.max(self.capacity - self.amount, 0)
end

---@return number
function BarrEx_Barrel:getLiquidWeightPerUnit()
    if not self.liquidType or self.liquidType == Constant.LIQUID_TYPE.EMPTY then
        return 0
    end

    local weightPerUnit = Constant.BARREL_LIQUID_WEIGHT_PER_UNIT[self.liquidType]
    if weightPerUnit == nil then
        return 0
    end

    return weightPerUnit
end

---@return number
function BarrEx_Barrel:getLiquidWeight()
    if self:isEmpty() then
        return 0
    end

    return self.amount * self:getLiquidWeightPerUnit()
end

---@return number
function BarrEx_Barrel:getTotalWeight()
    local baseWeight = Constant.BARREL_EMPTY_WEIGHT or 0
    return baseWeight + self:getLiquidWeight()
end

---@param liquidType string
---@param amount number|nil
---@return boolean
function BarrEx_Barrel:canAcceptLiquid(liquidType, amount)
    if Constant.LIQUID_TYPE[liquidType] == nil then
        return false
    end

    local requested = tonumber(amount)
    if requested and requested <= 0 then
        return false
    end

    if liquidType == Constant.LIQUID_TYPE.EMPTY then
        return self:isEmpty()
    end

    if self:isEmpty() then
        return true
    end

    return self.liquidType == liquidType
end

---@param amount number
---@return boolean
function BarrEx_Barrel:canRemoveLiquid(amount)
    local requested = tonumber(amount)
    if not requested or requested <= 0 then
        return false
    end

    return not self:isEmpty()
end

---@param liquidType string
---@param amount number
---@return number addedAmount
function BarrEx_Barrel:addLiquid(liquidType, amount)
    if amount <= 0 then
        return 0
    end

    if liquidType == Constant.LIQUID_TYPE.EMPTY then
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
    if not self:canRemoveLiquid(amount) then
        return 0
    end

    local removedAmount = math.min(amount, self.amount)

    self.amount = self.amount - removedAmount

    if self.amount <= EMPTY_AMOUNT_EPSILON then
        self.amount = 0
        self.liquidType = Constant.LIQUID_TYPE.EMPTY
    end

    return removedAmount
end

---@return table
function BarrEx_Barrel:toData()
    local isEmpty = self:isEmpty()

    return {
        id = self.id,
        liquidType = isEmpty and Constant.LIQUID_TYPE.EMPTY or self.liquidType,
        amount = isEmpty and 0 or self.amount,
        capacity = self.capacity,
        revealed = self.revealed,
    }
end

---@param data table|nil
---@return BarrEx_Barrel
function BarrEx_Barrel:fromData(data)
    return BarrEx_Barrel:new(data)
end

return BarrEx_Barrel
