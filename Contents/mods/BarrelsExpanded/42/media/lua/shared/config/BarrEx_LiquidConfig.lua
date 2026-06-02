-- BarrEx_LiquidConfig: all liquid-related gameplay configuration.
--
-- Centralizes liquid types, per-unit weights, compatible containers and the
-- O(1) inverse index (fullType -> liquidTypes).  Keeping this data in one
-- place makes it easier to add new liquids or adjust compatibility rules
-- without hunting through BarrEx_Constant.

local LiquidConfig = {}

-----------------------------------
---- AVAILABLE LIQUID TYPES   -----
-----------------------------------
LiquidConfig.LIQUID_TYPE = {
    EMPTY        = "EMPTY",
    WATER        = "WATER",
    TAINTED_WATER = "TAINTED_WATER",
    GASOLINE     = "GASOLINE",
    BLEACH       = "BLEACH",
}

-----------------------------------
-- LIQUID WEIGHT PER UNIT (kg/u) --
-----------------------------------
LiquidConfig.BARREL_LIQUID_WEIGHT_PER_UNIT = {
    TAINTED_WATER = 1.0,
    WATER         = 1.0,
    GASOLINE      = 0.75,
    BLEACH        = 1.1,
}

-----------------------------------
-- COMPATIBLE CONTAINERS PER LIQUID
-----------------------------------
local VANILLA_FLUID_COMPATIBLE_CONTAINERS = {
    ["Base.Bag_HydrationBackpack"]      = true,
    ["Base.Bag_HydrationBackpack_Camo"] = true,
    ["Base.Bag_LeatherWaterBag"]        = true,
    ["Base.BeerBottle"]                 = true,
    ["Base.BeerCan"]                    = true,
    ["Base.BeerCanEmpty"]               = true,
    ["Base.BeerEmpty"]                  = true,
    ["Base.BeerImported"]               = true,
    ["Base.Bleach"]                     = true,
    ["Base.BottleCrafted"]              = true,
    ["Base.Bowl"]                       = true,
    ["Base.Brandy"]                     = true,
    ["Base.Bucket"]                     = true,
    ["Base.BucketCarved"]               = true,
    ["Base.BucketEmpty"]                = true,
    ["Base.BucketForged"]               = true,
    ["Base.BucketWood"]                 = true,
    ["Base.Canteen"]                    = true,
    ["Base.CanteenClay"]                = true,
    ["Base.CanteenCowboy"]              = true,
    ["Base.CanteenMilitary"]            = true,
    ["Base.CanteenMilitaryFull"]        = true,
    ["Base.CeramicTeacup"]              = true,
    ["Base.CeramicCrucible"]            = true,
    ["Base.CeramicCrucibleSmall"]       = true,
    ["Base.Champagne"]                  = true,
    ["Base.Cider"]                      = true,
    ["Base.ClayBowl"]                   = true,
    ["Base.ClayJar"]                    = true,
    ["Base.ClayJarGlazed"]              = true,
    ["Base.ClayMug"]                    = true,
    ["Base.CleaningLiquid2"]            = true,
    ["Base.CoffeeLiquer"]               = true,
    ["Base.Curacao"]                    = true,
    ["Base.Disinfectant"]               = true,
    ["Base.DrinkingGlass"]              = true,
    ["Base.EmptyJar"]                   = true,
    ["Base.FeedingBottle"]              = true,
    ["Base.Flask"]                      = true,
    ["Base.FountainCup"]                = true,
    ["Base.FountainCupWater"]           = true,
    ["Base.Gin"]                        = true,
    ["Base.GlassChampagne"]             = true,
    ["Base.GlassTumbler"]               = true,
    ["Base.GlassWine"]                  = true,
    ["Base.Grenadine"]                  = true,
    ["Base.HotWaterBottle"]             = true,
    ["Base.JarCrafted"]                 = true,
    ["Base.JerryCan"]                   = true,
    ["Base.Kettle"]                     = true,
    ["Base.Kettle_Copper"]              = true,
    ["Base.MayonnaiseEmpty"]            = true,
    ["Base.MetalCup"]                   = true,
    ["Base.Mugl"]                       = true,
    ["Base.MugSpiffo"]                  = true,
    ["Base.MugWhite"]                   = true,
    ["Base.PaintbucketEmpty"]           = true,
    ["Base.PetrolCan"]                  = true,
    ["Base.PlasticCup"]                 = true,
    ["Base.Pop"]                        = true,
    ["Base.Pop2"]                       = true,
    ["Base.Pop2Empty"]                  = true,
    ["Base.Pop3"]                       = true,
    ["Base.Pop3Empty"]                  = true,
    ["Base.PopBottle"]                  = true,
    ["Base.PopBottleRare"]              = true,
    ["Base.PopEmpty"]                   = true,
    ["Base.Port"]                       = true,
    ["Base.Pot"]                        = true,
    ["Base.PotForged"]                  = true,
    ["Base.RemouladeEmpty"]             = true,
    ["Base.Rum"]                        = true,
    ["Base.Saucepan"]                   = true,
    ["Base.SaucepanCopper"]             = true,
    ["Base.Scotch"]                     = true,
    ["Base.Sherry"]                     = true,
    ["Base.Sportsbottle"]               = true,
    ["Base.Teacup"]                     = true,
    ["Base.Tequila"]                    = true,
    ["Base.TinCanEmpty"]                = true,
    ["Base.TrophyBronze"]               = true,
    ["Base.TrophyGold"]                 = true,
    ["Base.TrophySilver"]               = true,
    ["Base.Vermouth"]                   = true,
    ["Base.Vodka"]                      = true,
    ["Base.WaterBottle"]                = true,
    ["Base.WaterDispenserBottle"]       = true,
    ["Base.WaterDish"]                  = true,
    ["Base.WateredCan"]                 = true,
    ["Base.WaterRationCanEmpty"]        = true,
    ["Base.Whiskey"]                    = true,
    ["Base.Wine"]                       = true,
    ["Base.Wine2"]                      = true,
    ["Base.Wine2Open"]                  = true,
    ["Base.WineAged"]                   = true,
    ["Base.WineOpen"]                   = true,
    ["Base.WineScrewtop"]               = true,
}

