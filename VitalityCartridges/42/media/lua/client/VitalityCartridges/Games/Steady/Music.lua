-- Steady: the tunes. Notes for the console's sound chip (SDK docs/04 and 14).
-- The title tune plays on pulse 1 and the wave voice, the round's on all but
-- pulse 2; the cues borrow pulse 2, so they never cut the music.

require "VitalityCartridges/Core"
require "SpiffBoy/Core/Tunes"

VitalityCartridges.Steady = VitalityCartridges.Steady or {}

local Music = {}
VitalityCartridges.Steady.Music = Music

Music.TITLE = "title"
Music.ROUND = "round"
Music.MOVE = "move"
Music.SELECT = "select"
Music.GO = "go"
Music.TICK = "tick"
Music.END = "end"
Music.BEST = "best"

SpiffBoy.Tunes.register("Steady", {
    -- the title: an even, walking line over a plain bass, four bars of four beats
    [Music.TITLE] = {
        loop = true,
        pulse1 = "t96 @1 v9 y2 l8 o5"
            .. " e r g r e r d r | c r d r e4 r4 | e r g r a r g r | e r d r c4 r4",
        wave = "t96 @11 v2 l4 o3 c g c g | <a> e <a> e | f c f c | g d g d",
    },
    -- the round: a held-breath pulse, a soft tick on every beat and a slow high line
    [Music.ROUND] = {
        loop = true,
        pulse1 = "t120 @0 v4 y3 l2 o5 e r | d r | c r | d r",
        wave = "t120 @5 v2 l4 o2 [c r]2 | [c r]2 | [f r]2 | [g r]2",
        noise = "t120 l8 [v5 y1 n32 r r r v3 y1 n32 r r r]4",
    },
    [Music.MOVE] = { pulse2 = "t240 @3 v6 y1 l32 o6 d" },
    [Music.SELECT] = { pulse2 = "t220 @2 v8 y1 l32 o5 d a >d" },
    -- the round starts; a second left on the clock (the last three)
    [Music.GO] = { pulse2 = "t180 @1 v9 y2 l16 o5 c >c" },
    [Music.TICK] = { pulse2 = "t200 @2 v6 y1 l32 o6 c" },
    -- the round is over; over with a new best
    [Music.END] = { pulse2 = "t160 @2 v8 y2 l16 o5 g e c" },
    [Music.BEST] = { pulse2 = "t180 @1 v9 y2 l16 o5 c e g >c e" },
})
