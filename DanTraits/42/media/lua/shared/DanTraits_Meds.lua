-- Project Zomboid Vitality Project: the shared medication system.
--
-- One list of drugs (DanTraits_Drugs). Each trait asks this file how well a
-- character is covered instead of keeping its own pill bookkeeping, and the
-- tracking UI to come reads everything from here.
--
-- Daily drugs (beta blockers, anticonvulsants, metformin, baclofen,
-- amantadine) track two numbers:
--   level  what is in your system: every pill adds one, it halves every
--          halfH hours. Covered while it is at least onAt.
--   built  0..1, how well the drug works: it climbs for each minute you are
--          covered (full after buildDays) and slides back while you are not
--          (to nothing after fadeDays). The trait reads this as the effect.
-- So the first pill helps a little, a few days of regular doses give the full
-- effect, and a missed dose dents it instead of dropping you off a cliff.
-- A character who starts with the trait starts built up (DanTraits_MedStart).
--
-- Rescue drugs (diazepam, sumatriptan) and course drugs (prednisone, taken through an MS
-- flare) work at once: the effect is 1 while covered.
-- Regimen drugs keep their model in their trait file and lend it to this one
-- through state() (antidepressants: Depression's two-week streak). Supplements
-- (iron) only get the side effect roll here.
--
-- Side effects: the first dose on each game day rolls the side effect chance
-- (sandbox MedSideEffectChance, percent, default 3; 0 turns them off). A hit
-- runs that drug's mild side effect for sideH hours. Too much (level above
-- overAt) runs its overdose effect for as long as the level stays up.
--
-- A drug can also do something every minute it is in the system, for anyone
-- who takes it (taking: prednisone's hunger, baclofen's drowsiness while
-- awake, amantadine's dry mouth), and say when it wears off (lapse, for those
-- with the trait in lapseTrait; Heart Condition and Epilepsy say their own).
--
-- Effects are a small vocabulary, applied every minute while they run:
--   fatigue  tiredness added a minute      stress   stress added a minute
--   hunger   hunger added a minute         thirst   thirst added a minute
--   sick     food sickness floor (0..100; 30 shows the game's nausea moodle)
--   regen    endurance recovery x this     faint    chance a minute of fainting (awake)
-- overH: hours an overdose keeps running after the level falls back under
-- overAt (the quick-clearing drugs; the slow ones stay over long enough).
--   heart    (overdose) strain on the heart: Heart Condition's chest pain twice as likely
--
-- Vanilla beta blockers: their own effect (a large, short panic drop) is put
-- back the way it was after the pill, so they only do what this list says.
-- That panic drop belongs to diazepam now.
--
-- Mod data: meds[id] = { lvl, built, day (last game day dosed), sideMin
-- (minutes of side effect left), over (overdose running), overMin (minutes
-- of it left) }.
-- Old saves: the traits' own levels (hcBeta, epMeds, diaMedMinutes, msPred,
-- msBac, msAman) are carried across as each turns up.
-- Console: meds | meds take <id> | meds side <id>
require "DanTraits"

local notify = DanTraits_Notify

local SIDE_CHANCE_DEFAULT = 3          -- percent, on each day a drug is taken
local DZ_PANIC_RATE       = 0.6        -- diazepam: panic per 30fps tick, the vanilla beta blocker rate

