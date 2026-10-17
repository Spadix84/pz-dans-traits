-- Project Zomboid Vitality Project: reading for pleasure, the rules (the action wraps are
-- in DanTraits_ReadingAction.lua, the tooltip, context option and
-- moodle in client/DanTraits_ReadingClient.lua, the journal bridge in
-- client/DanTraits_ReadingTIYL.lua; design and as-built notes in
-- plans/reading.md).
--
-- Vanilla reads a novel in ten minutes and pays out all its boredom, stress
-- and unhappiness relief at the end, once per title. Here every vanilla
-- novel, comic, magazine and newspaper has a genre family, a page count and
-- a hidden quality (DanTraits_ReadingData.lua, generated from the
-- game; DanTraits_ReadingBooks.lua adds real 1993 books and hand
-- fixes). A read takes real time, the relief arrives per page while you
-- read, and a book you put down is bookmarked for the character by title.
-- Each character likes one family and dislikes another, hidden until about
-- FOUND_PAGES pages in that family tell them. Finishing a book gives the
-- Good Read moodle for about two days with one buff, set by the genre: each
-- family eases a stat, speeds a few skills' XP or quickens reading (R.BUFF),
-- and the moodle says which. Only one runs at a time; a new finish takes over
-- when it is a higher level, or the same level with more time to run.
-- Skill books, recipe magazines, fliers and brochures keep vanilla.
--
-- Player mod data DVF_Reading:
--   { v = 1, liked = family, disliked = family, found = { [family] = true },
--     pagesIn = { [family] = pages read }, marks = { [key] = pages },
--     read = { [key] = { q, family, when, verdict } },
--     moodle = { level, family, quality, strength, key, ends = world hour } }
-- Item mod data DVF_ReadPages: the pages read in this copy (a second bookmark).
-- Those two keys and the IGUI_DVF_BookTitle_ title prefix keep the names they
-- had in Dan's Vanilla Fixes, where reading started, so saves carry on.
-- Vitality's own hooks (home, age, concussion, Bad Day) are in
-- DanTraits_ReadingHooks.lua.
--
-- Stat scales (42.21): boredom and unhappiness 0-100, stress 0-1. The item
-- scripts' StressChange is in hundredths, as the game applies it.

require "DanTraits_ReadingData"
require "DanTraits_ReadingBooks"

DanTraits_Reading = DanTraits_Reading or {}
local R = DanTraits_Reading
local D = DanTraits_ReadingData

R.KEY = "DVF_Reading"
R.ITEM_KEY = "DVF_ReadPages"
R.REAL_PREFIX = "IGUI_DVF_BookTitle_"

-- tuning (proposals for the play-test; see plans/reading.md)
R.NOVEL_REF_PAGES = 300         -- a novel's vanilla relief is spread over this many pages
R.MPP_NOVEL = 1.5               -- minutes per page at the vanilla default MinutesPerPage of 2.0
R.MPP_PICTURE = 0.5             -- comics, magazines, newspapers, picture and kids' books
R.CHAPTER_MINUTES = 30          -- "Read a chapter"
R.FOUND_PAGES = 30              -- pages in a family before the character knows their taste
R.TASTE = { liked = 1.25, neutral = 1.0, disliked = 0.5 }
R.QUALITY = { 0.8, 0.9, 1.0, 1.1, 1.2 }
R.REREAD = 0.2                  -- of the drip, a finished title in the liked family only
R.DISLIKE_TICK_MIN = 20         -- a disliked book adds boredom this often, in game minutes
R.DISLIKE_TICK = 2
R.MOODLE_HOURS = 48             -- a novel or picture book, whatever its quality
R.SHORT_MOODLE_HOURS = 12       -- comics and magazines, level 1 only
R.LOVED_BONUS = 0.25            -- Loved It: on top of the liked multiplier
R.FALLBACK = { family = "popular", pages = 120, quality = 3 }   -- another mod's literature
R.PLAYERS = 4

