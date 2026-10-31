-- Project Zomboid Vitality Project: Essential Tremor (Age 2.0, 2026-10-31; any age).
--
-- Hands that shake. A shake (etShake, 0..1) is worked out every minute from a
-- base, plus caffeine in the system (the Caffeine file's level), tiredness,
-- stress and cold air; a drink steadies it for an hour (true, and a trap for
-- the Dependent), and the beta blockers the game has (propranolol: the real
-- first-line drug) damp it while they are in the system (the shared
-- medication system's "beta").
--
-- What the shake does, by its strength: stitches come out rough and splints
-- are set badly more often (the stitchPoor and splintBadSet hooks of
-- DanTraits_WoundCare.lua, for whoever does the work), a weapon slips from
-- the hand a little more often (the swingDrop hook, as the alcohol shakes
-- do), reloading and racking run slower (the game's ReloadSpeed variable,
-- the seam Steady Hands uses the other way), and careful reading takes
-- longer (ISReadABook's time). The game's aiming is Java and has no seam, so
-- the gun hand pays through the reload. Not with Steady Hands.
-- A new character starts with a bottle of beta blockers (Starting Medication).
--
-- Mod data: etShake, etDrinkMin (minutes a drink is still steadying), etIntox
-- (intoxication last minute), etTold, etKitGiven.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction
local clamp01 = DanTraits_Clamp01

local ET_BASE       = 0.4     -- the shake, calm, rested, warm and sober
local ET_CAFFEINE   = 0.25    -- added at a mug of coffee's level (100) in the system
local ET_FATIGUE    = 0.2     -- added at full tiredness
local ET_STRESS     = 0.2     -- added at full stress
local ET_COLD_C     = 10      -- air below this...
local ET_COLD       = 0.2     -- ...adds this
local ET_DRINK      = 0.5     -- the shake x this while a drink steadies it...
local ET_DRINK_MIN  = 60      -- ...for this long after intoxication last rose
local ET_BETA       = 0.6     -- the shake x (1 - this x the beta blockers' effect)
local ET_FINE       = 1       -- bad splint and rough stitch chance x (1 + this x shake)
local ET_DROP       = 1       -- percent added to the swing-drop chance at a full shake
local ET_RELOAD     = 0.25    -- reload speed x (1 - this x shake)
local ET_READ       = 0.2     -- reading time x (1 + this x shake)
local ET_TOLD_AT    = 0.65    -- the shake crossing this upward: a notice
local ET_START_BETA = "Base.PillsBeta"

local function has(player) return player ~= nil and hasTrait(player, "tremor") end

local function shakeOf(player)
    local d = player and player:getModData().DanTraits
    if not d or not has(player) then return 0 end
    return d.etShake or 0
end
DanTraits_TremorShake = shakeOf

local function updateTremorMinute(player, d)
    local stats = player:getStats()
    local shake = ET_BASE
    local caf = (d.cafLevel or 0) / 100
    shake = shake + ET_CAFFEINE * clamp01(caf)
    pcall(function() shake = shake + ET_FATIGUE * clamp01(stats:get(CharacterStat.FATIGUE) or 0) end)
    pcall(function() shake = shake + ET_STRESS * fraction(stats, CharacterStat.STRESS) end)
    local air = DanTraits_AirTemp(player)
    if type(air) == "number" and air < ET_COLD_C then shake = shake + ET_COLD end
    -- a drink steadies it for an hour from the last sip that raised intoxication
    local intox = 0
    pcall(function() intox = fraction(stats, CharacterStat.INTOXICATION) end)
    if intox > (d.etIntox or 0) + 1e-6 then d.etDrinkMin = ET_DRINK_MIN end
    d.etIntox = intox
    if (d.etDrinkMin or 0) > 0 then
        d.etDrinkMin = d.etDrinkMin - 1
        shake = shake * ET_DRINK
    end
    if DanTraits_MedEffect then
        local e = clamp01(tonumber(DanTraits_MedEffect(player, "beta")) or 0)
        shake = shake * (1 - ET_BETA * e)
    end
    shake = clamp01(shake)
    if (d.etShake or 0) < ET_TOLD_AT and shake >= ET_TOLD_AT and not d.etTold then
        d.etTold = true
        notify(player, "UI_DanTraits_TremorBad")
    elseif shake < ET_TOLD_AT then
        d.etTold = nil
    end
    d.etShake = shake
end

local function clearTremor(player, d)
    if d then d.etShake, d.etDrinkMin, d.etTold = nil, nil, nil end
end

-- fine work, for whoever does it
local function fine(chance, setter)
    local s = shakeOf(setter)
    if s <= 0 then return nil end
    return chance * (1 + ET_FINE * s)
end
DanTraits_AddHook("splintBadSet", fine)
DanTraits_AddHook("stitchPoor", fine)

DanTraits_AddHook("swingDrop", function(chance, player)
    local s = shakeOf(player)
    if s <= 0 then return nil end
    return chance + ET_DROP * s
end)

-- the gun hand: the reload speed the game works out for every reload and rack, lowered after it is set
local function wrapTremor()
    DanTraits_Wrap(ISReloadWeaponAction, "setReloadSpeed", "tremor-reload", function(original, character, ...)
        local result = original(character, ...)
        local s = shakeOf(character)
        if s > 0 then
            pcall(function()
                local speed = character:getVariableFloat("ReloadSpeed", 1.0)
                if type(speed) == "number" and speed > 0 then character:setVariable("ReloadSpeed", speed * (1 - ET_RELOAD * s)) end
            end)
        end
        return result
    end)
    DanTraits_Wrap(ISReadABook, "getDuration", "tremor-read", function(original, self, ...)
        local t = original(self, ...)
        local s = shakeOf(self.character)
        if type(t) == "number" and t > 1 and s > 0 then t = t * (1 + ET_READ * s) end
        return t
    end)
end
wrapTremor()
Events.OnGameStart.Add(wrapTremor)

DanTraits_Every("minute", "Tremor", updateTremorMinute, 40, { trait = "tremor", clear = clearTremor })

DanTraits_StartingKit({ trait = "tremor", flag = "etKitGiven", items = { ET_START_BETA } })
