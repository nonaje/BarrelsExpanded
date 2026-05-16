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
LiquidConfig.COMPATIBLE_CONTAINERS = {
    GASOLINE = {
        ["Base.PetrolCan"]  = true,
        ["Base.GasCan"]     = true,
        ["Base.JerryCan"]   = true,
    },
    WATER = {
        ["Base.WaterDispenserBottle"] = true,
        ["Base.WaterBottle"]          = true,
        ["Base.WaterBottleEmpty"]     = true,
        ["Base.WaterBottleFull"]      = true,
        ["Base.BottleCrafted"]        = true,
        ["Base.EmptyJar"]             = true,
        ["Base.JarCrafted"]           = true,
        ["Base.Pot"]                  = true,
        ["Base.PotForged"]            = true,
        ["Base.Bucket"]               = true,
        ["Base.BucketEmpty"]          = true,
        ["Base.BucketWaterFull"]      = true,
        ["Base.PaintbucketEmpty"]     = true,
        ["Base.WateredCan"]           = true,
        ["Base.Kettle"]               = true,
        ["Base.Kettle_Copper"]        = true,
        ["Base.Saucepan"]             = true,
        ["Base.SaucepanCopper"]       = true,
        ["Base.MugWhite"]             = true,
        ["Base.Mugl"]                 = true,
        ["Base.MugSpiffo"]            = true,
        ["Base.Teacup"]               = true,
        ["Base.Canteen"]              = true,
        ["Base.CanteenClay"]          = true,
        ["Base.CanteenMilitary"]      = true,
        ["Base.Sportsbottle"]         = true,
        ["Base.HotWaterBottle"]       = true,
        ["Base.FeedingBottle"]        = true,
    },
    TAINTED_WATER = {
        ["Base.WaterDispenserBottle"] = true,
        ["Base.WaterBottle"]          = true,
        ["Base.WaterBottleEmpty"]     = true,
        ["Base.WaterBottleFull"]      = true,
        ["Base.BottleCrafted"]        = true,
        ["Base.EmptyJar"]             = true,
        ["Base.JarCrafted"]           = true,
        ["Base.Pot"]                  = true,
        ["Base.PotForged"]            = true,
        ["Base.Bucket"]               = true,
        ["Base.BucketEmpty"]          = true,
        ["Base.BucketWaterFull"]      = true,
        ["Base.PaintbucketEmpty"]     = true,
        ["Base.WateredCan"]           = true,
        ["Base.Kettle"]               = true,
        ["Base.Kettle_Copper"]        = true,
        ["Base.Saucepan"]             = true,
        ["Base.SaucepanCopper"]       = true,
        ["Base.MugWhite"]             = true,
        ["Base.Mugl"]                 = true,
        ["Base.MugSpiffo"]            = true,
        ["Base.Teacup"]               = true,
        ["Base.Canteen"]              = true,
        ["Base.CanteenClay"]          = true,
        ["Base.CanteenMilitary"]      = true,
        ["Base.Sportsbottle"]         = true,
        ["Base.HotWaterBottle"]       = true,
        ["Base.FeedingBottle"]        = true,
    },
    BLEACH = {
        ["Base.Bleach"]          = true,
        ["Base.BleachEmpty"]     = true,
        ["Base.CleaningLiquid2"] = true,
    },
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
