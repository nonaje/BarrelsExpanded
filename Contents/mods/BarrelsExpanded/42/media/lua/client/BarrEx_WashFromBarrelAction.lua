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

local function getSelfDuration(player)
    local required = 1
    if ISWashYourself and type(ISWashYourself.GetRequiredWater) == "function" then
        required = math.max(tonumber(ISWashYourself.GetRequiredWater(player)) or 1, 1)
    end
    return math.min(math.max(required * 70, 100), 800)
end

local function getItemDuration(item)
    local maxTime = 100
    if item and ISWashClothing and type(ISWashClothing.GetRequiredWater) == "function" then
        maxTime = math.min(math.max((tonumber(ISWashClothing.GetRequiredWater(item)) or 1) * 15, 100), 800)
    end
    return maxTime
end

---@param player IsoPlayer
---@param barrel IsoObject
---@param washMode string
---@param item InventoryItem|nil
---@return BarrEx_WashFromBarrelAction
function BarrEx_WashFromBarrelAction:new(player, barrel, washMode, item)
    local maxTime = washMode == "item" and getItemDuration(item) or getSelfDuration(player)
    local o = BarrEx_BarrelUseAction.new(self, player, barrel, Constant.NETWORK.WASH_FROM_BARREL, maxTime)
    ---@cast o BarrEx_WashFromBarrelAction
    o.washMode = washMode or "self"
    o.item = item
    o.forceProgressBar = true
    return o
end

return BarrEx_WashFromBarrelAction
