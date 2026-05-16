-- BarrEx_BarrelUseService: server-authoritative non-transfer liquid uses.
--
-- Handles drink, wash and empty actions. Client timed actions only provide the
-- animation and intent; this service validates the world barrel and applies the
-- actual player/barrel mutations.

local Constant = require("BarrEx_Constant")
local BarrEx_BarrelData = require("BarrEx_BarrelData")
local BarrelResolver = require("BarrEx_BarrelResolver")
local InteractionRules = require("core/BarrEx_InteractionRules")
local Logger = require("utils/BarrEx_Logger")

local BarrelUseService = {}

local function log(message)
    Logger.info(message)
end

-- Reads the fluid amount consumed per soap use from the vanilla global defined in defines.lua.
-- Falls back to the canonical defines.lua value if the global is not yet initialized.
local function getSoapFluidUseAmount()
    -- Access via string key to avoid analyzer warnings for undeclared vanilla globals.
    local v = ZomboidGlobals and ZomboidGlobals["CleanStainCleaningFluidAmount"]
    return type(v) == "number" and v or 0.0999
end

local function isWaterLike(liquidType)
    return liquidType == Constant.LIQUID_TYPE.WATER
        or liquidType == Constant.LIQUID_TYPE.TAINTED_WATER
end

local function persistBarrel(barrel, barrelData)
    if not barrel or not barrelData then return end

    BarrEx_BarrelData.set(barrel, barrelData)
    -- First sync ensures the modData is updated on the object itself
    barrel:transmitModData()
end

local function notifyBarrelUseCompleted(player, barrel, barrelData, action)
    if not player or not barrel or not barrelData or type(sendServerCommand) ~= "function" then return end

    local modData = barrel:getModData()
    local barrelId = modData and modData[Constant.MODDATA_KEYS.BARREL_ID] or nil

    -- Log for debugging multiplayer sync issues
    log(string.format(
        "BarrelUseCompleted: action=%s barrelId=%s liquidType=%s amount=%.2f",
        action or "unknown",
        barrelId or "none",
        barrelData.liquidType or "empty",
        barrelData.amount or 0
    ))

    -- Notify the acting player that their action was processed
    sendServerCommand(player, Constant.NETWORK.MODULE, Constant.NETWORK.BARREL_USE_COMPLETED, {
        action = action or "use",
        barrelId = barrelId,
        liquidType = barrelData.liquidType,
        amount = tonumber(barrelData.amount) or 0,
        x = barrel:getX(),
        y = barrel:getY(),
        z = barrel:getZ(),
    })

    -- Second transmit to ensure all nearby clients receive the update,
    -- particularly other players who may have the barrel visible
    -- but didn't receive the initial transmitModData from persistBarrel
    barrel:transmitModData()
end

---@param player IsoPlayer
---@param args table|nil
---@param allowEmpty boolean|nil
---@return IsoObject|nil, BarrEx_Barrel|nil, string|nil
local function resolveBarrel(player, args, allowEmpty)
    if not player or type(args) ~= "table" then return nil, nil, "invalid_args" end

    local barrel = BarrelResolver.getBarrelFromArgs(args)
    if not barrel then return nil, nil, "barrel_not_found" end

    local barrelData = BarrEx_BarrelData.get(barrel)
    if not barrelData or not barrelData:isRevealed() then
        return nil, nil, "barrel_unavailable"
    end

    if not InteractionRules.validateInteraction(barrel, player, {}, false) then
        return nil, nil, "interaction_invalid"
    end

    if not allowEmpty and barrelData:isEmpty() then
        return nil, nil, "barrel_empty"
    end

    return barrel, barrelData, nil
end

local function syncStats(player)
    if type(syncPlayerStats) == "function" and SyncPlayerStatsPacket then
        syncPlayerStats(player, SyncPlayerStatsPacket.Stat_Thirst)
    end
end

local function applyTaintedWaterSickness(player)
    if not player or not player.getStats then return end

    local stats = player:getStats()
    if not stats then return end
    if (tonumber(stats:get(CharacterStat.POISON)) or 0) >= 20 then return end
    if type(stats.getSickness) == "function" and (tonumber(stats:getSickness()) or 0) >= 0.3 then return end

    local basePoison = 10
    if CharacterTrait and type(player.hasTrait) == "function" then
        if player:hasTrait(CharacterTrait.IRON_GUT) then
            basePoison = 5
        elseif player:hasTrait(CharacterTrait.WEAK_STOMACH) then
            basePoison = 15
        end
    end

    stats:set(CharacterStat.POISON, math.min((tonumber(stats:get(CharacterStat.POISON)) or 0) + basePoison, 20))
    if type(sendDamage) == "function" then
        sendDamage(player)
    end
