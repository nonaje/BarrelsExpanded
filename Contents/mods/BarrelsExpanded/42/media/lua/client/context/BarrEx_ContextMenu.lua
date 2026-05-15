local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local Constant = require("BarrEx_Constant")
local ContextConfig = require("config/BarrEx_ContextConfig")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local Text = require("context/BarrEx_ContextMenuText")
local Tooltips = require("context/BarrEx_ContextMenuTooltips")
local Inventory = require("context/BarrEx_ContextMenuInventory")
local Actions = require("context/BarrEx_ContextMenuActions")

local ContextMenu = {}

---@param subMenu ISContextMenu
---@param barrelData BarrEx_Barrel
local function addBarrelInfoOption(subMenu, barrelData)
    local amount = tonumber(barrelData.amount) or 0
    local capacity = tonumber(barrelData.capacity) or 0
    local percent = capacity > 0 and math.floor((amount / capacity) * 100) or 0

    local infoLabel = string.format("%s  %d%%", Text.translate(ContextConfig.CONTEXT_MENU.INFO), percent)
    local infoOption = subMenu:addOption(infoLabel, nil, nil)
    infoOption.notAvailable = true

    Tooltips.attachBarrelInfoTooltip(infoOption, barrelData)
end

---@param parentMenu ISContextMenu
---@param parentOption table
---@param sourceItems table<integer, InventoryItem>
---@param barrel IsoObject
---@param player IsoPlayer
---@param barrelData BarrEx_Barrel
local function addPourContainerSubMenu(parentMenu, parentOption, sourceItems, barrel, player, barrelData)
    if not parentMenu or not parentOption then return end
    if not sourceItems or #sourceItems == 0 then return end

    local itemMenu = parentMenu:getNew(parentMenu)
    parentMenu:addSubMenu(parentOption, itemMenu)

    for _, item in ipairs(sourceItems) do
        local liquidType = LiquidAdapter.getLiquidType(item)
        local transferAmount = Inventory.getPourTransferAmount(item, barrelData)

        local itemOption = itemMenu:addOption(
            Text.buildPourContainerOptionLabel(item, liquidType, transferAmount),
            barrel,
            Actions.onPourIntoBarrel,
            player,
            item
        )

        Tooltips.attachInventoryItemIcon(itemOption, item)
        Tooltips.attachTransferTooltip(itemOption, item, liquidType, transferAmount)
    end
end

---@param subMenu ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
---@param barrelData BarrEx_Barrel
---@param inRange boolean
local function addPourOption(subMenu, barrel, player, barrelData, inRange)
    local hasPourTool = PlayerUtils.isPlayerHoldingAnyRequiredItem(player, Constant.POUR_REQUIRED_ITEMS)
    local sourceItems = Inventory.collectSourceContainersForPour(player, barrelData)
    local canPour = inRange and hasPourTool and #sourceItems > 0

    local pourLabel = Text.translate(ContextConfig.CONTEXT_MENU.POUR)
    if #sourceItems == 1 and canPour then
        local item = sourceItems[1]
        local transferAmount = Inventory.getPourTransferAmount(item, barrelData)

        pourLabel = Text.buildPourContainerOptionLabel(item, LiquidAdapter.getLiquidType(item), transferAmount)
    elseif #sourceItems > 1 then
        pourLabel = pourLabel .. " >"
    end

    local pourOption
    if #sourceItems == 1 and canPour then
        local item = sourceItems[1]
        local transferAmount = Inventory.getPourTransferAmount(item, barrelData)

        pourOption = subMenu:addOption(pourLabel, barrel, Actions.onPourIntoBarrel, player, item)
        Tooltips.attachInventoryItemIcon(pourOption, item)
        Tooltips.attachTransferTooltip(pourOption, item, LiquidAdapter.getLiquidType(item), transferAmount)
    else
        pourOption = subMenu:addOption(pourLabel, nil, nil)
    end

    pourOption.notAvailable = not canPour

    if canPour and #sourceItems > 1 then
        addPourContainerSubMenu(subMenu, pourOption, sourceItems, barrel, player, barrelData)
        return
    end

    if canPour then return end

    if not inRange then
        Tooltips.attachTooFarTooltip(pourOption)
    elseif not hasPourTool then
        Tooltips.attachSimpleTooltip(pourOption, Text.translate(ContextConfig.TOOLTIP.REQUIRES_FUNNEL))
    elseif barrelData:isFull() then
        Tooltips.attachSimpleTooltip(pourOption, Text.translate(ContextConfig.TOOLTIP.BARREL_FULL))
    elseif #sourceItems == 0 then
        Tooltips.attachSimpleTooltip(pourOption, Text.translate(ContextConfig.TOOLTIP.NO_COMPATIBLE_CONTAINER))
    else
        Tooltips.attachSimpleTooltip(pourOption, Text.translate(ContextConfig.TOOLTIP.INCOMPATIBLE_LIQUID))
    end
end

---@param parentMenu ISContextMenu
---@param groupOption table
---@param group table
---@param barrel IsoObject
---@param player IsoPlayer
local function addGroupedFillSubSubMenu(parentMenu, groupOption, group, barrel, player)
    if not parentMenu or not groupOption or not group then return end
    if not group.items or #group.items == 0 then return end

    local groupMenu = parentMenu:getNew(parentMenu)
    parentMenu:addSubMenu(groupOption, groupMenu)

    groupMenu:addOption(
        Text.getVanillaFillOneText(),
        barrel,
        Actions.onExtractFromBarrel,
        player,
        group.items[1]
    )

    groupMenu:addOption(
        Text.getVanillaFillAllText(),
        barrel,
        Actions.onExtractAllFromBarrel,
        player,
        group.items
    )
