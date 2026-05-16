local Constant = require("BarrEx_Constant")
local BarrEx_BarrelUseAction = require("BarrEx_BarrelUseAction")

---@class BarrEx_WashFromBarrelAction : BarrEx_BarrelUseAction
---@field washMode string
---@field item InventoryItem|nil
local BarrEx_WashFromBarrelAction = BarrEx_BarrelUseAction:derive("BarrEx_WashFromBarrelAction")

function BarrEx_WashFromBarrelAction:getAnimName()
    if self.washMode == "item" then
        return "ScrubClothWithSoap"
    end
    return "WashFace"
end

function BarrEx_WashFromBarrelAction:getSoundName()
    if self.washMode == "item" then
        return "WashClothing"
    end
    return "WashYourself"
end

function BarrEx_WashFromBarrelAction:decoratePayload(payload)
    payload.washMode = self.washMode

    if self.item then
        payload.itemId = self.item:getID()
        payload.itemFullType = self.item:getFullType()
    end
end

function BarrEx_WashFromBarrelAction:isValid()
    if not BarrEx_BarrelUseAction.isValid(self) then return false end
    if self.washMode ~= "item" then return true end
    if not self.item then return false end

    local inventory = self.character:getInventory()
    if not inventory then return false end
    if type(inventory.containsID) == "function" then
        return inventory:containsID(self.item:getID())
    end
    return inventory:contains(self.item)
end

function BarrEx_WashFromBarrelAction:start()
    BarrEx_BarrelUseAction.start(self)
    if self.item and type(self.item.setJobDelta) == "function" then
        self.item:setJobDelta(0.0)
    end
end

function BarrEx_WashFromBarrelAction:update()
    if self.item and type(self.item.setJobDelta) == "function" then
        self.item:setJobDelta(self:getJobDelta())
    end
    BarrEx_BarrelUseAction.update(self)
end

function BarrEx_WashFromBarrelAction:stop()
    if self.item and type(self.item.setJobDelta) == "function" then
        self.item:setJobDelta(0.0)
    end
    BarrEx_BarrelUseAction.stop(self)
end

function BarrEx_WashFromBarrelAction:perform()
    if self.item and type(self.item.setJobDelta) == "function" then
        self.item:setJobDelta(0.0)
    end
    BarrEx_BarrelUseAction.perform(self)
end

-- Returns true when the player has enough soap to wash the given item at normal speed.
-- Mirrors vanilla ISWashClothing: soap covers blood stains, so only blood-stained items require soap.
local function playerHasSoapForItem(player, item)
    if not ISWashClothing
        or type(ISWashClothing.GetRequiredSoap) ~= "function"
        or type(ISWashClothing.GetSoapRemaining) ~= "function"
    then
        return false
    end
    local required = tonumber(ISWashClothing.GetRequiredSoap(item)) or 0
    if required <= 0 then return true end
    local inventory = player and player:getInventory()
    if not inventory then return false end
    local soaps = inventory:getSoapList(nil, true)
    local remaining = tonumber(ISWashClothing.GetSoapRemaining(soaps)) or 0
    return remaining >= required
end

-- Returns true when the player has enough soap to wash themselves at normal speed.
-- Mirrors vanilla ISWashYourself: soap reduces duration from 126/unit to 70/unit.
local function playerHasSoapForSelf(player)
    if not ISWashYourself or not ISWashClothing
        or type(ISWashYourself.GetRequiredSoap) ~= "function"
        or type(ISWashClothing.GetSoapRemaining) ~= "function"
    then
        return false
    end
    local required = tonumber(ISWashYourself.GetRequiredSoap(player)) or 0
    if required <= 0 then return true end
    local inventory = player and player:getInventory()
    if not inventory then return false end
    local soaps = inventory:getSoapList(nil, false)
    local remaining = tonumber(ISWashClothing.GetSoapRemaining(soaps)) or 0
    return remaining >= required
end

-- Duration mirrors ISWashYourself:getDuration():
--   with soap:    waterUnits * 70
--   without soap: waterUnits * 126
local function getSelfDuration(player)
    local required = 0
    if ISWashYourself and type(ISWashYourself.GetRequiredWater) == "function" then
        required = math.max(tonumber(ISWashYourself.GetRequiredWater(player)) or 0, 0)
    end
    if required == 0 then return 100 end
    return playerHasSoapForSelf(player) and (required * 70) or (required * 126)
end

-- Duration mirrors ISWashClothing:getDuration():
--   base  = (totalBlood + totalDirt) * 15, capped at 500
--   noSoap multiplier: * 5
--   hard cap: [100, 800]
local function getItemDuration(player, item)
    if not item then return 100 end
    local blood, dirt = 0, 0
    if instanceof and instanceof(item, "Clothing")
        and BloodClothingType
        and type(item.getBloodClothingType) == "function"
    then
        local coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        if coveredParts then
            for i = 0, coveredParts:size() - 1 do
                local part = coveredParts:get(i)
                blood = blood + (tonumber(item:getBlood(part)) or 0)
                dirt  = dirt  + (tonumber(item:getDirt(part))  or 0)
            end
        end
    elseif type(item.getBloodLevel) == "function" then
        blood = tonumber(item:getBloodLevel()) or 0
    end
    local maxTime = (blood + dirt) * 15
    if maxTime > 500 then maxTime = 500 end
    if not playerHasSoapForItem(player, item) then maxTime = maxTime * 5 end
    if maxTime > 800 then maxTime = 800 end
    if maxTime < 100 then maxTime = 100 end
    return maxTime
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param washMode string
---@param item InventoryItem|nil
---@return BarrEx_WashFromBarrelAction
function BarrEx_WashFromBarrelAction:new(player, barrel, washMode, item)
    local maxTime = washMode == "item" and getItemDuration(player, item) or getSelfDuration(player)
    local o = BarrEx_BarrelUseAction.new(self, player, barrel, Constant.NETWORK.WASH_FROM_BARREL, maxTime)
    ---@cast o BarrEx_WashFromBarrelAction
    o.washMode = washMode or "self"
    o.item = item
    o.forceProgressBar = true
    return o
end

return BarrEx_WashFromBarrelAction
