-- First Aid Quiz: registers the cartridge with the console. Shared: the server
-- reads it for the loot, the client for the game, its art and its texts.
require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    api = 1,
    id = "FirstAidQuiz",
    item = "VitalityCartridges.Cartridge_FirstAidQuiz",
    title = "First Aid Quiz",
    mod = VitalityCartridges.MOD_ID,
    game = "VitalityCartridgesFirstAidQuizGame",
    art = "media/ui/VitalityCartridges/Games/FirstAidQuiz/",
    texts = "media/lua/shared/VitalityCartridges/Games/FirstAidQuiz/Translate/",
    -- half as common as SpiffBoy's own cartridges (2)
    loot = { weight = 1 },
})