end

---@param parentMenu ISContextMenu
---@param parentOption table
---@param targetItems table<integer, InventoryItem>
---@param barrel IsoObject
---@param player IsoPlayer
local function addVanillaLikeFillSubMenu(parentMenu, parentOption, targetItems, barrel, player)
    if not parentMenu or not parentOption then return end
    if not targetItems or #targetItems == 0 then return end

    local fillMenu = parentMenu:getNew(parentMenu)
    parentMenu:addSubMenu(parentOption, fillMenu)

    fillMenu:addOption(
        Text.getVanillaFillAllText(),
        barrel,
        Actions.onExtractAllFromBarrel,
        player,
        targetItems
    )

    for _, group in ipairs(Inventory.groupInventoryItemsByFullType(targetItems)) do
        local itemCount = #(group.items or {})
        local label = Text.buildGroupedContainerLabel(group)

        if itemCount == 1 then
            local itemOption = fillMenu:addOption(
                label,
                barrel,
                Actions.onExtractFromBarrel,
                player,
                group.items[1]
            )

            Tooltips.attachInventoryItemIcon(itemOption, group.iconItem)
        else
            local groupOption = fillMenu:addOption(label, nil, nil)
            Tooltips.attachInventoryItemIcon(groupOption, group.iconItem)
            addGroupedFillSubSubMenu(fillMenu, groupOption, group, barrel, player)
        end
    end
end

---@param subMenu ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
---@param barrelData BarrEx_Barrel
---@param inRange boolean
local function addFillOption(subMenu, barrel, player, barrelData, inRange)
    local hasExtractTool = PlayerUtils.isPlayerHoldingAnyRequiredItem(player, Constant.EXTRACT_REQUIRED_ITEMS)
    local targetItems = Inventory.collectTargetContainersForExtract(player, barrelData)
    local canExtract = inRange and hasExtractTool and #targetItems > 0

    local fillOption = subMenu:addOption(Text.getVanillaFillText(), nil, nil)
    fillOption.notAvailable = not canExtract

    if canExtract then
        addVanillaLikeFillSubMenu(subMenu, fillOption, targetItems, barrel, player)
        return
    end

    if not inRange then
        Tooltips.attachTooFarTooltip(fillOption)
    elseif not hasExtractTool then
        Tooltips.attachSimpleTooltip(fillOption, Text.translate(ContextConfig.TOOLTIP.REQUIRES_HOSE))
    elseif barrelData:isEmpty() then
        Tooltips.attachSimpleTooltip(fillOption, Text.translate(ContextConfig.TOOLTIP.BARREL_EMPTY))
    elseif #targetItems == 0 then
        Tooltips.attachSimpleTooltip(fillOption, Text.translate(ContextConfig.TOOLTIP.NO_COMPATIBLE_CONTAINER))
    end
end

---@param subMenu ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
---@param canOpen boolean
---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
---@param inRange boolean
local function addOpenBarrelOption(subMenu, barrel, player, canOpen, foundItems, missingItems, inRange)
    local openOption = subMenu:addOption(Text.translate(ContextConfig.CONTEXT_MENU.OPEN_BARREL), barrel, Actions.onOpenBarrel, player)
    openOption.notAvailable = (not canOpen) or (not inRange)

    if not inRange then
        Tooltips.attachTooFarTooltip(openOption)
        return
    end

    Tooltips.attachRequiredItemsTooltip(openOption, foundItems, missingItems)
end

---@param worldObjects IsoObject[]|nil
---@return IsoGridSquare|nil
local function getClickedSquare(worldObjects)
    if not worldObjects or #worldObjects == 0 then return nil end

    local clickedObject = worldObjects[1]
    if not clickedObject then return nil end

    return clickedObject:getSquare()
end

---@param context ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
---@param canOpen boolean
---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
---@param inRange boolean
local function addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems, inRange)
    local barrelOption = context:addOption(Text.translate(ContextConfig.CONTEXT_MENU.BARREL), nil, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(barrelOption, subMenu)

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        addOpenBarrelOption(subMenu, barrel, player, canOpen, foundItems, missingItems, inRange)
        return
    end

    addBarrelInfoOption(subMenu, barrelData)
    addPourOption(subMenu, barrel, player, barrelData, inRange)
    addFillOption(subMenu, barrel, player, barrelData, inRange)
end

---@param playerIndex integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
function ContextMenu.onFillWorldObjectContextMenu(playerIndex, context, worldObjects, test)
    if test then return end

    local clickedSquare = getClickedSquare(worldObjects)
    if not clickedSquare then return end

    local barrel = WorldUtils.findExpandableBarrelOnSquare(clickedSquare)
    if not barrel then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local canOpen, foundItems, missingItems = PlayerUtils.getRequiredItemStatus(
        player,
        Constant.OPEN_BARREL_REQUIRED_ITEMS
    )
    local inRange = PlayerUtils.isPlayerInRange(player, barrel)

    addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems, inRange)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldObjectContextMenu)

return ContextMenu