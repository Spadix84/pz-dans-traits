-- Vitality Cartridges: the small helpers every game of the mod shares, so the
-- games keep only what is their own. Loaded by a plain require from each
-- Game.lua (the console runs the games in the mod's Lua, not apart): the
-- module is VitalityCartridges.Common.

require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"

local Common = {}
VitalityCartridges.Common = Common

local SHADES = SpiffBoy.Cartridges.SHADES

-- the r, g, b of the console's shade i (1 the darkest .. 4 the lightest)
function Common.ink(i)
    local s = SHADES[i]
    return s.r, s.g, s.b
end

function Common.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- a count from the save: a whole number 0..hi, 0 when the save holds none (or nonsense)
function Common.readNumber(v, hi)
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.min(math.floor(v), hi)
end

-- the sound switch from the save: on unless its options say false
function Common.readSound(save)
    local o = save.options
    return type(o) ~= "table" or o.sound ~= false
end

-- Moves a menu's selection (game.selection, 1..n) on a press: back to the entry
-- before, forward to the one after, wrapping at both ends, and plays the cue
-- through game:cue on a move. Back wins when both are pressed at once.
function Common.moveMenu(game, n, back, forward, cue)
    if back then
        game.selection = (game.selection - 2 + n) % n + 1
        game:cue(cue)
    elseif forward then
        game.selection = game.selection % n + 1
        game:cue(cue)
    end
end
