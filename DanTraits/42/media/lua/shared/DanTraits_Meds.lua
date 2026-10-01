-- Project Zomboid Vitality Project: the shared medication system.
--
-- One list of drugs (DanTraits_Drugs). Each trait asks this file how well a
-- character is covered instead of keeping its own pill bookkeeping, and the
-- tracking UI to come reads everything from here.
--
-- Daily drugs (beta blockers, anticonvulsants, metformin) track two numbers:
--   level  what is in your system: every pill adds one, it halves every
--          halfH hours. Covered while it is at least onAt.
--   built  0..1, how well the drug works: it climbs for each minute you are
--          covered (full after buildDays) and slides back while you are not
--          (to nothing after fadeDays). The trait reads this as the effect.
-- So the first pill helps a little, a few days of regular doses give the full
-- effect, and a missed dose dents it instead of dropping you off a cliff.
-- A character who starts with the trait starts built up (DanTraits_MedStart).
--
-- Rescue drugs (diazepam) work at once: the effect is 1 while covered.
-- Regimen drugs keep their model in their trait file and lend it to this one
-- through state() (antidepressants: Depression's two-week streak). Supplements
-- (iron) only get the side effect roll here.
--
-- Side effects: the first dose on each game day rolls the side effect chance
-- (sandbox MedSideEffectChance, percent, default 3; 0 turns them off). A hit
-- runs that drug's mild side effect for sideH hours. Too much (level above
-- overAt) runs its overdose effect for as long as the level stays up.
--
-- Effects are a small vocabulary, applied every minute while they run:
--   fatigue  tiredness added a minute      stress   stress added a minute
--   sick     food sickness floor (0..100)  regen    endurance recovery x this
--   faint    chance a minute of fainting
--
-- Vanilla beta blockers: their own effect (a large, short panic drop) is put
-- back the way it was after the pill, so they only do what this list says.
-- That panic drop belongs to diazepam now.
--
-- Mod data: meds[id] = { lvl, built, day (last game day dosed), sideMin
-- (minutes of side effect left), over (overdose running) }.
-- Console: meds | meds take <id> | meds side <id>
require "DanTraits"

local notify = DanTraits_Notify

local SIDE_CHANCE_DEFAULT = 3          -- percent, on each day a drug is taken
local DZ_PANIC_RATE       = 0.6        -- diazepam: panic per 30fps tick, the vanilla beta blocker rate

-- The drug list. items: lower-case item types (getType) that are a dose.
-- treats: trait ids, for the tooltip and the UI. kind: daily | rescue | regimen | supplement.
DanTraits_Drugs = {
    beta = {
        items = { "pillsbeta" }, treats = { "heart" }, kind = "daily",
        halfH = 12, onAt = 0.5, overAt = 3, buildDays = 3, fadeDays = 3,
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
        side = { sick = 15 }, sideH = 8,
        over = { sick = 35 },
    },
    antidepressant = {
        items = { "pillsantidep" }, treats = { "spiraling" }, kind = "regimen",
        side = { sick = 15 }, sideH = 8,
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
        over = { fatigue = 0.0015, regen = 0.7 },
    },
    iron = {
        items = { "ironpills" }, treats = { "anemic" }, kind = "supplement",
        side = { sick = 10 }, sideH = 4,
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

-- Old saves kept their own levels; carry them across once, so nobody loses
-- cover on update (a protecting level counts as fully built up).
local function migrate(d)
    if d.medsMigrated then return end
    d.medsMigrated = true
    local function carry(id, lvl)
        if not lvl or lvl <= 0 then return end
        local s = stateOf(d, id)
        s.lvl = math.max(s.lvl, lvl)
        if lvl >= DanTraits_Drugs[id].onAt then s.built = 1 end
    end
    carry("beta", d.hcBeta)
    carry("anticonvulsant", d.epMeds)
    if (d.diaMedMinutes or 0) > 0 then carry("metformin", d.diaMedMinutes / 1440) end
    d.hcBeta, d.epMeds, d.diaMedMinutes = nil, nil, nil
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

-- 0..1: how well the drug is working right now
function DanTraits_MedEffect(player, id)
    local drug = DanTraits_Drugs[id]
    if not drug then return 0 end
    if drug.kind == "rescue" then return DanTraits_MedCovered(player, id) and 1 or 0 end
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

local function applyEffect(player, d, fx)
    local stats = player:getStats()
    if fx.fatigue then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, fx.fatigue) end
    if fx.stress then DanTraits_StatAdd(stats, CharacterStat.STRESS, fx.stress) end
    if fx.sick then pcall(function() DanTraits_FloorUp(stats, CharacterStat.FOOD_SICKNESS, fx.sick, 1) end) end
    if fx.faint and DanTraits_PassOut and not (DanTraits_IsPassedOut and DanTraits_IsPassedOut(player))
        and DanTraits_Roll(fx.faint) then
        DanTraits_PassOut(player, DanTraits_RandRange(2, 5), "UI_DanTraits_ComeTo", false)
    end
end

local function updateDrug(player, d, id, drug, s)
    if drug.halfH and (s.lvl or 0) > 0 then
        s.lvl = s.lvl * 0.5 ^ (1 / (drug.halfH * 60))
        if s.lvl < 0.01 then s.lvl = 0 end
    end
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
    local over = drug.over and drug.overAt and (s.lvl or 0) > drug.overAt
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
    local stats = player:getStats()
    local panic = stats:get(CharacterStat.PANIC) or 0
    if panic <= 0 then return end
    local mult = 1
    pcall(function() mult = GameTime.getInstance():getThirtyFPSMultiplier() or 1 end)
    stats:set(CharacterStat.PANIC, math.max(0, panic - DZ_PANIC_RATE * mult))
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
            if v[3] then item:DoParam("UseDelta = " .. tostring(1 / v[3])) end
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
    if not container then return end
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
            out[#out + 1] = string.format("%s %.2f (%d%%)", id, lvl, math.floor(built * 100 + 0.5))
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
