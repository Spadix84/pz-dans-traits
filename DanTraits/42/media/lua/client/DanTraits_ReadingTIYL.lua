-- Dan's Vanilla Fixes: This Is Your Life (Workshop 3773911887) support. Does
-- nothing unless that mod is loaded; no dependency either way.
--
-- Its survivor journal keeps a "life so far" timeline: plain strings in
-- player:getModData().TIYL.journal.timeline, one per line, each starting with
-- the date the way its own milestones write it ("July 12, 1993 - ..."), drawn
-- in the handwritten font and cut to the page's width
-- (ThisIsYourLife/TIYLMilestones.lua, TIYLSurvivorJournal.lua). Reading adds
-- its own lines: a book finished, with the verdict, and a taste found out.

require "DansVanillaFixes_Reading"

local R = DVF_Reading

local function active()
    return type(TIYL) == "table"
end

-- the date as This Is Your Life writes it: its month name, day, year
local function dateText()
    local time = getGameTime()
    local month = (time and time:getMonth() or 6) + 1
    local name
    local ok, text = pcall(getText, "UI_TIYL_Common_Month" .. tostring(month))
    if ok and type(text) == "string" and text ~= "" and not text:find("^UI_TIYL") then name = text end
    if not name then name = getText("IGUI_DVF_Month" .. tostring(month)) end
    return name .. " " .. tostring((time and time:getDay() or 0) + 1) .. ", " .. tostring(time and time:getYear() or 1993)
end

function R.journalLine(player, text)
    if not active() or not player then return false end
    local ok = pcall(function()
        local data = player:getModData()
        data.TIYL = data.TIYL or {}
        data.TIYL.journal = data.TIYL.journal or {}
        local journal = data.TIYL.journal
        journal.timeline = journal.timeline or {}
        table.insert(journal.timeline, dateText() .. " - " .. text)
        if isClient() then player:transmitModData() end
    end)
    return ok
end

R.onFinish("tiyl", function(player, info, result)
    if not active() then return end
    local verdict = result and result.verdict or "fine"
    if result and result.reread then verdict = "again" end
    R.journalLine(player, getText("IGUI_DVF_Journal_Finished", R.titleText(info), getText("IGUI_DVF_JournalVerdict_" .. verdict)))
end)

R.onTasteFound("tiyl", function(player, family, verdict)
    if not active() or verdict == "neutral" then return end
    R.journalLine(player, getText("IGUI_DVF_JournalTaste_" .. verdict, R.familyName(family)))
end)