-- the one buff a finished book gives, by family: stat changes per minute at
-- strength 1, skills whose XP runs at XP_MULT, or read = page time x this
-- (the XP and read factors also scale with strength: 1 + 0.05 x strength).
-- The moodle's text for each is IGUI_DanTraits_ReadingBuff_<family>.
R.BUFF = {
    horror = { panic = 0.5 },
    thrillers = { stress = 0.0015 },
    romance = { unhappy = 0.05 },
    popular = { boredom = 0.05 },
    classics = { boredom = 0.04, unhappy = 0.04 },
    faith = { stress = 0.001, unhappy = 0.03 },
    truestories = { panic = 0.25, stress = 0.001 },
    kids = { boredom = 0.05 },
    humor = { unhappy = 0.05 },
    westerns = { endurance = 0.0005 },
    serious = { read = 0.9 },
    sports = { xp = { "Fitness", "Strength" } },
    scifi = { xp = { "Electricity", "Mechanics" } },
    science = { xp = { "Doctor", "PlantScavenging" } },
    history = { xp = { "Aiming", "Reloading" } },
    fringe = { xp = { "Trapping", "Sneak" } },
    arts = { xp = { "Carving", "Pottery" } },
    selfhelp = { xp = { "Cooking", "Farming", "Woodwork", "Tailoring", "Maintenance" } },
}
R.XP_MULT = 1.05

R.FAMILIES = { "horror", "thrillers", "romance", "scifi", "westerns", "popular", "classics", "history",
               "truestories", "sports", "faith", "fringe", "selfhelp", "science", "arts", "serious", "kids", "humor" }
-- the families a taste can be (Kids and Humor are never a taste)
R.TASTE_POOL = { "horror", "thrillers", "romance", "scifi", "westerns", "popular", "classics", "history",
                 "truestories", "sports", "faith", "fringe", "selfhelp", "science", "arts", "serious" }

local function now()
    local ok, h = pcall(function() return getGameTime():getWorldAgeHours() end)
    return ok and tonumber(h) or 0
end

local function serverSide()
    return isServer ~= nil and isServer() == true
end

local function transmit(player)
    pcall(function() player:transmitModData() end)
end

-- sandbox ---------------------------------------------------------------------------

function R.opt(name, default)
    local opts = SandboxVars and SandboxVars.DanTraits
    local v = opts and opts[name]
    if v == nil then return default end
    return v
end

function R.on()
    return R.opt("ReadingEnabled", true) ~= false
end

function R.familyName(family)
    return getText("IGUI_DanTraits_Genre_" .. tostring(family))
end

-- the title ------------------------------------------------------------------------

local PREFIXES = {
    { R.REAL_PREFIX, "real" },
    { "IGUI_BookTitle_", "book" },
    { "IGUI_ComicTitle_", "comic" },
    { "IGUI_MagazineTitle_", "magazine" },
}

function R.rawTitle(item)
    if not item then return nil end
    local ok, raw = pcall(function()
        if not item:hasModData() then return nil end
        return item:getModData().literatureTitle
    end)
    if ok and type(raw) == "string" and raw ~= "" then return raw end
    return nil
end

local function tableFor(kind)
    if kind == "book" then return D.books end
    if kind == "comic" then return D.comics end
    if kind == "magazine" then return D.magazines end
    if kind == "real" then return D.real end
    return nil
end

