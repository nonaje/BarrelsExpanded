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

local ContextMenu = {}

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
        Tooltips.attachSimpleTooltip(transferOption, Text.translate(reasonKey))
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

local function getWorldObject(value)
    if value and type(value) == "table" and value.object then
        return value.object
    end
    return value
end

local function appendUniqueBarrel(found, seen, barrel)
    if not barrel or seen[barrel] then return end
    seen[barrel] = true
    found[#found + 1] = barrel
end

local function collectBarrelsOnSquare(square, found, seen)
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

            local square = object:getSquare()
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
    addDrinkOption(subMenu, barrel, player, availability)
    addWashOption(subMenu, barrel, player, availability)
    addEmptyOption(subMenu, barrel, player, availability)
end

---@param playerIndex integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
function ContextMenu.onFillWorldObjectContextMenu(playerIndex, context, worldObjects, test)
    if test then return end

    local barrel = findContextBarrel(worldObjects)
    if not barrel then return end

    local player = getSpecificPlayer(playerIndex)
    if not player then return end

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

return ContextMenu