-- The drug list. items: lower-case item types (getType) that are a dose.
-- treats: trait ids (or what it is for), for the tooltip and the UI. kind: daily | rescue | course | regimen | supplement.
DanTraits_Drugs = {
    beta = {
        items = { "pillsbeta" }, treats = { "heart" }, kind = "daily",
        halfH = 24, onAt = 0.5, overAt = 3, buildDays = 3, fadeDays = 3,   -- once a day, like metformin
        side = { regen = 0.8 }, sideH = 8,
        over = { fatigue = 0.0005, faint = 0.002 },
    },
    anticonvulsant = {
        items = { "anticonvulsants" }, treats = { "epilepsy" }, kind = "daily",
        halfH = 12, onAt = 0.5, overAt = 3, buildDays = 5, fadeDays = 3,
        side = { fatigue = 0.0003 }, sideH = 8,
        over = { fatigue = 0.0012, regen = 0.7 },
    },
    metformin = {
        items = { "metformin" }, treats = { "diabetes2" }, kind = "daily",
        halfH = 24, onAt = 0.5, overAt = 3, buildDays = 2, fadeDays = 2,
        side = { sick = 30 }, sideH = 8,
        over = { sick = 50 },
    },
    antidepressant = {
        items = { "pillsantidep" }, treats = { "spiraling" }, kind = "regimen",
        side = { sick = 30 }, sideH = 8,
        state = function(player)
            if not DanTraits_MddBenefit or not DanTraits_HasTrait(player, "spiraling") then return nil end
            local d = DanTraits_Data(player)
            return d.mddMedDays or 0, DanTraits_MddBenefit(player)
        end,
    },
    diazepam = {
        items = { "diazepam" }, treats = { "panic" }, kind = "rescue",
        halfH = 1.5, onAt = 0.5, overAt = 2.5,
        side = { fatigue = 0.0004 }, sideH = 6,
        overH = 3,   -- the overdose lasts at least this long after the level falls back
        over = { fatigue = 0.0015, regen = 0.7 },
    },
    iron = {
        items = { "ironpills" }, treats = { "anemic" }, kind = "supplement",
        side = { sick = 30 }, sideH = 4,
    },
    -- Multiple Sclerosis (DanTraits_MS.lua reads the effect)
    prednisone = {
        items = { "prednisone" }, treats = { "ms" }, kind = "course",
        halfH = 24, onAt = 0.5, overAt = 3,
        taking = { hunger = 0.0002 },
        side = { stress = 0.001 }, sideH = 8,   -- the game eases stress itself: this nets about 0.05 an hour
        over = { stress = 0.001, hunger = 0.0004 },
        lapse = "UI_DanTraits_MSPredLapse", lapseTrait = "ms",
    },
    baclofen = {
        items = { "baclofen" }, treats = { "ms" }, kind = "daily",
        halfH = 12, onAt = 0.5, overAt = 3, buildDays = 2, fadeDays = 2,
        taking = { fatigue = 0.0001 },
        side = { regen = 0.85 }, sideH = 8,
        over = { fatigue = 0.0015, regen = 0.6 },
        lapse = "UI_DanTraits_MSBacLapse", lapseTrait = "ms",
    },
    amantadine = {
        items = { "amantadine" }, treats = { "ms" }, kind = "daily",
        halfH = 12, onAt = 0.5, overAt = 3, buildDays = 3, fadeDays = 3,
        taking = { thirst = 0.0001 },
        side = { sick = 30 }, sideH = 6,
        over = { stress = 0.0015 },
        lapse = "UI_DanTraits_MSAmanLapse", lapseTrait = "ms",
    },
    -- Everything else that is taken. The trait files still do what each one is
    -- for (the inhaler's relief, the gum's craving, the game's own painkiller,
    -- sleeping and caffeine effects); the list adds the level, side effects and
    -- too many at once. The inhaler action doses anyone who uses it.
    inhaler = {
        items = { "inhaler" }, treats = { "asthma" }, kind = "rescue",
        halfH = 0.5, onAt = 0.5, overAt = 4,   -- five puffs close together
        overH = 1,   -- the overdose lasts at least this long after the level falls back
        over = { stress = 0.002, heart = true },
    },
    nicotinegum = {
        items = { "nicotinegum" }, treats = { "smoker" }, kind = "rescue",
        halfH = 1, onAt = 0.5, overAt = 3,
        side = { sick = 30 }, sideH = 2,
        overH = 2,   -- the overdose lasts at least this long after the level falls back
        over = { sick = 50 },
    },
    -- Migraines (DanTraits_Migraine.lua reads the cover and runs the day after)
    sumatriptan = {
        items = { "sumatriptan" }, treats = { "migraine" }, kind = "rescue",
        halfH = 2, onAt = 0.5, overAt = 2.5,   -- three close together
        overH = 4,   -- the overdose lasts at least this long after the level falls back
        over = { stress = 0.002, heart = true },   -- chest tightness
    },
    painkillers = {
        items = { "pills" }, treats = { "pain" }, kind = "rescue",
        halfH = 2, onAt = 0.5, overAt = 3.5,   -- four or more at once
        side = { sick = 30 }, sideH = 4,
        overH = 4,   -- the overdose lasts at least this long after the level falls back
        over = { sick = 60 },
    },
    sleepingtablets = {
        items = { "pillssleepingtablets" }, treats = { "sleep" }, kind = "rescue",
        halfH = 8, onAt = 0.5, overAt = 2.5,
        side = { fatigue = 0.0003 }, sideH = 8,   -- taken at bedtime: groggy into the next day
        overH = 6,   -- the overdose lasts at least this long after the level falls back
        over = { fatigue = 0.0015, faint = 0.003 },
    },
    caffeinepills = {
        items = { "pillsvitamins" }, treats = { "tired" }, kind = "rescue",
        halfH = 5, onAt = 0.5, overAt = 3,
        overH = 3,   -- the overdose lasts at least this long after the level falls back
        over = { stress = 0.002, heart = true },
    },
    -- insulin: Diabetes keeps the doses (a low blood sugar is its overdose);
    -- listed so the tracking UI can show the doses on board
    insulin = {
        items = { "insulinpen" }, treats = { "diabetes1", "diabetes2" }, kind = "regimen",
        state = function(player)
            local d = DanTraits_Data(player)
            local doses = 0
            for _, shot in ipairs(d.diaInsulin or {}) do doses = doses + (shot.dose or 0) end
            return doses, 0
        end,
    },
}

