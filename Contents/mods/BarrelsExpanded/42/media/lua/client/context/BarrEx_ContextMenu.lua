local PlayerUtils = require("utils/BarrEx_PlayerUtils")
local WorldUtils = require("utils/BarrEx_WorldUtils")
local Constant = require("BarrEx_Constant")
local ContextConfig = require("config/BarrEx_ContextConfig")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local LiquidAdapter = require("BarrEx_LiquidContainerAdapter")
local TransferRules = require("core/BarrEx_TransferRules")
local Text = require("context/BarrEx_ContextMenuText")
local Tooltips = require("context/BarrEx_ContextMenuTooltips")
local Inventory = require("context/BarrEx_ContextMenuInventory")
local Availability = require("context/BarrEx_ContextMenuAvailability")
local Actions = require("context/BarrEx_ContextMenuActions")
local AdminBarrelActions = require("context/BarrEx_AdminBarrelActions")
local BarrelStateClient = require("BarrEx_BarrelStateClient")
local GeneratorUtils = require("utils/BarrEx_GeneratorUtils")

local ContextMenu = {}
local collectBarrelsOnSquare

---@class BarrEx_BarrelTransferTargetEntry
---@field barrel IsoObject
---@field data BarrEx_Barrel

---@class BarrEx_GeneratorSourceBarrelEntry
---@field barrel IsoObject
---@field data BarrEx_Barrel

local function attachReasonTooltip(option, reason)
    Tooltips.attachActionUnavailableTooltip(option, reason)
end

---@param subMenu ISContextMenu
---@param barrelData BarrEx_Barrel
local function addBarrelInfoOption(subMenu, barrelData)
    local amount = tonumber(barrelData.amount) or 0
    local capacity = tonumber(barrelData.capacity) or 0
    local percent = capacity > 0 and math.floor((amount / capacity) * 100) or 0

    local infoLabel = Text.translate(
        ContextConfig.CONTEXT_MENU.INFO_PERCENT,
        Text.getLiquidDisplayName(barrelData.liquidType),
        tostring(percent)
    )
    local infoOption = subMenu:addOption(infoLabel, nil, nil)

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

    if #sourceItems > 1 then
        itemMenu:addOption(Text.translate(ContextConfig.CONTEXT_MENU.POUR_ALL), barrel, Actions.onPourAllIntoBarrel, player, sourceItems)
    end

    for i = 1, #sourceItems do
        local item = sourceItems[i]
        local liquidType = LiquidAdapter.getLiquidType(item)

        local itemOption = itemMenu:addOption(
            Text.buildPourContainerOptionLabel(item, liquidType),
            barrel,
            Actions.onPourIntoBarrel,
            player,
            item
        )

        Tooltips.attachInventoryItemIcon(itemOption, item)
        Tooltips.attachTransferTooltip(itemOption, item, liquidType)
    end
end

---@param subMenu ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
---@param barrelData BarrEx_Barrel
---@param availability table
local function addPourOption(subMenu, barrel, player, barrelData, availability)
    local sourceItems = availability.sourceItems or {}
    local canPour = availability.canPour == true

    local pourLabel = Text.translate(ContextConfig.CONTEXT_MENU.POUR)
    if canPour then
        pourLabel = Text.withSubMenuShortcut(pourLabel)
    end
    local pourOption = subMenu:addOption(pourLabel, nil, nil)

    pourOption.notAvailable = not canPour

    if canPour then
        addPourContainerSubMenu(subMenu, pourOption, sourceItems, barrel, player, barrelData)
    elseif not canPour then
        Tooltips.attachPourRequirementsTooltip(pourOption, availability, barrelData)
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

    groupMenu:addOption(Text.getVanillaFillOneText(), barrel, Actions.onExtractFromBarrel, player, group.items[1])
    groupMenu:addOption(Text.getVanillaFillAllText(), barrel, Actions.onExtractAllFromBarrel, player, group.items)
end

---@param parentMenu ISContextMenu
---@param parentOption table
---@param targetItems table<integer, InventoryItem>
---@param barrel IsoObject
---@param player IsoPlayer
---@param liquidType string|nil
local function addVanillaLikeFillSubMenu(parentMenu, parentOption, targetItems, barrel, player, liquidType)
    if not parentMenu or not parentOption then return end
    if not targetItems or #targetItems == 0 then return end

    local fillMenu = parentMenu:getNew(parentMenu)
    parentMenu:addSubMenu(parentOption, fillMenu)

    if #targetItems > 1 then
        fillMenu:addOption(Text.getVanillaFillAllText(), barrel, Actions.onExtractAllFromBarrel, player, targetItems)
    end

    local groups = Inventory.groupInventoryItemsByFullType(targetItems)
    for i = 1, #groups do
        local group = groups[i]
        local itemCount = #(group.items or {})
        local label = Text.buildGroupedContainerLabel(group)

        if itemCount == 1 then
            local item = group.items[1]
            local itemOption = fillMenu:addOption(label, barrel, Actions.onExtractFromBarrel, player, item)
            Tooltips.attachInventoryItemIcon(itemOption, group.iconItem)
            Tooltips.attachFillContainerTooltip(itemOption, item, liquidType)
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
---@param availability table
local function addFillOption(subMenu, barrel, player, availability)
    local fillLabel = Text.getVanillaFillText()
    if availability.canFill then
        fillLabel = Text.withSubMenuShortcut(fillLabel)
    end
    local fillOption = subMenu:addOption(fillLabel, nil, nil)
    fillOption.notAvailable = not availability.canFill

    if availability.canFill then
        addVanillaLikeFillSubMenu(
            subMenu,
            fillOption,
            availability.targetItems,
            barrel,
            player,
            availability.liquidType
        )
        return
    end

    Tooltips.attachFillRequirementsTooltip(fillOption, availability)
