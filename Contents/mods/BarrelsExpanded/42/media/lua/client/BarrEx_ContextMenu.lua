local Utils = require("BarrEx_Utils")
local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrEx_OpenBarrelAction = require("BarrEx_OpenBarrelAction")
local BarrEx_PourIntoBarrelAction = require("BarrEx_PourIntoBarrelAction")
local BarrEx_ExtractFromBarrelAction = require("BarrEx_ExtractFromBarrelAction")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")

local ContextMenu = {}

local VANILLA_TEXT_KEYS = {
    FILL = { "ContextMenu_Fill" },
    FILL_ONE = { "ContextMenu_Fill_one", "ContextMenu_Fill_One", "ContextMenu_FillOne" },
    FILL_ALL = { "ContextMenu_Fill_all", "ContextMenu_Fill_All", "ContextMenu_FillAll" },
}

local FALLBACK_TEXT = {
    FILL = "Llenar",
    FILL_ONE = "Llenar uno",
    FILL_ALL = "Llenar todo",
}

-- --------------------------------------------------------------------------
-- Text / display helpers
-- --------------------------------------------------------------------------

---@param message string
local function log(message)
    print(Constant.LOG_PREFIX .. " - " .. message)
end

---@param key string
---@return string
local function translate(key)
    return getText(key)
end

---@param key string
---@return string|nil
local function getTextIfExists(key)
    if not key then return nil end

    if type(getTextOrNull) == "function" then
        local text = getTextOrNull(key)
        if text and text ~= "" then
            return text
        end
    end

    local text = getText(key)
    if text and text ~= "" and text ~= key then
        return text
    end

    return nil
end

---@param keys table<integer, string>
---@param fallback string
---@return string
local function getFirstAvailableText(keys, fallback)
    for _, key in ipairs(keys or {}) do
        local text = getTextIfExists(key)
        if text then
            return text
        end
    end

    return fallback
end

---@return string
local function getVanillaFillText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL, FALLBACK_TEXT.FILL)
end

---@return string
local function getVanillaFillOneText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL_ONE, FALLBACK_TEXT.FILL_ONE)
end

---@return string
local function getVanillaFillAllText()
    return getFirstAvailableText(VANILLA_TEXT_KEYS.FILL_ALL, FALLBACK_TEXT.FILL_ALL)
end

---@param amount number|nil
---@return string
local function formatAmount(amount)
    return string.format("%.1f", tonumber(amount) or 0)
end

---@param itemType string|nil
---@return string
local function getItemDisplayName(itemType)
    if not itemType or itemType == "" then return "" end

    local displayName = getItemNameFromFullType(itemType)
    if displayName and displayName ~= "" then
        return displayName
    end

    return itemType
end

---@param item InventoryItem|nil
---@return string
local function getInventoryItemFullType(item)
    if item and type(item.getFullType) == "function" then
        local fullType = item:getFullType()
        if fullType and fullType ~= "" then
            return fullType
        end
    end

    return tostring(item)
end

---@param item InventoryItem|nil
---@return string
local function getInventoryItemDisplayName(item)
    if not item then return "" end

    if type(item.getName) == "function" then
        local name = item:getName()
        if name and name ~= "" then return name end
    end

    if type(item.getDisplayName) == "function" then
        local displayName = item:getDisplayName()
        if displayName and displayName ~= "" then return displayName end
    end

    return getItemDisplayName(getInventoryItemFullType(item))
end

---@param liquidType string|nil
---@return string
local function getLiquidDisplayName(liquidType)
    if not liquidType or liquidType == Constant.LIQUID_TYPE.EMPTY then
        return translate(Constant.UI.EMPTY)
    end

    local translationKey = Constant.UI["LIQUID_" .. liquidType]
    if translationKey then
        return translate(translationKey)
    end

    return liquidType
end

-- --------------------------------------------------------------------------
-- Tooltip / icon helpers
-- --------------------------------------------------------------------------

---@return ISToolTip
local function newTooltip()
    return ISInventoryPaneContextMenu.addToolTip()
end