-- lower-case item type -> drug id
local byItem = {}
for id, drug in pairs(DanTraits_Drugs) do
    for _, item in ipairs(drug.items or {}) do byItem[item] = id end
end

function DanTraits_DrugOfItem(kind)
    return byItem[string.lower(tostring(kind or ""))]
end

local function medsOf(d)
    d.meds = d.meds or {}
    return d.meds
end

local function stateOf(d, id)
    local m = medsOf(d)
    m[id] = m[id] or { lvl = 0, built = 0 }
    return m[id]
end

local function today()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() or 0 end)
    return math.floor(h / 24)
end

local function sideChance()
    local sv = SandboxVars and SandboxVars.DanTraits
    local v = sv and tonumber(sv.MedSideEffectChance)
    if v == nil then return SIDE_CHANCE_DEFAULT end
    return math.max(0, v)
end

-- Old saves kept their own levels; carry each across the first time it turns
-- up, so nobody loses cover on update (a protecting level counts as fully
-- built up). Checked every time: the MS levels came later than the rest.
local OLD_KEYS = { hcBeta = "beta", epMeds = "anticonvulsant", msPred = "prednisone", msBac = "baclofen", msAman = "amantadine" }

local function migrate(d)
    local function carry(id, lvl)
        if not lvl or lvl <= 0 then return end
        local s = stateOf(d, id)
        s.lvl = math.max(s.lvl, lvl)
        if lvl >= DanTraits_Drugs[id].onAt then s.built = 1 end
    end
    for key, id in pairs(OLD_KEYS) do
        if d[key] ~= nil then
            carry(id, tonumber(d[key]))
            d[key] = nil
        end
    end
    if d.diaMedMinutes ~= nil then
        if d.diaMedMinutes > 0 then carry("metformin", d.diaMedMinutes / 1440) end
        d.diaMedMinutes = nil
    end
end

-- Reading ---------------------------------------------------------------------

-- what is in the system now, and how built up (0..1)
function DanTraits_MedState(player, id)
    local drug = DanTraits_Drugs[id]
    if not drug or not player then return 0, 0 end
    if drug.state then
        local lvl, built = drug.state(player)
        return lvl or 0, built or 0
    end
    local d = DanTraits_Data(player)
    migrate(d)
    local s = medsOf(d)[id]
    if not s then return 0, 0 end
    return s.lvl or 0, s.built or 0
end

-- enough in the system to count as a dose that is working
function DanTraits_MedCovered(player, id)
    local drug = DanTraits_Drugs[id]
    if not drug or not drug.onAt then return false end
    local lvl = DanTraits_MedState(player, id)
    return lvl >= drug.onAt
