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
--        the game shows it), plus a dressing wearing thin and a badly set
--        bone.
--   6-8  how far an infection has got (local, spreading) and how stitches
--        are holding (fresh, holding, sound).
--   9-10 an infection that hasn't shown yet, and how far a break has healed.
-- The debug view (ISHealthPanel.cheat) is left alone.
require "XpSystem/ISUI/ISHealthPanel"

local HP_VAGUE_BELOW   = 3       -- levels under this see only what anyone can see
local HP_DETAIL        = 6       -- infection stage and stitch condition from here
local HP_EXPERT        = 9       -- hidden infection and healing from here
local HP_RED_L         = 3       -- a layperson sees an infection from this level
local HP_SPREAD_L      = 5       -- the infection is in the body from here (as DanTraits_Infection.lua)
local HP_THIN_LIFE     = 1       -- a dressing is wearing thin under this life

local RED, GREEN, ORANGE = { 0.89, 0.28, 0.28 }, { 0.28, 0.89, 0.28 }, { 1, 0.58, 0 }

-- the game's own lines, by their text, once translations are loaded
local known = nil
local function knownText()
    if known then return known end
    known = {}
    for _, key in ipairs({ "Scratched", "Cut", "DeepWound", "Bitten", "Fracture", "Infected", "Severe", "Moderate",
                           "Stitched", "Good", "NeedTime", "Splinted" }) do
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
local function reword(body, level, part, rec)
    local k = knownText()
    if level >= HP_VAGUE_BELOW then
        -- the game shows infection its own way; this mod's infection has its own
        -- lines below, so the game's is only kept where it agrees
        if k.Infected and startsWith(body, k.Infected) then return false end
        return nil
    end
    if k.Scratched and startsWith(body, k.Scratched) then return t("Scratch") end
    if k.DeepWound and startsWith(body, k.DeepWound) then return t("BadCut") end
    if k.Cut and startsWith(body, k.Cut) then return t("Cut") end
    if k.Fracture and startsWith(body, k.Fracture) then return t("MaybeBroken") end
    if k.Infected and startsWith(body, k.Infected) then return false end
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
    -- a knock to the head
    if name == "Head" then
        local s = d.ccScore or 0
        if s > 0 then
            if level < HP_VAGUE_BELOW then
                out[#out + 1] = { t("KnockToHead"), ORANGE }
            else
                out[#out + 1] = { t(s >= 0.7 and "ConcussionSevere" or (s >= 0.4 and "ConcussionModerate" or "ConcussionMild")), ORANGE }
            end
        end
    end
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
DanTraits_HealthPanelExtra = extraLines
DanTraits_HealthPanelReword = reword

local function wrapDrawItem()
    if not ISHealthBodyPartListBox or not ISHealthBodyPartListBox.doDrawItem then return end
    if ISHealthBodyPartListBox.doDrawItem == ISHealthBodyPartListBox.DanTraitsDrawItem then return end
    local original = ISHealthBodyPartListBox.doDrawItem
    local function drawItem(self, y, item, alt)
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
        local ok, yEnd = pcall(original, self, y, item, alt)
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
                    local new = reword(body, level, part)
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

-- after every other mod has put its own in
Events.OnGameStart.Add(wrapDrawItem)
