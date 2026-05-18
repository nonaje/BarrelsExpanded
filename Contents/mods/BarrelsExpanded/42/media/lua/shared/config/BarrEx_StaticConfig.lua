local ConfigKeys = require("config/BarrEx_ConfigKeys")

local StaticConfig = {}

StaticConfig.LIQUID_TYPE = {
    EMPTY = "EMPTY",
    WATER = "WATER",
    TAINTED_WATER = "TAINTED_WATER",
    GASOLINE = "GASOLINE",
    BLEACH = "BLEACH",
}

StaticConfig.DEFAULT_OPEN_BARREL_REQUIRED_ITEMS_TEXT =
    "Base.Crowbar,Base.CrowbarForged,Base.Screwdriver,Base.PipeWrench,Base.SheetMetalSnips"

StaticConfig.VALUES = {
    [ConfigKeys.BARREL_DEFAULT_CAPACITY] = 160,
    [ConfigKeys.MAX_INTERACTION_DISTANCE] = 1.55,
    [ConfigKeys.OPEN_BARREL_ACTION_TIME] = 200,
    [ConfigKeys.BARREL_EMPTY_WEIGHT] = 20,
    [ConfigKeys.BARREL_DRINK_AMOUNT] = 0.12,
    [ConfigKeys.BARREL_DRINK_THIRST] = 0.10,
    [ConfigKeys.BARREL_WASH_UNIT_AMOUNT] = 1,

    [ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS] = {
        "Base.Crowbar",
        "Base.CrowbarForged",
        "Base.Screwdriver",
        "Base.PipeWrench",
        "Base.SheetMetalSnips",
    },
    [ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS_TEXT] = StaticConfig.DEFAULT_OPEN_BARREL_REQUIRED_ITEMS_TEXT,
    [ConfigKeys.REQUIRE_FUNNEL_TO_POUR] = true,
    [ConfigKeys.REQUIRE_HOSE_TO_EXTRACT] = true,
    [ConfigKeys.POUR_REQUIRED_ITEMS] = {
        "Base.Funnel",
    },
    [ConfigKeys.EXTRACT_REQUIRED_ITEMS] = {
        "Base.RubberHose",
    },

    [ConfigKeys.INDUSTRIAL_WEIGHT_EMPTY] = 40,
    [ConfigKeys.INDUSTRIAL_WEIGHT_WATER] = 15,
    [ConfigKeys.INDUSTRIAL_WEIGHT_TAINTED_WATER] = 20,
    [ConfigKeys.INDUSTRIAL_WEIGHT_GASOLINE] = 20,
    [ConfigKeys.INDUSTRIAL_WEIGHT_BLEACH] = 5,

    [ConfigKeys.MILITARY_WEIGHT_EMPTY] = 55,
    [ConfigKeys.MILITARY_WEIGHT_WATER] = 10,
    [ConfigKeys.MILITARY_WEIGHT_TAINTED_WATER] = 10,
    [ConfigKeys.MILITARY_WEIGHT_GASOLINE] = 25,
    [ConfigKeys.MILITARY_WEIGHT_BLEACH] = 0,

    [ConfigKeys.CRAFTED_WEIGHT_EMPTY] = 20,
    [ConfigKeys.CRAFTED_WEIGHT_WATER] = 30,
    [ConfigKeys.CRAFTED_WEIGHT_TAINTED_WATER] = 20,
    [ConfigKeys.CRAFTED_WEIGHT_GASOLINE] = 30,
    [ConfigKeys.CRAFTED_WEIGHT_BLEACH] = 0,

    [ConfigKeys.TRANSFER_ACTION_TIME_MULTIPLIER] = 2,
    [ConfigKeys.EMPTY_BARREL_ACTION_TIME_PER_UNIT] = 5,
    [ConfigKeys.SERVER_TRANSFER_TICK_INTERVAL] = 5,
    [ConfigKeys.SERVER_TRANSFER_SYNC_INTERVAL] = 10,
    [ConfigKeys.SERVER_TRANSFER_STALE_TICKS] = 300,
    [ConfigKeys.CLIENT_TRANSFER_PROGRESS_INTERVAL] = 5,
    [ConfigKeys.CLIENT_TRANSFER_PROGRESS_EPSILON] = 0.01,

    [ConfigKeys.ACTION_ACK_TIMEOUT_TICKS] = 240,
    [ConfigKeys.STATE_REQUEST_COOLDOWN_TICKS] = 60,
}

StaticConfig.METADATA = {
    [ConfigKeys.BARREL_DEFAULT_CAPACITY] = { sandbox = true, type = "integer", min = 20, max = 500 },
    [ConfigKeys.MAX_INTERACTION_DISTANCE] = { sandbox = true, type = "double", min = 0.5, max = 3.0 },
    [ConfigKeys.BARREL_EMPTY_WEIGHT] = { sandbox = true, type = "double", min = 0.0, max = 100.0 },

    [ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS_TEXT] = { sandbox = true, type = "string" },
    [ConfigKeys.REQUIRE_FUNNEL_TO_POUR] = { sandbox = true, type = "boolean" },
    [ConfigKeys.REQUIRE_HOSE_TO_EXTRACT] = { sandbox = true, type = "boolean" },

    [ConfigKeys.INDUSTRIAL_WEIGHT_EMPTY] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.INDUSTRIAL_WEIGHT_WATER] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.INDUSTRIAL_WEIGHT_TAINTED_WATER] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.INDUSTRIAL_WEIGHT_GASOLINE] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.INDUSTRIAL_WEIGHT_BLEACH] = { sandbox = true, type = "integer", min = 0, max = 1000 },

    [ConfigKeys.MILITARY_WEIGHT_EMPTY] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.MILITARY_WEIGHT_WATER] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.MILITARY_WEIGHT_TAINTED_WATER] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.MILITARY_WEIGHT_GASOLINE] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.MILITARY_WEIGHT_BLEACH] = { sandbox = true, type = "integer", min = 0, max = 1000 },

    [ConfigKeys.CRAFTED_WEIGHT_EMPTY] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.CRAFTED_WEIGHT_WATER] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.CRAFTED_WEIGHT_TAINTED_WATER] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.CRAFTED_WEIGHT_GASOLINE] = { sandbox = true, type = "integer", min = 0, max = 1000 },
    [ConfigKeys.CRAFTED_WEIGHT_BLEACH] = { sandbox = true, type = "integer", min = 0, max = 1000 },
}

function StaticConfig.get(key)
    return StaticConfig.VALUES[key]
end

function StaticConfig.getMetadata(key)
    return StaticConfig.METADATA[key]
end

return StaticConfig
