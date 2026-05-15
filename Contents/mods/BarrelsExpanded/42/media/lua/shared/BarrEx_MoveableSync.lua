require "Moveables/ISMoveableSpriteProps"

local Constant = require("BarrEx_Constant")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local Logger = require("utils/BarrEx_Logger")

local BarrEx_MoveableSync = {}

local started = false
local originalFromObject = nil
local originalCanPickUpMoveable = nil
local originalPickUpMoveableInternal = nil
local originalPlaceMoveableInternal = nil

local function log(message)
    Logger.info("[MoveableSync] " .. tostring(message))
end

local function isBarrelMoveable(worldObject)
    return worldObject ~= nil and WorldUtils.isExpandableBarrel(worldObject)
end

local function isBarrelSpriteName(spriteName)
    return type(spriteName) == "string" and Constant.BARREL_TILE_NAMES[spriteName] == true
end

local function findInventoryItemFromArgs(...)
    local argCount = select("#", ...)
    for i = 1, argCount do
        local value = select(i, ...)
        if value and type(value) == "userdata" and type(value.getModData) == "function" and type(value.getType) == "function" then
            return value
        end
    end
    return nil
end

local function findSquareFromArgs(...)
    local argCount = select("#", ...)
    for i = 1, argCount do
        local value = select(i, ...)
        if value and type(value) == "userdata" and type(value.getObjects) == "function" and type(value.getX) == "function" then
            return value
        end
    end
    return nil
end

local function findSpriteNameFromArgs(...)
    local argCount = select("#", ...)
    for i = 1, argCount do
        local value = select(i, ...)
        if type(value) == "string" and Constant.BARREL_TILE_NAMES[value] == true then
            return value
        end
    end
    return nil
end

local function markPlacedBarrelAsPlayerCrafted(item)
    if not item then return end

    local itemModData = item:getModData()
    if not itemModData then return end

    -- Items already carrying barrel payload came from world barrels.
    if type(itemModData[Constant.MODDATA_KEYS.BARREL]) == "table" then
        return
    end

    BarrEx_BarrelData.writeSpawnProfile(itemModData, Constant.BARREL_SPAWN_PROFILE.PLAYER_CRAFTED)
end

local function findNewestBarrelOnSquare(square)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    for i = objects:size() - 1, 0, -1 do
        local object = objects:get(i)
        if WorldUtils.isExpandableBarrel(object) then
            return object
        end
    end

    return nil
end

local function applyItemSpawnProfileToNewestPlacedBarrel(item, square)
    if not item or not square then return end

    local itemModData = item:getModData()
    if not itemModData then return end

    local spawnProfile = itemModData[Constant.MODDATA_KEYS.BARREL_SPAWN_PROFILE]
    if spawnProfile ~= Constant.BARREL_SPAWN_PROFILE.PLAYER_CRAFTED then
        return
    end

    local barrel = findNewestBarrelOnSquare(square)
    if not barrel then return end

    local barrelModData = barrel:getModData()
    if not barrelModData then return end

    BarrEx_BarrelData.writeSpawnProfile(barrelModData, spawnProfile)
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
        if props and props.isMoveable and WorldUtils.isExpandableBarrel(object) then
            local modData = object:getModData()
            local cachedWeight = modData and modData[Constant.MODDATA_KEYS.BARREL_WEIGHT] or nil

            if type(cachedWeight) == "number" then
                props.weight = cachedWeight
            else
                -- Fallback for barrels that still have no cached weight.
                local barrelData = BarrEx_BarrelData.get(object)
                if barrelData then
                    props.weight = barrelData:getTotalWeight()
                end
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
        if object and WorldUtils.isExpandableBarrel(object) then
            -- Read the pre-computed weight from modData instead of calling get(),
            -- which would allocate a BarrEx_Barrel table on every cursor frame.
            local modData = object:getModData()
            if modData then
                local w = modData[Constant.MODDATA_KEYS.BARREL_WEIGHT]
                if type(w) == "number" then
                    self.weight = w
                end
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

    if type(ISMoveableSpriteProps.placeMoveableInternal) == "function" then
        originalPlaceMoveableInternal = ISMoveableSpriteProps.placeMoveableInternal
        rawset(ISMoveableSpriteProps, "placeMoveableInternal", function(self, ...)
            local item = findInventoryItemFromArgs(...)
            local square = findSquareFromArgs(...)
            local spriteName = findSpriteNameFromArgs(...)
            local isBarrelPlacement = isBarrelSpriteName(spriteName)

            if item and isBarrelPlacement then
                markPlacedBarrelAsPlayerCrafted(item)
            end

            local result = originalPlaceMoveableInternal(self, ...)

            if item and isBarrelPlacement then
                applyItemSpawnProfileToNewestPlacedBarrel(item, square)
            end

            return result
        end)
    end

    log("Moveable pickup/place hooks installed.")
end

return BarrEx_MoveableSync
