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
--
-- Worn clothes dry on the body much faster in the game than anywhere else
-- (measured 2026-10-11 at 26 C: a soaked tee in about 20 game minutes, 300
-- points an hour, against 20 an hour carried), so wearing clothes straight
-- out of the washer cost nothing. Two brakes on that: each minute a worn
-- garment keeps only LaundryBodyDryRate% (25) of the drying the game gave it
-- since the last minute (rises, from rain or a wash, are left alone), and
-- every hour worn while damp adds LN.DAMP_WEAR odour.
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
-- as much. Blood left on a part for LaundryStainDays sets in: half of it,
-- capped at LN.STAIN_CAP, which keeps a washed stain under the game's bloody
-- line. Bleach (DanTraits_LaundryWash.lua) clears stains.
--
-- Mod data on the player (ln prefix): lnEx, lnHeat, lnMins (this ten
-- minutes' exertion and heat), lnMoodle (the level DanTraits_Moodles.lua
-- shows), lnHomeLine (Line-Dried, on a line at home), lnWashers
-- ({ "x,y,z" = true }: washers seen running).
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
    DRY_AT        = 10,     -- under this it is dry and the clock starts over
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
    WASHER_RADIUS = 4,      -- tiles around the player searched for running washers
    EPS           = 0.005,  -- a patch this close to its floor counts as at it
}
L.C = LN

-- how hard each way of washing is on fabric (chance per garment of a condition point)
local WEAR = { hand = 0.01, board = 0.03, machine = 0.04, bleach = 0.25 }
local WEAR_MODE = { 0, 0.5, 1, 2 }   -- LaundryWear: Off, Gentle, Normal, Harsh

-- body locations by layer: against the skin sweats in full, the outer layer
-- half, anything else (jewellery, bags, belts, armour, masks) not at all
local FULL = {}
for _, k in ipairs({ "underwear", "underwear_top", "underwear_bottom", "underwear_extra1", "underwear_extra2",
    "socks", "shirt", "tshirt", "short_sleeve_shirt", "tank_top", "pants", "pants_skinny", "short_pants",
    "shorts_short", "legs1", "legs5", "torso1", "torso1legs1", "dress", "long_dress", "skirt", "long_skirt",
    "boilersuit", "full_suit", "body_costume", "sweater", "sweater_hat", "jersey", "hands", "hands_left",
    "hands_right", "shoes", "full_top", "bath_robe", "codpiece" }) do FULL[k] = true end
local HALF = {}
for _, k in ipairs({ "jacket", "jacket_bulky", "jacket_down", "jacket_hat", "jacket_hat_bulky", "jacket_suit",
    "full_robe", "torso_extra", "torso_extra_vest", "hat", "full_hat", "pants_extra", "scarf", "neck" }) do HALF[k] = true end

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

-- "shirt" from base:shirt, ItemBodyLocation or a plain string
function L.location(item)
    local loc = ""
    pcall(function() loc = tostring(item:getBodyLocation() or "") end)
    return (loc:lower():gsub("^.*:", ""))
end

function L.layer(item)
    if not L.isClothing(item) then return 0 end
    local loc = L.location(item)
    if FULL[loc] then return 1 end
    if HALF[loc] then return 0.5 end
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
    -- an unworn garment's drying is only worked out when it is looked at or
    -- moved (Java): bring it up to date first, or a shirt drying in a closed
    -- bag would read as soaked all day
    if not worn then pcall(function() item:updateWetness() end) end
    local w = wetness(item)
    if w >= LN.DAMP_AT then
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
    if (s and s.m) or wetness(item) < LN.DAMP_AT then return nil end
    return math.max(0, num("LaundryDampHours", LN.DAMP_HOURS) - ((s and s.dh) or 0))
end

-- sweat --------------------------------------------------------------------------------

-- odour per hour on a full-layer garment, from this stretch's share of exertion and heat
function L.rate(exFrac, heatFrac)
    local r = LN.BASE + LN.EXERT * (exFrac or 0) + LN.HEAT * (heatFrac or 0)
    return r * math.max(0, num("LaundryOdourRate", 100)) / 100
end

function L.sweat(item, rate, hours)
    local layer = L.layer(item)
    if layer <= 0 then return end
    -- worn damp: the smell of clothes that dried on you
    if wetness(item) >= LN.DAMP_AT then
        rate = rate + LN.DAMP_WEAR * math.max(0, num("LaundryOdourRate", 100)) / 100
    end
    if rate <= 0 then return end
    local s = L.state(item, true)
    if not s then return end
    s.o = math.min(100, (s.o or 0) + rate * layer * hours)
end

-- each minute, worn: give back what the body dried beyond LaundryBodyDryRate%.
-- Only from a reading taken moments ago (a garment just put on, or put back
-- on after drying in a bag, starts a fresh reading).
function L.bodyDry(item, t)
    local s = L.state(item, true)
    if not s then return end
    local w = wetness(item)
    local keep = math.max(0, math.min(100, num("LaundryBodyDryRate", LN.BODY_DRY))) / 100
    if s.lw and s.lwT and t - s.lwT <= LN.WORN_GAP_H and w < s.lw and keep < 1 then
        w = s.lw - (s.lw - w) * keep
        setWetness(item, w)
    end
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

-- the washing container of a washer that is running now, else nil
function L.runningWasher(obj)
    local container = nil
    pcall(function()
        if is(obj, "IsoClothingWasher") then
            if obj:isActivated() then container = obj:getContainer() end
        elseif is(obj, "IsoCombinationWasherDryer") then
            if obj:isActivated() and obj:isModeWasher() then container = obj:getContainer() end
        end
    end)
    return container
end

local function isWasher(obj) return is(obj, "IsoClothingWasher") or is(obj, "IsoCombinationWasherDryer") end

-- every garment in a running washer is marked; the effects land when it is next seen
local function markWasher(obj)
    local container = L.runningWasher(obj)
    if not container then return false end
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if L.isClothing(item) then
                local s = L.state(item, true)
                if s then s.mw = true end
            end
        end
    end)
    return true
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
-- loaded marks its load while it runs, and drops off once it stands idle
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
            eachObject(sq, function(obj) if isWasher(obj) and markWasher(obj) then running = true end end)
            if not running then d.lnWashers[key] = nil end
        end
    end
end
L.watchWashers = watchWashers

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

local function updateLaundryMinute(player, d)
    if not L.on() then
        d.lnMoodle, d.lnEx, d.lnHeat, d.lnMins, d.lnHomeLine = nil, nil, nil, nil, nil
        return
    end
    sampleMinute(player, d)
    moodMinute(player, d)
    local t = now()
    for _, item in ipairs(L.worn(player)) do
        if L.isClothing(item) and (wetness(item) > 0 or (L.state(item, false) or {}).lw) then L.bodyDry(item, t) end
    end
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
    if L.watchLines then L.watchLines(player, d) end
    local level, atHome = L.wornLevel(player)
    d.lnHomeLine = atHome or nil
    d.lnMoodle = tonumber(DanTraits_RunHooks("laundryMoodle", level, player)) or level
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
