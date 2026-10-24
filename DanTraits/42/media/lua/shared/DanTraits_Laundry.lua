-- Project Zomboid Vitality Project: laundry.
-- Not a trait: every character has it (sandbox option LaundryEnabled, on its
-- own sandbox page; off: washing, wringing and drying are vanilla and nothing
-- here is tracked). The design and its reasoning are in plans/laundry.md.
--
-- Each garment keeps a little state in its mod data (DTL), made the first
-- time the garment is seen, so a garment nobody touches costs nothing:
--
--   o    odour 0..100: sweat and wear push it up, a wash takes it down
--   m    musty: it stayed damp too long; any wash clears it
--   dh   damp hours so far (worn counts LN.WORN_DAMP x)
--   ls   the game hour it was last seen (the damp clock's catch-up)
--   bs   { part = hour } blood first seen on a part
--   st   { part = 0..1 } set-in stain: a wash cannot take that part's blood under it
--   n    washes
--   mw   a washing machine ran with it inside (applied the next time it is seen)
--   lw, lwT  the last wetness read while worn, and when (the body-drying brake)
--   pr   fabric protector left (0..1; DanTraits_LaundryGear.lua)
--   pb   { part = { blood, dirt } } the protected garment's last reading
--   sun  dried on a clothesline in daylight since its last wash
--   sh   ...on a clothesline at home (laundryAtHome)
--   ok   known clean though never washed here (a starting outfit)
--   sw   damp from sweat (worn, away from rain), until it dries or is washed
--   ds   dried with a dryer sheet: the wash count it belongs to (L.sheeted)
--
-- Worn clothes dry on the body much faster in the game than anywhere else
-- (measured 2026-10-11 at 26 C: a soaked tee in about 20 game minutes, 300
-- points an hour, against 20 an hour carried), so wearing clothes straight
-- out of the washer cost nothing. Two brakes on that: each minute a worn
-- garment keeps only LaundryBodyDryRate% (25) of the drying the game gave it
-- since the last minute (rises, from rain or a wash, are left alone), and
-- every hour worn while damp adds LN.DAMP_WEAR odour. Neither applies to
-- sweat: in the heat the game wets worn clothes itself, and a garment that
-- went damp on the body away from rain is marked (sw) until it dries, so it
-- dries at the game's speed, keeps no damp clock and gathers only the sweat
-- odour (hot summer days turned fresh boots stale in two hours, 2026-10-20).
--
-- Seen means: worn or carried (bags included), every ten minutes; anything
-- else when it is next picked up. Damp at LN.DAMP_AT wetness or more; drying
-- under LN.DRY_AT starts the clock over. Damp for LaundryDampHours turns it
-- musty. Worn, sweat (exertion, heat, or just wearing it) raises odour by the
-- garment's layer. The worst worn garment sets the moodle: Stale Clothes at
-- LN.STALE, Musty Clothes when musty or at LN.MUSTY. Each level lifts
-- unhappiness a little, to a low cap (LaundryMood scales it; Germaphobe feels
-- it twice). The good side, for clean clothes: when everything worn that
-- sweats is fresh (odour under LN.FRESH), dry, not dirty or bloody and not
-- musty, Fresh Clothes eases unhappiness and stress a little; Line-Dried
-- (half or more of it dried on a line in daylight since it was washed) twice
-- as much. A dryer sheet in the dryer (DryerSheets, one per load) scents
-- every garment the run leaves dry: worn, it gathers odour at LN.SHEET_ODOUR
-- of the rate until its next wash. Clothes put away never gather odour here,
-- so they stay fresh until worn with or without one. Blood left on a part for LaundryStainDays sets in: half of it,
-- capped at LN.STAIN_CAP, which keeps a washed stain under the game's bloody
-- line. Bleach (DanTraits_LaundryWash.lua) clears stains.
--
-- Mod data on the player (ln prefix): lnEx, lnHeat, lnMins (this ten
-- minutes' exertion and heat), lnMoodle (the level DanTraits_Moodles.lua
-- shows), lnHomeLine (Line-Dried, on a line at home), lnWashers
-- ({ "x,y,z" = true }: washers switched on or seen running, watched until idle),
-- lnDryers (the same for dryers with a sheet in).
--
-- Traits reach in only through hooks (DanTraits_RunHooks), so this module
-- names none of them but Germaphobe; DanTraits_LaundryTraits.lua has them:
--   laundryOdour (1, player)                 sweat odour multiplier
--   laundryMood (1, player, level)           Stale/Musty mood multiplier
--   laundryFresh (1, player, level, d)       Fresh/Line-Dried multiplier
--   laundryMoodle (level, player)            the level shown (0 hides it)
--   laundrySkilled (false, player)           washes one floor better, half the wear
--   laundryAtHome (false, player, x, y, z)   a clothesline at home (the garment's sh)
--   laundryWashed (nil, player, item, method, wasBloody)   after each garment's wash or bleach
--   laundryTooltip (lines, item)             extra garment tooltip lines
require "DanTraits"

DanTraits_Laundry = DanTraits_Laundry or {}
local L = DanTraits_Laundry

-- the numbers, in one table (Kahlua's upvalue cap)
local LN = {
    DAMP_AT       = 30,     -- wetness at which a garment counts as damp
    DRY_AT        = 15,     -- under this it is dry and the clock starts over (a vanilla
                            -- dryer's 90 minutes, one point a minute, leave a soaked load at 10)
    WORN_DAMP     = 1.5,    -- damp hours count this much worn
    DAMP_HOURS    = 6,      -- default LaundryDampHours
    CATCHUP_MAX_H = 72,     -- the most a garment unseen for a while catches up
    STALE         = 50,     -- odour: Stale Clothes
    MUSTY         = 80,     -- odour: Musty Clothes (and where a musty garment starts)
    BASE          = 0.4,    -- odour per hour, just worn
    EXERT         = 1.5,    -- odour per hour, exerting
    HEAT          = 1.0,    -- odour per hour, hot
    HOT_BODY      = 37.5,   -- body temperature that counts as hot
    HOT_AIR       = 27,     -- or air this warm
    BODY_DRY      = 25,     -- default LaundryBodyDryRate: % of the game's drying speed a worn garment keeps
    DAMP_WEAR     = 25,     -- odour per hour worn while damp (x layer, x LaundryOdourRate)
    WORN_GAP_H    = 0.05,   -- a worn reading older than this (3 game minutes) is not continued from
    EXERT_END     = 0.9,    -- endurance under this, moving or fighting, is exertion
    NO_SOAP_ODOUR = 30,     -- a soapless hand wash takes odour down to this
    AIRED_FLOOR   = 30,     -- airing on a line never takes odour under this
    STAIN_DAYS    = 3,      -- default LaundryStainDays
    STAIN_SHARE   = 0.5,    -- of the blood on the part when it sets
    STAIN_CAP     = 0.2,    -- the most a stain can be
    BLOOD_SEEN    = 0.01,   -- blood on a part counts from here
    MOOD1_RATE    = 0.5,    -- unhappiness per hour, Stale Clothes...
    MOOD1_CAP     = 20,     -- ...while under this
    MOOD2_RATE    = 1.0,    -- Musty Clothes
    MOOD2_CAP     = 30,
    GERM_MULT     = 2,      -- Germaphobe: rate x this...
    GERM_CAP      = 10,     -- ...and the cap this much higher
    FRESH         = 15,     -- odour under this (dry, clean, not musty) is fresh
    FRESH1_UNHAPPY = 0.5,   -- unhappiness off per hour, Fresh Clothes
    FRESH1_STRESS = 0.01,   -- stress off per hour (0..1)
    FRESH2_UNHAPPY = 1.0,   -- Line-Dried: twice that
    FRESH2_STRESS = 0.02,
    LINE_SHARE    = 0.5,    -- of the fresh garments line-dried in daylight, for Line-Dried
    WRING         = 50,     -- default LaundryWringLeaves
    WRING_SHOES   = 70,
    WASHER_RADIUS = 4,      -- tiles around the player searched for running washers and dryers
    SHEET_ODOUR   = 0.5,    -- a dryer-sheet garment gathers odour at this share of the rate
    EPS           = 0.005,  -- a patch this close to its floor counts as at it
}
L.C = LN

-- how hard each way of washing is on fabric (chance per garment of a condition point)
local WEAR = { hand = 0.01, board = 0.03, machine = 0.04, bleach = 0.25 }
local WEAR_MODE = { 0, 0.5, 1, 2 }   -- LaundryWear: Off, Gentle, Normal, Harsh

-- body locations by layer: against the skin sweats in full, the outer layer
-- half, anything else (jewellery, bags, belts, armour, masks) not at all.
-- Matched without underscores: Build 42's ids have none (shortpants,
-- tanktop, torsoextravest), so until 2026-10-20 those never sweated
local FULL = {}
for _, k in ipairs({ "underwear", "underwear_top", "underwear_bottom", "underwear_extra1", "underwear_extra2",
    "socks", "shirt", "tshirt", "short_sleeve_shirt", "tank_top", "pants", "pants_skinny", "short_pants",
    "shorts_short", "legs1", "legs5", "torso1", "torso1legs1", "dress", "long_dress", "skirt", "long_skirt",
    "boilersuit", "full_suit", "body_costume", "sweater", "sweater_hat", "jersey", "hands", "hands_left",
    "hands_right", "shoes", "full_top", "bath_robe", "codpiece" }) do FULL[(k:gsub("_", ""))] = true end
local HALF = {}
for _, k in ipairs({ "jacket", "jacket_bulky", "jacket_down", "jacket_hat", "jacket_hat_bulky", "jacket_suit",
    "full_robe", "torso_extra", "torso_extra_vest", "hat", "full_hat", "pants_extra", "scarf", "neck" }) do HALF[(k:gsub("_", ""))] = true end
-- hard gear on a sweating slot: plastic and steel do not hold sweat (ear
-- protectors worn all day for Sensory Issues held Stale Clothes up on
-- 2026-10-19 under an outfit that was all fresh)
local HARD = { Hat_EarMuff_Protectors = true, Hat_Army = true, Hat_ArmyWWII = true, Hat_ArmyDesert = true,
    Hat_ArmyDesertNew = true, Hat_Fireman = true }
function L.isHard(item)
    local t = ""
    pcall(function() t = tostring(item:getType() or "") end)
    return HARD[t] == true or t:find("Helmet") ~= nil or t:find("HardHat") ~= nil
end

-- options ---------------------------------------------------------------------------

function L.on() return DanTraits_SandboxOn("LaundryEnabled") end
local function num(name, default) return DanTraits_SandboxNum(name, default) end
L.num = num

local function now()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end
L.now = now

local function is(obj, class)
    local ok, res = pcall(function() return instanceof(obj, class) end)
    return ok and res == true
end
L.is = is

-- water falling on the player now: rain outside (a drizzle counts), or Take A
-- Bath And Shower's shower or bath (DanTraits_BathingWet); what wets a worn
-- garment then is not sweat
local LN_RAIN_MIN = 0.05
function L.rainedOn(player)
    local wet = false
    pcall(function()
        if DanTraits_BathingWet and DanTraits_BathingWet(player) then wet = true return end
        if not player:isOutside() then return end
        local cm = getClimateManager and getClimateManager()
        wet = cm ~= nil and (cm:getRainIntensity() or 0) >= LN_RAIN_MIN
    end)
    return wet
end

-- the item's laundry state; create = make it if it has none
function L.state(item, create)
    local m
    pcall(function() m = item:getModData() end)
    if not m then return nil end
    local s = m.DTL
    if not s and create then
        s = { o = 0 }
        m.DTL = s
    end
    return s
end

-- clothing carries odour, damp and stains; bags only the wash floors
function L.isClothing(item) return item ~= nil and is(item, "Clothing") end
function L.handles(item) return item ~= nil and (is(item, "Clothing") or is(item, "InventoryContainer")) end

-- "sweaterhat" from base:sweaterhat or Sweater_Hat (DanTraits_BodyLocation in Util)
function L.location(item)
    return DanTraits_BodyLocation(item)
end

function L.layer(item)
    if not L.isClothing(item) then return 0 end
    local loc = L.location(item)
    if FULL[loc] then return 1 end
    if HALF[loc] then return L.isHard(item) and 0 or 0.5 end
    return 0
end

-- { { part = BloodBodyPartType, key = "Torso_Upper", blood = 0..1, dirt = 0..1 }, ... }
function L.snapshot(item)
    local out = {}
    pcall(function()
        local covered = item:getBloodClothingType() and BloodClothingType.getCoveredParts(item:getBloodClothingType())
        if not covered then return end
        for i = 0, covered:size() - 1 do
            local part = covered:get(i)
            out[#out + 1] = { part = part, key = tostring(part), blood = item:getBlood(part) or 0, dirt = item:getDirt(part) or 0 }
        end
    end)
    return out
end

-- the garment's overall Dirty and Bloody figures, from its parts as the game counts them
function L.recount(item, snap)
    if not L.isClothing(item) then return end
    local ok = pcall(function()
        BloodClothingType.calcTotalBloodLevel(item)
        BloodClothingType.calcTotalDirtLevel(item)
    end)
    if ok or #snap == 0 then return end
    local blood, dirt = 0, 0
    for _, p in ipairs(snap) do
        blood = blood + (item:getBlood(p.part) or 0)
        dirt = dirt + (item:getDirt(p.part) or 0)
    end
    pcall(function()
        item:setBloodLevel(blood / #snap * 100)
        item:setDirtiness(dirt / #snap * 100)
    end)
end

local function wetness(item)
    local w = 0
    pcall(function() w = item:getWetness() or 0 end)
    return w
end
L.wetness = wetness

local function setWetness(item, v)
    pcall(function() item:setWetness(math.max(0, math.min(100, v))) end)
end
L.setWetness = setWetness

function L.isStale(s) return s ~= nil and (s.m == true or (s.o or 0) >= LN.STALE) end
function L.isMusty(s) return s ~= nil and (s.m == true or (s.o or 0) >= LN.MUSTY) end

-- 1 Stale, 2 Musty, 0 neither
function L.levelOf(s)
    if L.isMusty(s) then return 2 end
    if L.isStale(s) then return 1 end
    return 0
end

-- seeing a garment: the damp clock and the stains -----------------------------------

local function stainOn(s, key, blood, t)
    s.bs = s.bs or {}
    if blood <= LN.BLOOD_SEEN then
        s.bs[key] = nil
        return
    end
    local since = s.bs[key]
    if not since then
        s.bs[key] = t
        return
    end
    local days = num("LaundryStainDays", LN.STAIN_DAYS)
    if days <= 0 or t - since < days * 24 then return end
    s.st = s.st or {}
    s.st[key] = math.max(s.st[key] or 0, math.min(blood * LN.STAIN_SHARE, LN.STAIN_CAP))
    s.bs[key] = nil
end

-- worn: the damp hours count LN.WORN_DAMP x. t: the game hour (now() when nil).
-- skilled: the one who sees it (a machine wash it went through wears it less)
function L.sight(item, worn, t, skilled)
    if not L.isClothing(item) then return nil end
    t = t or now()
    local s = L.state(item, true)
    if not s then return nil end
    local elapsed = s.ls and math.max(0, math.min(LN.CATCHUP_MAX_H, t - s.ls)) or 0
    s.ls = t
    -- (odour a hard hat gathered before it was known as one)
    if not s.m and (s.o or 0) > 0 and L.isHard(item) then s.o = 0 end
    -- an unworn garment's drying is only worked out when it is looked at or
    -- moved (Java): bring it up to date first, or a shirt drying in a closed
    -- bag would read as soaked all day
    if not worn then pcall(function() item:updateWetness() end) end
    local w = wetness(item)
    if w < LN.DRY_AT then s.sw = nil end
    -- sweat dries on the body at the game's speed; taken off damp, the garment
    -- is on the ordinary damp clock like any other (2026-10-22: a sweat-damp
    -- shirt stuffed in a bag kept its sweat flag and never went musty)
    if not worn then s.sw = nil end
    if w >= LN.DAMP_AT and s.sw then
        -- (sweat on the body: no damp clock)
    elseif w >= LN.DAMP_AT then
        s.dh = (s.dh or 0) + elapsed * (worn and LN.WORN_DAMP or 1)
        if s.dh >= num("LaundryDampHours", LN.DAMP_HOURS) and not s.m then
            s.m = true
            s.o = math.max(s.o or 0, LN.MUSTY)
        end
    elseif w < LN.DRY_AT then
        s.dh = nil
    end
    if num("LaundryStainDays", LN.STAIN_DAYS) > 0 then
        for _, p in ipairs(L.snapshot(item)) do stainOn(s, p.key, p.blood, t) end
    end
    if s.mw then L.machineWashed(item, skilled) end
    return s
end

-- hours left before a damp garment turns musty (nil when not damp or already musty)
function L.mustyIn(item)
    local s = L.state(item, false)
    if (s and (s.m or s.sw)) or wetness(item) < LN.DAMP_AT then return nil end
    return math.max(0, num("LaundryDampHours", LN.DAMP_HOURS) - ((s and s.dh) or 0))
end

-- sweat --------------------------------------------------------------------------------

-- odour per hour on a full-layer garment, from this stretch's share of exertion and heat
function L.rate(exFrac, heatFrac)
    local r = LN.BASE + LN.EXERT * (exFrac or 0) + LN.HEAT * (heatFrac or 0)
    return r * math.max(0, num("LaundryOdourRate", 100)) / 100
end

-- dried with a dryer sheet since its last wash (a machine wash still to be
-- applied counts: the sheet went in after it)
function L.sheeted(s)
    return s ~= nil and s.ds ~= nil and s.ds == (s.n or 0) + (s.mw and 1 or 0)
end

function L.sweat(item, rate, hours)
    local layer = L.layer(item)
    if layer <= 0 then return end
    -- worn damp: the smell of clothes that dried on you
    local s = L.state(item, true)
    if not s then return end
    if wetness(item) >= LN.DAMP_AT and not s.sw then
        rate = rate + LN.DAMP_WEAR * math.max(0, num("LaundryOdourRate", 100)) / 100
    end
    if rate <= 0 then return end
    if L.sheeted(s) then rate = rate * LN.SHEET_ODOUR end
    s.o = math.min(100, (s.o or 0) + rate * layer * hours)
end

-- each minute, worn: give back what the body dried beyond LaundryBodyDryRate%.
-- Only from a reading taken moments ago (a garment just put on, or put back
-- on after drying in a bag, starts a fresh reading). A rise from dry-ish away
-- from rain is sweat (sw): that dries at the game's own speed. rain: rain is
-- falling on the wearer (L.rainedOn)
function L.bodyDry(item, t, rain)
    local s = L.state(item, true)
    if not s then return end
    local w = wetness(item)
    local keep = math.max(0, math.min(100, num("LaundryBodyDryRate", LN.BODY_DRY))) / 100
    if s.lw and s.lwT and t - s.lwT <= LN.WORN_GAP_H then
        if w > s.lw + LN.EPS then
            if rain then s.sw = nil elseif s.lw < LN.DAMP_AT then s.sw = true end
        elseif w < s.lw and keep < 1 and not s.sw then
            w = s.lw - (s.lw - w) * keep
            setWetness(item, w)
        end
    end
    if w < LN.DRY_AT then s.sw = nil end
    if w > 0 then s.lw, s.lwT = w, t else s.lw, s.lwT = nil, nil end
end

-- washing ------------------------------------------------------------------------------

-- does this character wash like a pro (laundrySkilled)
function L.skilled(character)
    return character ~= nil and DanTraits_RunHooks("laundrySkilled", false, character) == true
end

-- method: "hand" | "board"; the floor as a share (0..1). Skilled: a hand wash
-- gets the washboard's floor, a washboard half of it
function L.floor(method, soap, skilled)
    if skilled then
        if method == "board" then return L.floor("board", soap) / 2 end
        method = "board"
    end
    local key, default
    if method == "board" then
        key, default = soap and "LaundryBoardSoapFloor" or "LaundryBoardFloor", soap and 10 or 25
    else
        key, default = soap and "LaundryHandSoapFloor" or "LaundryHandFloor", soap and 20 or 40
    end
    return math.max(0, math.min(100, num(key, default))) / 100
end

local function stainOf(s, key) return (s and s.st and s.st[key]) or 0 end

-- what a wash would leave on a part
local function after(p, floor, s)
    return math.min(p.blood, math.max(floor, stainOf(s, p.key))), math.min(p.dirt, floor)
end

-- the odour a wash leaves
local function odourAfter(s, method, soap, skilled)
    local o = (s and s.o) or 0
    if method == "hand" and not soap and not skilled then return math.min(o, LN.NO_SOAP_ODOUR) end
    return 0
end

-- would this wash do anything: blood or dirt to come off, or odour or must to wash out
function L.canGain(item, method, soap, skilled)
    if not L.handles(item) then return true end
    local s = L.state(item, false)
    local floor = L.floor(method, soap, skilled)
    for _, p in ipairs(L.snapshot(item)) do
        local b, d = after(p, floor, s)
        if p.blood > b + LN.EPS or p.dirt > d + LN.EPS then return true end
    end
    if s and (s.m or (s.o or 0) > odourAfter(s, method, soap, skilled) + 0.5) then return true end
    return false
end

-- a chance per wash at a condition point off; never under 1, never a hole.
-- skilled: half the chance
L.SKILLED_WEAR = 0.5
function L.wear(item, method, skilled)
    local mode = math.floor(num("LaundryWear", 3))
    local k = WEAR_MODE[mode] or 1
    local chance = (WEAR[method] or 0) * k * (skilled and L.SKILLED_WEAR or 1)
    if chance <= 0 or not L.isClothing(item) then return false end
    if not DanTraits_Roll(chance) then return false end
    local worn = false
    pcall(function()
        local c = item:getCondition()
        if c and c > 1 then
            item:setCondition(c - 1)
            worn = true
        end
    end)
    return worn
end

local function washed(item, s)
    s.m = nil
    s.dh = nil
    s.mw = nil
    s.ls = now()
    s.n = (s.n or 0) + 1
    s.sun, s.sh = nil, nil
    s.sw = nil
    if s.pr then s.pr = math.max(0, s.pr - (L.PROTECT_PER_WASH or 0.34)); if s.pr <= 0 then s.pr = nil end end
    s.pb = nil
end

-- after vanilla's hand wash (every part scrubbed to nothing, soaked): each
-- part back up to the floor (or its stain), or to what it was if that was less
function L.applyFloors(item, snap, method, soap, skilled)
    local s = L.state(item, false)
    local floor = L.floor(method, soap, skilled)
    for _, p in ipairs(snap) do
        local b, d = after(p, floor, s)
        pcall(function()
            item:setBlood(p.part, b)
            item:setDirt(p.part, d)
        end)
    end
    L.recount(item, snap)
end

function L.afterHandWash(item, snap, method, soap, skilled)
    L.applyFloors(item, snap, method, soap, skilled)
    local s = L.state(item, L.isClothing(item))
    if not s then return end
    s.o = odourAfter(s, method, soap, skilled)
    washed(item, s)
    L.wear(item, method, skilled)
end

-- bloody by the game's own line (for laundryWashed)
function L.wasBloody(item)
    local bloody = false
    pcall(function() bloody = item:isBloody() == true end)
    return bloody
end

-- a washing machine ran with it inside: blood back up to any stain, fresh.
-- skilled: the one who next sees it (half the wear)
function L.machineWashed(item, skilled)
    local s = L.state(item, true)
    if not s then return end
    if s.st then
        local snap = L.snapshot(item)
        for _, p in ipairs(snap) do
            local st = s.st[p.key]
            if st and p.blood < st then pcall(function() item:setBlood(p.part, st) end) end
        end
        L.recount(item, snap)
    end
    s.o = 0
    washed(item, s)
    L.wear(item, "machine", skilled)
end

-- bleach: every stain and all the blood out, dirt to the soap floor, soaked
function L.bleach(item, method, skilled)
    local snap = L.snapshot(item)
    local floor = L.floor(method or "hand", true, skilled)
    for _, p in ipairs(snap) do
        pcall(function()
            item:setBlood(p.part, 0)
            item:setDirt(p.part, math.min(p.dirt, floor))
        end)
    end
    L.recount(item, snap)
    local s = L.state(item, L.isClothing(item))
    if s then
        s.st, s.bs = nil, nil
        s.o = 0
        washed(item, s)
        L.wear(item, "bleach", skilled)
    end
    setWetness(item, 100)
end

function L.hasStain(item)
    local s = L.state(item, false)
    if not s or not s.st then return false end
    for _, v in pairs(s.st) do if v > 0 then return true end end
    return false
end

-- wringing leaves it this wet at least
function L.wringLeaves(item)
    if L.location(item):find("shoe") then return math.max(num("LaundryWringLeaves", LN.WRING), LN.WRING_SHOES) end
    return num("LaundryWringLeaves", LN.WRING)
end

-- drying ---------------------------------------------------------------------------

-- wetness off; a garment dried under the line is seen at once (the clock starts over)
function L.dry(item, amount)
    setWetness(item, wetness(item) - amount)
    if wetness(item) < LN.DRY_AT then
        local s = L.state(item, false)
        if s then s.dh = nil end
    end
end

-- airing in daylight: odour down, never under the floor, must stays
function L.air(item, amount)
    local s = L.state(item, false)
    if not s or s.m or (s.o or 0) <= LN.AIRED_FLOOR then return end
    s.o = math.max(LN.AIRED_FLOOR, s.o - amount)
end

-- the player: what is worn, what is carried --------------------------------------------

-- every worn item, as a list
function L.worn(player)
    local out = {}
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item then out[#out + 1] = item end
        end
    end)
    return out
end

-- every carried item (bags included), as a list
function L.carried(player)
    local out = {}
    local ok = pcall(function()
        local all = player:getInventory():getAllEvalRecurse(function() return true end, ArrayList.new())
        for i = 0, all:size() - 1 do out[#out + 1] = all:get(i) end
    end)
    if not ok then
        pcall(function()
            local items = player:getInventory():getItems()
            for i = 0, items:size() - 1 do out[#out + 1] = items:get(i) end
        end)
    end
    return out
end

-- clean enough to count as fresh: dry, odour under LN.FRESH, not musty, not
-- dirty or bloody by the game's own reading
function L.isFresh(item)
    local s = L.state(item, false)
    if s and (s.m or (s.o or 0) >= LN.FRESH) then return false end
    if wetness(item) >= LN.DRY_AT then return false end
    local grubby = false
    pcall(function() grubby = item:isDirty() == true or item:isBloody() == true end)
    return not grubby
end

-- the worst level among worn garments that sweat: 1 stale, 2 musty; when
-- there is none and every one of them (shoes aside) is fresh, the good side: -1 Fresh
-- Clothes, -2 Line-Dried. Second value: Line-Dried on a line at home
function L.wornLevel(player)
    local level, count, fresh, sunny, home = 0, 0, true, 0, 0
    for _, item in ipairs(L.worn(player)) do
        if L.layer(item) > 0 then
            local s = L.state(item, false)
            level = math.max(level, L.levelOf(s))
            -- shoes go stale like the rest, but pick up dirt from any walk:
            -- they never stand in the way of fresh
            if L.location(item) ~= "shoes" then
                count = count + 1
                if not L.isFresh(item) then fresh = false
                elseif s and s.sun then
                    sunny = sunny + 1
                    if s.sh then home = home + 1 end
                end
            end
        end
    end
    if level > 0 or count == 0 or not fresh then return level, false end
    if sunny >= count * LN.LINE_SHARE then return -2, home >= count * LN.LINE_SHARE end
    return -1, false
end

-- Germaphobe: the body parts (by name) under stale or musty worn clothes
function L.staleParts(player)
    local parts = {}
    if not L.on() then return parts end
    for _, item in ipairs(L.worn(player)) do
        if L.layer(item) > 0 and L.isStale(L.state(item, false)) then
            pcall(function()
                local covered = item:getCoveredParts()
                for j = 0, covered:size() - 1 do parts[tostring(covered:get(j))] = true end
            end)
        end
    end
    return parts
end
function DanTraits_LaundryStaleParts(player) return L.staleParts(player) end

-- Infection: a musty garment over this body part (its name, "Torso_Upper")
function DanTraits_LaundryMustyOver(player, partName)
    if not L.on() then return false end
    for _, item in ipairs(L.worn(player)) do
        local s = L.state(item, false)
        if s and s.m then
            local over = false
            pcall(function()
                local covered = item:getCoveredParts()
                for j = 0, covered:size() - 1 do
                    if tostring(covered:get(j)) == partName then over = true end
                end
            end)
            if over then return true end
        end
    end
    return false
end

-- Infection (its infectionHazard hook): a musty garment over a wound counts as
-- dirty clothing there, the same x1.5, never on top of the game's own
L.INFECTION_MUSTY = 1.5
DanTraits_AddHook("infectionHazard", function(h, player, part)
    if type(h) ~= "number" or h <= 0 or DanTraits_PartIs(part, "hasDirtyClothing") then return nil end
    local name = nil
    pcall(function() name = tostring(part:getType()) end)
    if name and DanTraits_LaundryMustyOver(player, name) then return h * L.INFECTION_MUSTY end
    return nil
end)

-- washers ------------------------------------------------------------------------------

-- Vanilla's cycle (ClothingWasherLogic, 42.21): every minute it takes 0.02
-- blood and dirt off each part and soaks the garment, and it switches itself
-- off after 90 minutes; nothing can come out while it runs. So a garment is
-- finished by minute 50 at the latest, and the ten-minute look below sees it
-- finished several times over, as long as the washer is watched: from the
-- moment it is switched on (the toggle actions, below), or once the player
-- has stood near it while it ran (a stacked pair's switch is Java).

-- the washing container of a washer that is running now, else nil
function L.runningWasher(obj)
    local container = nil
    pcall(function()
        if is(obj, "IsoClothingWasher") then
            if obj:isActivated() then container = obj:getContainer() end
        elseif is(obj, "IsoCombinationWasherDryer") then
            if obj:isActivated() and obj:isModeWasher() then container = obj:getContainer() end
        elseif is(obj, "IsoStackedWasherDryer") then
            -- (two drums: the washer's own switch and container)
            if obj:isWasherActivated() then container = obj:getContainerByType("clothingwasher") end
        end
    end)
    return container
end

-- the drum a washer washes in, running or not (a combo's one drum, whichever mode)
function L.washerDrum(obj)
    local container = nil
    pcall(function()
        if is(obj, "IsoClothingWasher") or is(obj, "IsoCombinationWasherDryer") then
            container = obj:getContainer()
        elseif is(obj, "IsoStackedWasherDryer") then
            container = obj:getContainerByType("clothingwasher")
        end
    end)
    return container
end

local function isWasher(obj)
    return is(obj, "IsoClothingWasher") or is(obj, "IsoCombinationWasherDryer") or is(obj, "IsoStackedWasherDryer")
end

-- the machine has finished with this garment: vanilla's cycle leaves every part
-- at blood 0 and dirt 0 and the garment soaked. Before that it is only in the
-- drum, and pulling it out early is not a wash.
local function cycleDone(item)
    for _, p in ipairs(L.snapshot(item)) do
        if p.blood > 0 or p.dirt > 0 then return false end
    end
    return wetness(item) >= 100 - 1e-6
end

-- every garment in this drum the cycle has finished with is marked; the effects land when it is next seen
local function markDrum(container)
    if not container then return end
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if L.isClothing(item) and cycleDone(item) then
                local s = L.state(item, true)
                if s then s.mw = true end
            end
        end
    end)
end
L.markDrum = markDrum

-- a running washer marks its load (true); an idle one marks nothing (false)
local function markWasher(obj)
    local container = L.runningWasher(obj)
    if not container then return false end
    markDrum(container)
    return true
end
L.markWasher = markWasher

-- "x,y,z" of the washer's square, the watch list's key
function L.washerKey(obj)
    local key = nil
    pcall(function()
        local sq = obj:getSquare()
        key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    end)
    return key
end

local function squareAt(x, y, z)
    local sq = nil
    pcall(function() sq = getCell():getGridSquare(x, y, z) end)
    return sq
end

local function eachObject(sq, fn)
    pcall(function()
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do fn(objects:get(i)) end
    end)
end

-- washers near the player join the watch list; every watched washer still
-- loaded marks its load while it runs, and once it stands idle marks what it
-- left finished (a cycle that ended since the last look) and drops off
local function watchWashers(player, d)
    local px, py, pz = 0, 0, 0
    pcall(function() px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()) end)
    d.lnWashers = d.lnWashers or {}
    local r = LN.WASHER_RADIUS
    for x = px - r, px + r do
        for y = py - r, py + r do
            local sq = squareAt(x, y, pz)
            if sq then
                eachObject(sq, function(obj)
                    if isWasher(obj) and L.runningWasher(obj) then d.lnWashers[x .. "," .. y .. "," .. pz] = true end
                end)
            end
        end
    end
    for key in pairs(d.lnWashers) do
        local x, y, z = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
        local sq = x and squareAt(tonumber(x), tonumber(y), tonumber(z))
        if sq then
            local running = false
            local idle = {}
            eachObject(sq, function(obj)
                if isWasher(obj) then
                    if markWasher(obj) then running = true else idle[#idle + 1] = obj end
                end
            end)
            if not running then
                for _, obj in ipairs(idle) do markDrum(L.washerDrum(obj)) end
                d.lnWashers[key] = nil
            end
        end
    end
end
L.watchWashers = watchWashers

-- the toggle actions: switched on, the washer is watched however far the
-- player then goes; switched off (or a combo set to dry), what it finished is
-- marked at once, before anything can be taken out
function L.onWasherSwitched(character, obj)
    if not L.on() or not character or not obj then return end
    if L.runningWasher(obj) then
        local key = L.washerKey(obj)
        if not key then return end
        local d = DanTraits_Data(character)
        d.lnWashers = d.lnWashers or {}
        d.lnWashers[key] = true
    else
        markDrum(L.washerDrum(obj))
    end
end

-- dryer sheets ------------------------------------------------------------------------
-- A sheet put in a dryer (the DryerSheets box, ISLaundryAction "sheet") is a
-- flag on the machine's mod data, dtlSheet, so it waits in the drum however
-- long until a run. Vanilla's dryer (ClothingDryerLogic, 42.21) runs 90
-- minutes and nothing can come out while it runs, so the ten-minute look sees
-- the load go dry. Each look at a running sheeted dryer scents every garment
-- in it that is dry (ds); once it stands idle (or is switched off), a last
-- look scents what it left dry and the sheet is spent. Only a watched run
-- spends it: switched on by the toggle actions, or seen running nearby (a
-- stacked pair's switch is Java).

local function isDryer(obj)
    return is(obj, "IsoClothingDryer") or is(obj, "IsoCombinationWasherDryer") or is(obj, "IsoStackedWasherDryer")
end
L.isDryer = isDryer

-- the drying container of a dryer that is running now, else nil
function L.runningDryer(obj)
    local container = nil
    pcall(function()
        if is(obj, "IsoClothingDryer") then
            if obj:isActivated() then container = obj:getContainer() end
        elseif is(obj, "IsoCombinationWasherDryer") then
            if obj:isActivated() and not obj:isModeWasher() then container = obj:getContainer() end
        elseif is(obj, "IsoStackedWasherDryer") then
            if obj:isDryerActivated() then container = obj:getContainerByType("clothingdryer") end
        end
    end)
    return container
end

-- the drum a dryer dries in, running or not
function L.dryerDrum(obj)
    local container = nil
    pcall(function()
        if is(obj, "IsoClothingDryer") or is(obj, "IsoCombinationWasherDryer") then
            container = obj:getContainer()
        elseif is(obj, "IsoStackedWasherDryer") then
            container = obj:getContainerByType("clothingdryer")
        end
    end)
    return container
end

function L.hasSheet(obj)
    local m = nil
    pcall(function() m = obj:getModData() end)
    return m ~= nil and m.dtlSheet == true
end

local function setSheet(obj, on)
    pcall(function()
        obj:getModData().dtlSheet = on or nil
        if isClient and isClient() then obj:transmitModData() end
    end)
end

-- a sheet goes in (the box's use is the caller's)
function L.addSheet(obj)
    if not isDryer(obj) or L.hasSheet(obj) then return false end
    setSheet(obj, true)
    return true
end

-- every dry garment in the drum gets the sheet's scent
local function sheetDrum(container)
    if not container then return end
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if L.isClothing(item) and wetness(item) < LN.DRY_AT then
                local s = L.state(item, true)
                if s then s.ds = (s.n or 0) + (s.mw and 1 or 0) end
            end
        end
    end)
end
L.sheetDrum = sheetDrum

-- a watched dryer has stopped: scent what it left dry, the sheet is spent
local function dryerDone(obj)
    if not L.hasSheet(obj) then return end
    sheetDrum(L.dryerDrum(obj))
    setSheet(obj, false)
end

-- (Kahlua has no next(): an empty watch list goes the long way)
local function dropEmptyDryers(d)
    if not d.lnDryers then return end
    for _ in pairs(d.lnDryers) do return end
    d.lnDryers = nil
end

-- sheeted dryers running near the player join the watch list; each watched one
-- still loaded scents its dry load while it runs, and once idle finishes up
local function watchDryers(player, d)
    local px, py, pz = 0, 0, 0
    pcall(function() px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()) end)
    local r = LN.WASHER_RADIUS
    for x = px - r, px + r do
        for y = py - r, py + r do
            local sq = squareAt(x, y, pz)
            if sq then
                eachObject(sq, function(obj)
                    if isDryer(obj) and L.hasSheet(obj) and L.runningDryer(obj) then
                        d.lnDryers = d.lnDryers or {}
                        d.lnDryers[x .. "," .. y .. "," .. pz] = true
                    end
                end)
            end
        end
    end
    if not d.lnDryers then return end
    for key in pairs(d.lnDryers) do
        local x, y, z = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
        local sq = x and squareAt(tonumber(x), tonumber(y), tonumber(z))
        if sq then
            local running = false
            local idle = {}
            eachObject(sq, function(obj)
                if isDryer(obj) and L.hasSheet(obj) then
                    local drum = L.runningDryer(obj)
                    if drum then
                        sheetDrum(drum)
                        running = true
                    else
                        idle[#idle + 1] = obj
                    end
                end
            end)
            if not running then
                for _, obj in ipairs(idle) do dryerDone(obj) end
                d.lnDryers[key] = nil
            end
        end
    end
    dropEmptyDryers(d)
end
L.watchDryers = watchDryers

-- the toggle actions: a sheeted dryer switched on is watched however far the
-- player goes; a watched one switched off (or a combo set to wash) finishes up
function L.onDryerSwitched(character, obj)
    if not L.on() or not character or not isDryer(obj) or not L.hasSheet(obj) then return end
    local key = L.washerKey(obj)
    if not key then return end
    local d = DanTraits_Data(character)
    if L.runningDryer(obj) then
        d.lnDryers = d.lnDryers or {}
        d.lnDryers[key] = true
    elseif d.lnDryers and d.lnDryers[key] then
        dryerDone(obj)
        d.lnDryers[key] = nil
        dropEmptyDryers(d)
    end
end

local function wrapWasherToggles()
    pcall(require, "TimedActions/ISToggleClothingWasher")
    pcall(require, "TimedActions/ISToggleClothingDryer")
    pcall(require, "TimedActions/ISToggleComboWasherDryer")
    pcall(require, "TimedActions/ISSetComboWasherDryerMode")
    for _, class in ipairs({ ISToggleClothingWasher or false, ISToggleClothingDryer or false, ISToggleComboWasherDryer or false }) do
        if class then
            DanTraits_Wrap(class, "complete", "laundry-washer", function(original, self, ...)
                local result = original(self, ...)
                DanTraits_Guard("laundry-washer", L.onWasherSwitched, self.character, self.object)
                DanTraits_Guard("laundry-dryer", L.onDryerSwitched, self.character, self.object)
                return result
            end)
        end
    end
    if ISSetComboWasherDryerMode then
        DanTraits_Wrap(ISSetComboWasherDryerMode, "complete", "laundry-washer", function(original, self, ...)
            DanTraits_Guard("laundry-washer", markDrum, L.washerDrum(self.object))
            local result = original(self, ...)
            DanTraits_Guard("laundry-dryer", L.onDryerSwitched, self.character, self.object)
            return result
        end)
    end
end
wrapWasherToggles()
if Events and Events.OnGameStart then Events.OnGameStart.Add(wrapWasherToggles) end

-- the clock --------------------------------------------------------------------------

local function flag(player, method)
    local ok, res = pcall(function() return player[method](player) end)
    return ok and res == true
end

-- each minute: was this minute hard work, was it hot
local function sampleMinute(player, d)
    local exert = flag(player, "isSprinting") or flag(player, "isRunning") or flag(player, "isAttacking")
    if not exert then
        local endurance = DanTraits_StatFraction and DanTraits_StatFraction(player:getStats(), CharacterStat.ENDURANCE) or 1
        exert = endurance < LN.EXERT_END and flag(player, "isPlayerMoving")
    end
    local hot = false
    pcall(function()
        local t = player:getStats():get(CharacterStat.TEMPERATURE)
        if type(t) == "number" and t >= LN.HOT_BODY then hot = true end
    end)
    if not hot and DanTraits_AirTemp then
        local air = tonumber(DanTraits_AirTemp(player)) or 0
        hot = air >= LN.HOT_AIR
    end
    d.lnMins = (d.lnMins or 0) + 1
    if exert then d.lnEx = (d.lnEx or 0) + 1 end
    if hot then d.lnHeat = (d.lnHeat or 0) + 1 end
end

-- each minute, awake: the moodle's lift on unhappiness
local function moodMinute(player, d)
    local level = d.lnMoodle or 0
    if level == 0 or DanTraits_Asleep(player) then return end
    local k = math.max(0, num("LaundryMood", 100)) / 100
    if k <= 0 then return end
    if level < 0 then
        -- fresh clothes: a little off unhappiness and stress
        local germ = DanTraits_HasTrait(player, "germaphobe") and LN.GERM_MULT or 1
        germ = germ * math.max(0, tonumber(DanTraits_RunHooks("laundryFresh", 1, player, level, d)) or 1)
        local unhappy = level <= -2 and LN.FRESH2_UNHAPPY or LN.FRESH1_UNHAPPY
        local stress = level <= -2 and LN.FRESH2_STRESS or LN.FRESH1_STRESS
        local stats = player:getStats()
        DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -unhappy * germ * k / 60)
        DanTraits_StatAdd(stats, CharacterStat.STRESS, -stress * germ * k / 60)
        return
    end
    local rate = level >= 2 and LN.MOOD2_RATE or LN.MOOD1_RATE
    local cap = level >= 2 and LN.MOOD2_CAP or LN.MOOD1_CAP
    if DanTraits_HasTrait(player, "germaphobe") then
        rate, cap = rate * LN.GERM_MULT, cap + LN.GERM_CAP
    end
    local tk = math.max(0, tonumber(DanTraits_RunHooks("laundryMood", 1, player, level)) or 1)
    if tk <= 0 then return end
    rate, cap = rate * tk, cap * math.min(1, tk)
    DanTraits_FloorUp(player:getStats(), CharacterStat.UNHAPPINESS, cap * math.min(1, k), rate * k / 60)
end

-- the moodle level from what is worn now
local function refreshLevel(player, d)
    local level, atHome = L.wornLevel(player)
    d.lnHomeLine = atHome or nil
    d.lnMoodle = tonumber(DanTraits_RunHooks("laundryMoodle", level, player)) or level
end

-- each minute: a garment just put on straight from the washer (or the dryer
-- after it) counts as washed at once, and the moodle follows a change of
-- clothes within the minute, not at the next ten-minute look
local function updateLaundryMinute(player, d)
    if not L.on() then
        d.lnMoodle, d.lnEx, d.lnHeat, d.lnMins, d.lnHomeLine = nil, nil, nil, nil, nil
        return
    end
    sampleMinute(player, d)
    local t = now()
    local skilled = nil
    local rain = L.rainedOn(player)
    for _, item in ipairs(L.worn(player)) do
        if L.isClothing(item) then
            local s = L.state(item, false)
            if s and s.mw then
                if skilled == nil then skilled = L.skilled(player) end
                L.machineWashed(item, skilled)
            end
            if wetness(item) > 0 or (s and s.lw) then L.bodyDry(item, t, rain) end
        end
    end
    refreshLevel(player, d)
    moodMinute(player, d)
    if L.shield then L.shield(player, d) end
end

-- every ten minutes: worn and carried garments are seen, worn ones sweat,
-- washers are watched, the moodle level is worked out
local function updateLaundryTen(player, d)
    if not L.on() then return end
    local mins = math.max(1, d.lnMins or 10)
    local rate = L.rate((d.lnEx or 0) / mins, (d.lnHeat or 0) / mins)
    local sweatRate = rate * math.max(0, tonumber(DanTraits_RunHooks("laundryOdour", 1, player)) or 1)
    local hours = mins / 60
    local skilled = L.skilled(player)
    local working = (d.lnEx or 0) > 0 or (d.lnHeat or 0) > 0
    d.lnEx, d.lnHeat, d.lnMins = 0, 0, 0
    local t = now()

    local wornSet = {}
    for _, item in ipairs(L.worn(player)) do wornSet[item] = true end
    for _, item in ipairs(L.carried(player)) do
        if L.isClothing(item) then
            local worn = wornSet[item] == true
            L.sight(item, worn, t, skilled)
            if worn then L.sweat(item, sweatRate, hours) end
        end
    end
    if L.wearPonchos then L.wearPonchos(player, working) end
    watchWashers(player, d)
    watchDryers(player, d)
    if L.watchLines then L.watchLines(player, d) end
    refreshLevel(player, d)
end

L.tenNow = updateLaundryTen   -- the laundry debug command runs a tick on demand
DanTraits_Every("minute", "Laundry", updateLaundryMinute, 40)
DanTraits_Every("ten", "Laundry", updateLaundryTen, 40)

-- for play-testing from the console: every carried garment with its laundry state
function L.report(player)
    local out = {}
    for _, item in ipairs(L.carried(player)) do
        if L.isClothing(item) then
            local s = L.state(item, false) or {}
            out[#out + 1] = string.format("%s wet%d odour%d%s dh%.1f n%d%s", tostring(item:getName()),
                math.floor(wetness(item) + 0.5), math.floor((s.o or 0) + 0.5), s.m and " MUSTY" or "",
                s.dh or 0, s.n or 0, L.hasStain(item) and " stain" or "")
        end
    end
    if #out == 0 then return "no clothing carried" end
    return table.concat(out, "; ")
end