end

-- the good side of a drug's moodle, the same rule for every drug that shows
-- one: 0 not in the system, 1 in the system but still building up (the
-- paler green), 2 fully built up (the full green). A rescue drug has no
-- build-up, so it is 2 whenever it is in the system.
function DanTraits_MedMoodle(player, id)
    local drug = DanTraits_Drugs[id]
    if not drug or not DanTraits_MedCovered(player, id) then return 0 end
    if drug.buildDays then
        local _, built = DanTraits_MedState(player, id)
        if built < 1 then return 1 end
    end
    return 2
end

-- a stimulant overdose running (the inhaler, caffeine pills): Heart Condition reads it
function DanTraits_MedHeartStrain(player)
    local d = player and DanTraits_Data(player)
    if not d or not d.meds then return false end
    for id, s in pairs(d.meds) do
        local drug = DanTraits_Drugs[id]
        if s.over and drug and drug.over and drug.over.heart then return true end
    end
    return false
end

-- 0..1: how well the drug is working right now
function DanTraits_MedEffect(player, id)
    local drug = DanTraits_Drugs[id]
    if not drug then return 0 end
    -- no build-up (rescue and course drugs): it works fully while it is in the system
    if not drug.buildDays and not drug.state then return DanTraits_MedCovered(player, id) and 1 or 0 end
    local _, built = DanTraits_MedState(player, id)
    return built
end

-- Dosing ------------------------------------------------------------------------

local function rollSide(player, d, id)
    local drug = DanTraits_Drugs[id]
    if not drug.side then return end
    local s = stateOf(d, id)
    local day = today()
    if s.day == day then return end
    s.day = day
    if DanTraits_Roll(sideChance() / 100) then
        s.sideMin = (drug.sideH or 8) * 60
        notify(player, "UI_DanTraits_MedSide_" .. id)
    end
end

-- a dose of a drug (amount in pills, default 1); returns the new level
function DanTraits_MedTake(player, id, amount)
    local drug = DanTraits_Drugs[id]
    if not drug or not player then return 0 end
    local d = DanTraits_Data(player)
    migrate(d)
    rollSide(player, d, id)
    if not drug.halfH then return 0 end
    local s = stateOf(d, id)
    s.lvl = (s.lvl or 0) + (amount or 1)
    return s.lvl
end

-- a new character who has been on this drug for years: dosed this morning, fully built up
function DanTraits_MedStart(player, id)
    local drug = DanTraits_Drugs[id]
    if not drug or not drug.halfH or not player then return end
    local d = DanTraits_Data(player)
    migrate(d)
    local s = stateOf(d, id)
    s.lvl = math.max(s.lvl or 0, 1)
    s.built = 1
    s.day = today()
end

-- Every minute -------------------------------------------------------------------

local function applyEffect(player, d, fx, awakeOnly)
    local stats = player:getStats()
    if fx.fatigue and not (awakeOnly and DanTraits_Asleep(player)) then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, fx.fatigue) end
    if fx.stress then DanTraits_StatAdd(stats, CharacterStat.STRESS, fx.stress) end
    if fx.hunger then DanTraits_StatAdd(stats, CharacterStat.HUNGER, fx.hunger) end
    if fx.thirst then DanTraits_StatAdd(stats, CharacterStat.THIRST, fx.thirst) end
    if fx.sick then pcall(function() DanTraits_FloorUp(stats, CharacterStat.FOOD_SICKNESS, fx.sick, 1) end) end
    if fx.faint and DanTraits_PassOut and not DanTraits_Asleep(player) and not (DanTraits_IsPassedOut and DanTraits_IsPassedOut(player))
        and DanTraits_Roll(fx.faint) then
        DanTraits_PassOut(player, DanTraits_RandRange(2, 5), "UI_DanTraits_ComeTo", false)
    end
end

