local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")

local ContextMenu = {}

local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

--- @param barrel IsoObject
local function onOpenBarrel(barrel)
    -- Acá después se puede abrir UI, transformar el objeto, agregar modData, etc.
    log("Barrel Opened")
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
--- @param canOpen boolean
--- @param foundItems table<string>
--- @param missingItems table<string>
local function addBarrelSubMenu(context, barrel, canOpen, foundItems, missingItems)
    local barrelOption = context:addOption(Constant.CONTEXT_MENU.BARREL, nil, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(barrelOption, subMenu)

    local openOption = subMenu:addOption(Constant.CONTEXT_MENU.OPEN_BARREL, barrel, onOpenBarrel)
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

    addBarrelSubMenu(context, barrel, canOpen, foundItems, missingItems)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldObjectContextMenu)

return ContextMenu
