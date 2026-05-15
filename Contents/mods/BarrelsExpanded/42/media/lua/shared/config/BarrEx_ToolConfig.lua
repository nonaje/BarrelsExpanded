-- BarrEx_ToolConfig: required items for each barrel interaction.
--
-- Separating tool requirements from general constants lets us extend
-- interaction rules (degradation, alternatives, barrel-type restrictions,
-- Sandbox overrides) without touching BarrEx_Constant or game logic.

local ToolConfig = {}

-- Items required to open a sealed barrel (at least one must be present).
ToolConfig.OPEN_BARREL_REQUIRED_ITEMS = {
    "Base.Crowbar",
    "Base.CrowbarForged",
    "Base.Screwdriver",
    "Base.PipeWrench",
    "Base.SheetMetalSnips",
}

-- Items required to pour liquid into a barrel (at least one must be present).
ToolConfig.POUR_REQUIRED_ITEMS = {
    "Base.Funnel",
}

-- Items required to extract liquid from a barrel (at least one must be present).
ToolConfig.EXTRACT_REQUIRED_ITEMS = {
    "Base.RubberHose",
}

return ToolConfig
