local LiquidConfig   = require("config/BarrEx_LiquidConfig")
local ToolConfig     = require("config/BarrEx_ToolConfig")
local TransferConfig = require("config/BarrEx_TransferConfig")
local LogConfig      = require("config/BarrEx_LogConfig")
local NetworkConfig  = require("config/BarrEx_NetworkConfig")
local ConfigKeys     = require("config/BarrEx_ConfigKeys")
local ConfigRepository = require("config/BarrEx_ConfigRepository")

local Constant = {}

Constant.MOD_ID = "BarrelsExpanded"
Constant.LOG_PREFIX = LogConfig.LOG_PREFIX
Constant.DEBUG = LogConfig.DEBUG
Constant.LOG_LEVEL = LogConfig.LOG_LEVEL

Constant.NETWORK = {
    MODULE = "BarrEx",
    OPEN_BARREL = "openBarrel",
    START_OPEN_BARREL = "startOpenBarrel",
    CANCEL_OPEN_BARREL = "cancelOpenBarrel",
    COMPLETE_OPEN_BARREL = "completeOpenBarrel",
    START_POUR_INTO_BARREL = "startPourIntoBarrel",
    STOP_POUR_INTO_BARREL = "stopPourIntoBarrel",
    COMPLETE_POUR_INTO_BARREL = "completePourIntoBarrel",
    START_EXTRACT_FROM_BARREL = "startExtractFromBarrel",
    STOP_EXTRACT_FROM_BARREL = "stopExtractFromBarrel",
    COMPLETE_EXTRACT_FROM_BARREL = "completeExtractFromBarrel",
    UPDATE_TRANSFER_PROGRESS = "updateTransferProgress",
    START_EMPTY_BARREL = "startEmptyBarrel",
    STOP_EMPTY_BARREL = "stopEmptyBarrel",
    COMPLETE_EMPTY_BARREL = "completeEmptyBarrel",
    UPDATE_EMPTY_BARREL_PROGRESS = "updateEmptyBarrelProgress",
    START_ENDPOINT_TRANSFER = "startEndpointTransfer",
    STOP_ENDPOINT_TRANSFER = "stopEndpointTransfer",
    COMPLETE_ENDPOINT_TRANSFER = "completeEndpointTransfer",
    TRANSFER_REJECTED = "transferRejected",
    TRANSFER_STARTED = "transferStarted",
    TRANSFER_PROGRESS = "transferProgress",
    DRINK_FROM_BARREL = "drinkFromBarrel",
    WASH_FROM_BARREL = "washFromBarrel",
    EMPTY_BARREL = "emptyBarrel",
    ADMIN_BARREL_ACTION = "adminBarrelAction",
    REQUEST_BARREL_STATE = "requestBarrelState",
    BARREL_STATE = "barrelState",
    BARREL_ACTION_RESULT = "barrelActionResult",
}

Constant.ADMIN_BARREL_OPERATION = {
    INSPECT = "inspect",
    REPAIR = "repair",
    REVEAL = "reveal",
    EMPTY = "empty",
    SET_LIQUID = "set_liquid",
    REROLL = "reroll",
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

Constant.BARREL_DEFAULT_CAPACITY   = ConfigRepository.getInteger(ConfigKeys.BARREL_DEFAULT_CAPACITY)
Constant.MAX_INTERACTION_DISTANCE  = ConfigRepository.getNumber(ConfigKeys.MAX_INTERACTION_DISTANCE)
Constant.OPEN_BARREL_ACTION_TIME   = ConfigRepository.getInteger(ConfigKeys.OPEN_BARREL_ACTION_TIME)
Constant.BARREL_EMPTY_WEIGHT       = ConfigRepository.getNumber(ConfigKeys.BARREL_EMPTY_WEIGHT)
Constant.BARREL_DRINK_AMOUNT       = ConfigRepository.getNumber(ConfigKeys.BARREL_DRINK_AMOUNT)
Constant.BARREL_DRINK_THIRST       = ConfigRepository.getNumber(ConfigKeys.BARREL_DRINK_THIRST)
Constant.BARREL_WASH_UNIT_AMOUNT   = ConfigRepository.getNumber(ConfigKeys.BARREL_WASH_UNIT_AMOUNT)

-- Delegated to TransferConfig.
Constant.TRANSFER_ACTION_TIME_MULTIPLIER = TransferConfig.ACTION_TIME_MULTIPLIER
Constant.EMPTY_BARREL_ACTION_TIME_PER_UNIT = TransferConfig.EMPTY_ACTION_TIME_PER_UNIT
Constant.SERVER_TRANSFER_TICK_INTERVAL   = TransferConfig.SERVER_TICK_INTERVAL
Constant.SERVER_TRANSFER_SYNC_INTERVAL   = TransferConfig.SERVER_SYNC_INTERVAL
Constant.SERVER_TRANSFER_STALE_TICKS     = TransferConfig.SERVER_TRANSFER_STALE_TICKS
Constant.CLIENT_TRANSFER_PROGRESS_INTERVAL = TransferConfig.CLIENT_PROGRESS_SYNC_INTERVAL
Constant.CLIENT_TRANSFER_PROGRESS_EPSILON  = TransferConfig.CLIENT_PROGRESS_SYNC_EPSILON
Constant.ACTION_ACK_TIMEOUT_TICKS          = NetworkConfig.ACTION_ACK_TIMEOUT_TICKS
Constant.STATE_REQUEST_COOLDOWN_TICKS      = NetworkConfig.STATE_REQUEST_COOLDOWN_TICKS

Constant.BARREL_SPAWN_PROFILE = {
    WORLD = "WORLD",
    PLAYER_CRAFTED = "PLAYER_CRAFTED",
}

Constant.BARREL_TILE_CATEGORY = {
    INDUSTRIAL = "INDUSTRIAL",
    MILITARY = "MILITARY",
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

Constant.BARREL_TILE_NAME_TO_ICON_TILE_NAME = {
    industry_01_23 = "industry_01_22",
    location_military_generic_01_15 = "location_military_generic_01_14",
    location_military_generic_01_7 = "location_military_generic_01_6",
}

Constant.BARREL_LIQUID_DISTRIBUTION = {
    INDUSTRIAL = ConfigRepository.getLiquidDistribution("INDUSTRIAL", Constant.BARREL_SPAWN_PROFILE.WORLD),
    MILITARY = ConfigRepository.getLiquidDistribution("MILITARY", Constant.BARREL_SPAWN_PROFILE.WORLD),
    CRAFTED_WORLD = ConfigRepository.getLiquidDistribution("CRAFTED", Constant.BARREL_SPAWN_PROFILE.WORLD),
    CRAFTED_PLAYER = ConfigRepository.getLiquidDistribution("CRAFTED", Constant.BARREL_SPAWN_PROFILE.PLAYER_CRAFTED),
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