-- kind and the bare key of a literatureTitle. Magazines carry _month_year and
-- comics an issue number, so the key is tried whole, then with trailing
-- numbers taken off until the table knows it.
function R.parseKey(raw)
    if type(raw) ~= "string" then return nil, nil end
    for _, p in ipairs(PREFIXES) do
        local prefix, kind = p[1], p[2]
        if raw:sub(1, #prefix) == prefix then
            local key = raw:sub(#prefix + 1)
            local t = tableFor(kind)
            local tries = 0
            while key ~= "" and tries < 4 do
                if t[key] then return kind, key end
                local shorter = key:match("^(.-)_?%d+$")
                if not shorter or shorter == key then break end
                key = shorter
                tries = tries + 1
            end
            return kind, key
        end
    end
    return nil, raw
end

-- the table row for a title: { family, pages, quality, cover } with the hand
-- overrides on top; nil for a title the table does not know
function R.lookup(kind, key)
    local t = tableFor(kind)
    local row = t and t[key]
    if not row then return nil end
    local family, pages, quality, cover
    if kind == "real" then
        family, pages, quality, cover = row.family, row.pages, row.quality, row.cover
    else
        family, pages, quality, cover = row[1], row[2], row[3], row[4]
    end
    local over = D.overrides and D.overrides[key]
    if over then
        family = over.family or family
        pages = over.pages or pages
        quality = over.quality or quality
    end
    return { family = family, pages = pages, quality = quality, cover = cover }
end

local function hasTag(item, name)
    local ok, yes = pcall(function() return ItemTag and ItemTag[name] and item:hasTag(ItemTag[name]) end)
    return ok and yes == true
end

local function num(item, method)
    local ok, v = pcall(function() return item[method](item) end)
    return ok and tonumber(v) or 0
end

-- is this literature ours to handle? Skill books, recipe magazines, things
-- you write in, fliers and brochures (fast reads with a picture) and the old
-- newspapers nobody reads are vanilla's.
function R.handles(item)
    if not item or not R.on() then return false end
    local ok, yes = pcall(function()
        if not instanceof(item, "Literature") then return false end
        if SkillBook and SkillBook[item:getSkillTrained()] then return false end
        local recipes = item:getLearnedRecipes()
        if recipes and recipes:size() > 0 then return false end
        if item:canBeWrite() then return false end
        if hasTag(item, "UNINTERESTING") then return false end
        if hasTag(item, "FAST_READ") and not hasTag(item, "NEWSPAPER") then return false end
        return true
    end)
    return ok and yes == true
end

function R.medium(item, kind)
    if hasTag(item, "NEWSPAPER") then return "newspaper" end
    if kind == "comic" then return "comic" end
    if kind == "magazine" or hasTag(item, "MAGAZINE") then return "magazine" end
    if hasTag(item, "PICTUREBOOK") or hasTag(item, "PICTURE") then return "picture" end
    if kind == "book" or kind == "real" then return "novel" end
    return "other"
end

-- everything the rest needs to know about an item, or nil when it is not ours
function R.info(item)
    if not R.handles(item) then return nil end
    local raw = R.rawTitle(item)
    local kind, key = R.parseKey(raw)
    local row = kind and R.lookup(kind, key)
    local medium = R.medium(item, kind)
    local info = { raw = raw, kind = kind, key = key or raw or item:getFullType(), medium = medium, known = row ~= nil }
    if row then
        info.family, info.pages, info.quality = row.family, row.pages, row.quality
        info.real = kind == "real" and D.real[key] or nil
    else
        info.family, info.pages, info.quality = R.FALLBACK.family, R.FALLBACK.pages, R.FALLBACK.quality
        if medium == "newspaper" then
            info.pages = 12 + (R.hash(info.key) % 29)
        elseif medium == "comic" or medium == "picture" then
            info.pages = 24 + (R.hash(info.key) % 25)
        elseif medium == "magazine" then
            info.pages = 60 + (R.hash(info.key) % 81)
        end
    end
    if info.family == "kids" and medium == "novel" then info.medium = "picture" end
    info.boredom = num(item, "getBoredomChange")
    info.stress = num(item, "getStressChange")
    info.unhappy = num(item, "getUnhappyChange")
    if info.medium == "newspaper" and info.boredom == 0 and info.stress == 0 then
        info.boredom, info.stress = -10, -5
    end
    -- the moodle: novels, comics and magazines that the table knows; never
    -- newspapers, never another mod's books
    info.moodle = info.known and info.medium ~= "newspaper"
    return info
end

-- a small stable hash of a string (24 bits, so it stays a plain number)
function R.hash(s)
    local h = 7
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 0x1000000
    end
    return h
end

-- is the pictures-only read (an Illiterate character) all this item allows?
function R.pictureOnly(item)
    return hasTag(item, "PICTUREBOOK") or hasTag(item, "PICTURE")
end

-- the store -------------------------------------------------------------------------

function R.data(player)
    local md = player:getModData()
    local d = md[R.KEY]
    if type(d) ~= "table" then
        d = { v = 1 }
        md[R.KEY] = d
    end
    d.found = d.found or {}
    d.pagesIn = d.pagesIn or {}
    d.marks = d.marks or {}
    d.read = d.read or {}
    return d
end

-- taste ----------------------------------------------------------------------------

-- one liked and one disliked family, rolled the first time they are asked for
function R.tastes(player)
    local d = R.data(player)
    if not d.liked or not d.disliked or d.liked == d.disliked then
        local pool = R.TASTE_POOL
        local a = ZombRand(#pool) + 1
        local b = ZombRand(#pool - 1) + 1
        if b >= a then b = b + 1 end
        d.liked, d.disliked = pool[a], pool[b]
        transmit(player)
    end
    return d.liked, d.disliked
end

function R.tasteOf(player, family)
    if family == "kids" or family == "humor" then return "neutral" end
    local liked, disliked = R.tastes(player)
    if family == liked then return "liked" end
    if family == disliked then return "disliked" end
    return "neutral"
end

function R.tasteKnown(player, family)
    return R.data(player).found[family] == true
end

-- the taste multiplier, pulled toward 1 (or past the table) by the sandbox strength
function R.tasteMult(player, family)
    local base = R.TASTE[R.tasteOf(player, family)] or 1
    local strength = tonumber(R.opt("ReadingTasteStrength", 1)) or 1
    return math.max(0.05, 1 + (base - 1) * strength)
end

function R.qualityMult(quality)
    return R.QUALITY[math.max(1, math.min(5, math.floor(tonumber(quality) or 3)))]
end

-- pages read in a family; the verdict the first time it is found out, else nil
function R.notePages(player, family, pages)
    if not family or family == "kids" or family == "humor" then return nil end
    local d = R.data(player)
    d.pagesIn[family] = (d.pagesIn[family] or 0) + pages
    if d.found[family] or d.pagesIn[family] < R.FOUND_PAGES then return nil end
    d.found[family] = true
    transmit(player)
    local verdict = R.tasteOf(player, family)
    for _, fn in pairs(R.tasteListeners) do pcall(fn, player, family, verdict) end
    return verdict
end

-- relief ---------------------------------------------------------------------------

-- Vitality (or anyone) hooks in here: fn(player, info) -> multiplier on the
-- relief per page, nil for 1
R.reliefHooks = {}
R.durationHooks = {}   -- fn(player, info) -> multiplier on the time a page takes
R.finishListeners = {} -- fn(player, info, result)
R.tasteListeners = {}  -- fn(player, family, verdict)

function R.addReliefHook(tag, fn) R.reliefHooks[tag] = fn end
function R.addDurationHook(tag, fn) R.durationHooks[tag] = fn end
function R.onFinish(tag, fn) R.finishListeners[tag] = fn end
function R.onTasteFound(tag, fn) R.tasteListeners[tag] = fn end

local function hookMult(hooks, player, info)
    local m = 1
    for _, fn in pairs(hooks) do
        local ok, v = pcall(fn, player, info)
        if ok and type(v) == "number" and v > 0 then m = m * v end
    end
    return m
end

function R.finished(player, key)
    return R.data(player).read[key] ~= nil
end

-- the relief one page gives: boredom, stress, unhappiness (negative numbers,
-- on the stats' own scales). A re-read gives REREAD of it in the liked
-- family and nothing elsewhere.
function R.perPage(player, info, reread)
    local ref = info.medium == "novel" and R.NOVEL_REF_PAGES or math.max(1, info.pages)
    local mult = R.tasteMult(player, info.family) * R.qualityMult(info.quality) * hookMult(R.reliefHooks, player, info)
    if reread then
        if R.tasteOf(player, info.family) == "liked" and R.opt("ReadingRereadComfort", true) ~= false then
            mult = mult * R.REREAD
        else
            mult = 0
        end
    end
    return info.boredom / ref * mult, info.stress / 100 / ref * mult, info.unhappy / ref * mult
end

local function nudge(stats, stat, amount, max)
    if amount == 0 then return end
    local v = stats:get(stat) + amount
    stats:set(stat, math.max(0, math.min(max, v)))
end

-- n pages read: the relief, applied at once
function R.applyPages(player, info, n, reread)
    if n <= 0 or serverSide() then return end
    local b, s, u = R.perPage(player, info, reread)
    local stats = player:getStats()
    nudge(stats, CharacterStat.BOREDOM, b * n, 100)
    nudge(stats, CharacterStat.STRESS, s * n, 1)
    nudge(stats, CharacterStat.UNHAPPINESS, u * n, 100)
end

-- a disliked book, every DISLIKE_TICK_MIN minutes: a little boredom back
function R.dislikeTick(player)
    if serverSide() then return end
    nudge(player:getStats(), CharacterStat.BOREDOM, R.DISLIKE_TICK, 100)
end

-- time -----------------------------------------------------------------------------

-- minutes one page takes, before the character's own modifiers
function R.minutesPerPage(player, info)
    local vanilla = 2.0
    pcall(function()
        local v = getSandboxOptions():getOptionByName("MinutesPerPage"):getValue()
        if type(v) == "number" and v > 0 then vanilla = v end
    end)
    local base = info.medium == "novel" and R.MPP_NOVEL or R.MPP_PICTURE
    local scale = tonumber(R.opt("ReadingPageScale", 1)) or 1
    return base * (vanilla / 2.0) * scale * hookMult(R.durationHooks, player, info)
end

-- how many pages "a chapter" is for this title
function R.chapterPages(player, info)
    return math.max(1, math.floor(R.CHAPTER_MINUTES / R.minutesPerPage(player, info) + 0.5))
end

-- bookmarks --------------------------------------------------------------------------

local function itemMark(item)
    local ok, v = pcall(function() return item:getModData()[R.ITEM_KEY] end)
    return ok and tonumber(v) or 0
end

-- where this character is in the title: their own bookmark or the copy's,
-- whichever is further, never past the end
function R.mark(player, item, info)
    local d = R.data(player)
    local mine = tonumber(d.marks[info.key]) or 0
    local pages = math.max(mine, itemMark(item))
    return math.max(0, math.min(info.pages, math.floor(pages)))
end

function R.setMark(player, item, info, pages)
    pages = math.max(0, math.min(info.pages, math.floor(pages)))
    R.data(player).marks[info.key] = pages > 0 and pages or nil
    pcall(function() item:getModData()[R.ITEM_KEY] = pages > 0 and pages or nil end)
end

function R.clearMark(player, item, info)
    R.setMark(player, item, info, 0)
end

-- finishing --------------------------------------------------------------------------

-- 0 none, 1 Good Read, 2 Great Read, 3 Loved It
function R.moodleLevel(player, info)
    if not info.moodle then return 0 end
    if info.medium ~= "novel" and info.medium ~= "picture" then return 1 end
    local liked = R.tasteOf(player, info.family) == "liked"
    local good = info.quality >= 4
    if liked and good then return 3 end
    if liked or good then return 2 end
    return 1
end

function R.moodleHours(info, level)
    if level <= 0 then return 0 end
    local hours = R.SHORT_MOODLE_HOURS
    if info.medium == "novel" or info.medium == "picture" then hours = R.MOODLE_HOURS end
    return hours * (tonumber(R.opt("ReadingMoodleScale", 1)) or 1)
end

function R.strength(player, info, level)
    local s = R.tasteMult(player, info.family) * R.qualityMult(info.quality)
    if level >= 3 then s = s + R.LOVED_BONUS end
    return s
end

local VERDICT = { "poor", "fine", "good", "great", "great" }

function R.verdictFor(info, level)
    if level >= 3 then return "loved" end
    return VERDICT[math.max(1, math.min(5, info.quality))]
end

-- the character finished the title: the record, the verdict and the moodle
-- (no moodle for a re-read). Returns { level, hours, verdict, reread }.
function R.finish(player, info, reread)
    local d = R.data(player)
    local level = reread and 0 or R.moodleLevel(player, info)
    -- a re-read keeps the verdict the first reading gave (recomputed at level 0 it turned "loved" into "great")
    local prior = reread and d.read[info.key]
    local verdict = (prior and prior.verdict) or R.verdictFor(info, level)
    d.read[info.key] = { q = info.quality, family = info.family, when = now(), verdict = verdict, title = R.titleText(info) }
    d.marks[info.key] = nil
    local result = { level = level, hours = 0, verdict = verdict, reread = reread }
    if level > 0 then
        local hours = R.moodleHours(info, level)
        local strength = R.strength(player, info, level)
        local m = d.moodle
        local t = now()
        local running = m and m.level and m.ends and m.ends > t
        if running and (m.level > level or (m.level == level and m.ends - t >= hours)) then
            -- one buff at a time: the running one is better, and stays as it is
            result.kept = true
        else
            R.endMoodle(player)
            d.moodle = { level = level, family = info.family, quality = info.quality, strength = strength,
                         key = info.key, ends = t + hours }
        end
        result.hours = hours
    end
    transmit(player)
    for _, fn in pairs(R.finishListeners) do pcall(fn, player, info, result) end
    return result
end

function R.verdict(player, info)
    local r = R.data(player).read[info.key]
    return r and r.verdict or nil
end

-- the running moodle, or nil
function R.moodle(player)
    local m = R.data(player).moodle
    if not m or not m.ends or m.ends <= now() then return nil end
    return m
end

-- a buff factor scaled by the moodle's strength: 1.05 at 1 becomes 1.0625 at 1.25
local function scaled(factor, strength)
    return 1 + (factor - 1) * (strength or 1)
end
R.scaled = scaled

local function xpMult(player, perkName, value, onlyIfOurs)
    pcall(function()
        local perk = Perks and Perks[perkName]
        if not perk then return end
        local current = player:getXp():getMultiplier(perk)
        if onlyIfOurs then
            if math.abs(current - onlyIfOurs) > 0.001 then return end
        elseif current > 1 then
            return   -- a skill book's multiplier is running; leave it
        end
        addXpMultiplier(player, perk, value, 0, 10)
    end)
end

-- the moodle's XP buffs come off; the moodle record stays for the tooltip until replaced
function R.endMoodle(player)
    local d = R.data(player)
    local m = d.moodle
    if not m then return end
    local buff = R.BUFF[m.family]
    if buff and buff.xp and m.xpOn then
        local ours = type(m.xpOn) == "number" and m.xpOn or R.XP_MULT   -- true before 2026-10-12
        for _, perk in ipairs(buff.xp) do xpMult(player, perk, 1, ours) end
    end
    d.moodle = nil
end

-- once a minute: the running moodle's easing and its genre buff
function R.minute(player)
    if not player or serverSide() then return end
    local d = R.data(player)
    local m = d.moodle
    if not m then return end
    if not m.ends or m.ends <= now() then
        R.endMoodle(player)
        return
    end
    if player:isDead() then return end
    local s = m.strength or 1
    local stats = player:getStats()
    local buff = R.BUFF[m.family]
    if not buff then return end
    if buff.panic then nudge(stats, CharacterStat.PANIC, -buff.panic * s, 100) end
    if buff.stress then nudge(stats, CharacterStat.STRESS, -buff.stress * s, 1) end
    if buff.unhappy then nudge(stats, CharacterStat.UNHAPPINESS, -buff.unhappy * s, 100) end
    if buff.boredom then nudge(stats, CharacterStat.BOREDOM, -buff.boredom * s, 100) end
    if buff.endurance then nudge(stats, CharacterStat.ENDURANCE, buff.endurance * s, 1) end
    if buff.xp and not m.xpOn then
        m.xpOn = scaled(R.XP_MULT, s)   -- the value set, so only ours is taken off
        for _, perk in ipairs(buff.xp) do xpMult(player, perk, m.xpOn, false) end
    end
end

-- the running buff's page-time factor (Serious Reading)
R.addDurationHook("goodread", function(player, info)
    local m = R.moodle(player)
    local buff = m and R.BUFF[m.family]
    return buff and buff.read and scaled(buff.read, m.strength) or nil
end)

-- the moodle's text: the genre, what it does and the hours left
function R.moodleText(player)
    local m = R.moodle(player)
    if not m then return nil end
    local hours = math.max(1, math.floor(m.ends - now() + 0.5))
    return getText("IGUI_DanTraits_Reading_MoodleDesc", R.familyName(m.family),
        getText("IGUI_DanTraits_ReadingBuff_" .. tostring(m.family)), hours)
end

-- the title as text, for the journal: a real book's own, else the game's translation
function R.titleText(info)
    if info.real then return info.real.title end
    if info.raw then
        local ok, text = pcall(getText, info.raw)
        if ok and type(text) == "string" and text ~= info.raw then return text end
    end
    return info.key
end

-- real books ---------------------------------------------------------------------------

local function coverFits(item, cover)
    if cover == "B" then return true end
    if hasTag(item, "SOFTCOVER") then return cover == "S" end
    return cover == "H"   -- hardcovers and the fancy editions
end

-- the real titles a vanilla book could be swapped for, in a stable order
function R.realCandidates(item, family)
    local keys = {}
    for key, row in pairs(D.real) do
        if row.family == family and coverFits(item, row.cover) then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

-- the item becomes the real book `key`: its name and its title, the way the
-- game names its own books (ItemCodeOnCreate), so read-tracking and the
-- vanilla tooltip carry on unchanged
function R.makeReal(item, key)
    local row = D.real[key]
    if not row then return false end
    local ok = pcall(function()
        local base = item:getScriptItem():getDisplayName()
        local title = getText("IGUI_DanTraits_BookBy", row.title, row.author)
        item:setName(getText("IGUI_MagazineNameNoIssue", base, title))
        item:getModData().literatureTitle = R.REAL_PREFIX .. key
        item:getModData()[R.ITEM_KEY] = nil
    end)
    return ok
end

-- a vanilla subject book has the sandbox chance of being a real one of the same family
function R.maybeReal(item)
    if not R.on() then return false end
    local raw = R.rawTitle(item)
    if not raw or raw:sub(1, 15) ~= "IGUI_BookTitle_" then return false end
    local chance = tonumber(R.opt("ReadingRealBookChance", 8)) or 0
    if chance <= 0 or ZombRand(100) >= chance then return false end
    local kind, key = R.parseKey(raw)
    local row = kind and R.lookup(kind, key)
    if not row then return false end
    local candidates = R.realCandidates(item, row.family)
    if #candidates == 0 then return false end
    return R.makeReal(item, candidates[ZombRand(#candidates) + 1])
end

function R.onFillContainer(roomName, containerType, container)
    if not container or not instanceof(container, "ItemContainer") then return end
    local ok, items = pcall(function() return container:getItems() end)
    if not ok or not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        pcall(R.maybeReal, item)
    end
end

-- events --------------------------------------------------------------------------------

local function everyMinute()
    if not R.on() then return end
    for i = 0, R.PLAYERS - 1 do
        local player = getSpecificPlayer(i)
        if player then pcall(R.minute, player) end
    end
end

local function onCreatePlayer(index, player)
    if not player or not R.on() then return end
    pcall(R.tastes, player)
end

Events.OnFillContainer.Add(R.onFillContainer)
Events.EveryOneMinute.Add(everyMinute)
Events.OnCreatePlayer.Add(onCreatePlayer)
