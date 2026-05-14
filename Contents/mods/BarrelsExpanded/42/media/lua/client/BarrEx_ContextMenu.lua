local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")

--- This module adds a custom option to the context menu when right-clicking on certain barrel objects in the game world. It checks if the clicked object is an expandable barrel and, if so, adds a "Click Barrel" option to the context menu that allows the player to interact with the barrel.

--- Handler function for when the "Click Barrel" option is selected from the context menu. This function can be expanded to include any specific interactions or behaviors that should occur when the player clicks on the barrel.
local function onClickBarrel()
    print("[BarrelsExpanded] - Barrel Opened")
end

--- Adds a "Click Barrel" option to the context menu when right-clicking on an expandable barrel object in the game world.
--- This function is triggered by the OnFillWorldObjectContextMenu event, which is called whenever the context menu is being populated for a right-click action in the game world. It checks if the clicked object is an expandable barrel and, if so, adds a custom option to the context menu that allows the player to interact with the barrel.
--- @param playerIndex integer The index of the player who triggered the context menu.
--- @param context ISContextMenu The context menu object that is being populated.
--- @param worldObjects IsoObject[] An array of world objects that are associated with the context menu action (e.g., the objects that were right-clicked).
--- @param test boolean A flag indicating whether the context menu is being tested (e.g., for UI purposes) or is being populated for actual gameplay. If true, the function should not add any options to the context menu.
local function onContextMenu(playerIndex, context, worldObjects, test)
    if test then return end

    --- EXTRACT REFACTOR
    if not worldObjects or #worldObjects == 0 then return end

    local clickedObject = worldObjects[1]
    if not clickedObject then return end

    local clickedSquare = clickedObject:getSquare()
    if not clickedSquare then return end
    --- EXTRACT REFACTOR
    
    local objects = clickedSquare:getObjects()

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)

        if Utils.isExpandableBarrel(object) then
            --- EXTRACT REFACTOR
            local player = getSpecificPlayer(playerIndex)
            local playerCanOpenBarrel, foundedItems, missingItems = Utils.isPlayerHoldingAnyRequiredItem(player, Constant.AVAILABLE_ITEMS_FOR_OPENING_BARREL)
            local barrelContextOption = context:addOption(Constant.BARREL, nil, nil)
            local subMenu = context:getNew(context)
            local openBarrelOption = subMenu:addOption(Constant.OPEN_BARREL, object, onClickBarrel)
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            openBarrelOption.toolTip = tooltip

            context:addSubMenu(barrelContextOption, subMenu)

            tooltip.description = tooltip.description .. "Necesita: <LINE>"
            tooltip.description = tooltip.description .. "Uno de: <LINE>"
            for _, itemType in ipairs(foundedItems) do
                tooltip.description = tooltip.description .. " <RGB:0,1,0> " .. itemType .. " 1/1 <LINE>"
            end

            for _, itemType in ipairs(missingItems) do
                tooltip.description = tooltip.description .. " <RGB:1,0,0> " .. itemType .. " 1/1 <LINE>"
            end

            openBarrelOption.notAvailable = not playerCanOpenBarrel
        end
    end
end


Events.OnFillWorldObjectContextMenu.Add(onContextMenu)