---@param option table|nil
---@param message string|nil
local function attachSimpleTooltip(option, message)
    if not option or not message then return end

    local tooltip = newTooltip()
    tooltip.description = message
    option.toolTip = tooltip
end

---@param option table|nil
local function attachTooFarTooltip(option)
    attachSimpleTooltip(option, translate(Constant.TOOLTIP.TOO_FAR))
end

---@param option table|nil
---@param item InventoryItem|nil
local function attachInventoryItemIcon(option, item)
    if not option or not item then return end

    if type(item.getTex) == "function" then
        option.iconTexture = item:getTex()
        return
    end

    if type(item.getTexture) == "function" then
        option.iconTexture = item:getTexture()
    end
end

---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
---@return string
local function buildRequiredItemsTooltipDescription(foundItems, missingItems)
    local lines = {
        translate(Constant.TOOLTIP.REQUIRED) .. " <LINE>",
        translate(Constant.TOOLTIP.ONE_OF) .. " <LINE>",
    }

    for _, itemType in ipairs(foundItems or {}) do
        lines[#lines + 1] = " <RGB:0,1,0> " .. getItemDisplayName(itemType) .. " 1/1 <LINE>"
    end

    for _, itemType in ipairs(missingItems or {}) do
        lines[#lines + 1] = " <RGB:1,0,0> " .. getItemDisplayName(itemType) .. " 1/1 <LINE>"
    end

    return table.concat(lines)
end

---@param option table|nil
---@param foundItems table<string>|nil
---@param missingItems table<string>|nil
local function attachRequiredItemsTooltip(option, foundItems, missingItems)
    if not option then return end

    local tooltip = newTooltip()
    tooltip.description = (tooltip.description or "") .. buildRequiredItemsTooltipDescription(foundItems, missingItems)
    option.toolTip = tooltip
end

---@param barrelData BarrEx_Barrel|nil
---@return string
local function buildBarrelInfoTooltipDescription(barrelData)
    if not barrelData then return "" end

    local amount = tonumber(barrelData.amount) or 0
    local capacity = tonumber(barrelData.capacity) or 0
    local percent = capacity > 0 and math.floor((amount / capacity) * 100) or 0

    return table.concat({
        translate(Constant.TOOLTIP.BARREL_CONTENTS) .. " <LINE>",
        " <RGB:1,1,1> " .. translate(Constant.TOOLTIP.LIQUID) .. " " .. getLiquidDisplayName(barrelData.liquidType) .. " <LINE>",
        string.format(
            " <RGB:1,1,1> %s %.1f/%.1f <LINE>",
            translate(Constant.TOOLTIP.AMOUNT),
            amount,
            capacity
        ),
        string.format(
            " <RGB:1,1,1> %s %d%% <LINE>",
            translate(Constant.TOOLTIP.FILL_LEVEL),
            percent
        ),
        string.format(
            " <RGB:1,1,1> %s %.2f <LINE>",
            translate(Constant.TOOLTIP.WEIGHT),
            barrelData:getTotalWeight()
        ),
    })
end

---@param option table|nil
---@param barrelData BarrEx_Barrel|nil
local function attachBarrelInfoTooltip(option, barrelData)
    if not option or not barrelData then return end

    local tooltip = newTooltip()
    tooltip.description = (tooltip.description or "") .. buildBarrelInfoTooltipDescription(barrelData)
    option.toolTip = tooltip
end

---@param option table|nil
---@param item InventoryItem
---@param liquidType string|nil
---@param transferAmount number
local function attachTransferTooltip(option, item, liquidType, transferAmount)
    if not option or not item then return end

    local tooltip = newTooltip()
    tooltip.description = table.concat({
        string.format(
            "<RGB:1,1,1> %s %s <LINE>",
            translate(Constant.TOOLTIP.LIQUID),
            getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))
        ),
        string.format(
            "<RGB:1,1,1> %s %s <LINE>",
            translate(Constant.TOOLTIP.TRANSFER_AMOUNT),
            formatAmount(transferAmount)
        ),
        string.format(
            "<RGB:1,1,1> %s %s/%s <LINE>",
            translate(Constant.TOOLTIP.CONTAINER_CAPACITY),
            formatAmount(LiquidAdapter.getAmount(item)),
            formatAmount(LiquidAdapter.getCapacity(item))
        ),
    })
    option.toolTip = tooltip
