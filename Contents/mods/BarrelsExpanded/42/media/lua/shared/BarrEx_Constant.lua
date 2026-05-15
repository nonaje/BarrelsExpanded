local Constant = {}

Constant.MOD_ID = "BarrelsExpanded"
Constant.LOG_PREFIX = "[BarrelsExpanded]"

Constant.NETWORK = {
    MODULE = "BarrEx",
    OPEN_BARREL = "openBarrel"
}

Constant.MODDATA_KEYS = {
    BARREL = "BarrEx_Barrel",
    BARREL_WEIGHT = "BarrEx_Weight",
    BARREL_ID = "BarrEx_BarrelId",
    BARREL_SPAWN_PROFILE = "BarrEx_SpawnProfile",
}

-----------------------------------
------ CONTEXT MENU OPTIONS -------
-----------------------------------
Constant.CONTEXT_MENU = {
    BARREL = "ContextMenu_BarrEx_Barrel",
    OPEN_BARREL = "ContextMenu_BarrEx_OpenBarrel",
    INFO = "ContextMenu_BarrEx_Info",
    REMOVE_THE_COVER = "ContextMenu_BarrEx_RemoveCover"
}

Constant.TOOLTIP = {
    REQUIRED = "Tooltip_BarrEx_Required",
    ONE_OF = "Tooltip_BarrEx_OneOf",
    BARREL_CONTENTS = "Tooltip_BarrEx_BarrelContents",
    LIQUID = "Tooltip_BarrEx_Liquid",
    AMOUNT = "Tooltip_BarrEx_Amount",
    WEIGHT = "Tooltip_BarrEx_Weight",
    TOO_FAR = "Tooltip_BarrEx_TooFar"
}

Constant.UI = {
    EMPTY = "UI_BarrEx_Empty",
    LIQUID_WATER = "UI_BarrEx_Liquid_WATER",
    LIQUID_TAINTED_WATER = "UI_BarrEx_Liquid_TAINTED_WATER",
    LIQUID_GASOLINE = "UI_BarrEx_Liquid_GASOLINE",
    LIQUID_BLEACH = "UI_BarrEx_Liquid_BLEACH"
}

---------------------------------------
--- REQUIRED ITEMS FOR INTERACTIONS ---
---------------------------------------
Constant.OPEN_BARREL_REQUIRED_ITEMS = {
    "Base.Crowbar",
    "Base.CrowbarForged",
    "Base.Screwdriver",
    "Base.PipeWrench",
    "Base.SheetMetalSnips"
}

-----------------------------------
---- AVAILABLE LIQUID TYPES   -----
-----------------------------------
Constant.LIQUID_TYPE = {
    EMPTY = "EMPTY",
    WATER = "WATER",
    TAINTED_WATER = "TAINTED_WATER",
    GASOLINE = "GASOLINE",
    BLEACH = "BLEACH",
}

Constant.BARREL_DEFAULT_CAPACITY = 160
Constant.BARREL_DATA_POLL_TICKS = 120
Constant.MAX_INTERACTION_DISTANCE = 1.55
Constant.OPEN_BARREL_ACTION_TIME = 1

Constant.BARREL_EMPTY_WEIGHT = 20
Constant.BARREL_LIQUID_WEIGHT_PER_UNIT = {
    TAINTED_WATER = 1.0,
    WATER = 1.0,
    GASOLINE = 0.75,
    BLEACH = 1.1,
}

Constant.BARREL_SPAWN_PROFILE = {
    WORLD = "WORLD",
    PLAYER_CRAFTED = "PLAYER_CRAFTED",
}

Constant.BARREL_TILE_CATEGORY = {
    INDUSTRIAL = "INDUSTRIAL",
    MILITARY = "MILITARY",
    RURAL = "RURAL",
    CRAFTED = "CRAFTED",
}

Constant.BARREL_TILE_NAME_TO_CATEGORY = {
    industry_01_22 = Constant.BARREL_TILE_CATEGORY.INDUSTRIAL,
    industry_01_23 = Constant.BARREL_TILE_CATEGORY.INDUSTRIAL,

    location_military_generic_01_14 = Constant.BARREL_TILE_CATEGORY.MILITARY,
    location_military_generic_01_15 = Constant.BARREL_TILE_CATEGORY.MILITARY,

    location_military_generic_01_6 = Constant.BARREL_TILE_CATEGORY.MILITARY,
    location_military_generic_01_7 = Constant.BARREL_TILE_CATEGORY.MILITARY,

    crafted_01_32 = Constant.BARREL_TILE_CATEGORY.CRAFTED,
}

Constant.BARREL_LIQUID_DISTRIBUTION = {
    INDUSTRIAL = {
        [Constant.LIQUID_TYPE.EMPTY] = 40,
        [Constant.LIQUID_TYPE.WATER] = 15,
        [Constant.LIQUID_TYPE.TAINTED_WATER] = 20,
        [Constant.LIQUID_TYPE.GASOLINE] = 20,
        [Constant.LIQUID_TYPE.BLEACH] = 5,
    },
    MILITARY = {
        [Constant.LIQUID_TYPE.EMPTY] = 55,
        [Constant.LIQUID_TYPE.GASOLINE] = 25,
        [Constant.LIQUID_TYPE.WATER] = 10,
        [Constant.LIQUID_TYPE.TAINTED_WATER] = 10,
    },
    RURAL = {
        [Constant.LIQUID_TYPE.EMPTY] = 30,
        [Constant.LIQUID_TYPE.WATER] = 45,
        [Constant.LIQUID_TYPE.TAINTED_WATER] = 20,
        [Constant.LIQUID_TYPE.GASOLINE] = 3,
        [Constant.LIQUID_TYPE.BLEACH] = 2,
    },
    CRAFTED_WORLD = {
        [Constant.LIQUID_TYPE.GASOLINE] = 30,
        [Constant.LIQUID_TYPE.WATER] = 30,
        [Constant.LIQUID_TYPE.TAINTED_WATER] = 20,
        [Constant.LIQUID_TYPE.EMPTY] = 20,
        [Constant.LIQUID_TYPE.BLEACH] = 0,
    },
    CRAFTED_PLAYER = {
        [Constant.LIQUID_TYPE.EMPTY] = 100,
    },
}

-----------------------------------
-------- BARREL TILE NAMES --------
-----------------------------------
Constant.BARREL_TILE_NAMES = {
}

for tileName, _ in pairs(Constant.BARREL_TILE_NAME_TO_CATEGORY) do
    Constant.BARREL_TILE_NAMES[tileName] = true
end

return Constant
