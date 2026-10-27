-- Still Water: registers the cartridge with the console. Shared: the server
-- reads it for the loot, the client for the game, its art and its texts.
require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    api = 1,
    id = "StillWater",
    item = "VitalityCartridges.Cartridge_StillWater",
    title = "Still Water",
    mod = VitalityCartridges.MOD_ID,
    game = "VitalityCartridgesStillWaterGame",
    art = "media/ui/VitalityCartridges/Games/StillWater/",
    texts = "media/lua/shared/VitalityCartridges/Games/StillWater/Translate/",
    -- half as common as SpiffBoy's own cartridges (2)
    loot = { weight = 1 },
})
