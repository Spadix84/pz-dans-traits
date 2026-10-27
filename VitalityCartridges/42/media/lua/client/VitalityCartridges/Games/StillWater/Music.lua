-- Still Water: the tunes. Notes for the console's sound chip (SDK docs/04 and 14).
-- The pond plays on pulse 1 and the wave voice; the cues borrow pulse 2, so
-- they never cut the pond.

require "VitalityCartridges/Core"
require "SpiffBoy/Core/Tunes"

VitalityCartridges.StillWater = VitalityCartridges.StillWater or {}

local Music = {}
VitalityCartridges.StillWater.Music = Music

Music.POND = "pond"
Music.IN = "in"
Music.OUT = "out"
Music.HOLD = "hold"
Music.MOVE = "move"
Music.SELECT = "select"
Music.BLOOM = "bloom"

SpiffBoy.Tunes.register("StillWater", {
    -- the pond: slow, soft arpeggios over a held bass, a bar of four seconds
    [Music.POND] = {
        loop = true,
        pulse1 = "t60 @0 v4 y3 l4 o4"
            .. " c g e g | <a> e c e | f c <a> c | g d <b> d",
        wave = "t60 @12 v1 l1 o2 c <a> f g",
    },
    -- breathe in: two notes rising; breathe out: two falling; a hold: one soft note
    [Music.IN] = { pulse2 = "t120 @2 v6 y2 l8 o5 c e" },
    [Music.OUT] = { pulse2 = "t120 @2 v6 y2 l8 o5 e c" },
    [Music.HOLD] = { pulse2 = "t160 @2 v4 y2 l16 o5 g" },
    [Music.MOVE] = { pulse2 = "t200 @1 v5 y2 l32 o5 a" },
    [Music.SELECT] = { pulse2 = "t160 @1 v7 y2 l16 o5 e a" },
    -- a lily pad opens
    [Music.BLOOM] = { pulse2 = "t180 @1 v7 y2 l16 o5 c e g >c" },
})