end

local function appendCompatibleTargetBarrel(found, seen, sourceBarrel, player, sourceData, targetBarrel)
    if not targetBarrel or targetBarrel == sourceBarrel or seen[targetBarrel] then return end
    if not PlayerUtils.isPlayerInRange(player, targetBarrel) then return end

    local targetData = BarrEx_BarrelData.get(targetBarrel)

    if not targetData then return end
    if not TransferRules.canTransferBetweenBarrels(sourceData, targetData) then return end

    seen[targetBarrel] = true
    found[#found + 1] = {
        barrel = targetBarrel,
        data = targetData,
    }
end

local function collectNearbyTransferTargets(sourceBarrel, player, sourceData)
    local found = {}
    local seen = {}
    local sourceSquare = sourceBarrel and sourceBarrel:getSquare() or nil
    if not sourceSquare or not sourceData then return found end

    local cell = getCell()
    if not cell then return found end

    local radius = math.max(math.floor(tonumber(Constant.MAX_INTERACTION_DISTANCE) or 2), 1)
    local sourceX = sourceSquare:getX()
    local sourceY = sourceSquare:getY()
    local sourceZ = sourceSquare:getZ()

    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(sourceX + dx, sourceY + dy, sourceZ)
            local objects = square and square:getObjects() or nil
            if objects then
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    if WorldUtils.isExpandableBarrel(object) then
                        appendCompatibleTargetBarrel(found, seen, sourceBarrel, player, sourceData, object)
                    end
                end
            end
        end
    end

    table.sort(found, function(a, b)
        local aData = a and a.data or nil
        local bData = b and b.data or nil
        local aAmount = tonumber(aData and aData.amount) or 0
        local bAmount = tonumber(bData and bData.amount) or 0
        return aAmount < bAmount
    end)

    return found
end

local function addBarrelTransferOption(subMenu, sourceBarrel, player, sourceData, inRange)
    if not inRange then
        local transferOption = subMenu:addOption(Text.translate(ContextConfig.CONTEXT_MENU.TRANSFER_TO_BARREL), nil, nil)
        transferOption.notAvailable = true
        Tooltips.attachTooFarTooltip(transferOption)
        return
    end

    local targetBarrels = collectNearbyTransferTargets(sourceBarrel, player, sourceData)
    local canTransfer = #targetBarrels > 0
    local transferLabel = Text.translate(ContextConfig.CONTEXT_MENU.TRANSFER_TO_BARREL)
    if canTransfer then
        transferLabel = Text.withSubMenuShortcut(transferLabel)
    end

    local transferOption = subMenu:addOption(transferLabel, nil, nil)
    transferOption.notAvailable = not canTransfer

    if not canTransfer then
        local reasonKey = sourceData and sourceData:isEmpty()
            and ContextConfig.TOOLTIP.BARREL_EMPTY
            or ContextConfig.TOOLTIP.NO_COMPATIBLE_BARREL
        Tooltips.attachUnavailableTooltip(transferOption, Text.translate(reasonKey))
        return
    end

    local transferMenu = subMenu:getNew(subMenu)
    subMenu:addSubMenu(transferOption, transferMenu)

    for i = 1, #targetBarrels do
        local target = targetBarrels[i]
        local targetData = target.data
        local option = transferMenu:addOption(
            Text.buildBarrelTransferTargetLabel(targetData),
            sourceBarrel,
            Actions.onTransferToBarrel,
            player,
            target.barrel
        )
        Tooltips.attachWorldObjectIcon(option, target.barrel)
        Tooltips.attachBarrelTransferTooltip(option, sourceData, targetData)
    end
end

