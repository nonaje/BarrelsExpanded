local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local Constant = require("BarrEx_Constant")
local Inventory = require("context/BarrEx_ContextMenuInventory")

local Availability = {}

local function isWaterLike(liquidType)
    return liquidType == Constant.LIQUID_TYPE.WATER
        or liquidType == Constant.LIQUID_TYPE.TAINTED_WATER
end

local function isGasoline(liquidType)
    return liquidType == Constant.LIQUID_TYPE.GASOLINE
end

local function playerNeedsDrink(player)
    if not player or not player.getStats then return false end
    local stats = player:getStats()
    return stats and (tonumber(stats:get(CharacterStat.THIRST)) or 0) > 0.1
end

---@param player IsoPlayer
---@param barrelData BarrEx_Barrel
---@param inRange boolean
---@return table
function Availability.build(player, barrelData, inRange)
    local state = {
        liquidType = barrelData and barrelData.liquidType or Constant.LIQUID_TYPE.EMPTY,
        targetItems = {},
        sourceItems = {},
        washItems = {},
        washSelfWaterRequired = 0,
        isWaterLike = false,
        isTaintedWater = false,
        isGasoline = false,
        canFill = false,
        canDrink = false,
        canWash = false,
        canEmpty = false,
        canPour = false,
        hasFillTool = false,
        fillFoundItems = {},
        fillMissingItems = {},
        hasPourTool = false,
        pourFoundItems = {},
        pourMissingItems = {},
        fillReason = nil,
        drinkReason = nil,
        washReason = nil,
        emptyReason = nil,
        pourReason = nil,
    }

    if not barrelData then
        state.fillReason = "barrel_unavailable"
        state.drinkReason = "barrel_unavailable"
        state.washReason = "barrel_unavailable"
        state.emptyReason = "barrel_unavailable"
        state.pourReason = "barrel_unavailable"
        return state
    end

    state.isWaterLike = isWaterLike(state.liquidType)
    state.isTaintedWater = state.liquidType == Constant.LIQUID_TYPE.TAINTED_WATER
    state.isGasoline = isGasoline(state.liquidType)
    state.targetItems = Inventory.collectTargetContainersForExtract(player, barrelData)
    state.sourceItems = Inventory.collectSourceContainersForPour(player, barrelData)
    state.washItems = Inventory.collectWashableItems(player)
    state.washSelfWaterRequired = Inventory.getWashSelfWaterRequired(player)

    local hasFillTool, fillFoundItems, fillMissingItems =
        PlayerUtils.getRequiredItemStatus(player, Constant.EXTRACT_REQUIRED_ITEMS)
    local hasPourTool, pourFoundItems, pourMissingItems =
        PlayerUtils.getRequiredItemStatus(player, Constant.POUR_REQUIRED_ITEMS)

    state.hasFillTool = hasFillTool
    state.fillFoundItems = fillFoundItems
    state.fillMissingItems = fillMissingItems
    state.hasPourTool = hasPourTool
    state.pourFoundItems = pourFoundItems
    state.pourMissingItems = pourMissingItems

    if not inRange then
        state.fillReason = "too_far"
        state.drinkReason = "too_far"
        state.washReason = "too_far"
        state.emptyReason = "too_far"
        state.pourReason = "too_far"
        return state
    end

    if barrelData:isEmpty() then
        state.fillReason = "barrel_empty"
        state.drinkReason = "barrel_empty"
        state.washReason = "barrel_empty"
        state.emptyReason = "barrel_empty"
    elseif not hasFillTool then
        state.fillReason = "missing_tool"
    elseif #state.targetItems == 0 then
        state.fillReason = "no_target_items"
    else
        state.canFill = true
    end

    if barrelData:isEmpty() then
        -- reason already set above
    elseif not state.isWaterLike then
        state.drinkReason = "not_drinkable"
        state.washReason = "not_washable"
    else
        state.canDrink = playerNeedsDrink(player)
        if not state.canDrink then
            state.drinkReason = "not_thirsty"
        end

        state.canWash = state.washSelfWaterRequired > 0 or #state.washItems > 0
        if not state.canWash then
            state.washReason = "nothing_to_wash"
        end
    end

    if not barrelData:isEmpty() then
        state.canEmpty = true
    end

    if not hasPourTool then
        state.pourReason = "missing_tool"
    elseif barrelData:isFull() then
        state.pourReason = "barrel_full"
    elseif #state.sourceItems == 0 then
        state.pourReason = "no_source_items"
    else
        state.canPour = true
    end

    return state
end

return Availability
