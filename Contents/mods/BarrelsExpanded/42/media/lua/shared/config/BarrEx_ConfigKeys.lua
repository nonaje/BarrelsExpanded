-- BarrEx_ConfigKeys: canonical keys shared by static config and SandboxVars.

local ConfigKeys = {}

ConfigKeys.SANDBOX_NAMESPACE = "BarrelsExpanded"
ConfigKeys.SANDBOX_PAGE = "BarrelsExpanded"

ConfigKeys.BARREL_DEFAULT_CAPACITY = "BarrelDefaultCapacity"
ConfigKeys.MAX_INTERACTION_DISTANCE = "MaxInteractionDistance"
ConfigKeys.OPEN_BARREL_ACTION_TIME = "OpenBarrelActionTime"
ConfigKeys.BARREL_EMPTY_WEIGHT = "BarrelEmptyWeight"
ConfigKeys.BARREL_DRINK_AMOUNT = "BarrelDrinkAmount"
ConfigKeys.BARREL_DRINK_THIRST = "BarrelDrinkThirst"
ConfigKeys.BARREL_WASH_UNIT_AMOUNT = "BarrelWashUnitAmount"

ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS = "OpenBarrelRequiredItems"
ConfigKeys.OPEN_BARREL_REQUIRED_ITEMS_TEXT = "OpenBarrelRequiredItemsText"
ConfigKeys.REQUIRE_FUNNEL_TO_POUR = "RequireFunnelToPour"
ConfigKeys.REQUIRE_HOSE_TO_EXTRACT = "RequireHoseToExtract"
ConfigKeys.POUR_REQUIRED_ITEMS = "PourRequiredItems"
ConfigKeys.EXTRACT_REQUIRED_ITEMS = "ExtractRequiredItems"

ConfigKeys.INDUSTRIAL_WEIGHT_EMPTY = "IndustrialWeightEmpty"
ConfigKeys.INDUSTRIAL_WEIGHT_WATER = "IndustrialWeightWater"
ConfigKeys.INDUSTRIAL_WEIGHT_TAINTED_WATER = "IndustrialWeightTaintedWater"
ConfigKeys.INDUSTRIAL_WEIGHT_GASOLINE = "IndustrialWeightGasoline"
ConfigKeys.INDUSTRIAL_WEIGHT_BLEACH = "IndustrialWeightBleach"

ConfigKeys.MILITARY_WEIGHT_EMPTY = "MilitaryWeightEmpty"
ConfigKeys.MILITARY_WEIGHT_WATER = "MilitaryWeightWater"
ConfigKeys.MILITARY_WEIGHT_TAINTED_WATER = "MilitaryWeightTaintedWater"
ConfigKeys.MILITARY_WEIGHT_GASOLINE = "MilitaryWeightGasoline"
ConfigKeys.MILITARY_WEIGHT_BLEACH = "MilitaryWeightBleach"

ConfigKeys.CRAFTED_WEIGHT_EMPTY = "CraftedWeightEmpty"
ConfigKeys.CRAFTED_WEIGHT_WATER = "CraftedWeightWater"
ConfigKeys.CRAFTED_WEIGHT_TAINTED_WATER = "CraftedWeightTaintedWater"
ConfigKeys.CRAFTED_WEIGHT_GASOLINE = "CraftedWeightGasoline"
ConfigKeys.CRAFTED_WEIGHT_BLEACH = "CraftedWeightBleach"

ConfigKeys.TRANSFER_ACTION_TIME_MULTIPLIER = "TransferActionTimeMultiplier"
ConfigKeys.EMPTY_BARREL_ACTION_TIME_PER_UNIT = "EmptyBarrelActionTimePerUnit"
ConfigKeys.SERVER_TRANSFER_TICK_INTERVAL = "ServerTransferTickInterval"
ConfigKeys.SERVER_TRANSFER_SYNC_INTERVAL = "ServerTransferSyncInterval"
ConfigKeys.SERVER_TRANSFER_STALE_TICKS = "ServerTransferStaleTicks"
ConfigKeys.CLIENT_TRANSFER_PROGRESS_INTERVAL = "ClientTransferProgressInterval"
ConfigKeys.CLIENT_TRANSFER_PROGRESS_EPSILON = "ClientTransferProgressEpsilon"

ConfigKeys.ACTION_ACK_TIMEOUT_TICKS = "ActionAckTimeoutTicks"
ConfigKeys.STATE_REQUEST_COOLDOWN_TICKS = "StateRequestCooldownTicks"

function ConfigKeys.getSandboxOptionName(key)
    return ConfigKeys.SANDBOX_NAMESPACE .. "." .. tostring(key)
end

return ConfigKeys