local function updateDrug(player, d, id, drug, s)
    local was = drug.onAt and (s.lvl or 0) >= drug.onAt
    if drug.halfH and (s.lvl or 0) > 0 then
        s.lvl = s.lvl * 0.5 ^ (1 / (drug.halfH * 60))
        if s.lvl < 0.01 then s.lvl = 0 end
    end
    local covered = drug.onAt and (s.lvl or 0) >= drug.onAt
    if was and not covered and drug.lapse
        and (not drug.lapseTrait or DanTraits_HasTrait(player, drug.lapseTrait)) then
        notify(player, drug.lapse)
    end
    if covered and drug.taking then applyEffect(player, d, drug.taking, true) end
    if drug.buildDays then
        if (s.lvl or 0) >= drug.onAt then
            s.built = math.min(1, (s.built or 0) + 1 / (drug.buildDays * 1440))
        elseif (s.built or 0) > 0 then
            s.built = math.max(0, s.built - 1 / ((drug.fadeDays or drug.buildDays) * 1440))
        end
    end
    if (s.sideMin or 0) > 0 then
        s.sideMin = s.sideMin - 1
        if sideChance() > 0 then applyEffect(player, d, drug.side) end
        if s.sideMin <= 0 then s.sideMin = nil end
    end
    -- too many: runs while the level is over, and for overH hours after it falls
    -- back (a quick-clearing drug would otherwise be over in minutes)
    local above = drug.over and drug.overAt and (s.lvl or 0) > drug.overAt
    if above then
        if drug.overH then s.overMin = drug.overH * 60 end
    elseif (s.overMin or 0) > 0 then
        s.overMin = s.overMin - 1
        if s.overMin <= 0 then s.overMin = nil end
    end
    local over = above or (s.overMin or 0) > 0
    if over and not s.over then notify(player, "UI_DanTraits_MedOver_" .. id) end
    s.over = over or nil
    if over then applyEffect(player, d, drug.over) end
end

local function updateMedsMinute(player, d)
    migrate(d)
    if not d.meds then return end
    for id, s in pairs(d.meds) do
        local drug = DanTraits_Drugs[id]
        if drug then updateDrug(player, d, id, drug, s) end
    end
end

-- the endurance recovery cuts of whatever side or overdose effect is running
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or not d.meds then return nil end
    local k = 1
    for id, s in pairs(d.meds) do
        local drug = DanTraits_Drugs[id]
        if drug then
            if (s.sideMin or 0) > 0 and drug.side and drug.side.regen and sideChance() > 0 then k = k * drug.side.regen end
            if s.over and drug.over and drug.over.regen then k = k * drug.over.regen end
        end
    end
    if k == 1 then return nil end
    return delta * k
end)

-- Diazepam: the vanilla beta blocker's panic drop, while it is in the system
local function updateMedsFrame(player, d)
    if not d or not d.meds or not d.meds.diazepam then return end
    if not DanTraits_MedCovered(player, "diazepam") or DanTraits_Asleep(player) then return end
    DanTraits_PanicDecay(player:getStats(), DZ_PANIC_RATE)
end

-- Pills ----------------------------------------------------------------------------

-- vanilla beta blockers: keep the timers as they were before the pill (the
-- pill action reaches us before and after the vanilla effect)
local betaBefore = {}

DanTraits_AddHook("prePill", function(_, player, kind)
    if string.lower(tostring(kind or "")) ~= "pillsbeta" then return nil end
    pcall(function() betaBefore[player] = { player:getBetaEffect(), player:getBetaDelta() } end)
    return nil
end)

DanTraits_AddHook("pill", function(_, player, kind)
    local id = DanTraits_DrugOfItem(kind)
    if not id then return nil end
    if id == "beta" then
        local snap = betaBefore[player]
        betaBefore[player] = nil
        if snap then
            pcall(function()
                player:setBetaEffect(snap[1])
                player:setBetaDelta(snap[2])
            end)
        end
    end
    DanTraits_MedTake(player, id, 1)
    return nil
end)

