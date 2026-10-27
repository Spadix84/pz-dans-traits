-- Project Zomboid Vitality Project: what First Aid tells you (health
-- overhaul, phase 4).
--
-- The health panel's per-part list is drawn by ISHealthBodyPartListBox:
-- doDrawItem, which vanilla and other mods (NestedHealthInfo, for one)
-- replace wholesale. So this wraps whichever one is installed once every
-- mod has loaded: the lines it draws are collected instead of drawn, then
-- reworded, dropped or added to by the examiner's First Aid level (the
-- panel's examiner, read live: your own for yourself, the doctor's for a patient),
-- and drawn closed up. The item height follows the returned y.
--
--   0-2  what anyone can see: a scratch, a cut, a bad cut, a bite, bleeding,
--        something stuck in it, a dressing and whether it is bloody. A break
--        is "might be broken"; an infection only shows once it is red and
--        swollen (level 3); no severities.
--   3-5  the game's own detail (wound severities, fracture, infection as
--        the game shows it), plus a dressing wearing thin, a badly set
--        bone and rough stitches.
--   6-8  how far an infection has got (local, spreading) and how stitches
--        are holding (fresh, holding, sound).
--   9-10 an infection that hasn't shown yet, and how far a break has healed.
-- The debug view (ISHealthPanel.cheat) is left alone.
--
-- Blood: under the overall body status, how much blood the patient has
-- (DanTraits_Blood.lua), told by the examiner's First Aid, the same levels:
--   0-2  how they look: pale, light-headed, in shock, bleeding out; still bleeding.
--   3-5  the class of blood loss, how fast it is bleeding, whether it is
--        coming back or needs water, red cells low.
--   6-8  the volume and red cells to the nearest 5%, the loss or refill an hour.
--   9-10 the exact figures and how long: to shock, to the heart giving out,
--        back to full.
-- Yourself, or another player in split-screen: read from their mod data. Another
-- player in multiplayer: their client is asked through the server
-- (DanTraits_BloodRelay.lua), so it shows a moment after the panel opens.
-- Left out while there is nothing to tell: full, not bleeding, red cells whole.
--
-- Daily medication: under that, your own character's
-- scheduled drugs (DanTraits_Meds.lua: the ones for traits you have), each
-- with when it was last taken and when the next is due; orange when it is
-- due, red once it has worn off. Not shown for another player in multiplayer:
-- their mod data is not sent to the doctor.
--
-- Strain: under that, your own character's strain tier (DanTraits_Strain.lua)
-- and whether it got worse or eased over the last hour. Yourself only, and
-- only from Frayed or while it is getting worse (the moodle covers the rest).
--
-- Blood and Strain are one status each: the header and the first line share
-- a row, any further lines sit under the first. Medication is a list of
-- drugs, so it keeps a header row of its own. The body part list moves down
-- to make room. What the character has learned about themselves (migraine
-- triggers, safe foods) is in the Notes tab (DanTraits_Notes.lua), not here.
require "XpSystem/ISUI/ISHealthPanel"

local HP_VAGUE_BELOW   = 3       -- levels under this see only what anyone can see
local HP_DETAIL        = 6       -- infection stage and stitch condition from here
local HP_EXPERT        = 9       -- hidden infection and healing from here
local HP_RED_L         = 3       -- a layperson sees an infection from this level
local HP_SPREAD_L      = 5       -- the infection is in the body from here (as DanTraits_Infection.lua)
local HP_THIN_LIFE     = 1       -- a dressing is wearing thin under this life
local HP_GAP           = 4       -- px under each section above the body part list
local HP_INDENT        = 8       -- px a list section's lines sit in from its header
local HP_BLEED_SLOW    = 0.001   -- blood volume a minute: bleeding slowly under this (6% an hour)...
local HP_BLEED_HEAVY   = 0.004   -- ...heavily from this (24% an hour)
local HP_BLOOD_SLIGHT  = 0.05    -- volume lost: "a little blood" from this (First Aid 3-5)
local HP_BLOOD_FULL    = 0.005   -- short of full by less than this reads as full

