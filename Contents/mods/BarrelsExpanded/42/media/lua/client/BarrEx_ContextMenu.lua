local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_OpenBarrelAction = require("BarrEx_OpenBarrelAction")

local ContextMenu = {}

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

--- @param key string
--- @return string
local function translate(key)
    return getText(key)
end

--- @param itemType string
--- @return string
local function getItemDisplayName(itemType)
    local displayName = getItemNameFromFullType(itemType)
    if displayName and displayName ~= "" then
        return displayName
    end

    return itemType
end

--- @param liquidType string|nil
--- @return string
local function getLiquidDisplayName(liquidType)
    if not liquidType then
        return translate(Constant.UI.EMPTY)
    end

    local translationKey = Constant.UI["LIQUID_" .. liquidType]
    if translationKey then
        return translate(translationKey)
    end

    return liquidType
end

--- @param barrel IsoObject
--- @param player IsoPlayer
local function onOpenBarrel(barrel, player)
    if not barrel or not player then return end
    if BarrEx_BarrelData.isRevealedRaw(barrel) then
        log("Open ignored; barrel already revealed.")
        return
    end

    local inventory = player:getInventory()
    if not inventory then return end
    local tool = nil
    for _, itemType in ipairs(Constant.OPEN_BARREL_REQUIRED_ITEMS) do
        tool = inventory:getFirstTypeRecurse(itemType)
        if tool then break end
    end

    if not tool then return end

    ISTimedActionQueue.add(BarrEx_OpenBarrelAction:new(player, barrel, tool))
end

--- @param worldObjects IsoObject[]|nil
--- @return IsoGridSquare|nil
local function getClickedSquare(worldObjects)
    if not worldObjects or #worldObjects == 0 then return nil end

    local clickedObject = worldObjects[1]
    if not clickedObject then return nil end

    return clickedObject:getSquare()
end

--- @param foundItems table<string>
--- @param missingItems table<string>
--- @return string
local function buildRequiredItemsTooltipDescription(foundItems, missingItems)
    local lines = {
        translate(Constant.TOOLTIP.REQUIRED) .. " <LINE>",
        translate(Constant.TOOLTIP.ONE_OF) .. " <LINE>"
    }

    for _, itemType in ipairs(foundItems) do
        lines[#lines + 1] = " <RGB:0,1,0> " .. getItemDisplayName(itemType) .. " 1/1 <LINE>"
    end

    for _, itemType in ipairs(missingItems) do
        lines[#lines + 1] = " <RGB:1,0,0> " .. getItemDisplayName(itemType) .. " 1/1 <LINE>"
    end

    return table.concat(lines)
end

--- @param option table
--- @param foundItems table<string>
--- @param missingItems table<string>
local function attachRequiredItemsTooltip(option, foundItems, missingItems)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = (tooltip.description or "") .. buildRequiredItemsTooltipDescription(foundItems, missingItems)
    option.toolTip = tooltip
end

--- @param barrelData BarrEx_Barrel|nil
--- @return string
local function buildBarrelInfoTooltipDescription(barrelData)
    if not barrelData then return "" end

    local liquidType = getLiquidDisplayName(barrelData.liquidType)
    local totalWeight = barrelData:getTotalWeight()

    return table.concat({
        translate(Constant.TOOLTIP.BARREL_CONTENTS) .. " <LINE>",
        " <RGB:1,1,1> " .. translate(Constant.TOOLTIP.LIQUID) .. " " .. liquidType .. " <LINE>",
        string.format(
            " <RGB:1,1,1> %s %d/%d <LINE>",
            translate(Constant.TOOLTIP.AMOUNT),
            barrelData.amount,
            barrelData.capacity
        ),
        string.format(
            " <RGB:1,1,1> %s %.2f <LINE>",
            translate(Constant.TOOLTIP.WEIGHT),
            totalWeight
        )
    })
end

--- @param option table
local function attachTooFarTooltip(option)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = translate(Constant.TOOLTIP.TOO_FAR)
    option.toolTip = tooltip
end

--- @param option table
--- @param barrelData BarrEx_Barrel|nil
local function attachBarrelInfoTooltip(option, barrelData)
    if not barrelData then return end

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = (tooltip.description or "") .. buildBarrelInfoTooltipDescription(barrelData)
    option.toolTip = tooltip
end

--- @param context ISContextMenu
--- @param barrel IsoObject
--- @param player IsoPlayer
--- @param canOpen boolean
--- @param foundItems table<string>
--- @param missingItems table<string>
--- @param inRange boolean
local function addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems, inRange)
    local barrelData = BarrEx_BarrelData.get(barrel)
    local barrelOption = context:addOption(translate(Constant.CONTEXT_MENU.BARREL), nil, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(barrelOption, subMenu)

    if barrelData and barrelData:isRevealed() then
        local amount = barrelData.amount or 0
        local capacity = barrelData.capacity or 0
        local pct = capacity > 0 and math.floor((amount / capacity) * 100) or 0
        local infoLabel = string.format("%s  %d%%", translate(Constant.CONTEXT_MENU.INFO), pct)
        local infoOption = subMenu:addOption(infoLabel, nil, nil)
        infoOption.notAvailable = true
        attachBarrelInfoTooltip(infoOption, barrelData)
        return
    end

    local openOption = subMenu:addOption(translate(Constant.CONTEXT_MENU.OPEN_BARREL), barrel, onOpenBarrel, player)
    openOption.notAvailable = (not canOpen) or (not inRange)

    if not inRange then
        attachTooFarTooltip(openOption)
        return
    end

    attachRequiredItemsTooltip(openOption, foundItems, missingItems)
end

--- @param playerIndex integer
--- @param context ISContextMenu
--- @param worldObjects IsoObject[]
--- @param test boolean
function ContextMenu.onFillWorldObjectContextMenu(playerIndex, context, worldObjects, test)
    if test then return end

    local clickedSquare = getClickedSquare(worldObjects)
    if not clickedSquare then return end

    local barrel = Utils.findExpandableBarrelOnSquare(clickedSquare)
    if not barrel then return end

    local player = getSpecificPlayer(playerIndex)
    local canOpen, foundItems, missingItems = Utils.getRequiredItemStatus(
        player,
        Constant.OPEN_BARREL_REQUIRED_ITEMS
    )
    local inRange = Utils.isPlayerInRange(player, barrel)

    addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems, inRange)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldObjectContextMenu)

return ContextMenu
