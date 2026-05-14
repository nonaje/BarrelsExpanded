local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")

local ContextMenu = {}

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

--- @param barrel IsoObject
--- @param player IsoPlayer
local function onOpenBarrel(barrel, player)
    if not barrel or not player then return end

    local square = barrel:getSquare()
    if not square then return end

    sendClientCommand(Constant.NETWORK.MODULE, Constant.NETWORK.OPEN_BARREL, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = barrel:getObjectIndex()
    })

    local ticks = 0
    local function onTick()
        ticks = ticks + 1

        local barrelData = BarrEx_BarrelData.get(barrel)
        if barrelData then
            local liquidType = barrelData.liquidType or "EMPTY"
            log(string.format(
                "Barrel data synced: id=%s, liquid=%s, amount=%d/%d",
                barrelData.id or "N/A",
                liquidType,
                barrelData.amount,
                barrelData.capacity
            ))
            Events.OnTick.Remove(onTick)
            return
        end

        if ticks >= Constant.BARREL_DATA_POLL_TICKS then
            log("Barrel data not available yet.")
            Events.OnTick.Remove(onTick)
        end
    end

    Events.OnTick.Add(onTick)
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
        "Necesita: <LINE>",
        "Uno de: <LINE>"
    }

    for _, itemType in ipairs(foundItems) do
        lines[#lines + 1] = " <RGB:0,1,0> " .. itemType .. " 1/1 <LINE>"
    end

    for _, itemType in ipairs(missingItems) do
        lines[#lines + 1] = " <RGB:1,0,0> " .. itemType .. " 1/1 <LINE>"
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

--- @param context ISContextMenu
--- @param barrel IsoObject
--- @param player IsoPlayer
--- @param canOpen boolean
--- @param foundItems table<string>
--- @param missingItems table<string>
local function addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems)
    local barrelOption = context:addOption(Constant.CONTEXT_MENU.BARREL, nil, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(barrelOption, subMenu)

    local openOption = subMenu:addOption(Constant.CONTEXT_MENU.OPEN_BARREL, barrel, onOpenBarrel, player)
    openOption.notAvailable = not canOpen

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

    addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldObjectContextMenu)

return ContextMenu