end

-- --------------------------------------------------------------------------
-- Action callbacks
-- --------------------------------------------------------------------------

---@param barrel IsoObject
---@param player IsoPlayer
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

---@param barrel IsoObject
---@param player IsoPlayer
---@param sourceItem InventoryItem
local function onPourIntoBarrel(barrel, player, sourceItem)
    if not barrel or not player or not sourceItem then return end

    ISTimedActionQueue.add(BarrEx_PourIntoBarrelAction:new(player, barrel, sourceItem))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param targetItem InventoryItem
local function onExtractFromBarrel(barrel, player, targetItem)
    if not barrel or not player or not targetItem then return end

    ISTimedActionQueue.add(BarrEx_ExtractFromBarrelAction:new(player, barrel, targetItem))
end

---@param barrel IsoObject
---@param player IsoPlayer
---@param targetItems table<integer, InventoryItem>
local function onExtractAllFromBarrel(barrel, player, targetItems)
    if not barrel or not player or not targetItems then return end

    for _, item in ipairs(targetItems) do
        if item then
            ISTimedActionQueue.add(BarrEx_ExtractFromBarrelAction:new(player, barrel, item))
        end
    end
end

---@param item InventoryItem
---@param barrelData BarrEx_Barrel
---@return number
local function getPourTransferAmount(item, barrelData)
    if not item or not barrelData then return 0 end

    local amount = tonumber(LiquidAdapter.getAmount(item)) or 0
    local freeCapacity = tonumber(barrelData:getFreeCapacity()) or 0

    return math.max(math.min(amount, freeCapacity), 0)
end

-- --------------------------------------------------------------------------
-- Inventory collection / grouping
-- --------------------------------------------------------------------------

