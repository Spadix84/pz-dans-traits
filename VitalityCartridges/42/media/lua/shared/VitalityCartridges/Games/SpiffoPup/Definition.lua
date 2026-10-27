-- Spiffo Pup: registers the cartridge with the console. Shared: the server
-- reads it for the loot, the client for the game, its art and its texts.
require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    api = 1,
    id = "SpiffoPup",
    item = "VitalityCartridges.Cartridge_SpiffoPup",
    title = "Spiffo Pup",
    mod = VitalityCartridges.MOD_ID,
    game = "VitalityCartridgesSpiffoPupGame",
    art = "media/ui/VitalityCartridges/Games/SpiffoPup/",
    texts = "media/lua/shared/VitalityCartridges/Games/SpiffoPup/Translate/",
    -- half as common as SpiffBoy's own cartridges (2)
    loot = { weight = 1 },
})
