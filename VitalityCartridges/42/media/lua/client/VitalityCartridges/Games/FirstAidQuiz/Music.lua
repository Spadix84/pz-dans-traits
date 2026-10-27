-- First Aid Quiz: the tunes. Notes for the console's sound chip (SDK docs/04 and 14).
-- The theme plays on pulse 1 and the wave voice, quiet enough to think over;
-- the cues borrow pulse 2, so they never cut the theme.

require "VitalityCartridges/Core"
require "SpiffBoy/Core/Tunes"

VitalityCartridges.FirstAidQuiz = VitalityCartridges.FirstAidQuiz or {}

local Music = {}
VitalityCartridges.FirstAidQuiz.Music = Music

Music.THEME = "theme"
Music.MOVE = "move"
Music.SELECT = "select"
Music.RIGHT = "right"
Music.WRONG = "wrong"
Music.DONE = "done"
Music.PERFECT = "perfect"

SpiffBoy.Tunes.register("FirstAidQuiz", {
    -- the waiting room: a light tune in F over a walking bass, four bars
    [Music.THEME] = {
        loop = true,
        pulse1 = "t100 @1 v6 y0 q5 l8 o5"
            .. " c4 a f c4 f a | g4 e c <b-4> c e | f4 a >c< b- a g f | e4 g e c2",
        wave = "t100 @11 v2 l4 o3 f c a c | c <g> e <g> | f c d <b-> | c e c2",
    },
    [Music.MOVE] = { pulse2 = "t240 @3 v6 y1 l32 o6 c" },
    [Music.SELECT] = { pulse2 = "t220 @2 v8 y1 l32 o5 c g >c" },
    -- a right answer: a bright rising pair; a wrong one: a low buzz falling
    [Music.RIGHT] = { pulse2 = "t200 @2 v9 y2 l16 o5 e >c8" },
    [Music.WRONG] = { pulse2 = "t160 @3 v8 y2 l16 o3 e- c8" },
    -- the round over, and a perfect round
    [Music.DONE] = { pulse2 = "t180 @1 v8 y2 l16 o5 c e g e c8" },
    [Music.PERFECT] = { pulse2 = "t200 @1 v9 y2 l16 o5 c e g >c e g >c8" },
})
