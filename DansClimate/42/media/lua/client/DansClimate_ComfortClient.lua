-- What the player sees of Comfort (shared/DansClimate_Comfort.lua).
--
-- With Moodle Framework: three moodles, set once a game minute.
--   ClimateChilly  bad   level 1 Chilly, level 2 Cold
--   ClimateStuffy  bad   level 1 Too Warm, level 2 Sweltering
--   ClimateCosy    good  level 1 Cosy (warm indoors while it is cold out),
--                        level 2 Cool Indoors (cool indoors while it is hot out)
-- Moodle Framework's convention: a moodle's value sits at 0.5 for nothing, under it
-- for the bad levels and over it for the good ones; the thresholds here are a tenth
-- apart either side, and the value goes in the middle of the level's band.
--
-- Without Moodle Framework the mod still does everything; the character says a line
-- over their head when a level is reached.
require "DansClimate_Comfort"

local Comfort = DansClimate.Comfort

Comfort.MOODLES = { chill = "ClimateChilly", stuffy = "ClimateStuffy", cosy = "ClimateCosy" }

local hasMF = pcall(require, "MF_ISMoodle")
if hasMF and MF and MF.createMoodle then
    for _, name in pairs(Comfort.MOODLES) do MF.createMoodle(name) end
end

local function framework()
    return MF ~= nil and MF.getMoodle ~= nil
end

-- level > 0 a bad level, < 0 a good one, 0 nothing
local function setMoodle(player, name, level)
    local moodle = MF.getMoodle(name, player:getPlayerNum())
    if not moodle then return end
    moodle:setThresholds(0.1, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8, 0.9)
    if level > 0 then
        moodle:setValue(0.45 - 0.1 * level)
    elseif level < 0 then
        moodle:setValue(0.55 - 0.1 * level)
    else
        moodle:setValue(0.5)
    end
end

-- The levels to show: chill and stuffy 0-2 by their meters; cosy 0, or 1 warm, 2 cool.
function Comfort.levels(d)
    local cosy = 0
    if (d.cosy or 0) >= Comfort.LEVELS[1] then cosy = d.kind == "cool" and 2 or 1 end
    return { chill = Comfort.level(d.chill or 0), stuffy = Comfort.level(d.stuffy or 0), cosy = cosy }
end

local LINES = {
    chill = { "IGUI_DansClimate_Comfort_Chilly", "IGUI_DansClimate_Comfort_Cold" },
    stuffy = { "IGUI_DansClimate_Comfort_TooWarm", "IGUI_DansClimate_Comfort_Sweltering" },
    cosy = { "IGUI_DansClimate_Comfort_Cosy", "IGUI_DansClimate_Comfort_Cool" },
}

-- Called by Comfort.everyMinute for each local player, with their data.
function Comfort.show(player, d)
    local levels = Comfort.levels(d)
    if framework() then
        setMoodle(player, Comfort.MOODLES.chill, levels.chill)
        setMoodle(player, Comfort.MOODLES.stuffy, levels.stuffy)
        setMoodle(player, Comfort.MOODLES.cosy, -levels.cosy)
        d.shown = nil
        return levels
    end
    -- no moodles: say it once as each level is reached (not while asleep)
    local shown = d.shown or {}
    for key, level in pairs(levels) do
        local was = shown[key] or 0
        if level > was and not player:isAsleep() then
            local text = getText(LINES[key][level])
            if key == "cosy" then HaloTextHelper.addGoodText(player, text) else HaloTextHelper.addBadText(player, text) end
        end
        shown[key] = level
    end
    d.shown = shown
    return levels
end
