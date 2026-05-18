-- BarrEx_ToolConfig: required items for each barrel interaction.
--
-- Separating tool requirements from general constants lets us extend
-- interaction rules (degradation, alternatives, barrel-type restrictions,
-- Sandbox overrides) without touching BarrEx_Constant or game logic.

local ConfigRepository = require("config/BarrEx_ConfigRepository")

local ToolConfig = {}

-- Items required to open a sealed barrel (at least one must be present).
ToolConfig.OPEN_BARREL_REQUIRED_ITEMS = ConfigRepository.getOpenBarrelRequiredItems()

-- Items required to pour liquid into a barrel (at least one must be present).
ToolConfig.POUR_REQUIRED_ITEMS = ConfigRepository.getPourRequiredItems()

-- Items required to extract liquid from a barrel (at least one must be present).
ToolConfig.EXTRACT_REQUIRED_ITEMS = ConfigRepository.getExtractRequiredItems()

return ToolConfig