-- Item scripts ----------------------------------------------------------------------
-- Vanilla bottles of the daily drugs hold 30 pills like ours, and every
-- medicine the system knows says what it treats and what it can do to you.
local VANILLA_ITEMS = {
    { "Base.PillsBeta", "Tooltip_DanTraits_PillsBeta", 30 },
    { "Base.PillsAntiDep", "Tooltip_DanTraits_PillsAntiDep", 30 },
    { "Base.Pills", "Tooltip_DanTraits_Painkillers" },
    { "Base.PillsSleepingTablets", "Tooltip_DanTraits_SleepingTablets" },
    { "Base.PillsVitamins", "Tooltip_DanTraits_Vitamins" },
}

function DanTraits_MedPatchScripts()
    local sm
    pcall(function() sm = getScriptManager() end)
    if not sm then pcall(function() sm = ScriptManager.instance end) end
    if not sm then return end
    for _, v in ipairs(VANILLA_ITEMS) do
        pcall(function()
            local item = sm:getItem(v[1])
            if not item then return end
            item:DoParam("Tooltip = " .. v[2])
            -- the game counts a bottle's pills as 1 / UseDelta rounded down, so
            -- 1/30 itself (0.0333...4 as a float) gives 29: cut it to four places
            if v[3] then item:DoParam("UseDelta = " .. string.format("%.4f", math.floor(10000 / v[3]) / 10000)) end
        end)
    end
end

-- Bottles turn up partly used (vanilla does the same for foraged ones): a
-- fresh spawn of one of the mod's medicines keeps 30% to 100% of its doses.
-- Two part bottles of the same kind merge with vanilla's own Merge option,
-- as any drainable without cantBeConsolided does.
local SPAWN_TYPES = {
    ["DanTraits.Anticonvulsants"] = true, ["DanTraits.Metformin"] = true, ["DanTraits.IronPills"] = true,
    ["DanTraits.Diazepam"] = true, ["DanTraits.NicotineGum"] = true, ["DanTraits.Inhaler"] = true,
    ["DanTraits.Sumatriptan"] = true,
}

function DanTraits_MedRandomFill(item)
    local done = false
    pcall(function()
        local md = item:getModData()
        if md.DanTraitsFilled then done = true return end
        md.DanTraitsFilled = true
    end)
    if done then return false end
    -- setUsedDelta takes the fraction left, as vanilla's own random fills use it
    local frac = (30 + ZombRand(71)) / 100
    pcall(function() item:setUsedDelta(frac) end)
    return true
end

local function onMedsFillContainer(roomName, containerType, container)
    if not container or not instanceof(container, "ItemContainer") then return end   -- the game sometimes passes a loot-table entry
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and SPAWN_TYPES[item:getFullType()] then DanTraits_MedRandomFill(item) end
        end
    end)
end

-- Console --------------------------------------------------------------------------
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.meds = function(player, args)
    if args[1] == "take" and DanTraits_Drugs[args[2] or ""] then
        return args[2] .. " level " .. tostring(DanTraits_MedTake(player, args[2], 1))
    end
    if args[1] == "side" and DanTraits_Drugs[args[2] or ""] then
        local d = DanTraits_Data(player)
        stateOf(d, args[2]).sideMin = (DanTraits_Drugs[args[2]].sideH or 8) * 60
        notify(player, "UI_DanTraits_MedSide_" .. args[2])
        return args[2] .. " side effect started"
    end
    local out = {}
    for id in pairs(DanTraits_Drugs) do
        local lvl, built = DanTraits_MedState(player, id)
        if lvl > 0 or built > 0 then
            local drug, s = DanTraits_Drugs[id], (DanTraits_Data(player).meds or {})[id] or {}
            local how = drug.buildDays and string.format("%d%%", math.floor(built * 100 + 0.5)) or (drug.state and "regimen" or "at once")
            out[#out + 1] = string.format("%s %.2f (%s%s)", id, lvl, how, s.over and ", TOO MANY" or "")
        end
    end
    table.sort(out)
    if #out == 0 then return "no medication in the system (meds take <id> | meds side <id>)" end
    return table.concat(out, ", ")
end

DanTraits_Every("minute", "Meds", updateMedsMinute, 30)
DanTraits_Every("frame", "Meds", updateMedsFrame, 40)
Events.OnGameBoot.Add(DanTraits_MedPatchScripts)
Events.OnFillContainer.Add(onMedsFillContainer)
