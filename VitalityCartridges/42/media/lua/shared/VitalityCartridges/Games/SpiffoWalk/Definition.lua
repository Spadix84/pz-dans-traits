-- Spiffo Walk: registers the cartridge with the console. Shared: the server
-- reads it for the loot, the client for the game, its art and its texts.
require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    api = 1,
    id = "SpiffoWalk",
    item = "VitalityCartridges.Cartridge_SpiffoWalk",
    title = "Spiffo Walk",
    mod = VitalityCartridges.MOD_ID,
    game = "VitalityCartridgesSpiffoWalkGame",
    art = "media/ui/VitalityCartridges/Games/SpiffoWalk/",
    texts = "media/lua/shared/VitalityCartridges/Games/SpiffoWalk/Translate/",
    -- half as common as SpiffBoy's own cartridges (2)
    loot = { weight = 1 },
})
