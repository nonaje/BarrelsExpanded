local ContextConfig = {}

ContextConfig.CONTEXT_MENU = {
    BARREL = "ContextMenu_BarrEx_Barrel",
    OPEN_BARREL = "ContextMenu_BarrEx_OpenBarrel",
    INFO = "ContextMenu_BarrEx_Info",
    REMOVE_THE_COVER = "ContextMenu_BarrEx_RemoveCover",
    POUR = "ContextMenu_BarrEx_Pour",
    EXTRACT = "ContextMenu_BarrEx_Extract",
}

ContextConfig.TOOLTIP = {
    REQUIRED = "Tooltip_BarrEx_Required",
    ONE_OF = "Tooltip_BarrEx_OneOf",
    BARREL_CONTENTS = "Tooltip_BarrEx_BarrelContents",
    LIQUID = "Tooltip_BarrEx_Liquid",
    AMOUNT = "Tooltip_BarrEx_Amount",
    WEIGHT = "Tooltip_BarrEx_Weight",
    TOO_FAR = "Tooltip_BarrEx_TooFar",
    REQUIRES_FUNNEL = "Tooltip_BarrEx_RequiresFunnel",
    REQUIRES_HOSE = "Tooltip_BarrEx_RequiresHose",
    BARREL_FULL = "Tooltip_BarrEx_BarrelFull",
    BARREL_EMPTY = "Tooltip_BarrEx_BarrelEmpty",
    BARREL_CLOSED = "Tooltip_BarrEx_BarrelClosed",
    INCOMPATIBLE_LIQUID = "Tooltip_BarrEx_IncompatibleLiquid",
    NO_COMPATIBLE_CONTAINER = "Tooltip_BarrEx_NoCompatibleContainer",
    FILL_LEVEL = "Tooltip_BarrEx_FillLevel",
    TRANSFER_AMOUNT = "Tooltip_BarrEx_TransferAmount",
    CONTAINER_CAPACITY = "Tooltip_BarrEx_ContainerCapacity",
}

ContextConfig.UI = {
    EMPTY = "UI_BarrEx_Empty",
    LIQUID_WATER = "UI_BarrEx_Liquid_WATER",
    LIQUID_TAINTED_WATER = "UI_BarrEx_Liquid_TAINTED_WATER",
    LIQUID_GASOLINE = "UI_BarrEx_Liquid_GASOLINE",
    LIQUID_BLEACH = "UI_BarrEx_Liquid_BLEACH",
}

return ContextConfig