end

local function consumeSoap(player)
    local inventory = player and player:getInventory()
    local soaps = inventory and inventory:getSoapList(nil, true) or nil
    if not soaps then return false end

    for i = 0, soaps:size() - 1 do
        local soap = soaps:get(i)
        if soap then
            if ComponentType and soap.hasComponent and soap:hasComponent(ComponentType.FluidContainer)
                and soap:getFluidContainer()
                and soap:getFluidContainer():getAmount() > 0
            then
                local amount = soap:getFluidContainer():getAmount() - getSoapFluidUseAmount()
                if amount <= 0.001 then
                    soap:getFluidContainer():Empty()
                else
                    soap:getFluidContainer():adjustAmount(amount)
                end
                if type(sendItemStats) == "function" then sendItemStats(soap) end
                return true
            elseif instanceof and instanceof(soap, "DrainableComboItem") and soap:getCurrentUses() > 0 then
                soap:UseAndSync()
                return true
            end
        end
    end

    return false
end

local function syncItem(player, item)
    if type(syncItemFields) == "function" then
        syncItemFields(player, item)
    end
end

local function syncPlayerVisuals(player)
    if type(sendHumanVisual) == "function" then sendHumanVisual(player) end
    if type(syncVisuals) == "function" then syncVisuals(player) end
    if player and type(player.updateHandEquips) == "function" then
        player:updateHandEquips()
    end
end

local function removeMakeup(player)
    if not player or not ItemBodyLocation then return end

    local inventory = player:getInventory()
    if not inventory then return end

    local locations = {
        ItemBodyLocation.MAKE_UP_FULL_FACE,
        ItemBodyLocation.MAKE_UP_EYES,
        ItemBodyLocation.MAKE_UP_EYES_SHADOW,
        ItemBodyLocation.MAKE_UP_LIPS,
    }

    for _, location in ipairs(locations) do
        local item = player:getWornItem(location)
        if item then
            player:removeWornItem(item)
            inventory:Remove(item)
        end
    end
end

local function isCleanableBandageLikeItem(item)
    return item ~= nil
        and type(item.getItemAfterCleaning) == "function"
        and item:getItemAfterCleaning() ~= nil
end

local function getWashWaterRequired(item)
    if isCleanableBandageLikeItem(item) then
        return 1
    end

    if item and ISWashClothing and type(ISWashClothing.GetRequiredWater) == "function" then
        return math.max(tonumber(ISWashClothing.GetRequiredWater(item)) or 0, 1)
    end

    return 1
end

function BarrelUseService.drink(player, args)
    local barrel, barrelData, reason = resolveBarrel(player, args, false)
    if not barrel or not barrelData then
        log("Drink rejected: " .. tostring(reason))
        return
    end

    if not isWaterLike(barrelData.liquidType) then
        log("Drink rejected: liquid is not drinkable.")
        return
    end

    local stats = player:getStats()
    if not stats or (tonumber(stats:get(CharacterStat.THIRST)) or 0) <= 0.01 then
        return
    end

    local liquidType = barrelData.liquidType
    local removed = barrelData:removeLiquid(math.min(Constant.BARREL_DRINK_AMOUNT or 0.12, barrelData.amount or 0))
    if removed <= 0 then return end

    stats:remove(CharacterStat.THIRST, Constant.BARREL_DRINK_THIRST or 0.1)
    syncStats(player)

    if liquidType == Constant.LIQUID_TYPE.TAINTED_WATER then
        applyTaintedWaterSickness(player)
    end

    persistBarrel(barrel, barrelData)
    notifyBarrelUseCompleted(player, barrel, barrelData, "drink")
end

