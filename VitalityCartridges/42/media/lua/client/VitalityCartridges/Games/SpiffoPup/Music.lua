-- Spiffo Pup: the tunes. Notes for the console's sound chip (SDK docs/04 and 14).
-- The room and the night play on pulse 1 and the wave voice, the catch game
-- adds the noise; the cues borrow pulse 2, so they never cut the music.

require "VitalityCartridges/Core"
require "SpiffBoy/Core/Tunes"

VitalityCartridges.SpiffoPup = VitalityCartridges.SpiffoPup or {}

local Music = {}
VitalityCartridges.SpiffoPup.Music = Music

Music.ROOM = "room"
Music.NIGHT = "night"
Music.CATCH = "catch"
Music.MOVE = "move"
Music.SELECT = "select"
Music.NO = "no"
Music.EAT = "eat"
Music.CLEAN = "clean"
Music.LIGHTS = "lights"
Music.THROW = "throw"
Music.CAUGHT = "caught"
Music.MISS = "miss"
Music.HATCH = "hatch"
Music.GONE = "gone"

SpiffBoy.Tunes.register("SpiffoPup", {
    -- the room: a little skipping tune over a plain bass, four bars
    [Music.ROOM] = {
        loop = true,
        pulse1 = "t108 @1 v7 y2 q6 l8 o5"
            .. " c e g e a g e c | d f a f g e d4"
            .. " | c e g e a g e c | d g f d c4 r4",
        wave = "t108 @11 v2 l2 o3 c g | f g | c a | g c",
    },
    -- lights out: a slow lullaby, soft
    [Music.NIGHT] = {
        loop = true,
        pulse1 = "t66 @2 v4 y3 l4 o4 e c d <g> | e c d2 | c <a b g> | c2 r2",
        wave = "t66 @2 v1 l1 o2 c f c g",
    },
    -- the catch game: quicker, with a light beat, two bars
    [Music.CATCH] = {
        loop = true,
        pulse1 = "t152 @1 v7 y1 q5 l8 o5 g e g >c< a g e g | f d f a g e c4",
        wave = "t152 @5 v2 l4 o3 c g a g | f g c g",
        noise = "t152 l8 [v7 y1 n{36 70 112} r v2 y1 n24 v2 y1 n24 v5 y2 n60 r v2 y1 n24 r]2",
    },
    [Music.MOVE] = { pulse2 = "t240 @3 v6 y1 l32 o6 c" },
    [Music.SELECT] = { pulse2 = "t220 @2 v8 y1 l32 o5 c g >c" },
    [Music.NO] = { pulse2 = "t200 @3 v6 y2 l16 o3 c r32 c" },
    -- chomp, chomp
    [Music.EAT] = { pulse2 = "t200 @1 v8 y1 l32 o4 c r g r c r g" },
    -- a sweep up the scale
    [Music.CLEAN] = { pulse2 = "t240 @0 v7 y1 l32 o5 c d e f g a b >c" },
    [Music.LIGHTS] = { pulse2 = "t200 @2 v6 y2 l16 o5 g <g" },
    [Music.THROW] = { pulse2 = "t240 @3 v4 y1 l32 o6 e" },
    [Music.CAUGHT] = { pulse2 = "t240 @2 v9 y1 l32 o5 e g >c" },
    [Music.MISS] = { pulse2 = "t200 @3 v7 y2 l16 o4 e <c" },
    [Music.HATCH] = { pulse2 = "t180 @1 v9 y2 l16 o5 c e g >c e8" },
    -- the pup ran away
    [Music.GONE] = { pulse2 = "t96 @2 v7 y4 l8 o4 e d c <b a4" },
})
