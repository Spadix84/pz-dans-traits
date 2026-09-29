-- Project Zomboid Vitality Project: drink relief tied to the Drunk moodle.
-- Not a trait: every character has it (sandbox option DrinkReliefEnabled; off:
-- vanilla's full pill dose from any drink, no pain floor, no panic decay; the
-- definition of drunk below is not affected).
--
-- Vanilla (B42) hands any alcoholic drink to BodyDamage.JustDrankBoozeFluid,
-- which raises intoxication by the amount drunk and then calls the same
-- BetaBlockers and PainMeds methods a pill does. Those ignore the dose: the
-- beta-blocker timer (6600 ticks) and the painkiller timer (5400 ticks) are
-- set in full, and the per-tick update takes a flat 0.6 panic and 0.023
-- pain off while they run. One sip of whiskey is a full dose of both.
--
-- Here the drink action is wrapped to put those timers back the way they
-- were (real pills taken earlier keep working), and the relief comes from
-- the Drunk moodle instead: the body's pain reduction is floored by level
-- (ALC_PAIN_CUT), and panic decays each tick at a share of the beta-blocker
-- rate (a quarter per level). The floor is bookkept so it steps down as the
-- character sobers up and never eats a painkilling fluid's own reduction.
--
-- This file is also the one definition of "drunk" for the rest of the mod:
-- DanTraits_DRINK holds the named intoxication thresholds (0..1) that
-- Dependent (any), Hangover (buzz, sober), MDD and Diabetes (tipsy) read, and
-- DanTraits_Intoxication(player) reads the stat as 0..1. Smoker uses the
-- Drunk moodle level (DanTraits_DrunkLevel) instead. Readers copy the table
-- at load with a fallback of the same numbers, so load order does not matter.
--
-- ISDrinkFluidAction.updateEat is wrapped through DanTraits_Wrap with the tag
-- "alcohol-relief"; DanTraits_Diabetes.lua adds its own layer ("drink-intake")
-- on the same method, and the two chain, so both always run.
require "DanTraits"

local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

local ALC_PAIN_CUT   = { 20, 40, 60, 80 }    -- pain reduction floor by Drunk level 1..4
local ALC_PANIC_RATE = 0.6                   -- vanilla beta blocker: panic per 30fps tick, level 4 gets all of it
local ALC_LEVELS     = { 10, 30, 50, 70 }    -- intoxication (0..100) above which each Drunk level starts (fallback)

-- Drunk moodle level 0..4; from intoxication if the moodle cannot be read
local function drunkLevel(player)
    local level
    if MoodleType and MoodleType.DRUNK then
        pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.DRUNK) end)
    end
    if type(level) == "number" then return level end
    local intox = fraction(player:getStats(), CharacterStat.INTOXICATION) * 100
    level = 0
    for i, threshold in ipairs(ALC_LEVELS) do if intox > threshold then level = i end end
    return level
end
DanTraits_DrunkLevel = drunkLevel

-- Named intoxication thresholds, 0..1. any: had a drink at all; tipsy: the
-- liver is busy and mood lifts; buzz: hangover load starts to build; sober:
-- below this a drinking session is over.
DanTraits_DRINK = { any = 0.01, tipsy = 0.05, buzz = 0.20, sober = 0.05 }

-- intoxication as a 0..1 fraction of its range
function DanTraits_Intoxication(player)
    local value = 0
    pcall(function() value = fraction(player:getStats(), CharacterStat.INTOXICATION) end)
    return value
end

-- Undo the vanilla dose ------------------------------------------------------
local function snapshotMeds(player)
    local snap
    pcall(function()
        snap = { beta = player:getBetaEffect(), betaDelta = player:getBetaDelta(),
                 pain = player:getPainEffect(), painDelta = player:getPainDelta() }
    end)
    return snap
end

local function restoreMeds(player, snap)
    pcall(function()
        player:setBetaEffect(snap.beta)
        player:setBetaDelta(snap.betaDelta)
        player:setPainEffect(snap.pain)
        player:setPainDelta(snap.painDelta)
    end)
end

local function isAlcoholic(container)
    local alcoholic = true   -- if the fluid cannot be read, restoring is harmless for a soft drink anyway
    pcall(function() alcoholic = container:getProperties():getAlcohol() > 0 end)
    return alcoholic
end

-- ISDrinkFluidAction:updateEat is the one place the drink reaches the
-- character (DrinkFluid), on the client in single player and on the server
-- in multiplayer; the timers are read before it and put back after.
local function wrapDrinkAction()
    DanTraits_Wrap(ISDrinkFluidAction, "updateEat", "alcohol-relief", function(original, self, ...)
        local snap = self.character and snapshotMeds(self.character)
        -- read before the sip: the last one empties the container, and an
        -- empty container reports no alcohol (found in game: finishing a
        -- shot left full beta-blocker and painkiller timers)
        local alcoholic = snap and isAlcoholic(self.fluidContainer)
        local result = original(self, ...)
        if alcoholic and DanTraits_SandboxOn("DrinkReliefEnabled") then restoreMeds(self.character, snap) end
        return result
    end)
end
wrapDrinkAction()
Events.OnGameStart.Add(wrapDrinkAction)

-- Pain: floor the body's pain reduction by level -----------------------------
-- painReduction is subtracted from wound pain every tick and decays slowly on
-- its own. d.alcPainCut is our share of it; whatever is above that came from
-- somewhere else (a medicinal fluid) and is left to decay as vanilla intends.
local function updateAlcoholMinute(player, d)
    local level = drunkLevel(player)
    local target = DanTraits_SandboxOn("DrinkReliefEnabled") and ALC_PAIN_CUT[level] or 0   -- off: the floor steps down and stays 0
    local applied = d.alcPainCut or 0
    if target == 0 and applied == 0 then return end
    pcall(function()
        local bd = player:getBodyDamage()
        local other = math.max(0, (bd:getPainReduction() or 0) - applied)
        bd:setPainReduction(other + target)
        d.alcPainCut = target
    end)
end
DanTraits_updateAlcoholMinute = updateAlcoholMinute

-- Panic: decay each tick at (level / 4) of the beta-blocker rate ------------
local function updateAlcoholFrame(player)
    local level = drunkLevel(player)
    if level <= 0 or not DanTraits_SandboxOn("DrinkReliefEnabled") then return end
    local stats = player:getStats()
    local panic = stats:get(CharacterStat.PANIC) or 0
    if panic <= 0 then return end
    local asleep = DanTraits_Asleep(player)
    if asleep then return end
    local mult = 1
    pcall(function() mult = GameTime.getInstance():getThirtyFPSMultiplier() or 1 end)
    stats:set(CharacterStat.PANIC, math.max(0, panic - ALC_PANIC_RATE * (level / 4) * mult))
end
DanTraits_updateAlcoholFrame = updateAlcoholFrame

DanTraits_Every("minute", "Alcohol", updateAlcoholMinute, 40)
DanTraits_Every("frame", "Alcohol", updateAlcoholFrame, 40)
