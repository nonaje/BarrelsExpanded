local Constant = {}

Constant.MOD_ID = "BarrelsExpanded"
Constant.LOG_PREFIX = "[BarrelsExpanded]"

Constant.NETWORK = {
    MODULE = "BarrEx",
    OPEN_BARREL = "openBarrel"
}

Constant.MODDATA_KEYS = {
    BARREL = "BarrEx_Barrel"
}

-----------------------------------
------ CONTEXT MENU OPTIONS -------
-----------------------------------
Constant.CONTEXT_MENU = {
    BARREL = "ContextMenu_BarrEx_Barrel",
    OPEN_BARREL = "ContextMenu_BarrEx_OpenBarrel",
    REMOVE_THE_COVER = "ContextMenu_BarrEx_RemoveCover"
}

Constant.TOOLTIP = {
    REQUIRED = "Tooltip_BarrEx_Required",
    ONE_OF = "Tooltip_BarrEx_OneOf",
    BARREL_CONTENTS = "Tooltip_BarrEx_BarrelContents",
    LIQUID = "Tooltip_BarrEx_Liquid",
    AMOUNT = "Tooltip_BarrEx_Amount",
    TOO_FAR = "Tooltip_BarrEx_TooFar"
}

Constant.UI = {
    EMPTY = "UI_BarrEx_Empty",
    LIQUID_FUEL = "UI_BarrEx_Liquid_FUEL",
    LIQUID_WATER = "UI_BarrEx_Liquid_WATER"
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
    FUEL    = "FUEL",
    WATER   = "WATER",
}

Constant.BARREL_DEFAULT_CAPACITY = 160
Constant.BARREL_DATA_POLL_TICKS = 120
Constant.MAX_INTERACTION_DISTANCE = 1.55


-----------------------------------
-------- BARREL TILE NAMES --------
-----------------------------------
Constant.BARREL_TILE_NAMES = {
    industry_01_22 = true,
    industry_01_23 = true,

    location_military_generic_01_14 = true,
    location_military_generic_01_15 = true,

    location_military_generic_01_6 = true,
    location_military_generic_01_7 = true,

    crafted_01_32 = true
}

return Constant