local RED, GREEN, ORANGE = { 0.89, 0.28, 0.28 }, { 0.28, 0.89, 0.28 }, { 1, 0.58, 0 }
local GREY = { 0.7, 0.7, 0.7 }

-- the game's own lines, by their text, once translations are loaded
local known = nil
local function knownText()
    if known then return known end
    known = {}
    for _, key in ipairs({ "Scratched", "Cut", "DeepWound", "Fracture", "Infected" }) do
        local ok, text = pcall(getText, "IGUI_health_" .. key)
        if ok and text then known[key] = text end
    end
    return known
end

local function startsWith(s, prefix) return prefix and string.sub(s, 1, #prefix) == prefix end

-- the text after the line's bullet ("- " in vanilla, "     * " nested under a bandage)
local function splitBullet(str)
    local s, e = string.find(str, "^%s*[-*] ")
    if not s then return nil, str end
    return string.sub(str, 1, e), string.sub(str, e + 1)
end

local function t(key) return getText("UI_DanTraits_health_" .. key) end

-- a line of the game's, as the examiner sees it: new text, or false to drop it
local function reword(body, level)
    local k = knownText()
    -- the game shows infection its own way; this mod's infection has its own
    -- lines below, so the game's goes, unless the mod's infection is switched
    -- off (then the game's is all there is)
    if k.Infected and startsWith(body, k.Infected) then
        if DanTraits_SandboxOn("InfectionEnabled") then return false end
        return nil
    end
    if level >= HP_VAGUE_BELOW then return nil end
    if k.Scratched and startsWith(body, k.Scratched) then return t("Scratch") end
    if k.DeepWound and startsWith(body, k.DeepWound) then return t("BadCut") end
    if k.Cut and startsWith(body, k.Cut) then return t("Cut") end
    if k.Fracture and startsWith(body, k.Fracture) then return t("MaybeBroken") end
    return nil
end

local num = DanTraits_PartNum

-- this mod's own lines for a part, by level: { text, colour }
local function extraLines(part, level, patient)
    local out = {}
    local name = tostring(part:getType())
    local d = patient and patient:getModData().DanTraits or {}
    local inf = d.infParts and d.infParts[name]
    local wc = d.wcParts and d.wcParts[name]
    local L = inf and inf.L or 0
    -- infection
    if L > 0 then
        if level < HP_VAGUE_BELOW then
            if L >= HP_RED_L then out[#out + 1] = { t("RedSwollen"), ORANGE } end
        elseif level < HP_DETAIL then
            out[#out + 1] = { t("Infected"), ORANGE }
        else
            out[#out + 1] = { t(L >= HP_SPREAD_L and "InfectionSpreading" or "InfectionLocal"), ORANGE }
        end
    elseif inf and inf.inc and level >= HP_EXPERT then
        out[#out + 1] = { t("MightTurn"), ORANGE }
    end
    -- dressing wearing thin
    local ok, bandaged = pcall(function() return part:bandaged() end)
    if ok and bandaged and level >= HP_VAGUE_BELOW then
        local life = num(part, "getBandageLife")
        if life > 0 and life < HP_THIN_LIFE then out[#out + 1] = { t("DressingThin"), ORANGE } end
    end
    -- stitches, read from the time (a bandage clears the flag)
    local stitch = num(part, "getStitchTime")
    if stitch > 0 and level >= HP_DETAIL then
        local key = stitch >= 40 and "StitchesSound" or (stitch >= 15 and "StitchesHolding" or "StitchesFresh")
        out[#out + 1] = { t(key), key == "StitchesFresh" and ORANGE or GREEN }
    end
    -- a rough stitching job: anyone who knows the work can see it
    if stitch > 0 and wc and wc.poorStitch and level >= HP_VAGUE_BELOW then out[#out + 1] = { t("StitchesRough"), RED } end
    -- a knock to the head
    if name == "Head" then
        local s = d.ccScore or 0
        if d.ccLate and d.ccLate.left and s <= 0 then out[#out + 1] = { t("ConcussionLate"), ORANGE } end
        if s > 0 then
            if level < HP_VAGUE_BELOW then
                out[#out + 1] = { t("KnockToHead"), ORANGE }
            else
                out[#out + 1] = { t(s >= 0.7 and "ConcussionSevere" or (s >= 0.4 and "ConcussionModerate" or "ConcussionMild")), ORANGE }
            end
        end
    end
    -- clotting powder packed in (anyone can see it)
    if d.clot and (d.clot[name] or 0) > 0 then out[#out + 1] = { t("ClotPacked"), GREEN } end
    -- sunburn (not a wound: anyone can see it)
    if d.sbBurn and (d.sbBurn[name] or 0) > 0 then out[#out + 1] = { t("Sunburnt"), ORANGE } end
    -- the bone
    local fracture = num(part, "getFractureTime")
    if fracture > 0 then
        if wc and wc.badSet and level >= HP_VAGUE_BELOW then out[#out + 1] = { t("SetBadly"), RED } end
        if level >= HP_EXPERT then
            out[#out + 1] = { t(fracture > 50 and "BoneEarly" or (fracture > 20 and "BoneKnitting" or "BoneNearly")), GREEN }
        end
    end
    return out
end

local function wrapDrawItem()
    if not ISHealthBodyPartListBox or not ISHealthBodyPartListBox.doDrawItem then return end
    if ISHealthBodyPartListBox.doDrawItem == ISHealthBodyPartListBox.DanTraitsDrawItem then return end
    local original = ISHealthBodyPartListBox.doDrawItem
    local function drawItem(self, y, item, alt)
        -- wrapped twice (another mod wrapped after this one, then a second world
        -- re-wrapped on OnGameStart): the inner layer is already inside the outer's
        -- call, so it passes through and the lines are drawn once
        if self.danTraitsDrawing then return original(self, y, item, alt) end
        local panel = self.parent
        if not panel or ISHealthPanel.cheat or not item or not item.item or not item.item.bodyPart then
            return original(self, y, item, alt)
        end
        local part = item.item.bodyPart
        -- the examiner's level now: the panel keeps the one it was made with
        -- (your own panel, the one from game start), so it is brought up to date
        pcall(function() panel.doctorLevel = panel:getDoctor():getPerkLevel(Perks.Doctor) end)
        local level = panel.doctorLevel or 0
        local patient = nil
        pcall(function() patient = panel:getPatient() end)
        -- collect what it draws
        local lines = {}
        local draw = self.drawText
        self.drawText = function(_, str, x, ly, r, g, b, a, font)
            lines[#lines + 1] = { str = str, x = x, y = ly, r = r, g = g, b = b, a = a, font = font }
        end
        self.danTraitsDrawing = true
        local ok, yEnd = pcall(original, self, y, item, alt)
        self.danTraitsDrawing = nil
        self.drawText = draw
        if not ok then
            local bottom = y
            for _, l in ipairs(lines) do
                draw(self, l.str, l.x, l.y, l.r, l.g, l.b, l.a, l.font)
                bottom = math.max(bottom, l.y + 10)
            end
            return bottom
        end
        -- reword, drop duplicates, close up
        local seen, shift = {}, 0
        local fontHgt = getTextManager():getFontHeight(UIFont.Small)
        local lastY, x = y, 15
        for i, l in ipairs(lines) do
            local str = l.str
            if i > 1 then
                local bullet, body = splitBullet(str)
                if bullet then
                    local new = reword(body, level)
                    if new == false then str = nil
                    elseif new then str = bullet .. new end
                    x = l.x
                end
            end
            if str and seen[str] and i > 1 then str = nil end
            if str then
                seen[str] = true
                draw(self, str, l.x, l.y - shift, l.r, l.g, l.b, l.a, l.font)
                lastY = l.y - shift + fontHgt
            else
                shift = shift + fontHgt
            end
        end
        yEnd = (yEnd or lastY) - shift
        -- this mod's own lines, before the gap the game leaves at the end
        local extra = extraLines(part, level, patient)
        if #extra > 0 then
            local ey = yEnd - 5
            for _, e in ipairs(extra) do
                draw(self, "- " .. e[1], x, ey, e[2][1], e[2][2], e[2][3], 1, UIFont.Small)
                ey = ey + fontHgt
            end
            yEnd = ey + 5
        end
        return yEnd
    end
    ISHealthBodyPartListBox.doDrawItem = drawItem
    ISHealthBodyPartListBox.DanTraitsDrawItem = drawItem
end

local BLOOD_COLOUR = { ORANGE, ORANGE, RED, RED }   -- by tier: pale, light-headed, shock, bleeding out

-- a fraction as a percentage, to the nearest step
local function pct(x, step) return math.floor(x * 100 / step + 0.5) * step end

-- a stretch of game minutes as the panel words it
local function inTime(minutes)
    local h = minutes / 60
    if h < 1 then return t("BloodUnderHour") end
    if h < 1.5 then return t("BloodHour") end
    if h < 48 then return getText("UI_DanTraits_health_BloodHours", tostring(math.floor(h + 0.5))) end
    return getText("UI_DanTraits_health_BloodDays", tostring(math.floor(h / 24 + 0.5)))
end

-- the blood lines for a DanTraits_BloodState at the examiner's First Aid level: { text, colour }
local function bloodLinesOf(s, level)
    if not s then return {} end
    -- nothing to tell: full, not bleeding, red cells whole
    if s.tier == 0 and s.loss <= 0 and s.weak <= 0
        and 1 - s.vol < HP_BLOOD_FULL and 1 - s.cells < HP_BLOOD_FULL then return {} end
    local out = {}
    local function add(text, colour) out[#out + 1] = { text, colour } end
    local lost = math.max(0, 1 - s.vol)
    local colour = BLOOD_COLOUR[s.tier] or GREEN
    local bleeding = s.loss > 0
    local bleedColour = s.loss >= HP_BLEED_HEAVY and RED or ORANGE
    if level < HP_VAGUE_BELOW then
        -- how they look
        if s.tier > 0 then add(t("BloodFeel" .. s.tier), colour)
        elseif s.weak > 0 then add(t("BloodFeelWeak"), ORANGE)
        elseif not bleeding then add(t("BloodFeelFine"), GREEN) end
        if bleeding then add(t("BloodStillBleeding"), bleedColour) end
        return out
    end
    local expert = level >= HP_EXPERT
    -- the volume
    if level < HP_DETAIL then
        if s.tier > 0 then add(t("BloodLoss" .. s.tier), colour)
        else add(t(lost >= HP_BLOOD_SLIGHT and "BloodLossSlight" or "BloodLossNone"), GREEN) end
    else
        add(getText(expert and "UI_DanTraits_health_BloodVol" or "UI_DanTraits_health_BloodVolAbout",
            tostring(pct(s.vol, expert and 1 or 5))), colour)
    end
    -- which way it is going
    local net = s.loss - s.volGain   -- volume a minute, falling while over 0
    if bleeding then
        if level < HP_DETAIL then
            add(t(s.loss >= HP_BLEED_HEAVY and "BleedHeavy" or (s.loss >= HP_BLEED_SLOW and "BleedSteady" or "BleedSlow")), bleedColour)
        elseif net <= 0 then
            add(t("BloodHolding"), GREY)
        elseif not expert then
            add(getText("UI_DanTraits_health_BloodLosingAbout", tostring(math.max(1, pct(net * 60, 1)))), bleedColour)
        else
            local hour = string.format("%.1f", DanTraits_Round(net * 60 * 100, 1))
            local toShock, toDeath = s.vol - (1 - s.shock), s.vol - (1 - s.death)
            if toShock > 0 then
                add(getText("UI_DanTraits_health_BloodLosingShock", hour, inTime(toShock / net)), bleedColour)
            elseif toDeath > 0 then
                add(getText("UI_DanTraits_health_BloodLosingDeath", hour, inTime(toDeath / net)), RED)
            else
                add(getText("UI_DanTraits_health_BloodLosing", hour), RED)
            end
        end
    elseif lost >= HP_BLOOD_FULL then
        if s.volGain <= 0 then add(t("BloodNoRefill"), ORANGE)
        elseif level < HP_DETAIL then add(t("BloodRefilling"), GREEN)
        elseif not expert then add(getText("UI_DanTraits_health_BloodRefillAbout", tostring(math.max(1, pct(s.volGain * 60, 1)))), GREEN)
        else add(getText("UI_DanTraits_health_BloodRefillFull", inTime(lost / s.volGain)), GREEN) end
    end
    -- the red cells
    local cellsShort = 1 - s.cells
    if level < HP_DETAIL then
        if s.weak > 0 then add(t("BloodCellsLow"), ORANGE) end
    elseif cellsShort >= HP_BLOOD_FULL then
        local cellColour = s.weak > 0 and ORANGE or GREY
        local rebuild = s.cellGain - s.loss
        if not expert then
            add(getText("UI_DanTraits_health_BloodCellsAbout", tostring(pct(s.cells, 5))), cellColour)
        elseif rebuild > 0 then
            add(getText("UI_DanTraits_health_BloodCellsBack", tostring(pct(s.cells, 1)), inTime(cellsShort / rebuild)), cellColour)
        else
            add(getText("UI_DanTraits_health_BloodCells", tostring(pct(s.cells, 1))), cellColour)
        end
    end
    return out
end

-- the same for a character: their own state when they are on this machine, or
-- the last answer from their client in multiplayer
local function bloodLines(patient, level, doctor)
    local here = false
    pcall(function() here = patient:isLocalPlayer() end)
    if here then return bloodLinesOf(DanTraits_BloodState and DanTraits_BloodState(patient), level) end
    return bloodLinesOf(DanTraits_PatientBloodState and DanTraits_PatientBloodState(doctor, patient), level)
end
DanTraits_HealthBloodLines = bloodLines

-- the bottle's name, as the game shows it
local function medName(id)
    local drug = DanTraits_Drugs[id]
    local name = nil
    if drug and drug.item then pcall(function() name = getItemNameFromFullType(drug.item) end) end
    return name or id
end

-- the medication lines for a character: { text, colour }
local function medLines(patient)
    local out = {}
    if not DanTraits_MedSchedule then return out end
    for _, id in ipairs(DanTraits_MedSchedule(patient)) do
        local since = DanTraits_MedSince(patient, id)
        local inSystem = DanTraits_MedInSystem(patient, id)
        local due = DanTraits_MedDue(patient, id)
        local when
        if not since then when = t(inSystem and "MedEarlier" or "MedNever")
        elseif since < 1 then when = t("MedJustNow")
        elseif since < 2 then when = t("MedHour")
        elseif since < 48 then when = getText("UI_DanTraits_health_MedHours", tostring(math.floor(since)))
        else when = getText("UI_DanTraits_health_MedDays", tostring(math.floor(since / 24))) end
        local status, colour = nil, GREY
        if due == 2 then status, colour = t("MedWornOff"), RED
        elseif due == 1 then status, colour = t("MedDueNow"), ORANGE
        elseif inSystem then
            colour = GREEN
            local nextIn = DanTraits_MedNextIn(patient, id)
            if nextIn then
                status = nextIn <= 1 and t("MedNextSoon") or getText("UI_DanTraits_health_MedNextIn", tostring(math.ceil(nextIn)))
            end
        end
        out[#out + 1] = { medName(id) .. ": " .. when .. (status and (", " .. status) or ""), colour }
    end
    return out
end
DanTraits_HealthMedLines = medLines

-- strain (DanTraits_Strain.lua): the tier as the moodle shows it, and which
-- way it went over the last hour; never the number. Nothing while it is under
-- Frayed and not getting worse.
local STRAIN_COLOUR = { [-1] = GREEN, [0] = GREY, [1] = ORANGE, [2] = ORANGE, [3] = RED, [4] = RED }
local function strainLines(patient)
    if not DanTraits_StrainSummary then return {} end
    local s = DanTraits_StrainSummary(patient)
    if not s then return {} end
    local level = math.max(-1, math.min(4, tonumber(s.moodle) or 0))
    if level <= 0 and s.way ~= "rising" then return {} end
    local name = t(level < 0 and "StrainEase" or ("Strain" .. level))
    return { { name .. ", " .. t("Strain" .. s.way), STRAIN_COLOUR[level] or GREY } }
end
DanTraits_HealthStrainLines = strainLines

local function wrapRender()
    if not ISHealthPanel or not ISHealthPanel.render then return end
    if ISHealthPanel.render == ISHealthPanel.DanTraitsRender then return end
    local original = ISHealthPanel.render
    local function render(self)
        -- wrapped twice (as doDrawItem above): only the outer layer adds the lines
        if self.danTraitsRendering then return original(self) end
        self.danTraitsRendering = true
        local ok, err = pcall(original, self)
        self.danTraitsRendering = nil
        if not ok then error(err) end
        if ISHealthPanel.cheat or self.blockingMessage or not self.listbox then return end
        local patient, doctor, here = nil, nil, false
        pcall(function() patient = self:getPatient(); here = patient:isLocalPlayer() end)
        if not patient then return end
        pcall(function() doctor = self:getDoctor() end)
        local level = self.doctorLevel or 0
        pcall(function() level = doctor:getPerkLevel(Perks.Doctor) end)
        -- { header, lines, inline }: an inline section's header shares its first line's row
        local sections = {}
        local blood = bloodLines(patient, level, doctor)
        if #blood > 0 then sections[#sections + 1] = { t("BloodHeader"), blood, true } end
        local meds = here and medLines(patient) or {}
        if #meds > 0 then sections[#sections + 1] = { t("MedHeader"), meds, false } end
        local strain = here and strainLines(patient) or {}
        if #strain > 0 then sections[#sections + 1] = { t("StrainHeader"), strain, true } end
        if #sections == 0 then return end
        local tm = getTextManager()
        local fontHgt = tm:getFontHeight(UIFont.Small)
        local border = UI_BORDER_SPACING or 10
        local x, y = self.listbox:getX(), self.listbox:getY()
        local widest = 0
        local function draw(str, dx, c)
            self:drawText(str, x + dx, y, c[1], c[2], c[3], 1, UIFont.Small)
            widest = math.max(widest, dx + tm:MeasureStringX(UIFont.Small, str))
        end
        for _, section in ipairs(sections) do
            local dx = HP_INDENT
            if section[3] then
                local head = getText("UI_DanTraits_health_Inline", section[1]) .. " "   -- the space here: a translation may lose a trailing one
                draw(head, 0, { 1, 1, 1 })
                dx = tm:MeasureStringX(UIFont.Small, head)
            else
                draw(section[1], 0, { 1, 1, 1 })
                y = y + fontHgt
            end
            for _, l in ipairs(section[2]) do
                draw(l[1], dx, l[2])
                y = y + fontHgt
            end
            y = y + HP_GAP
        end
        -- the list moves down; the panel grows to fit on the next update
        -- (vanilla sizes it from allTextHeight), within the screen
        local extra = y - self.listbox:getY()
        self.listbox:setY(y)
        local all = (self.allTextHeight or 0) + extra
        all = math.min(all, getCore():getScreenHeight() - self:getAbsoluteY() - fontHgt - border * 2)
        self.allTextHeight = all
        self.listbox:setHeight(math.max(0, all - y))
        if self.listbox.vscroll then self.listbox.vscroll:setHeight(self.listbox:getHeight()) end
        -- and wide enough for the longest line (vanilla's rounding)
        self.listbox.textRight = math.max(self.listbox.textRight or 0, widest - math.fmod(widest, 20) + 40)
    end
    ISHealthPanel.render = render
    ISHealthPanel.DanTraitsRender = render
end

-- after every other mod has put its own in
Events.OnGameStart.Add(wrapDrawItem)
Events.OnGameStart.Add(wrapRender)
