-- Project Zomboid Vitality Project: small shared helpers.
--
-- The one-liners every trait file used to carry its own copy of: clamping,
-- floor-raising and adding on a stat, dice, body-part lookups, the asleep
-- check, the sandbox toggle and the Moodle Framework updater. It requires
-- nothing and is loaded by DanTraits.lua right after DanTraits_Attrib, so any
-- file that requires "DanTraits" can read these into locals at the top
-- (`local clamp01 = DanTraits_Clamp01`). Core sits near the 200-local limit
-- and this file keeps well under the 60-upvalue one: everything is a global
-- prefixed DanTraits_, and nothing here touches a game object outside pcall.
--
--   DanTraits_DRINK                        named intoxication thresholds, 0..1 (any, tipsy,
--                                          buzz, sober): the one definition of "drunk"
--   DanTraits_DRUNK_LEVELS                 intoxication (0..1) above which Drunk levels 1..4 start
--   DanTraits_NIGHT                        the numbers a night is judged by, shared by Sleep,
--                                          Vitality, Spoons and Migraine: dark / bright (light
--                                          levels), qualityDark / qualityBright (the score
--                                          bonus and penalty), napMaxHours (shorter is a nap),
--                                          gapMin (awake this long ends the night)
--   DanTraits_Clamp01(x)                   x limited to 0..1
--   DanTraits_StatMax(stat)                the stat's maximum (1 when unknown)
--   DanTraits_StatFraction(stats, stat)    0..1 fraction of the stat's range (intoxication
--                                          is 0..100), 0 on failure
--   DanTraits_Intoxication(player)         intoxication as 0..1, 0 on failure
--   DanTraits_Strength(name, player)       another system's 0..1 by the name of its
--                                          getter ("DanTraits_InfectionFever"), resolved
--                                          when called: 0 when that system is not loaded
--   DanTraits_FloorUp(stats, stat, floor, ramp)
--                                          raise the stat toward floor by at
--                                          most ramp; never above floor or the
--                                          stat's maximum (read and write in
--                                          pcall: nothing happens when the stat
--                                          cannot be read). When the stat has a
--                                          delta hook (below) and the floor did
--                                          raise it, records
--                                          d.floorsThisMinute[hookName] = true
--                                          so the pipeline can tell a mod floor
--                                          from the game's own rise
--   DanTraits_StatAdd(stats, stat, amount) add, clamped to 0..maximum (in pcall)
--   DanTraits_Roll(chance01)               true with that chance (0 never, 1 always)
--   DanTraits_RollPercent(pct)             the same on a 0..100 scale, in
--                                          millionths so 0.05 works; goes
--                                          through ZombRand (the queue tests use)
--   DanTraits_RandRange(lo, hi)            a random number in lo..hi
--   DanTraits_Round(x, places)             x rounded to that many decimals (default 2)
--   DanTraits_Over(value, from, full)      0..1 how far value is from `from` to `full`
--   DanTraits_TierOf(value, tiers)         the highest 1-based index in the ascending
--                                          list `tiers` whose point value reaches; 0 under
--                                          the first
--   DanTraits_IsItem(item, fullType)       item:getFullType() == fullType, false on failure
--   DanTraits_ItemUses(item)               uses left (item:getCurrentUses()), 0 on failure
--   DanTraits_FluidName(container)         the container's main fluid, lowercase
--                                          ("coffee", "milk"), nil when empty or unknown
--   DanTraits_FluidRatio(container)        that fluid's share of the mix, 1 on failure
--   DanTraits_AirTemp(player)              the air temperature around the character
--                                          (the game's two-argument form, else one), or nil
--   DanTraits_PanicDecay(stats, perTick)   take perTick (scaled by the frame multiplier)
--                                          off PANIC, not below 0: the frame systems
--                                          that calm you (drink, diazepam)
--   DanTraits_ScaleActionTime(classes, tag, applies, factor)
--                                          wrap getDuration on each class in the list
--                                          (and ISSplint.new, which sets its own time)
--                                          to multiply the time by factor when
--                                          applies(character) is true
--   DanTraits_HeadPainAtLeast(player, value)
--                                          raise the head's additional pain to value
--                                          (never lower it)
--   DanTraits_PartNames                    short console names -> BodyPartType names
--   DanTraits_PartOf(player, shortName)    the BodyPart for a short name, or nil
--   DanTraits_PartNum(part, method)        a numeric BodyPart getter, 0 on failure
--   DanTraits_PartIs(part, method)         a boolean BodyPart getter, false on failure
--   DanTraits_Asleep(player)               whether the player is asleep, false on failure
--   DanTraits_SandboxOn(optionName)        SandboxVars.DanTraits[option] ~= false
--                                          (true when the table is absent)
--   DanTraits_CorpsesNearby(player, radius)
--                                          dead bodies on the squares within
--                                          radius tiles, same floor (0 on failure)
--   DanTraits_Cough(player, radius, why, force)
--                                          the one cough, see "The cough" below
--   DanTraits_DeltaHook(stat, name, cadence [, access])
--                                          the stat delta pipeline, see below
--   DanTraits_DeltaRemember(d, name, value)
--                                          tell the pipeline the stat's value
--                                          after a later writer changed it
--   DanTraits_PainFloor(player, d, source, floor, ramp, hold)
--                                          a system's pain floor for this minute,
--                                          see "Pain floors" below
--   DanTraits_PainBurst(player, amount)    a one-off jolt of pain that fades
--   DanTraits_GrantFoldIn(player, trait, constName, flag)
--                                          a mod trait that carries a vanilla one
--                                          (Steady Hands: Dexterous, Fast Recovery:
--                                          Fast Healer): once the mod trait is seen,
--                                          CharacterTrait[constName] is added once
--                                          and d[flag] remembers it
--   DanTraits_BadMoodle(player, name, value01, tiers)
--                                          Moodle Framework updater for a
--                                          bad-side-only moodle (0.5 is none,
--                                          lower is worse): value 0.5 * (1 - value01)
--                                          and thresholds 0.5 * (1 - t) for the 3 or
--                                          4 tier points given, ascending; or
--                                          { thresholds = { a, b, c, d } } to hand-set them
--   DanTraits_LevelMoodle(player, name, level)
--                                          Moodle Framework updater by level: 1..4
--                                          on the bad side, -1..-4 on the good
--                                          side, 0 for none (DanTraits_Moodles.lua)

-- Shared constants: numbers more than one file judges by, so they are written
-- once. Files load alphabetically, so a reader cannot take them from the
-- file that owns the system (Dependent loads before Alcohol has run; Spoons
-- before Vitality); they live here, where every file can read them at load.
-- Named intoxication thresholds, 0..1. any: had a drink at all; tipsy: the
-- liver is busy and mood lifts; buzz: hangover load starts to build; sober:
-- below this a drinking session is over. Dependent reads any, Hangover buzz
-- and sober, MDD and Diabetes tipsy.
DanTraits_DRINK = { any = 0.01, tipsy = 0.05, buzz = 0.20, sober = 0.05 }
-- intoxication (0..1) above which each Drunk moodle level starts (the game's
-- own lines, used when the moodle cannot be read; Dependent's "a drink" is
-- level 1 rising to level 2)
DanTraits_DRUNK_LEVELS = { 0.10, 0.30, 0.50, 0.70 }
-- the night: Sleep reads the light (dark and bright are light levels; the
-- midpoint, 0.425, is about vanilla's reading threshold) and scores it
-- (qualityDark added after a dark night, qualityBright taken off after a lit
-- one); Vitality decides what a night is (a sleep shorter than napMaxHours is
-- a nap; awake gapMin minutes and the night is over, less and the next sleep
-- is the same night); Spoons and Migraine read the same numbers
DanTraits_NIGHT = { dark = 0.25, bright = 0.60, qualityDark = 0.10, qualityBright = 0.15, napMaxHours = 3, gapMin = 60 }

function DanTraits_Clamp01(x) return math.max(0, math.min(1, x)) end

function DanTraits_StatMax(stat)
    local max = 1
    pcall(function() max = stat:getMaximumValue() or 1 end)
    if not max or max <= 0 then max = 1 end
    return max
end

-- 0..1 fraction of a stat's range, for the ones the game keeps on other
-- scales (intoxication is 0..100)
function DanTraits_StatFraction(stats, stat)
    local value, max = 0, 1
    pcall(function() value = stats:get(stat) or 0 end)
    pcall(function() max = stat:getMaximumValue() or 1 end)
    if not max or max <= 0 then max = 1 end
    if max == 1 and value > 1 then max = 100 end
    return math.max(0, math.min(1, value / max))
end

-- intoxication as a 0..1 fraction of its range
function DanTraits_Intoxication(player)
    local value = 0
    pcall(function() value = DanTraits_StatFraction(player:getStats(), CharacterStat.INTOXICATION) end)
    return value
end

-- Another system's 0..1 reading (a fever, a hangover, a concussion, sleep
-- debt, a low) by the name of its getter, looked up when called so load
-- order does not matter and a system that is not loaded reads 0. The
-- getters never throw by contract; one that does is still caught, logged
-- once (DanTraits_Guard, when core is loaded) and read as 0 rather than
-- taking its reader down.
function DanTraits_Strength(name, player)
    local fn = _G[name]
    if type(fn) ~= "function" then return 0 end
    local ok, value
    if DanTraits_Guard then ok, value = DanTraits_Guard("strength:" .. tostring(name), fn, player)
    else ok, value = pcall(fn, player) end
    if not ok then return 0 end
    return DanTraits_Clamp01(tonumber(value) or 0)
end

-- stat object -> name of the delta hook registered for it (DanTraits_DeltaHook)
DanTraits_DeltaKeys = {}

function DanTraits_FloorUp(stats, stat, floor, ramp)
    local okV, value = pcall(function() return stats:get(stat) end)
    if not okV then return end
    value = tonumber(value) or 0
    floor = math.min(floor, DanTraits_StatMax(stat))
    if value < floor then
        local okS = pcall(function() stats:set(stat, math.min(floor, value + ramp)) end)
        local key = okS and DanTraits_DeltaKeys[stat]
        if key then
            pcall(function()
                local d = DanTraits_Data(getSpecificPlayer(0))
                d.floorsThisMinute = d.floorsThisMinute or {}
                d.floorsThisMinute[key] = true
            end)
        end
    end
end

function DanTraits_StatAdd(stats, stat, amount)
    if not stat then return end
    pcall(function()
        stats:set(stat, math.max(0, math.min(DanTraits_StatMax(stat), (stats:get(stat) or 0) + amount)))
    end)
end

function DanTraits_Roll(chance)
    if chance <= 0 then return false end
    if chance >= 1 then return true end
    if ZombRandFloat then return ZombRandFloat(0, 1) < chance end
    return math.random() < chance
end

function DanTraits_RollPercent(percent)
    if ZombRand then return ZombRand(1000000) < percent * 10000 end
    return math.random() * 100 < percent
end

function DanTraits_RandRange(lo, hi)
    if ZombRandFloat then return ZombRandFloat(lo, hi) end
    return lo + math.random() * (hi - lo)
end

function DanTraits_Round(x, places)
    local k = 10 ^ (places or 2)
    return math.floor(x * k + 0.5) / k
end

function DanTraits_Over(value, from, full)
    return DanTraits_Clamp01((value - from) / (full - from))
end

function DanTraits_TierOf(value, tiers)
    local tier = 0
    value = tonumber(value) or 0
    for i, at in ipairs(tiers) do if value >= at then tier = i end end
    return tier
end

function DanTraits_IsItem(item, fullType)
    if not item then return false end
    local ok, res = pcall(function() return item:getFullType() == fullType end)
    return ok and res == true
end

-- the count of uses left (a full 40-dose pen is 40). getCurrentUses() is the
-- count; getCurrentUsesFloat() is how full it is, 0 to 1 (vanilla shows it
-- x100 as a percent), which made a full pen read as one dose (found in play
-- 2026-10-08). The float stays as a fallback for stand-ins that only have it.
function DanTraits_ItemUses(item)
    local n
    pcall(function() n = item:getCurrentUses() end)
    if tonumber(n) == nil then pcall(function() n = item:getCurrentUsesFloat() end) end
    return tonumber(n) or 0
end

function DanTraits_FluidName(container)
    local name = nil
    pcall(function()
        local fluid = container:getPrimaryFluid()
        if fluid then name = string.lower(tostring(fluid:getFluidTypeString())) end
    end)
    return name
end

function DanTraits_FluidRatio(container)
    local ratio = 1
    pcall(function()
        local fluid = container:getPrimaryFluid()
        if fluid then ratio = container:getRatioForFluid(fluid) or 1 end
    end)
    return ratio
end

-- the installed game has getAirTemperatureForCharacter(character, boolean);
-- older builds took the character alone, so both are tried
function DanTraits_AirTemp(player)
    local temp = nil
    local ok = pcall(function() temp = getClimateManager():getAirTemperatureForCharacter(player, false) end)
    if not ok or temp == nil then pcall(function() temp = getClimateManager():getAirTemperatureForCharacter(player) end) end
    return tonumber(temp)
end

function DanTraits_PanicDecay(stats, perTick)
    local panic = stats:get(CharacterStat.PANIC) or 0
    if panic <= 0 or perTick <= 0 then return end
    local mult = 1
    pcall(function() mult = GameTime.getInstance():getThirtyFPSMultiplier() or 1 end)
    stats:set(CharacterStat.PANIC, math.max(0, panic - perTick * mult))
end

function DanTraits_ScaleActionTime(classes, tag, applies, factor)
    for _, class in ipairs(classes) do
        DanTraits_Wrap(class, "getDuration", tag, function(original, self, ...)
            local t = original(self, ...)
            if type(t) == "number" and t > 1 and applies(self.character) then t = t * factor end
            return t
        end)
    end
    -- the splint sets its time in new(), not getDuration()
    DanTraits_Wrap(ISSplint, "new", tag .. "-splint", function(original, self, character, ...)
        local o = original(self, character, ...)
        pcall(function() if o.maxTime and o.maxTime > 1 and applies(character) then o.maxTime = o.maxTime * factor end end)
        return o
    end)
end

DanTraits_PartNames = {
    hand_l = "Hand_L", hand_r = "Hand_R", forearm_l = "ForeArm_L", forearm_r = "ForeArm_R",
    upperarm_l = "UpperArm_L", upperarm_r = "UpperArm_R", thigh_l = "UpperLeg_L", thigh_r = "UpperLeg_R",
    shin_l = "LowerLeg_L", shin_r = "LowerLeg_R", foot_l = "Foot_L", foot_r = "Foot_R",
    chest = "Torso_Upper", belly = "Torso_Lower", groin = "Groin", head = "Head", neck = "Neck",
}

function DanTraits_PartOf(player, shortName)
    local typeName = DanTraits_PartNames[string.lower(tostring(shortName or ""))]
    if not typeName then return nil end
    local part = nil
    pcall(function() part = player:getBodyDamage():getBodyPart(BodyPartType[typeName]) end)
    return part
end

function DanTraits_PartNum(part, method)
    local v = 0
    pcall(function() v = part[method](part) or 0 end)
    return tonumber(v) or 0
end

function DanTraits_PartIs(part, method)
    local ok, res = pcall(function() return part[method](part) end)
    return ok and res == true
end

function DanTraits_Asleep(player)
    local asleep = false
    pcall(function() asleep = player:isAsleep() end)
    return asleep
end

function DanTraits_SandboxOn(optionName)
    local sv = SandboxVars and SandboxVars.DanTraits
    return not sv or sv[optionName] ~= false
end

function DanTraits_CorpsesNearby(player, radius)
    local count = 0
    pcall(function()
        local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
        local cell = getCell()
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sq = cell:getGridSquare(px + dx, py + dy, pz)
                local bodies = sq and sq:getDeadBodys()
                if bodies then count = count + bodies:size() end
            end
        end
    end)
    return count
end

-- Moodle Framework is client side and optional; without it the trait still
-- works, you just do not get the icon.
function DanTraits_BadMoodle(player, name, value01, tiers)
    if not MF or not MF.getMoodle then return end
    pcall(function()
        local moodle = MF.getMoodle(name, player:getPlayerNum())
        if not moodle then return end
        local th = tiers.thresholds
        if th then
            moodle:setThresholds(th[1], th[2], th[3], th[4])
        elseif #tiers >= 4 then
            moodle:setThresholds(0.5 * (1 - tiers[4]), 0.5 * (1 - tiers[3]), 0.5 * (1 - tiers[2]), 0.5 * (1 - tiers[1]))
        else
            moodle:setThresholds(nil, 0.5 * (1 - tiers[3]), 0.5 * (1 - tiers[2]), 0.5 * (1 - tiers[1]))
        end
        moodle:setValue(0.5 * (1 - value01))
    end)
end

-- a moodle set straight to a level: the thresholds are a tenth apart either
-- side of 0.5 and the value sits in the middle of the level's band
function DanTraits_LevelMoodle(player, name, level)
    if not MF or not MF.getMoodle then return end
    level = math.max(-4, math.min(4, math.floor(tonumber(level) or 0)))
    pcall(function()
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
    end)
end

-- The cough ------------------------------------------------------------------------
-- Asthma and Smoker both cough. There is one primitive and one gap between coughs
-- (COUGH_GAP_MIN game minutes, kept as the world-age hour it ends in
-- d.coughGap), so the two never cough in the same minute:
--
--   DanTraits_Cough(player, radius, why, force)
--     Tries the game's own player:triggerCough(), which zombies hear at its
--     own radius (35 tiles), when the caller wants a cough at least that loud
--     or does not say (radius nil). A quieter cough (Asthma's 6, 10 and 30)
--     is the voice sound plus an addSound at `radius`, as is any cough when the
--     game has no triggerCough. Refused (false) inside the gap unless force is
--     true (an asthma attack's burst); a cough that happens starts the gap, and
--     records d.coughs and d.lastCoughWhy = why. Returns whether it coughed.
local COUGH_GAP_MIN = 3
local COUGH_GAME_RADIUS = 35

function DanTraits_Cough(player, radius, why, force)
    if not player or player:isDead() then return false end
    local d = DanTraits_Data(player)
    local now = 0
    pcall(function() now = getGameTime():getWorldAgeHours() end)
    if not force and (d.coughGap or 0) > now then return false end
    local ok = false
    if not radius or radius >= COUGH_GAME_RADIUS then ok = pcall(function() player:triggerCough() end) end
    if not ok then
        pcall(function() player:playerVoiceSound("Cough") end)
        pcall(function() addSound(player, player:getX(), player:getY(), player:getZ(), radius or 10, radius or 10) end)
    end
    d.coughGap = now + COUGH_GAP_MIN / 60
    d.coughs = (d.coughs or 0) + 1
    d.lastCoughWhy = why
    return true
end

-- The stat delta pipeline ---------------------------------------------------------
-- Several systems scale how fast one stat recovers (endurance: Vitality, Smoker
-- lungs, Blood, Anemia, Concussion, Asthma; catch-a-cold: Vitality, Anemia; food
-- sickness: Iron Gut). Each used to remember its own "last" value and scale
-- whatever had risen since, which made every handler's "gain" include the
-- earlier handlers' cuts. Now there is one remembered value per stat and the
-- systems only subscribe:
--
--   DanTraits_DeltaHook(stat, name, cadence [, access])
--     Registered once (core does it for the three below). Once per cadence,
--     before any other clock system (DanTraits_Every order 0): read the stat,
--     take how much it ROSE since the pipeline last wrote it (the game's own
--     change and anything else outside the pipeline; a fall passes through
--     untouched), run the hook `name` with that delta, and write back
--     last + the delta the hook returns, in 0..the stat's maximum. The
--     remembered value is d.deltaLast[name].
--     stat    a CharacterStat entry, or nil with `access`
--     access  { get = fn(player), set = fn(player, value), max = number or nil }
--             for a value that is not a CharacterStat (catch-a-cold)
--
--   DanTraits_AddHook(name, function(delta, player, d) return delta * k end)
--     Subscribers are pure: they see the game's delta, never each other's
--     writes, and the results multiply (two cuts of 0.5 leave 0.25). Return nil
--     to leave the delta alone.
--
-- Registered in core: enduranceRegen (frame, CharacterStat.ENDURANCE),
-- catchCold (minute, the body's catch-a-cold value) and foodSicknessRise
-- (minute, CharacterStat.FOOD_SICKNESS).
--
-- Mod floors and food sickness: the floors other systems set (hangover,
-- migraine, gluten, diabetes, concussion, MDD side effects) are rises too.
-- DanTraits_FloorUp records d.floorsThisMinute[name] = true when it raised a
-- stat that has a hook; the pipeline clears that flag after each run, so during
-- the run the table says whether a mod floor moved the stat since the last one.
-- A subscriber that must not touch mod-made rises (Iron Gut) checks it.
function DanTraits_DeltaHook(stat, name, cadence, access)
    if stat then DanTraits_DeltaKeys[stat] = name end
    local function read(player)
        if access then return access.get(player) end
        return player:getStats():get(stat)
    end
    return DanTraits_Every(cadence, "Delta:" .. name, function(player, d)
        -- the read is a game-object call (a stat, the body's catch-a-cold), so it is
        -- guarded like the write below; nothing to read, nothing to do
        local okR, now = pcall(read, player)
        now = okR and tonumber(now) or nil
        if not now then return end
        d.deltaLast = d.deltaLast or {}
        local last = d.deltaLast[name]
        if last and now > last then
            local delta = tonumber(DanTraits_RunHooks(name, now - last, player, d)) or (now - last)
            local max = access and access.max or (stat and DanTraits_StatMax(stat)) or nil
            local new = last + math.max(0, delta)
            if max and new > max then new = max end
            if new ~= now then
                pcall(function()
                    if access then access.set(player, new) else player:getStats():set(stat, new) end
                end)
                now = new
            end
        end
        d.deltaLast[name] = now
        if d.floorsThisMinute then d.floorsThisMinute[name] = nil end
    end, 0)
end

function DanTraits_DeltaRemember(d, name, value)
    d.deltaLast = d.deltaLast or {}
    d.deltaLast[name] = value
end

-- Pain floors ---------------------------------------------------------------------
-- Hangover, Caffeine, Migraine, Gluten and alcohol withdrawal hold pain up.
-- The game rebuilds the PAIN stat from the body parts every tick, so writing
-- the stat does nothing (measured in game 2026-09-29: PAIN set to 20 read 0
-- a moment later). Pain goes on the head as additional pain instead: the stat
-- settles at about PAIN_PART_RATIO times the part's pain, less the body's
-- painReduction (0..100, what drink relief sets), which the game subtracts
-- itself, so a drink dulls a headache in proportion. Painkiller pills are
-- vanilla's: their own timer (5400, about 45 game minutes) pulls the stat
-- to 0 while it runs, and the headache returns when it ends (measured in
-- game 2026-09-29; kept on purpose, it is how pills treat wound pain too).
-- The game also decays
-- additional pain by about 1 a minute, so the floor is topped up each minute
-- and fades on its own once no source holds it.
--
--   DanTraits_PainFloor(player, d, source, floor, ramp, hold)
--     floor    the source's floor on the 0..100 pain stat scale
--     ramp     how fast the stat may rise toward it per minute
--     hold     minutes the floor stays registered (default 1; a ten-minute
--              system passes 11 so its floor bridges to its next run)
--     Stores d.painFloors[source]; a later call by the same source replaces
--     the earlier one. Does not touch the body.
--   DanTraits_ApplyPainFloors(player, d)
--     A minute system at order 95 (registered in core, label "PainFloor"): the
--     largest registered floor is applied once, with the ramp of the source
--     that set it, by raising the head's additional pain (never lowering it:
--     Concussion and wounds write it too). Floors whose hold has run out are
--     dropped, and d.painHurting[source] = floor is the health panel's "who
--     is hurting" list. Floors are max-like, not additive.
--   DanTraits_PainBurst(player, amount)
--     A one-off jolt of about `amount` on the stat (a seizure) that fades as
--     the game decays it.
--
-- Migraine's "a pill taken once shortens the attack" still reads the
-- painkiller timer.
local PAIN_PART_RATIO = 0.79    -- stat per point of part pain (measured: 30 -> 23.5, 60 -> 47.5)
DanTraits_PAIN_PART_RATIO = PAIN_PART_RATIO

local function headPart(player)
    local head
    pcall(function() head = player:getBodyDamage():getBodyPart(BodyPartType.Head) end)
    return head
end

local function raiseHead(head, value)
    pcall(function()
        if (head:getAdditionalPain() or 0) < value then head:setAdditionalPain(math.min(100, value)) end
    end)
end

-- a system that writes the head's pain itself (Concussion): never lowers it
function DanTraits_HeadPainAtLeast(player, value)
    local head = player and headPart(player)
    if head and value and value > 0 then raiseHead(head, value) end
end

function DanTraits_PainFloor(player, d, source, floor, ramp, hold)
    if not d or not source then return end
    floor = tonumber(floor) or 0
    if floor <= 0 then return end
    d.painFloors = d.painFloors or {}
    d.painFloors[source] = { floor = floor, ramp = ramp or 1, hold = hold or 1 }
end

function DanTraits_ApplyPainFloors(player, d)
    local floors = d.painFloors
    if not floors then
        d.painHurting = nil
        d.painAdd = nil
        return
    end
    local best, ramp, hurting, keep = 0, 1, {}, nil
    for source, f in pairs(floors) do
        hurting[source] = f.floor
        if f.floor > best then best, ramp = f.floor, f.ramp end
        local left = (f.hold or 1) - 1
        if left > 0 then
            keep = keep or {}
            keep[source] = { floor = f.floor, ramp = f.ramp, hold = left }
        end
    end
    d.painFloors = keep
    d.painHurting = hurting
    local head = headPart(player)
    if best <= 0 or not head then return end
    local value = math.min(best / PAIN_PART_RATIO, (d.painAdd or 0) + ramp / PAIN_PART_RATIO)
    d.painAdd = value
    raiseHead(head, value)
end

function DanTraits_PainBurst(player, amount)
    local head = player and headPart(player)
    if not head or not amount or amount <= 0 then return end
    pcall(function()
        head:setAdditionalPain(math.min(100, (head:getAdditionalPain() or 0) + amount / PAIN_PART_RATIO))
    end)
end

-- Fold-ins ------------------------------------------------------------------------
-- A mod trait that carries a vanilla one grants it once, the first time the
-- mod trait is seen (a new character, or the trait added later). Returns
-- whether it is granted now. Deep Sleeper's Wakeful predates this and keeps
-- its own copy in DanTraits_Sleep.lua.
function DanTraits_GrantFoldIn(player, trait, constName, flag)
    if not player or not DanTraits_HasTrait or not DanTraits_HasTrait(player, trait) then return false end
    local d = DanTraits_Data(player)
    if d[flag] then return true end
    if not DanTraits_SetTrait then return false end
    local ok = DanTraits_SetTrait(player, "base:" .. tostring(constName), true)
    if ok then d[flag] = true end
    return ok
end
