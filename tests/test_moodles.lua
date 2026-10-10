-- Offline test for DanTraits_Moodles.lua and DanTraits_LevelMoodle: every
-- moodle's level from what the systems keep in mod data, the good side for
-- medication and sun block, nothing for a character without the trait, the
-- value Moodle Framework is handed for each level, and nothing at all
-- without Moodle Framework.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Meds", "Moodles")
H.expectEvery("minute", "Moodles")

local near = H.near
local EVERY = { "heart", "epilepsy", "gluten", "lactose", "germaphobe", "caffeine", "dependent", "spiraling", "anemia", "arthritis", "migraine" }
local p = H.player({ traits = EVERY }); H.current = p
local d = DanTraits_Data(p)
local function level(name, who, data) return DanTraits_MoodleLevels(who or p, data or d)[name] end

-- 0. the list the client creates them from
assert(#DanTraits_MoodleNames == 20, "twenty moodles")
local listed = {}
for _, name in ipairs(DanTraits_MoodleNames) do listed[name] = true end
for _, name in ipairs({ "ChestPain", "Seizure", "Tinnitus", "GutFlare", "Filthy", "Sunburn", "Dehydration",
                        "CaffeineWithdrawal", "AlcoholWithdrawal", "NicotineCraving", "Depression", "LowIron", "StiffJoints", "MSHeat", "MSFlare", "Spoons", "LightTooBright", "TriptanAfter", "Antidepressants", "WeakHeart" }) do
  assert(listed[name], name .. " is listed")
end
for name, l in pairs(DanTraits_MoodleLevels(p, d)) do assert(l == 0, name .. ": nothing to show on a well character") end

-- 1. Heart: beta blockers working, the strain, chest pain, pushing on; the week after an attack
d.meds = { beta = { lvl = 1, built = 0 } }; assert(level("ChestPain") == -1, "beta blockers building up: the paler green")
d.meds.beta.built = 0.999; assert(level("ChestPain") == -1, "still building up just short of full")
d.meds.beta.built = 1; assert(level("ChestPain") == -2, "fully built up: the full green")
d.meds.beta.lvl = 0.4; assert(level("ChestPain") == 0, "worn off")
d.hcStrain = 0.39; assert(level("ChestPain") == 0, "a little strain: nothing yet")
d.hcStrain = 0.5; assert(level("ChestPain") == 1, "working hard")
d.hcStrain = 0.8; assert(level("ChestPain") == 2, "pounding")
d.hcAnginaMin = 12; assert(level("ChestPain") == 3, "chest pain")
d.meds.beta.lvl = 1; assert(level("ChestPain") == 3, "chest pain shows over the medication")
d.hcPushing = true; assert(level("ChestPain") == 4, "pushing on")
assert(level("WeakHeart") == 0, "no attack: nothing")
d.hcWeakH = 150; assert(level("WeakHeart") == 3, "the first days after an attack")
d.hcWeakH = 100; assert(level("WeakHeart") == 2, "the middle")
d.hcWeakH = 10; assert(level("WeakHeart") == 1, "on the mend")
d.hcAnginaMin, d.hcPushing, d.hcWeakH, d.hcStrain, d.meds = nil, nil, nil, nil, nil

-- 2. Epilepsy: medication, the hour after, the aura
d.meds = { anticonvulsant = { lvl = 0.6, built = 0 } }; assert(level("Seizure") == -1, "anticonvulsants building up")
d.meds.anticonvulsant.built = 1; assert(level("Seizure") == -2, "anticonvulsants fully working")
d.meds.anticonvulsant.lvl = 0.4; assert(level("Seizure") == 0, "out of the system: nothing, however built up")
d.meds.anticonvulsant.lvl = 0.6; d.meds.anticonvulsant.built = 0
d.epAfterMin = 30; assert(level("Seizure") == 1, "after a seizure")
d.epAuraMin = 4; assert(level("Seizure") == 2, "one coming")
d.meds, d.epAfterMin, d.epAuraMin = nil, nil, nil

-- 3. ears, gut, grime
d.tnRinging, d.tnDeafMin = true, 30; assert(level("Tinnitus") == 1, "ringing")
d.tnDeafMin = 90; assert(level("Tinnitus") == 2, "deafened")
d.tnRinging, d.tnDeafMin = nil, nil
d.gluten = 0.8; assert(level("GutFlare") == 3, "a full gluten flare")
d.gluten = 0; d.lacFlare = 1; assert(level("GutFlare") == 2, "a full lactose flare is the second level")
d.lacFlare = 0.3; assert(level("GutFlare") == 0, "a little dairy: nothing yet")
d.lacFlare = 0.4; assert(level("GutFlare") == 1, "gurgling")
d.lacFlare = nil
d.gmGrime = 0.1; assert(level("Filthy") == 0, "a little grime is fine")
d.gmGrime = 0.2; assert(level("Filthy") == 1, "grubby")
d.gmGrime = 0.5; assert(level("Filthy") == 2, "filthy")
d.gmGrime = 0.9; assert(level("Filthy") == 3, "disgusting")
d.gmGrime = nil

-- 4. the sun and thirst, anyone's
local plain = H.player(); H.current = plain
local pd = DanTraits_Data(plain)
pd.sbBlockMin = 300; assert(level("Sunburn", plain, pd) == -1, "sun block on")
pd.sbBlockMin = nil; pd.sbHot = 0.8; assert(level("Sunburn", plain, pd) == 1, "skin feels hot")
pd.sbBurn = { Head = 20, Neck = 20 }; assert(level("Sunburn", plain, pd) == 2, "sunburnt")
pd.sbBlockMin = 300; assert(level("Sunburn", plain, pd) == 2, "a burn shows over the sun block")
pd.sbBurn = { Head = 20, Neck = 20, Hand_L = 20, Hand_R = 20, ForeArm_L = 20, ForeArm_R = 20 }
assert(level("Sunburn", plain, pd) == 3, "badly sunburnt")
pd.sbBurn, pd.sbHot, pd.sbBlockMin = nil, nil, nil
pd.dhLoad = 0.2; assert(level("Dehydration", plain, pd) == 0, "a little thirsty")
pd.dhLoad = 0.4; assert(level("Dehydration", plain, pd) == 1, "thirst headache")
pd.dhLoad = 0.8; assert(level("Dehydration", plain, pd) == 2, "dehydrated")
pd.dhLoad = nil

-- 5. the habits
d.cafWithdraw = 0.2; assert(level("CaffeineWithdrawal") == 1, "needs coffee")
d.cafWithdraw = 0.7; assert(level("CaffeineWithdrawal") == 2, "withdrawal")
d.cafWithdraw = nil
d.alcWithdrawing, d.alcStage = true, 2; assert(level("AlcoholWithdrawal") == 2, "the shakes")
d.alcStage = 3; assert(level("AlcoholWithdrawal") == 3, "delirium")
d.alcWithdrawing = false; assert(level("AlcoholWithdrawal") == 0, "a drink ends it")
d.alcStage = nil
DanTraits_NicotineWithdrawal = function() return 0.6 end
assert(level("NicotineCraving") == 2, "craving")
SandboxVars = { DanTraits = { SmokerCravingMoodle = false } }
assert(level("NicotineCraving") == 0, "option off: the craving moodle is hidden")
SandboxVars = nil
DanTraits_NicotineWithdrawal = function() return 0 end
assert(level("NicotineCraving") == 0, "sated")
DanTraits_NicotineWithdrawal = nil
assert(level("NicotineCraving") == 0, "Smoker not loaded: nothing")

-- 6. mood, iron, joints
d.mddEpisode, d.mddSeverity = true, 0.5; assert(level("Depression") == 1, "a low spell")
d.mddSeverity = 0.7; assert(level("Depression") == 2, "an episode")
d.mddSeverity = 1; assert(level("Depression") == 3, "deep")
d.mddEpisode = false; assert(level("Depression") == 0, "over")
d.anDeficit = 0.05; assert(level("LowIron") == 0, "iron fine")
d.anDeficit = 0.3; assert(level("LowIron") == 1, "low on iron")
d.anDeficit = 0.95; assert(level("LowIron") == 3, "light-headed")
d.artJoint = 0.3; assert(level("StiffJoints") == 1, "stiff")
d.artJoint = 0.6; assert(level("StiffJoints") == 2, "a flare")
d.artJoint = 0.9; assert(level("StiffJoints") == 3, "a bad flare")
-- Migraines: the light's pain against full sun (a lit room 0.67, in sunglasses 0.33; the sun 1, in sunglasses 0.5)
d.migGlare = 0.33; assert(level("LightTooBright") == 1, "too bright")
d.migGlare = 0.5; assert(level("LightTooBright") == 2, "the sun through sunglasses: the light hurts")
d.migGlare = 0.67; assert(level("LightTooBright") == 2, "a lit room: the light hurts")
d.migGlare = 1; assert(level("LightTooBright") == 3, "the sun: blinding")
d.migGlare = nil; assert(level("LightTooBright") == 0, "no light adding pain")
-- the day after sumatriptan, for anyone
d.tripAfterMin = 600; assert(level("TriptanAfter") == 1, "heavy-limbed")
d.tripAfterMin = nil; assert(level("TriptanAfter") == 0, "worn off")
-- antidepressants: Depression's regimen, paler until the two weeks are up; through an episode too
DanTraits_MddBenefit = function() return (d.mddMedStreak or 0) >= 14 and 1 or 0.5 end
d.mddMedDays, d.mddMedStreak = 0.5, 1; assert(level("Antidepressants") == -1, "a pill's coverage running: building up")
d.mddEpisode, d.mddSeverity = true, 0.7; assert(level("Antidepressants") == -1 and level("Depression") == 2, "shows through an episode")
d.mddEpisode = false
d.mddMedStreak = 14; assert(level("Antidepressants") == -2, "two weeks unbroken: working")
d.mddMedDays = 0; assert(level("Antidepressants") == 0, "coverage run out: the icon goes")
p._depress = 500; assert(level("Antidepressants") == 0, "Depression goes by its regimen, not the game's timer")
p._depress = 0

-- 7. the same mod data on a character without the traits: nothing (only the
--    sun, thirst and the day after sumatriptan are everyone's)
pd.gluten, pd.lacFlare, pd.gmGrime, pd.cafWithdraw, pd.anDeficit, pd.artJoint, pd.migGlare = 1, 1, 1, 1, 1, 1, 1
pd.mddEpisode, pd.mddSeverity, pd.alcWithdrawing, pd.alcStage, pd.epAuraMin, pd.meds = true, 1, true, 3, 3, { beta = { lvl = 1, built = 1 } }
for name, l in pairs(DanTraits_MoodleLevels(plain, pd)) do assert(l == 0, name .. ": not without the trait") end
pd.mddMedDays = 1; assert(level("Antidepressants", plain, pd) == 0, "the regimen is Depression's"); pd.mddMedDays = nil
plain._depress = 500; assert(level("Antidepressants", plain, pd) == -2, "anyone else: while the game's own effect runs"); plain._depress = 0
pd.tripAfterMin = 60; assert(level("TriptanAfter", plain, pd) == 1, "sumatriptan's day after shows without Migraines too"); pd.tripAfterMin = nil

-- 8. without Moodle Framework the minute does nothing, and does not fail
H.current = p
H.minute()

-- 9. with it: every moodle is set each minute, thresholds a tenth apart, the
--    value in the middle of its level's band
local set = {}
MF = { getMoodle = function(name)
  set[name] = set[name] or {}
  local m = set[name]
  return { setThresholds = function(_, ...) m.thresholds = { ... } end, setValue = function(_, v) m.value = v end }
end }
d.meds = { beta = { lvl = 1, built = 0.5 } }   -- good 1 (building up)
d.epAuraMin = 3              -- bad 2
d.gluten = 1                 -- bad 3
H.minute()
local n = 0
for _ in pairs(set) do n = n + 1 end
assert(n == 20, "all twenty set")
near(set.ChestPain.value, 0.65, 1e-9, "good 1 sits between 0.6 and 0.7")
near(set.Seizure.value, 0.25, 1e-9, "bad 2 sits between 0.2 and 0.3")
near(set.GutFlare.value, 0.15, 1e-9, "bad 3")
near(set.StiffJoints.value, 0.15, 1e-9, "bad 3 (the joints from step 6)")
near(set.Sunburn.value, 0.5, 1e-9, "nothing: neutral")
assert(set.Seizure.thresholds[4] == 0.4 and set.Seizure.thresholds[5] == 0.6, "bad 1 at 0.4, good 1 at 0.6")
DanTraits_LevelMoodle(p, "Seizure", 9); near(set.Seizure.value, 0.05, 1e-9, "a level past 4 is 4")
DanTraits_LevelMoodle(p, "Seizure", 1); near(set.Seizure.value, 0.35, 1e-9, "bad 1")
MF = nil

H.pass()
