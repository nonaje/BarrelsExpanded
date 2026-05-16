local LiquidConfig   = require("config/BarrEx_LiquidConfig")
local ToolConfig     = require("config/BarrEx_ToolConfig")
local TransferConfig = require("config/BarrEx_TransferConfig")
local LogConfig      = require("config/BarrEx_LogConfig")

local Constant = {}

Constant.MOD_ID = "BarrelsExpanded"
Constant.LOG_PREFIX = LogConfig.LOG_PREFIX
Constant.DEBUG = LogConfig.DEBUG
Constant.LOG_LEVEL = LogConfig.LOG_LEVEL

Constant.NETWORK = {
    MODULE = "BarrEx",
    OPEN_BARREL = "openBarrel",
    START_POUR_INTO_BARREL = "startPourIntoBarrel",
    STOP_POUR_INTO_BARREL = "stopPourIntoBarrel",
    COMPLETE_POUR_INTO_BARREL = "completePourIntoBarrel",
    START_EXTRACT_FROM_BARREL = "startExtractFromBarrel",
    STOP_EXTRACT_FROM_BARREL = "stopExtractFromBarrel",
    COMPLETE_EXTRACT_FROM_BARREL = "completeExtractFromBarrel",
    UPDATE_TRANSFER_PROGRESS = "updateTransferProgress",
    TRANSFER_REJECTED = "transferRejected",
    TRANSFER_STARTED = "transferStarted",
    TRANSFER_PROGRESS = "transferProgress",
    DRINK_FROM_BARREL = "drinkFromBarrel",
    WASH_FROM_BARREL = "washFromBarrel",
    EMPTY_BARREL = "emptyBarrel",
    BARREL_USE_COMPLETED = "barrelUseCompleted",
}

Constant.MODDATA_KEYS = {
    BARREL = "BarrEx_Barrel",
    BARREL_WEIGHT = "BarrEx_Weight",
    BARREL_ID = "BarrEx_BarrelId",
    BARREL_SPAWN_PROFILE = "BarrEx_SpawnProfile",
}

---------------------------------------
--- REQUIRED ITEMS FOR INTERACTIONS ---
---------------------------------------
-- Delegated to ToolConfig.
Constant.OPEN_BARREL_REQUIRED_ITEMS = ToolConfig.OPEN_BARREL_REQUIRED_ITEMS
Constant.POUR_REQUIRED_ITEMS        = ToolConfig.POUR_REQUIRED_ITEMS
Constant.EXTRACT_REQUIRED_ITEMS     = ToolConfig.EXTRACT_REQUIRED_ITEMS

-----------------------------------
---- AVAILABLE LIQUID TYPES   -----
-----------------------------------
-- Delegated to LiquidConfig.
Constant.LIQUID_TYPE                  = LiquidConfig.LIQUID_TYPE
Constant.COMPATIBLE_CONTAINERS        = LiquidConfig.COMPATIBLE_CONTAINERS
Constant.FULLTYPE_TO_LIQUIDS          = LiquidConfig.FULLTYPE_TO_LIQUIDS
Constant.BARREL_LIQUID_WEIGHT_PER_UNIT = LiquidConfig.BARREL_LIQUID_WEIGHT_PER_UNIT

Constant.BARREL_DEFAULT_CAPACITY   = 160
Constant.BARREL_DATA_POLL_TICKS    = 120
Constant.MAX_INTERACTION_DISTANCE  = 1.55
Constant.OPEN_BARREL_ACTION_TIME   = 200
Constant.BARREL_EMPTY_WEIGHT       = 20
Constant.BARREL_DRINK_AMOUNT       = 0.12
Constant.BARREL_DRINK_THIRST       = 0.10
Constant.BARREL_WASH_UNIT_AMOUNT   = 1

-- Delegated to TransferConfig.
Constant.TRANSFER_ACTION_TIME_MULTIPLIER = TransferConfig.ACTION_TIME_MULTIPLIER
Constant.SERVER_TRANSFER_TICK_INTERVAL   = TransferConfig.SERVER_TICK_INTERVAL
Constant.SERVER_TRANSFER_SYNC_INTERVAL   = TransferConfig.SERVER_SYNC_INTERVAL
Constant.SERVER_TRANSFER_STALE_TICKS     = TransferConfig.SERVER_TRANSFER_STALE_TICKS
Constant.CLIENT_TRANSFER_PROGRESS_INTERVAL = TransferConfig.CLIENT_PROGRESS_SYNC_INTERVAL
Constant.CLIENT_TRANSFER_PROGRESS_EPSILON  = TransferConfig.CLIENT_PROGRESS_SYNC_EPSILON

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