---@param inventory ItemContainer|nil
---@param predicate fun(item: InventoryItem): boolean
---@param found table<integer, InventoryItem>|nil
---@return table<integer, InventoryItem>
local function collectInventoryItems(inventory, predicate, found)
    found = found or {}
    if not inventory then return found end

    local items = inventory:getItems()
    if not items then return found end

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if item and predicate(item) then
            found[#found + 1] = item
        end

        if item and type(item.getInventory) == "function" then
            collectInventoryItems(item:getInventory(), predicate, found)
        end
    end

    return found
end

---@param player IsoPlayer|nil
---@param barrelData BarrEx_Barrel|nil
---@return table<integer, InventoryItem>
local function collectSourceContainersForPour(player, barrelData)
    local inventory = player and player:getInventory()
    if not inventory or not barrelData then return {} end
    if barrelData:isFull() then return {} end

    local expectedType = nil
    if not barrelData:isEmpty() then
        expectedType = barrelData.liquidType
    end

    return collectInventoryItems(inventory, function(item)
        if not LiquidAdapter.isLiquidContainer(item) then
            return false
        end

        if not LiquidAdapter.canProvide(item, expectedType) then
            return false
        end

        local sourceType = LiquidAdapter.getLiquidType(item)
        if not sourceType then
            return false
        end

        local transferAmount = getPourTransferAmount(item, barrelData)

        return transferAmount > 0 and barrelData:canAcceptLiquid(sourceType, transferAmount)
    end)
end

---@param player IsoPlayer|nil
---@param barrelData BarrEx_Barrel|nil
---@return table<integer, InventoryItem>
local function collectTargetContainersForExtract(player, barrelData)
    local inventory = player and player:getInventory()
    if not inventory or not barrelData then return {} end
    if barrelData:isEmpty() then return {} end

    return collectInventoryItems(inventory, function(item)
        return LiquidAdapter.canReceive(item, barrelData.liquidType)
            and LiquidAdapter.getFreeCapacity(item) > 0
    end)
end

---@param items table<integer, InventoryItem>
---@return table<integer, table>
local function groupInventoryItemsByFullType(items)
    local groupedByFullType = {}
    local orderedGroups = {}

    for _, item in ipairs(items or {}) do
        local fullType = getInventoryItemFullType(item)

        if not groupedByFullType[fullType] then
            groupedByFullType[fullType] = {
                fullType = fullType,
                label = getInventoryItemDisplayName(item),
                iconItem = item,
                items = {},
            }

            orderedGroups[#orderedGroups + 1] = groupedByFullType[fullType]
        end

        table.insert(groupedByFullType[fullType].items, item)
    end

    table.sort(orderedGroups, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return orderedGroups
end

-- --------------------------------------------------------------------------
-- Menu label builders
-- --------------------------------------------------------------------------

---@param group table
---@return string
local function buildGroupedContainerLabel(group)
    local count = #(group.items or {})

    if count > 1 then
        return string.format("%s (%d)", group.label, count)
    end

    return group.label
end

---@param item InventoryItem
---@param liquidType string|nil
---@param transferAmount number
---@return string
local function buildPourContainerOptionLabel(item, liquidType, transferAmount)
    local amount = LiquidAdapter.getAmount(item)
    local capacity = LiquidAdapter.getCapacity(item)
    local liquidName = getLiquidDisplayName(liquidType or LiquidAdapter.getLiquidType(item))

    return string.format(
        "%s - %s %s/%s (%s %s)",
        getInventoryItemDisplayName(item),
        liquidName,
        formatAmount(amount),
        formatAmount(capacity),
        formatAmount(transferAmount),
        translate(Constant.TOOLTIP.TRANSFER_AMOUNT)
    )
end

-- --------------------------------------------------------------------------
-- Submenu builders
-- --------------------------------------------------------------------------

---@param subMenu ISContextMenu
---@param barrelData BarrEx_Barrel
local function addBarrelInfoOption(subMenu, barrelData)
    local amount = tonumber(barrelData.amount) or 0
    local capacity = tonumber(barrelData.capacity) or 0
    local percent = capacity > 0 and math.floor((amount / capacity) * 100) or 0

    local infoLabel = string.format("%s  %d%%", translate(Constant.CONTEXT_MENU.INFO), percent)
    local infoOption = subMenu:addOption(infoLabel, nil, nil)
    infoOption.notAvailable = true

    attachBarrelInfoTooltip(infoOption, barrelData)
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
        local transferAmount = getPourTransferAmount(item, barrelData)

        local itemOption = itemMenu:addOption(
            buildPourContainerOptionLabel(item, liquidType, transferAmount),
            barrel,
            onPourIntoBarrel,
            player,
            item
        )

        attachInventoryItemIcon(itemOption, item)
        attachTransferTooltip(itemOption, item, liquidType, transferAmount)
    end
end

---@param subMenu ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
---@param barrelData BarrEx_Barrel
---@param inRange boolean
local function addPourOption(subMenu, barrel, player, barrelData, inRange)
    local hasPourTool = Utils.isPlayerHoldingAnyRequiredItem(player, Constant.POUR_REQUIRED_ITEMS)
    local sourceItems = collectSourceContainersForPour(player, barrelData)
    local canPour = inRange and hasPourTool and #sourceItems > 0

    local pourLabel = translate(Constant.CONTEXT_MENU.POUR)
    if #sourceItems == 1 and canPour then
        local item = sourceItems[1]
        local transferAmount = getPourTransferAmount(item, barrelData)

        pourLabel = buildPourContainerOptionLabel(item, LiquidAdapter.getLiquidType(item), transferAmount)
    elseif #sourceItems > 1 then
        pourLabel = pourLabel .. " >"
    end

    local pourOption
    if #sourceItems == 1 and canPour then
        local item = sourceItems[1]
        local transferAmount = getPourTransferAmount(item, barrelData)

        pourOption = subMenu:addOption(pourLabel, barrel, onPourIntoBarrel, player, item)
        attachInventoryItemIcon(pourOption, item)
        attachTransferTooltip(pourOption, item, LiquidAdapter.getLiquidType(item), transferAmount)
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
        attachTooFarTooltip(pourOption)
    elseif not hasPourTool then
        attachSimpleTooltip(pourOption, translate(Constant.TOOLTIP.REQUIRES_FUNNEL))
    elseif barrelData:isFull() then
        attachSimpleTooltip(pourOption, translate(Constant.TOOLTIP.BARREL_FULL))
    elseif #sourceItems == 0 then
        attachSimpleTooltip(pourOption, translate(Constant.TOOLTIP.NO_COMPATIBLE_CONTAINER))
    else
        attachSimpleTooltip(pourOption, translate(Constant.TOOLTIP.INCOMPATIBLE_LIQUID))
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

    local fillOneOption = groupMenu:addOption(
        getVanillaFillOneText(),
        barrel,
        onExtractFromBarrel,
        player,
        group.items[1]
    )
    attachInventoryItemIcon(fillOneOption, group.iconItem)

    local fillAllOption = groupMenu:addOption(
        getVanillaFillAllText(),
        barrel,
        onExtractAllFromBarrel,
        player,
        group.items
    )
    attachInventoryItemIcon(fillAllOption, group.iconItem)
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
        getVanillaFillAllText(),
        barrel,
        onExtractAllFromBarrel,
        player,
        targetItems
    )

    for _, group in ipairs(groupInventoryItemsByFullType(targetItems)) do
        local itemCount = #(group.items or {})
        local label = buildGroupedContainerLabel(group)

        if itemCount == 1 then
            local itemOption = fillMenu:addOption(
                label,
                barrel,
                onExtractFromBarrel,
                player,
                group.items[1]
            )

            attachInventoryItemIcon(itemOption, group.iconItem)
        else
            local groupOption = fillMenu:addOption(label, nil, nil)
            attachInventoryItemIcon(groupOption, group.iconItem)
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
    local hasExtractTool = Utils.isPlayerHoldingAnyRequiredItem(player, Constant.EXTRACT_REQUIRED_ITEMS)
    local targetItems = collectTargetContainersForExtract(player, barrelData)
    local canExtract = inRange and hasExtractTool and #targetItems > 0

    local fillOption = subMenu:addOption(getVanillaFillText(), nil, nil)
    fillOption.notAvailable = not canExtract

    if canExtract then
        addVanillaLikeFillSubMenu(subMenu, fillOption, targetItems, barrel, player)
        return
    end

    if not inRange then
        attachTooFarTooltip(fillOption)
    elseif not hasExtractTool then
        attachSimpleTooltip(fillOption, translate(Constant.TOOLTIP.REQUIRES_HOSE))
    elseif barrelData:isEmpty() then
        attachSimpleTooltip(fillOption, translate(Constant.TOOLTIP.BARREL_EMPTY))
    elseif #targetItems == 0 then
        attachSimpleTooltip(fillOption, translate(Constant.TOOLTIP.NO_COMPATIBLE_CONTAINER))
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
    local openOption = subMenu:addOption(translate(Constant.CONTEXT_MENU.OPEN_BARREL), barrel, onOpenBarrel, player)
    openOption.notAvailable = (not canOpen) or (not inRange)

    if not inRange then
        attachTooFarTooltip(openOption)
        return
    end

    attachRequiredItemsTooltip(openOption, foundItems, missingItems)
end

-- --------------------------------------------------------------------------
-- Main menu
-- --------------------------------------------------------------------------

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
    local barrelOption = context:addOption(translate(Constant.CONTEXT_MENU.BARREL), nil, nil)
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

    local barrel = Utils.findExpandableBarrelOnSquare(clickedSquare)
    if not barrel then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local canOpen, foundItems, missingItems = Utils.getRequiredItemStatus(
        player,
        Constant.OPEN_BARREL_REQUIRED_ITEMS
    )
    local inRange = Utils.isPlayerInRange(player, barrel)

    addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems, inRange)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldObjectContextMenu)

return ContextMenu
