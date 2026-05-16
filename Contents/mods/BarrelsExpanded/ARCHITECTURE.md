# BarrelsExpanded Architecture & Future Config Separation

## Current State (Phase 5-6)

All configuration constants are centralized in `BarrEx_Constant.lua` for backward compatibility, with actual config values delegated to specialized modules:

- `config/BarrEx_LiquidConfig.lua` - LIQUID_TYPE, compatible containers, weight multipliers
- `config/BarrEx_ToolConfig.lua` - required tools for interactions (open, pour, extract)
- `config/BarrEx_TransferConfig.lua` - transfer timing (ACTION_TIME_MULTIPLIER, tick intervals)

## Future Separation Plan (Post-Phase 6)

As the mod scales, the following configs should be extracted from `Constant.lua` and `BarrEx_BarrelData.lua` into dedicated modules:

### 1. BarrelConfig (NEW)

**Purpose**: Core barrel type definitions and capacity rules.

**Migration Path**:
- Move from `Constant.lua`: 
  - `BARREL_DEFAULT_CAPACITY`
  - `BARREL_EMPTY_WEIGHT`
- Move from `BarrEx_Barrel.lua`:
  - Constants defining barrel structure version and defaults
  
**Usage**: Clients needing to understand barrel capacity, weight, and schema versioning.

---

### 2. TileConfig (NEW)

**Purpose**: Sprite name ↔ barrel category mapping, tile-to-liquid distribution rules.

**Migration Path**:
- Move from `Constant.lua`:
  - `BARREL_TILE_NAME_TO_CATEGORY` - maps `industry_01_22` → `INDUSTRIAL`
  - `BARREL_TILE_CATEGORY` - enum of category names
  - `BARREL_LIQUID_DISTRIBUTION` - per-category spawn distributions

**Why separate**: These define world-building rules that may expand significantly as more tilesets are added. Separating them reduces `Constant.lua` clutter and makes it easier to add new barrel types without touching core logic.

**Usage**:
- `BarrEx_BarrelFactory.lua`: Selects category from sprite name, then uses distribution
- `BarrEx_WorldUtils.lua`: Resolves sprite → category mapping

---

### 3. SpawnConfig (NEW)

**Purpose**: Barrel generation profiles and spawn weighting rules.

**Migration Path**:
- Move from `Constant.lua`:
  - `BARREL_SPAWN_PROFILE` - enum of spawn sources (WORLD, PLAYER_CRAFTED)
  - `BARREL_DATA_POLL_TICKS` - tick interval for reconciliation

- Could later include:
  - Probability weights for empty vs. full barrels by location
  - Respawn rules for persistent worlds

**Why separate**: Spawn behavior is a self-contained system that may grow with new loot-generation features. Isolating it makes future changes cleaner.

**Usage**:
- `BarrEx_BarrelFactory.lua`: Checks spawn profile to determine initial distribution
- `BarrEx_BarrelWorldService.lua`: Uses BARREL_DATA_POLL_TICKS for reconciliation timing

---

## Benefits of Separation

1. **Single Responsibility**: Each config owns its domain (liquid types, barrel physical properties, world spawn rules).
2. **Testability**: Smaller, focused modules are easier to unit test and mock.
3. **Extensibility**: New contributors can extend TileConfig with new barrel sprites without modifying core logic.
4. **Maintainability**: Constants are organized by concern, not lumped into a single 300+ line file.
5. **Documentation**: Each config module documents the semantic meaning of its values (not just "numbers that work").

---

## Migration Checklist (Post-Phase 6)

- [ ] Create `config/BarrEx_BarrelConfig.lua` with capacity/weight/schema defaults
- [ ] Create `config/BarrEx_TileConfig.lua` with sprite mappings and distributions
- [ ] Create `config/BarrEx_SpawnConfig.lua` with profile enums and polling intervals
- [ ] Update `Constant.lua` to delegate to new modules (for backward compatibility)
- [ ] Update all consumers to import from specialized modules (gradual, not a breaking change)
- [ ] Add integration tests verifying each config module loads correctly
- [ ] Document in README which configs are "user-editable" vs. "internal"

---

## Notes

- **Backward Compatibility**: After separation, `Constant.lua` should continue to re-export values from the new config modules (e.g., `Constant.BARREL_TILE_CATEGORY = require("config/BarrEx_TileConfig").BARREL_TILE_CATEGORY`). This allows old code to continue working without changes.
- **No Implementation Yet**: This document describes the *future* state. Do not implement until Phase 6 is complete and the mod has stabilized.
- **User Customization**: Once configs are separated, consider exposing TileConfig and SpawnConfig to modders via a `Customize` folder (e.g., `Customize/BarrelsExpanded_TileConfig.lua`).
