require "Moveables/ISMoveableSpriteProps"

local Constant = require("BarrEx_Constant")
local Utils = require("BarrEx_Utils")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

local BarrEx_MoveableSync = {}

local started = false
local originalFromObject = nil
local originalCanPickUpMoveable = nil
local originalPickUpMoveableInternal = nil

local function log(message)
    print(Constant.LOG_PREFIX .. " [MoveableSync] " .. message)
end

local function isBarrelMoveable(worldObject)
    return worldObject ~= nil and Utils.isExpandableBarrel(worldObject)
end

local function decoratePickedUpItem(item, worldObject)
    if not item or not isBarrelMoveable(worldObject) then
        return
    end

    local barrelData = BarrEx_BarrelData.copyWorldDataToItem(worldObject, item)
    if not barrelData then
        return
    end

    log(string.format(
        "Applied barrel payload to picked item: id=%s weight=%.2f",
        barrelData.id or "unknown",
        barrelData:getTotalWeight()
    ))
end

function BarrEx_MoveableSync.start()
    if started then return end

    if not ISMoveableSpriteProps or type(ISMoveableSpriteProps.pickUpMoveableInternal) ~= "function" then
        log("Moveable sync unavailable; ISMoveableSpriteProps not loaded.")
        return
    end

    started = true

    -- Patch fromObject so every caller (ISMoveablesAction:new, getObjectList for the
    -- tooltip info-panel) sees the real total weight (base + liquid) in props.weight.
    -- This fixes both the tooltip display and the action-time canPickUpMoveable check.
    originalFromObject = ISMoveableSpriteProps.fromObject
    rawset(ISMoveableSpriteProps, "fromObject", function(object)
        local props = originalFromObject(object)
        if props and props.isMoveable and Utils.isExpandableBarrel(object) then
            local barrelData = BarrEx_BarrelData.get(object)
            if barrelData then
                props.weight = barrelData:getTotalWeight()
            end
        end
        return props
    end)

    -- Patch canPickUpMoveable so the real barrel weight is used for the inventory
    -- capacity check in EVERY caller:
    --   1. ISMoveableCursor.isValid() calls moveProps:canPickUpMoveable() to decide
    --      whether to set canCreate=true. moveProps comes from getObjectList()→new(),
    --      which always returns weight=20. Without this patch the cursor check passes
    --      for any opened barrel regardless of how heavy it actually is.
    --   2. ISMoveablesAction:complete() calls pickUpMoveable()→canPickUpMoveable().
    --      Its moveProps come from fromObject() (our patched version, weight=realWeight).
    --      Without fixing the cursor side, the action is queued when it shouldn't be,
    --      then fails silently at completion because realWeight > player carry capacity.
    -- Setting self.weight permanently (no restore) also lets getInfoPanelDescription
    -- pick up the correct value for the tooltip weight display.
    originalCanPickUpMoveable = ISMoveableSpriteProps.canPickUpMoveable
    rawset(ISMoveableSpriteProps, "canPickUpMoveable", function(self, character, square, object)
        if object and Utils.isExpandableBarrel(object) then
            local barrelData = BarrEx_BarrelData.get(object)
            if barrelData then
                self.weight = barrelData:getTotalWeight()
            end
        end
        return originalCanPickUpMoveable(self, character, square, object)
    end)

    -- After vanilla creates the item (instanceItem already uses self.weight = real weight
    -- from the fromObject patch), copy barrel-specific modData to the InventoryItem.
    originalPickUpMoveableInternal = ISMoveableSpriteProps.pickUpMoveableInternal
    rawset(ISMoveableSpriteProps, "pickUpMoveableInternal", function(self, character, square, worldObject, sprInstance, spriteName, createItem, rotating)
        local item = originalPickUpMoveableInternal(self, character, square, worldObject, sprInstance, spriteName, createItem, rotating)
        decoratePickedUpItem(item, worldObject)
        return item
    end)

    log("Moveable pickup hook installed.")
end

return BarrEx_MoveableSync