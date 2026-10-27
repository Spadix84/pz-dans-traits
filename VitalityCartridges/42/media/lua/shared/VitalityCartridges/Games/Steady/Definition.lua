-- Steady: registers the cartridge with the console. Shared: the server
-- reads it for the loot, the client for the game, its art and its texts.
require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    api = 1,
    id = "Steady",
    item = "VitalityCartridges.Cartridge_Steady",
    title = "Steady",
    mod = VitalityCartridges.MOD_ID,
    game = "VitalityCartridgesSteadyGame",
    art = "media/ui/VitalityCartridges/Games/Steady/",
    texts = "media/lua/shared/VitalityCartridges/Games/Steady/Translate/",
    -- half as common as SpiffBoy's own cartridges (2)
    loot = { weight = 1 },
})