---@param found table<integer, IsoGenerator>
---@param seen table<IsoGenerator, boolean>
---@param sourceBarrel IsoObject
---@param player IsoPlayer
---@param generator IsoGenerator|nil
local function appendNearbyTargetGenerator(found, seen, sourceBarrel, player, generator)
    if not generator or seen[generator] then return end
    if not PlayerUtils.isPlayerInRange(player, generator) then return end
    if not PlayerUtils.isObjectInRange(sourceBarrel, generator) then return end

    seen[generator] = true
    found[#found + 1] = generator
end

---@param sourceBarrel IsoObject
---@param player IsoPlayer
---@return table<integer, IsoGenerator>
local function collectNearbyGenerators(sourceBarrel, player)
    local found = {}
    local seen = {}
    local sourceSquare = sourceBarrel and sourceBarrel:getSquare() or nil
    if not sourceSquare then return found end

    local cell = getCell()
    if not cell then return found end

    local radius = math.max(math.floor(tonumber(Constant.MAX_INTERACTION_DISTANCE) or 2), 1)
    local sourceX = sourceSquare:getX()
    local sourceY = sourceSquare:getY()
    local sourceZ = sourceSquare:getZ()

    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(sourceX + dx, sourceY + dy, sourceZ)
            local generators = GeneratorUtils.collectGeneratorsOnSquare(square)
            for i = 1, #generators do
                appendNearbyTargetGenerator(found, seen, sourceBarrel, player, generators[i])
            end
        end
    end

    return found
end

---@param generators table<integer, IsoGenerator>|nil
---@param sourceData BarrEx_Barrel|nil
---@return table<integer, IsoGenerator>
local function collectCompatibleGeneratorTargets(generators, sourceData)
    local found = {}
    if not generators then return found end

    for i = 1, #generators do
        local generator = generators[i]
        if generator and TransferRules.canFuelGeneratorFromBarrel(sourceData, generator) then
            found[#found + 1] = generator
        end
    end

    table.sort(found, function(a, b)
        return GeneratorUtils.getFuel(a) < GeneratorUtils.getFuel(b)
    end)

    return found
end

---@param sourceData BarrEx_Barrel|nil
---@param generators table<integer, IsoGenerator>|nil
---@param hasTool boolean
---@return string
---@return IsoGenerator|nil
local function getGeneratorTargetUnavailableReason(sourceData, generators, hasTool)
    if not sourceData or not sourceData:isRevealed() then
        return ContextConfig.TOOLTIP.BARREL_CLOSED, nil
    end
    if sourceData:isEmpty() or (tonumber(sourceData.amount) or 0) <= 0 then
        return ContextConfig.TOOLTIP.BARREL_EMPTY, nil
    end
    if sourceData.liquidType ~= Constant.LIQUID_TYPE.GASOLINE then
        return ContextConfig.TOOLTIP.NEED_GASOLINE_BARREL, nil
    end

    local hasGenerator = false
    local fullGenerator = nil
    if not generators then
        return ContextConfig.TOOLTIP.NO_COMPATIBLE_GENERATOR, nil
    end

    for i = 1, #generators do
        local generator = generators[i]
        if generator and GeneratorUtils.isAvailable(generator) then
            hasGenerator = true
            if GeneratorUtils.isFull(generator) then
                fullGenerator = fullGenerator or generator
            else
                if not hasTool then
                    return ContextConfig.TOOLTIP.MISSING_REQUIRED_TOOL, generator
                end
                return ContextConfig.TOOLTIP.NO_COMPATIBLE_GENERATOR, generator
            end
        end
    end

    if fullGenerator then
        return ContextConfig.TOOLTIP.GENERATOR_FULL, fullGenerator
    end
    if not hasGenerator then
        return ContextConfig.TOOLTIP.NO_COMPATIBLE_GENERATOR, nil
    end

    return ContextConfig.TOOLTIP.NO_COMPATIBLE_GENERATOR, nil
end

---@param found table<integer, BarrEx_GeneratorSourceBarrelEntry>
---@param generator IsoGenerator
---@param barrel IsoObject|nil
local function appendCompatibleSourceBarrel(found, generator, barrel)
    if not barrel then return end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then return end
    if not PlayerUtils.isObjectInRange(barrel, generator) then return end

    found[#found + 1] = {
        barrel = barrel,
        data = barrelData,
    }
end

---@param sourceData BarrEx_Barrel|nil
---@param generator IsoGenerator|nil
---@param hasTool boolean
---@return string|nil
local function getGeneratorRefuelUnavailableReason(sourceData, generator, hasTool)
    if not sourceData or not sourceData:isRevealed() then
        return ContextConfig.TOOLTIP.BARREL_CLOSED
    end
    if sourceData:isEmpty() or (tonumber(sourceData.amount) or 0) <= 0 then
        return ContextConfig.TOOLTIP.BARREL_EMPTY
    end
    if sourceData.liquidType ~= Constant.LIQUID_TYPE.GASOLINE then
        return ContextConfig.TOOLTIP.NEED_GASOLINE_BARREL
    end
    if not GeneratorUtils.isAvailable(generator) then
        return ContextConfig.TOOLTIP.NO_COMPATIBLE_GENERATOR
    end
    if GeneratorUtils.isFull(generator) then
        return ContextConfig.TOOLTIP.GENERATOR_FULL
    end
    if not hasTool then
        return ContextConfig.TOOLTIP.MISSING_REQUIRED_TOOL
    end

    return nil
end

---@param generator IsoGenerator
---@param player IsoPlayer
---@return table<integer, BarrEx_GeneratorSourceBarrelEntry>
local function collectNearbyGeneratorSourceBarrels(generator, player)
    local found = {}
    local generatorSquare = generator and generator:getSquare() or nil
    if not generatorSquare or not PlayerUtils.isPlayerInRange(player, generator) then return found end

    local cell = getCell()
    if not cell then return found end

    local barrels = {}
    local seen = {}
    local radius = math.max(math.floor(tonumber(Constant.MAX_INTERACTION_DISTANCE) or 2), 1)
    local generatorX = generatorSquare:getX()
    local generatorY = generatorSquare:getY()
    local generatorZ = generatorSquare:getZ()

    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(generatorX + dx, generatorY + dy, generatorZ)
            collectBarrelsOnSquare(square, barrels, seen)
        end
    end

    for i = 1, #barrels do
        appendCompatibleSourceBarrel(found, generator, barrels[i])
    end

    table.sort(found, function(a, b)
        local amountA = tonumber(a and a.data and a.data.amount) or 0
        local amountB = tonumber(b and b.data and b.data.amount) or 0
        return amountA > amountB
    end)

    return found
end

---@param menu ISContextMenu|nil
---@param optionName string|nil
---@return table|nil
local function findOptionByName(menu, optionName)
    if not menu or not menu.options or not optionName then return nil end

    for i = 1, #menu.options do
        local option = menu.options[i]
        if option and option.name == optionName then
            return option
        end
    end

    return nil
end

---@param option table|nil
---@param optionName string|nil
---@return boolean
local function optionNameMatches(option, optionName)
    if not option or not option.name or not optionName then return false end
    return option.name == optionName or string.find(option.name, optionName, 1, true) == 1
end

---@param menu ISContextMenu|nil
---@param option table|nil
---@return ISContextMenu|nil
local function getOptionSubMenu(menu, option)
    if not menu or not option or not option.subOption or type(menu.getSubMenu) ~= "function" then return nil end
    return menu:getSubMenu(option.subOption)
end

---@param menu ISContextMenu|nil
---@param option table|nil
---@return ISContextMenu|nil
local function getOrCreateOptionSubMenu(menu, option)
    if not menu or not option then return nil end

    local subMenu = getOptionSubMenu(menu, option)
    if subMenu then return subMenu end

    subMenu = menu:getNew(menu)
    menu:addSubMenu(option, subMenu)
    return subMenu
end

---@param menu ISContextMenu|nil
---@param optionName string|nil
---@param maxDepth number|nil
---@return ISContextMenu|nil
---@return table|nil
---@return ISContextMenu|nil
local function findOptionSubMenuRecursive(menu, optionName, maxDepth)
    local depth = tonumber(maxDepth) or 0
    if not menu or not optionName or depth < 0 then return nil end

    local option = findOptionByName(menu, optionName)
    local subMenu = getOptionSubMenu(menu, option)
    if subMenu then return subMenu, option, menu end

    if depth == 0 or not menu.options then return nil end

    for i = 1, #menu.options do
        local childOption = menu.options[i]
        local childMenu = getOptionSubMenu(menu, childOption)
        if childMenu then
            local foundMenu, foundOption, parentMenu = findOptionSubMenuRecursive(childMenu, optionName, depth - 1)
            if foundMenu then
                return foundMenu, foundOption, parentMenu
            end
        end
    end

    return nil
end

---@param menu ISContextMenu|nil
local function refreshMenuSize(menu)
    if not menu then return end
    if type(menu.calcHeight) == "function" then
        menu:calcHeight()
    end
    if type(menu.calcWidth) == "function" and type(menu.setWidth) == "function" then
        menu:setWidth(menu:calcWidth())
    end
end

---@param option table|nil
---@param reasonKey string|nil
---@param appendReason boolean|nil
---@param detachSubMenu boolean|nil
local function markMenuOptionUnavailable(option, reasonKey, appendReason, detachSubMenu)
    if not option or not reasonKey then return end

    local reasonText = Text.translate(reasonKey)
    option.notAvailable = true
    if detachSubMenu == true then
        option.subOption = nil
    end
    if appendReason ~= false and option.name and reasonText and not string.find(option.name, reasonText, 1, true) then
        option.name = Text.withDisabledReason(option.name, reasonText)
    end
    Tooltips.attachUnavailableTooltip(option, reasonText)
end

---@param menu ISContextMenu|nil
---@param reasonKey string|nil
---@param appendReason boolean|nil
---@param detachSubMenu boolean|nil
local function markMenuOptionsUnavailable(menu, reasonKey, appendReason, detachSubMenu)
    if not menu or not menu.options or not reasonKey then return end

    for i = 1, #menu.options do
        local option = menu.options[i]
        markMenuOptionUnavailable(option, reasonKey, appendReason, detachSubMenu)

        local subMenu = getOptionSubMenu(menu, option)
        if subMenu then
            markMenuOptionsUnavailable(subMenu, reasonKey, appendReason, detachSubMenu)
        end
    end

    refreshMenuSize(menu)
end

---@param menu ISContextMenu|nil
---@param optionName string|nil
---@param found table<integer, table>|nil
---@param maxDepth number|nil
---@return table<integer, table>
local function collectNamedMenuOptions(menu, optionName, found, maxDepth)
    found = found or {}
    local depth = tonumber(maxDepth) or 0
    if not menu or not menu.options or not optionName or depth < 0 then return found end

    for i = 1, #menu.options do
        local option = menu.options[i]
        local subMenu = getOptionSubMenu(menu, option)
        if optionNameMatches(option, optionName) then
            found[#found + 1] = {
                menu = menu,
                option = option,
                subMenu = subMenu,
            }
        end
        if subMenu and depth > 0 then
            collectNamedMenuOptions(subMenu, optionName, found, depth - 1)
        end
    end

    return found
end

---@param menu ISContextMenu|nil
---@param optionName string|nil
---@param reasonKey string|nil
---@param appendReason boolean|nil
---@param detachSubMenu boolean|nil
---@param markSubMenuOptions boolean|nil
local function markNamedMenuOptionsUnavailable(menu, optionName, reasonKey, appendReason, detachSubMenu, markSubMenuOptions)
    if not menu or not optionName or not reasonKey then return end

    local entries = collectNamedMenuOptions(menu, optionName, {}, 4)
    for i = 1, #entries do
        local entry = entries[i]
        markMenuOptionUnavailable(entry.option, reasonKey, appendReason, detachSubMenu)
        if markSubMenuOptions ~= false then
            markMenuOptionsUnavailable(entry.subMenu, reasonKey, appendReason, detachSubMenu)
        end
        refreshMenuSize(entry.menu)
    end
end

---@param context ISContextMenu|nil
---@return ISContextMenu|nil
local function getGeneratorSubMenu(context)
    if not context then return nil end

    local generatorLabel = getText("ContextMenu_Generator")
    local generatorOption = findOptionByName(context, generatorLabel)
    local generatorMenu = getOptionSubMenu(context, generatorOption)
    if generatorMenu then return generatorMenu end

    return findOptionSubMenuRecursive(context, generatorLabel, 3)
end

---@param context ISContextMenu|nil
---@param generator IsoGenerator|nil
---@return ISContextMenu|nil
local function getOrCreateGeneratorSubMenu(context, generator)
    if not context then return nil end

    local generatorMenu = getGeneratorSubMenu(context)
    if generatorMenu then return generatorMenu end

    local generatorLabel = getText("ContextMenu_Generator")
    local generatorOption = findOptionByName(context, generatorLabel)
    if generatorOption then
        return getOrCreateOptionSubMenu(context, generatorOption)
    end

    generatorOption = context:addOption(generatorLabel, nil, nil)
    Tooltips.attachWorldObjectIcon(generatorOption, generator)
    return getOrCreateOptionSubMenu(context, generatorOption)
end

---@param context ISContextMenu
---@param generator IsoGenerator
---@return table|nil
local function getOrCreateGeneratorAddFuelOption(context, generator)
    local generatorMenu = getOrCreateGeneratorSubMenu(context, generator)
    if not generatorMenu then return nil end

    local addFuelOption = findOptionByName(generatorMenu, getText("ContextMenu_GeneratorAddFuel"))
    if addFuelOption then return addFuelOption end

    return generatorMenu:addOption(getText("ContextMenu_GeneratorAddFuel"), nil, nil)
end

---@param context ISContextMenu
---@return ISContextMenu|nil
local function getGeneratorAddFuelSubMenu(context)
    local generatorMenu = getGeneratorSubMenu(context)
    if not generatorMenu then return nil end

    local addFuelOption = findOptionByName(generatorMenu, getText("ContextMenu_GeneratorAddFuel"))
    if not addFuelOption or addFuelOption.notAvailable then return nil end
    return getOptionSubMenu(generatorMenu, addFuelOption)
end

---@param context ISContextMenu
---@param generator IsoGenerator
---@return ISContextMenu|nil
local function getOrCreateGeneratorAddFuelSubMenu(context, generator)
    local generatorMenu = getOrCreateGeneratorSubMenu(context, generator)
    if not generatorMenu then return nil end

    local addFuelOption = findOptionByName(generatorMenu, getText("ContextMenu_GeneratorAddFuel"))
    if addFuelOption then
        if addFuelOption.notAvailable then return nil end
        return getOrCreateOptionSubMenu(generatorMenu, addFuelOption)
    end

    addFuelOption = generatorMenu:addOption(getText("ContextMenu_GeneratorAddFuel"), nil, nil)
    return getOrCreateOptionSubMenu(generatorMenu, addFuelOption)
end

---@param context ISContextMenu
local function markGeneratorAddFuelFull(context)
    markNamedMenuOptionsUnavailable(
        context,
        getText("ContextMenu_GeneratorAddFuel"),
        ContextConfig.TOOLTIP.GENERATOR_FULL,
        false,
        true,
        false
    )
end

---@param context ISContextMenu
---@param player IsoPlayer
---@param generator IsoGenerator
local function addGeneratorSourceBarrelOptions(context, player, generator)
    local sourceBarrels = collectNearbyGeneratorSourceBarrels(generator, player)
    local generatorFull = GeneratorUtils.isAvailable(generator) and GeneratorUtils.isFull(generator)

    if generatorFull then
        if #sourceBarrels > 0 then
            getOrCreateGeneratorAddFuelOption(context, generator)
        end
        markGeneratorAddFuelFull(context)
        return
    end

    if #sourceBarrels == 0 then return end

    local addFuelMenu = getOrCreateGeneratorAddFuelSubMenu(context, generator)
    if not addFuelMenu then return end

    local hasTool, foundItems, missingItems = PlayerUtils.getRequiredItemStatus(player, Constant.EXTRACT_REQUIRED_ITEMS)
    for i = 1, #sourceBarrels do
        local source = sourceBarrels[i]
        local sourceBarrel = source.barrel
        local sourceData = source.data
        local reasonKey = getGeneratorRefuelUnavailableReason(sourceData, generator, hasTool)
        local option = addFuelMenu:addGetUpOption(
            Text.buildGeneratorTransferSourceBarrelLabel(sourceData),
            sourceBarrel,
            Actions.onTransferToGenerator,
            player,
            generator
        )

        option.notAvailable = reasonKey ~= nil
        Tooltips.attachWorldObjectIcon(option, sourceBarrel)
        if not reasonKey then
            Tooltips.attachGeneratorTransferTooltip(option, sourceData, generator)
        else
            Tooltips.attachGeneratorRefuelRequirementsTooltip(option, sourceData, foundItems, missingItems, generator, reasonKey)
        end
    end
end

---@param subMenu ISContextMenu
---@param sourceBarrel IsoObject
---@param player IsoPlayer
---@param sourceData BarrEx_Barrel|nil
---@param inRange boolean
local function addGeneratorTransferOption(subMenu, sourceBarrel, player, sourceData, inRange)
    if not inRange then
        local transferOption = subMenu:addOption(Text.translate(ContextConfig.CONTEXT_MENU.TRANSFER_TO_GENERATOR), nil, nil)
        transferOption.notAvailable = true
        Tooltips.attachTooFarTooltip(transferOption)
        return
    end

    local hasTool, foundItems, missingItems = PlayerUtils.getRequiredItemStatus(player, Constant.EXTRACT_REQUIRED_ITEMS)
    local nearbyGenerators = collectNearbyGenerators(sourceBarrel, player)
    local targetGenerators = collectCompatibleGeneratorTargets(nearbyGenerators, sourceData)
    local canTransfer = hasTool and #targetGenerators > 0
    local transferLabel = Text.translate(ContextConfig.CONTEXT_MENU.TRANSFER_TO_GENERATOR)
    if canTransfer then
        transferLabel = Text.withSubMenuShortcut(transferLabel)
    end

    local transferOption = subMenu:addOption(transferLabel, nil, nil)
    transferOption.notAvailable = not canTransfer

    if not canTransfer then
        local reasonKey, reasonGenerator = getGeneratorTargetUnavailableReason(sourceData, nearbyGenerators, hasTool)
        Tooltips.attachGeneratorRefuelRequirementsTooltip(transferOption, sourceData, foundItems, missingItems, reasonGenerator, reasonKey)
        return
    end

    local transferMenu = subMenu:getNew(subMenu)
    subMenu:addSubMenu(transferOption, transferMenu)

    for i = 1, #targetGenerators do
        local generator = targetGenerators[i]
        local option = transferMenu:addOption(
            Text.buildGeneratorTransferTargetLabel(generator),
            sourceBarrel,
            Actions.onTransferToGenerator,
            player,
            generator
        )
        Tooltips.attachWorldObjectIcon(option, generator)
        Tooltips.attachGeneratorTransferTooltip(option, sourceData, generator)
    end
end

local function addDrinkOption(subMenu, barrel, player, availability)
    local drinkOption = subMenu:addOption(Text.getVanillaDrinkText(), barrel, Actions.onDrinkFromBarrel, player)
    drinkOption.notAvailable = not availability.canDrink

    if availability.isTaintedWater or not availability.canDrink then
        Tooltips.attachDrinkTooltip(drinkOption, availability)
    end
end

local function addWashItemOption(washMenu, barrel, player, item, isTaintedWater)
    local label = getText("ContextMenu_WashClothing", Text.getInventoryItemDisplayName(item))
    local option = washMenu:addOption(label, barrel, Actions.onWashItemFromBarrel, player, item)
    Tooltips.attachInventoryItemIcon(option, item)

    if isTaintedWater and Inventory.isCleanableBandageLikeItem(item) then
        option.notAvailable = true
        Tooltips.attachTaintedWaterTooltip(option)
    end

    return option
end

local function addWashOption(subMenu, barrel, player, availability)
    local washOption = subMenu:addOption(Text.getVanillaWashText(), nil, nil)
    washOption.notAvailable = not availability.canWash

    if not availability.canWash then
        attachReasonTooltip(washOption, availability.washReason)
        return
    end

    local washMenu = subMenu:getNew(subMenu)
    subMenu:addSubMenu(washOption, washMenu)

    if (tonumber(availability.washSelfWaterRequired) or 0) > 0 then
        washMenu:addOption(Text.getVanillaYourselfText(), barrel, Actions.onWashSelfFromBarrel, player)
    end

    local washableItems = availability.washItems or {}
    if #washableItems > 1 then
        local allowedItems = {}
        for i = 1, #washableItems do
            local item = washableItems[i]
            if not (availability.isTaintedWater and Inventory.isCleanableBandageLikeItem(item)) then
                allowedItems[#allowedItems + 1] = item
            end
        end

        if #allowedItems > 1 then
            washMenu:addOption(Text.getVanillaWashAllClothingText(), barrel, Actions.onWashAllFromBarrel, player, allowedItems)
        end
    end

    for i = 1, #washableItems do
        local item = washableItems[i]
        addWashItemOption(washMenu, barrel, player, item, availability.isTaintedWater)
    end
end

local function addEmptyOption(subMenu, barrel, player, availability)
    local emptyOption = subMenu:addOption(Text.getVanillaEmptyText(), barrel, Actions.onEmptyBarrel, player)
    emptyOption.notAvailable = not availability.canEmpty

    if not availability.canEmpty then
        attachReasonTooltip(emptyOption, availability.emptyReason)
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

---@param context ISContextMenu
---@param barrel IsoObject
---@param player IsoPlayer
local function addSyncingSubMenu(context, barrel, player)
    local barrelOption = context:addOption(Text.translate(ContextConfig.CONTEXT_MENU.BARREL), nil, nil)
    Tooltips.attachWorldObjectIcon(barrelOption, barrel)

    local subMenu = context:getNew(context)
    context:addSubMenu(barrelOption, subMenu)

    local syncingOption = subMenu:addOption(Text.translate(ContextConfig.CONTEXT_MENU.SYNCING), nil, nil)
    syncingOption.notAvailable = true

    AdminBarrelActions.addSubMenu(subMenu, barrel, player)
end

---@param value any
---@return any
local function getWorldObject(value)
    if value and type(value) == "table" and value.object then
        return value.object
    end
    return value
end

---@param found table<integer, IsoObject>
---@param seen table<IsoObject, boolean>
---@param barrel IsoObject|nil
local function appendUniqueBarrel(found, seen, barrel)
    if not barrel or seen[barrel] then return end
    seen[barrel] = true
    found[#found + 1] = barrel
end

---@param found table<integer, IsoGenerator>
---@param seen table<IsoGenerator, boolean>
---@param generator IsoGenerator|nil
local function appendUniqueGenerator(found, seen, generator)
    if not generator or not GeneratorUtils.isGenerator(generator) or seen[generator] then return end
    seen[generator] = true
    found[#found + 1] = generator
end

---@param square IsoGridSquare|nil
---@param found table<integer, IsoObject>
---@param seen table<IsoObject, boolean>
function collectBarrelsOnSquare(square, found, seen)
    if not square then return end

    local objects = square:getObjects()
    if not objects then return end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if WorldUtils.isExpandableBarrel(object) then
            appendUniqueBarrel(found, seen, object)
        end
    end
end

---@generic T
---@param found table<integer, T>
---@return T|nil
local function chooseOnly(found)
    if #found == 1 then return found[1] end
    return nil
end

---@param worldObjects IsoObject[]|nil
---@return IsoObject|nil
local function findContextBarrel(worldObjects)
    if not worldObjects or #worldObjects == 0 then return nil end

    local found = {}
    local seen = {}
    local squares = {}
    local squareSeen = {}

    for i = 1, #worldObjects do
        local object = getWorldObject(worldObjects[i])
        if object then
            if WorldUtils.isExpandableBarrel(object) then
                appendUniqueBarrel(found, seen, object)
            end

            local square = type(object.getSquare) == "function" and object:getSquare() or nil
            if square and not squareSeen[square] then
                squareSeen[square] = true
                squares[#squares + 1] = square
            end
        end
    end

    local directBarrel = chooseOnly(found)
    if directBarrel then return directBarrel end
    if #found > 1 then return nil end

    for i = 1, #squares do
        collectBarrelsOnSquare(squares[i], found, seen)
    end

    local sameSquareBarrel = chooseOnly(found)
    if sameSquareBarrel then return sameSquareBarrel end
    return nil
end

---@param worldObjects IsoObject[]|nil
---@return IsoGenerator|nil
local function findContextGenerator(worldObjects)
    if not worldObjects or #worldObjects == 0 then return nil end

    local found = {}
    local seen = {}
    local squares = {}
    local squareSeen = {}

    for i = 1, #worldObjects do
        local object = getWorldObject(worldObjects[i])
        if object then
            if GeneratorUtils.isGenerator(object) and not seen[object] then
                seen[object] = true
                found[#found + 1] = object
            end

            local square = type(object.getSquare) == "function" and object:getSquare() or nil
            if square and not squareSeen[square] then
                squareSeen[square] = true
                squares[#squares + 1] = square
            end
        end
    end

    local directGenerator = chooseOnly(found)
    if directGenerator then return directGenerator end
    if #found > 1 then return nil end

    for i = 1, #squares do
        GeneratorUtils.collectGeneratorsOnSquare(squares[i], found, seen)
    end

    local sameSquareGenerator = chooseOnly(found)
    if sameSquareGenerator then return sameSquareGenerator end
    return nil
end

---@param found table<integer, IsoGenerator>
---@param seen table<IsoGenerator, boolean>
---@param value any
local function appendGeneratorOptionValue(found, seen, value)
    local object = getWorldObject(value)
    if GeneratorUtils.isGenerator(object) then
        appendUniqueGenerator(found, seen, object)
    end
end

---@param menu ISContextMenu|nil
---@param found table<integer, IsoGenerator>
---@param seen table<IsoGenerator, boolean>
---@param maxDepth number|nil
local function collectGeneratorsFromMenu(menu, found, seen, maxDepth)
    local depth = tonumber(maxDepth) or 0
    if not menu or not menu.options or depth < 0 then return end

    for i = 1, #menu.options do
        local option = menu.options[i]
        if option then
            appendGeneratorOptionValue(found, seen, option.target)
            appendGeneratorOptionValue(found, seen, option.param1)
            appendGeneratorOptionValue(found, seen, option.param2)
            appendGeneratorOptionValue(found, seen, option.param3)
            appendGeneratorOptionValue(found, seen, option.param4)
            appendGeneratorOptionValue(found, seen, option.param5)
            appendGeneratorOptionValue(found, seen, option.param6)
            appendGeneratorOptionValue(found, seen, option.param7)
            appendGeneratorOptionValue(found, seen, option.param8)
            appendGeneratorOptionValue(found, seen, option.param9)
            appendGeneratorOptionValue(found, seen, option.param10)

            local subMenu = getOptionSubMenu(menu, option)
            if subMenu and depth > 0 then
                collectGeneratorsFromMenu(subMenu, found, seen, depth - 1)
            end
        end
    end
end

---@param context ISContextMenu
---@return IsoGenerator|nil
local function findContextGeneratorFromMenu(context)
    local found = {}
    local seen = {}
    collectGeneratorsFromMenu(context, found, seen, 4)
    return chooseOnly(found)
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
    Tooltips.attachWorldObjectIcon(barrelOption, barrel)

    local subMenu = context:getNew(context)
    context:addSubMenu(barrelOption, subMenu)

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        addOpenBarrelOption(subMenu, barrel, player, canOpen, foundItems, missingItems, inRange)
        AdminBarrelActions.addSubMenu(subMenu, barrel, player)
        return
    end

    local availability = Availability.build(player, barrelData, inRange)
    AdminBarrelActions.addSubMenu(subMenu, barrel, player)
    addBarrelInfoOption(subMenu, barrelData)
    addFillOption(subMenu, barrel, player, availability)
    addPourOption(subMenu, barrel, player, barrelData, availability)
    addBarrelTransferOption(subMenu, barrel, player, barrelData, inRange)
    addGeneratorTransferOption(subMenu, barrel, player, barrelData, inRange)
    addDrinkOption(subMenu, barrel, player, availability)
    addWashOption(subMenu, barrel, player, availability)
    addEmptyOption(subMenu, barrel, player, availability)
end

local function patchVanillaGeneratorAddFuelGuard()
    if not ISWorldObjectContextMenu or ISWorldObjectContextMenu.BarrEx_GeneratorAddFuelPatched then return end
    local original = ISWorldObjectContextMenu.doAddFuelGenerator
    if type(original) ~= "function" then return end

    ---@diagnostic disable-next-line: duplicate-set-field
    ISWorldObjectContextMenu.doAddFuelGenerator = function(worldobjects, generator, fuelContainerList, fuelContainer, player)
        if GeneratorUtils.isFull(generator) then return end
        return original(worldobjects, generator, fuelContainerList, fuelContainer, player)
    end
    ISWorldObjectContextMenu.BarrEx_GeneratorAddFuelPatched = true
end

---@param playerIndex integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
function ContextMenu.onFillWorldObjectContextMenu(playerIndex, context, worldObjects, test)
    if test then return end
    patchVanillaGeneratorAddFuelGuard()

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    local generator = findContextGenerator(worldObjects) or findContextGeneratorFromMenu(context)
    if generator then
        addGeneratorSourceBarrelOptions(context, player, generator)
    end

    local barrel = findContextBarrel(worldObjects)
    if not barrel then return end

    local canOpen, foundItems, missingItems = PlayerUtils.getRequiredItemStatus(
        player,
        Constant.OPEN_BARREL_REQUIRED_ITEMS
    )
    local inRange = PlayerUtils.isPlayerInRange(player, barrel)

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData.id or barrelData.revision == nil then
        BarrelStateClient.requestStateForBarrel(barrel, "context")
        addSyncingSubMenu(context, barrel, player)
        return
    end

    addBarrelSubMenu(context, barrel, player, canOpen, foundItems, missingItems, inRange)
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldObjectContextMenu)
patchVanillaGeneratorAddFuelGuard()

return ContextMenu
