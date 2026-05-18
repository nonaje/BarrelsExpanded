local Constant = require("BarrEx_Constant")

local WorldUtils = {}

---@param worldObject IsoObject|nil
---@return string|nil
function WorldUtils.getSpriteName(worldObject)
    if not worldObject then return nil end

    local sprite = worldObject:getSprite()
    if not sprite then return nil end

    local spriteName = sprite:getName()
    if not spriteName or spriteName == "" then return nil end

    return spriteName
end

---@param worldObject IsoObject|nil
---@return string|nil
function WorldUtils.getBarrelIconSpriteName(worldObject)
    local spriteName = WorldUtils.getSpriteName(worldObject)
    if not spriteName then return nil end

    return Constant.BARREL_TILE_NAME_TO_ICON_TILE_NAME[spriteName] or spriteName
end

---@param worldObject IsoObject|nil
---@return boolean
function WorldUtils.isExpandableBarrel(worldObject)
    local spriteName = WorldUtils.getSpriteName(worldObject)
    return spriteName ~= nil and Constant.BARREL_TILE_NAMES[spriteName] == true
end

---@param worldObject IsoObject|nil
---@return string|nil
function WorldUtils.getBarrelCategory(worldObject)
    local spriteName = WorldUtils.getSpriteName(worldObject)
    if not spriteName then return nil end

    local category = Constant.BARREL_TILE_NAME_TO_CATEGORY[spriteName]
    if category then return category end

    return nil
end

---@param square IsoGridSquare|nil
---@return IsoObject|nil
function WorldUtils.findExpandableBarrelOnSquare(square)
    if not square then return nil end

    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if WorldUtils.isExpandableBarrel(object) then
            return object
        end
    end

    return nil
end

return WorldUtils
