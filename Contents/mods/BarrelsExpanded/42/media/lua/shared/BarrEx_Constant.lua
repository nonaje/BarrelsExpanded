local Constant = {}

-----------------------------------
------ CONTEXT MENU OPTIONS -------
-----------------------------------
Constant.REMOVE_THE_COVER = "Destapar"
Constant.OPEN_BARREL = "Abrir"
Constant.BARREL = "Barril"

---------------------------------------
--- REQUIRED ITEMS FOR INTERACTIONS ---
---------------------------------------
Constant.AVAILABLE_ITEMS_FOR_OPENING_BARREL = {
    "Base.Crowbar",
    "Base.CrowbarForged",
    "Base.Screwdriver",
    "Base.PipeWrench",
    "Base.SheetMetalSnips"
}


-----------------------------------
-------- BARREL TILE NAMES --------
-----------------------------------
Constant.ORANGE_BARREL_NORTH_FACE_TILE_NAME = 'industry_01_22'
Constant.ORANGE_BARREL_SOUTH_FACE_TILE_NAME = 'industry_01_23'

Constant.DARK_GREEN_BARREL_NORTH_FACE_TILE_NAME = 'location_military_generic_01_14'
Constant.DARK_GREEN_BARREL_SOUTH_FACE_TILE_NAME = 'location_military_generic_01_15'

Constant.LIGHT_GREEN_BARREL_NORTH_FACE_TILE_NAME = 'location_military_generic_01_6'
Constant.LIGHT_GREEN_BARREL_SOUTH_FACE_TILE_NAME = 'location_military_generic_01_7'

Constant.GRAY_BARREL_TILE_NAME = 'crafted_01_32'

Constant.BARREL_TILE_NAMES = {
    [Constant.ORANGE_BARREL_NORTH_FACE_TILE_NAME]       = true,
    [Constant.ORANGE_BARREL_SOUTH_FACE_TILE_NAME]       = true,
    [Constant.DARK_GREEN_BARREL_NORTH_FACE_TILE_NAME]   = true,
    [Constant.DARK_GREEN_BARREL_SOUTH_FACE_TILE_NAME]   = true,
    [Constant.LIGHT_GREEN_BARREL_NORTH_FACE_TILE_NAME]  = true,
    [Constant.LIGHT_GREEN_BARREL_SOUTH_FACE_TILE_NAME]  = true,
    [Constant.GRAY_BARREL_TILE_NAME]                    = true
}

return Constant