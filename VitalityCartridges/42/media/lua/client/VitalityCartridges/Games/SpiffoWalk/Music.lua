-- Spiffo Walk: the tunes. Notes for the console's sound chip (SDK docs/04 and 14).
-- The stroll plays on pulse 1 and the wave voice, softly, as it plays on in the
-- pocket; the cues borrow pulse 2, so they never cut the stroll.

require "VitalityCartridges/Core"
require "SpiffBoy/Core/Tunes"

VitalityCartridges.SpiffoWalk = VitalityCartridges.SpiffoWalk or {}

local Music = {}
VitalityCartridges.SpiffoWalk.Music = Music

Music.STROLL = "stroll"
Music.PAT = "pat"
Music.HATCH = "hatch"
Music.GROW = "grow"
Music.TREASURE = "treasure"
Music.GOAL = "goal"
Music.MOVE = "move"
Music.SELECT = "select"
Music.NOPE = "nope"

SpiffBoy.Tunes.register("SpiffoWalk", {
    -- the stroll: an easy walking tune over a plodding bass, four bars of four beats
    [Music.STROLL] = {
        loop = true,
        pulse1 = "t104 @1 v5 y2 q6 l8 o5"
            .. " c4 e g e4 d c | d4 f a f4 e d | e4 g >c< g4 f e | d c <b> d c2",
        wave = "t104 @11 v1 l4 o3 c g c g | <b> g <b> g | c g c g | g d c2",
    },
    -- a pat: a little chirp
    [Music.PAT] = { pulse2 = "t220 @2 v7 y1 l32 o6 c e" },
    -- the egg hatches: a rising run
    [Music.HATCH] = { pulse2 = "t200 @1 v8 y2 l16 o5 c d e g >c e g4" },
    -- a new stage
    [Music.GROW] = { pulse2 = "t180 @1 v8 y2 l16 o5 e g >c< g >e4" },
    -- a hat found
    [Music.TREASURE] = { pulse2 = "t220 @2 v8 y1 l32 o6 c e g >c8" },
    -- today's goal met: a small fanfare
    [Music.GOAL] = { pulse2 = "t180 @1 v8 y2 l16 o5 g g g >c8 <g >c4" },
    [Music.MOVE] = { pulse2 = "t240 @3 v6 y1 l32 o6 c" },
    [Music.SELECT] = { pulse2 = "t220 @2 v8 y1 l32 o5 c g >c" },
    [Music.NOPE] = { pulse2 = "t200 @3 v7 y2 l16 o4 c <g" },
})