function BarrelUseService.washSelf(player, barrel, barrelData)
    if not isWaterLike(barrelData.liquidType) then return false end

    local visual = player:getHumanVisual()
    if not visual then return false end

    local availableUnits = math.floor((tonumber(barrelData.amount) or 0) / (Constant.BARREL_WASH_UNIT_AMOUNT or 1))
    if availableUnits <= 0 then return false end

    local waterUsed = 0
    for i = 1, BloodBodyPartType.MAX:index() do
        if waterUsed >= availableUnits then break end

        local part = BloodBodyPartType.FromIndex(i - 1)
        local blood = tonumber(visual:getBlood(part)) or 0
        local dirt = tonumber(visual:getDirt(part)) or 0
        if blood + dirt > 0 then
            if blood > 0 then consumeSoap(player) end
            visual:setBlood(part, 0)
            visual:setDirt(part, 0)
            waterUsed = waterUsed + 1
        end
    end

    if waterUsed <= 0 then return false end

    removeMakeup(player)
    syncPlayerVisuals(player)
    barrelData:removeLiquid(waterUsed * (Constant.BARREL_WASH_UNIT_AMOUNT or 1))
    persistBarrel(barrel, barrelData)

    return true
end

local function washItem(player, item)
    if not item then return false end

    local itemAfterCleaning = type(item.getItemAfterCleaning) == "function" and item:getItemAfterCleaning() or nil
    if itemAfterCleaning then
        local container = item:getContainer()
        if not container then return false end

        local favorite = type(item.isFavorite) == "function" and item:isFavorite() or false
        container:Remove(item)
        if type(sendRemoveItemFromContainer) == "function" then
            sendRemoveItemFromContainer(container, item)
        end

        local newItem = container:AddItem(itemAfterCleaning)
        if newItem and type(newItem.setFavorite) == "function" then
            newItem:setFavorite(favorite)
        end
        if newItem and type(sendAddItemToContainer) == "function" then
            sendAddItemToContainer(container, newItem)
        end
        return true
    end

    if instanceof and (instanceof(item, "Clothing") or instanceof(item, "InventoryContainer")) then
        local coveredParts = nil
        if BloodClothingType and type(item.getBloodClothingType) == "function" then
            coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        end
        if coveredParts then
            for i = 0, coveredParts:size() - 1 do
                local part = coveredParts:get(i)
                if (tonumber(item:getBlood(part)) or 0) > 0 then consumeSoap(player) end
                item:setBlood(part, 0)
                item:setDirt(part, 0)
            end
        end
        if instanceof(item, "Clothing") then
            if type(item.setWetness) == "function" then item:setWetness(100) end
            if type(item.setDirtiness) == "function" then item:setDirtiness(0) end
        end
    else
        if type(item.getBloodLevel) == "function" and (tonumber(item:getBloodLevel()) or 0) > 0 then
            consumeSoap(player)
        end
    end

    if type(item.setBloodLevel) == "function" then item:setBloodLevel(0) end
    if type(item.setDirtiness) == "function" then item:setDirtiness(0) end
    syncItem(player, item)
    syncPlayerVisuals(player)

    return true
end

function BarrelUseService.washItem(player, barrel, barrelData, args)
    if not isWaterLike(barrelData.liquidType) then return false end

    local item = InteractionRules.getItemFromArgsStrict(player, args)
    if not item then return false end

    if barrelData.liquidType == Constant.LIQUID_TYPE.TAINTED_WATER
        and isCleanableBandageLikeItem(item)
    then
        return false
    end

    local waterRequired = getWashWaterRequired(item)
    if (tonumber(barrelData.amount) or 0) < waterRequired then
        return false
    end

    if not washItem(player, item) then
        return false
    end

    barrelData:removeLiquid(waterRequired)
    persistBarrel(barrel, barrelData)

    return true
end

function BarrelUseService.wash(player, args)
    local barrel, barrelData, reason = resolveBarrel(player, args, false)
    if not barrel or not barrelData then
        log("Wash rejected: " .. tostring(reason))
        return
    end

    if args.washMode == "item" then
        if BarrelUseService.washItem(player, barrel, barrelData, args) then
            notifyBarrelUseCompleted(player, barrel, barrelData, "wash_item")
        else
            log("Wash item rejected.")
        end
        return
    end

    if BarrelUseService.washSelf(player, barrel, barrelData) then
        notifyBarrelUseCompleted(player, barrel, barrelData, "wash_self")
    else
        log("Wash self rejected.")
    end
end

function BarrelUseService.empty(player, args)
    local barrel, barrelData, reason = resolveBarrel(player, args, false)
    if not barrel or not barrelData then
        log("Empty rejected: " .. tostring(reason))
        return
    end

    local removed = barrelData:removeLiquid(barrelData.amount or 0)
    if removed <= 0 then return end

    persistBarrel(barrel, barrelData)
    notifyBarrelUseCompleted(player, barrel, barrelData, "empty")
end

return BarrelUseService