local DAMNLIB_COMPATIBLE_CONTAINERS = {
    GASOLINE = {
        ["USMIL.GasCan0"] = true,
    },
    WATER = {
        ["USMIL.WaterCan0"] = true,
    },
    TAINTED_WATER = {
        ["USMIL.WaterCan0"] = true,
    },
}

local WATER_BIDON_COMPATIBLE_CONTAINERS = {
    ["WaterBidon.WaterBidon"]        = true,
    ["WaterBidon.WaterBidon_Blue"]   = true,
    ["WaterBidon.WaterBidon_Red"]    = true,
    ["WaterBidon.WaterBidon_Yellow"] = true,
    ["WaterBidon.WaterBidon_Orange"] = true,
    ["WaterBidon.WaterBidon_White"]  = true,
    ["WaterBidon.WaterBidon_Black"]  = true,
}

local function mergeContainerSets(baseContainers, extraContainers)
    local merged = {}

    for fullType, enabled in pairs(baseContainers) do
        merged[fullType] = enabled
    end

    if type(extraContainers) == "table" then
        for fullType, enabled in pairs(extraContainers) do
            merged[fullType] = enabled
        end
    end

    return merged
end

local function mergeMultipleContainerSets(...)
    local merged = {}
    local sets = { ... }

    for i = 1, #sets do
        local containers = sets[i]
        if type(containers) == "table" then
            for fullType, enabled in pairs(containers) do
                merged[fullType] = enabled
            end
        end
    end

    return merged
end

LiquidConfig.COMPATIBLE_CONTAINERS = {
    GASOLINE = mergeMultipleContainerSets(
        VANILLA_FLUID_COMPATIBLE_CONTAINERS,
        DAMNLIB_COMPATIBLE_CONTAINERS.GASOLINE,
        WATER_BIDON_COMPATIBLE_CONTAINERS
    ),
    WATER = mergeMultipleContainerSets(
        VANILLA_FLUID_COMPATIBLE_CONTAINERS,
        DAMNLIB_COMPATIBLE_CONTAINERS.WATER,
        WATER_BIDON_COMPATIBLE_CONTAINERS
    ),
    TAINTED_WATER = mergeMultipleContainerSets(
        VANILLA_FLUID_COMPATIBLE_CONTAINERS,
        DAMNLIB_COMPATIBLE_CONTAINERS.TAINTED_WATER,
        WATER_BIDON_COMPATIBLE_CONTAINERS
    ),
    BLEACH = mergeContainerSets(
        {
            ["Base.Bleach"]          = true,
            ["Base.CleaningLiquid2"] = true,
        },
        WATER_BIDON_COMPATIBLE_CONTAINERS
    ),
}

-----------------------------------
-- INVERSE INDEX: fullType -> {liquidTypes}
-- Built once at load time for O(1) lookup.
-----------------------------------
LiquidConfig.FULLTYPE_TO_LIQUIDS = {}

for liquidType, containers in pairs(LiquidConfig.COMPATIBLE_CONTAINERS) do
    for fullType, _ in pairs(containers) do
        if not LiquidConfig.FULLTYPE_TO_LIQUIDS[fullType] then
            LiquidConfig.FULLTYPE_TO_LIQUIDS[fullType] = {}
        end
        table.insert(LiquidConfig.FULLTYPE_TO_LIQUIDS[fullType], liquidType)
    end
end

return LiquidConfig
