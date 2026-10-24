-- Offline test for DanTraits_Sensory.lua: the texture groups, the food draw,
-- the load climbing to an overload in a crowd (shutdown or meltdown) and
-- draining when calm, sound, ears and ear muffs, scratchy and tight clothes,
-- safe and disliked food, refusing food while overloaded, a food learned as
-- safe, the stim, the moodle level, the hooks into other systems, the food
-- tooltip, and nothing without the trait.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Germaphobe", "Sensory", "Moodles")
-- the stand-in foods answer getFoodType; nothing else counts as Food
local realInstanceof = instanceof
instanceof = function(obj, cls)
  if cls == "Food" then return type(obj) == "table" and obj.getFoodType ~= nil end
  if cls == "Clothing" then return type(obj) == "table" and obj.getBodyLocation ~= nil end
  return realInstanceof(obj, cls)
end
H.expectEvery("minute", "Sensory")
H.expectHooks("OnWorldSound")

local near = H.near
local S = DanTraits_SensoryC
local G = DanTraits_SensoryGroupsOfName

-- 0. texture groups by name and food type
assert(G("crackers", "").crunchy and G("crackers", "").plain, "crackers: crunchy and plain")
assert(G("eggboiled", "egg").slimy, "a boiled egg is slimy")
assert(not G("eggplant", "vegetables").slimy, "an eggplant is not an egg")
local sardines = G("cannedsardines", "")
assert(sardines.slimy and sardines.strong, "sardines: slimy and strong")
assert(G("steak", "beef").chewy, "steak is chewy")
local pie = G("pieapple", "")
assert(pie.mixed and pie.sweet and not pie.crunchy, "apple pie: mixed and sweet, not crunchy")
assert(not G("blackcrappie", "fish").mixed and not G("blackcrappie", "fish").sweet, "a crappie is no pie")
assert(G("blackcrappie", "fish").strong, "but it is fish")
assert(next(G("broccoli", "vegetables")) == nil, "broccoli is in no group")

-- a fake food
local function food(full, foodType, ingredients)
  local short = full:gsub("^.*%.", "")
  return { getFullType = function() return full end, getType = function() return short end,
           getFoodType = function() return foodType or "" end, getDisplayName = function() return short end,
           haveExtraItems = function() return ingredients ~= nil end,
           getExtraItems = function()
             local list = ingredients or {}
             return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
           end }
end

-- a player whose stats count zombies
local function person(o)
  local p = H.player(o)
  p._seen, p._close = 0, 0
  local base = p.getStats
  p.getStats = function()
    local s = base()
    s.getNumVisibleZombies = function() return p._seen end
    s.getNumVeryCloseZombies = function() return p._close end
    return s
  end
  return p
end

-- 1. the draw: two safe (the first one keeps), two disliked, no repeats
H.rng = { 0, 0, 0, 0 }
local p = person({ traits = { "sensory" } }); H.current = p
local d = DanTraits_Data(p)
DanTraits_SensoryRollFoods(d)
assert(d.siSafe[1] == "crunchy" and d.siSafe[2] == "mushy", "safe: crunchy, mushy")
assert(d.siHate[1] == "slimy" and d.siHate[2] == "chewy", "disliked: slimy, chewy")
H.rng = { 3, 0, 0, 0 }   -- the fourth keeping group, then the first of what is left
DanTraits_SensoryRollFoods(d, true)
assert(d.siSafe[1] == "sweet" and S.STABLE[d.siSafe[1]], "the first safe group keeps")
local seen = {}
for _, k in ipairs({ d.siSafe[1], d.siSafe[2], d.siHate[1], d.siHate[2] }) do
  assert(not seen[k], "no group twice: " .. k); seen[k] = true
end
d.siSafe, d.siHate = { "crunchy", "plain" }, { "slimy", "mixed" }

-- 2. food verdicts: a disliked group wins; a dish of three things is mixed
assert(DanTraits_SensoryFood(p, food("Base.Crackers")) == "safe", "crackers are safe")
assert(DanTraits_SensoryFood(p, food("Base.Egg", "Egg")) == "disliked", "an egg is not")
assert(DanTraits_SensoryFood(p, food("Base.BaguetteSandwich")) == "disliked", "plain but mixed: disliked")
assert(DanTraits_SensoryFood(p, food("Base.RiceBowl", "", { "Base.Rice", "Base.Carrots", "Base.Steak" })) == "disliked", "three things in it: mixed")
assert(DanTraits_SensoryFood(p, food("Base.Broccoli", "Vegetables")) == nil, "broccoli: neither")

-- 3. ten zombies in sight: the load climbs to an overload, a shutdown (the roll fails)
p._seen = 10
H.rollf = 0.99
H.clearHalo()
H.minute()
local ch = d.siCh
near(ch.crowd, 1, 1e-9, "ten in sight is the most")
near(d.siIn, 2, 1e-9, "input: the crowd at weight 2")
near(d.siLoad, 10, 1e-6, "a tenth of the way to 100")
H.mins(29)
assert(d.siLoad > 90 and d.siTier == 3, "overloaded")
assert(d.siOver == "shutdown", "a shutdown")
local told = table.concat(H.halo, " ")
assert(told:find("UI_DanTraits_SensoryCause_crowd", 1, true), "the first notice names the crowd")
assert(told:find("UI_DanTraits_SensoryOverwhelmed", 1, true) and told:find("UI_DanTraits_SensoryShutdown", 1, true), "overwhelmed, then shutdown")
assert(p._st.stress >= 0.5, "stress held up")
assert(p._st.unhappy > 0 and p._st.boredom > 0, "low and bored")
assert(DanTraits_MoodleLevels(p, d).SensoryLoad == 4, "shutdown is the fourth level")
near(DanTraits_RunHooks("enduranceRegen", 1, p, d), S.SHUT_ENDURANCE, 1e-9, "stamina back at half")
near(DanTraits_SensoryOverload(p), (d.siLoad - 50) / 50, 1e-9, "Migraine reads the overload: how far in, from where it would end")

-- 4. overloaded, only a safe food goes down
assert(DanTraits_RunHooks("refuseFood", nil, p, food("Base.Broccoli", "Vegetables")) == "UI_DanTraits_SensoryRefuse", "broccoli refused")
assert(DanTraits_RunHooks("refuseFood", nil, p, food("Base.Crackers")) == nil, "crackers go down")
-- right-clicking anything else while overloaded asks nothing of it (B42 logs a nil call even in pcall)
local protectors = { getFullType = function() return "Base.Hat_EarMuff_Protectors" end, getType = function() return "Hat_EarMuff_Protectors" end }
assert(DanTraits_RunHooks("refuseFood", nil, p, protectors) == nil, "ear protectors are not food")
assert(DanTraits_SensoryFood(p, protectors) == nil, "no verdict on clothing")
local before = d.siLoad
DanTraits_RunHooks("eat", nil, p, food("Base.Crackers"), 1)
near(d.siLoad, before - S.SAFE_LOAD, 1e-6, "a safe food takes load off")

-- 5. the zombies gone, indoors in the dark: it drains, the overload ends under 50, calm at 0
p._seen = 0
H.clearHalo()
H.minute()
local drained = before - S.SAFE_LOAD - d.siLoad
near(drained, S.DRAIN * S.CALM_INDOORS * S.CALM_DARK, 1e-6, "drains fast indoors in the dark")
assert(d.siLoad >= S.OVER_END and d.siTier == 3, "still overloaded over 50")
H.mins(10)
assert(d.siTier == 3, "an overload lingers: still in it ten minutes on")
H.mins(15)
assert(d.siLoad < S.OVER_END and d.siTier < 3 and d.siOver == nil, "out of the overload under 50")
assert(d.siToll == 1, "worn thin by one")
H.mins(60)
assert(d.siLoad == 0 and d.siTier == 0, "calm again")
assert(table.concat(H.halo, " "):find("+UI_DanTraits_SensoryCalm", 1, true), "the world is quiet again")

-- 5a. the notices come again on the next climb (2026-10-22: after an overload the told
-- tier stuck at 3 until calm, so a day spent between Overwhelmed and calm said nothing).
-- The load is pinned a minute at a time with the console's hold
local function pin(load) d.siLoad, d.siHoldMin = load, 1; H.minute() end
H.clearHalo(); p._seen = 10
pin(95); assert(d.siTier == 3 and d.siTold == 3, "overloaded again")
p._seen = 0
pin(40); assert(d.siTier == 1 and d.siOver == nil, "down to tier 1, out of the overload")
assert(d.siTold == 1 and d.siPeak == 3, "the told tier follows it down; the peak is kept")
H.clearHalo(); p._seen = 10
pin(65); assert(d.siTier == 2, "back up to tier 2")
assert(table.concat(H.halo, " "):find("UI_DanTraits_SensoryOverwhelmed", 1, true), "Overwhelmed is said again")
near(DanTraits_SensoryOverload(p), 0, 1e-9, "Overwhelmed is no overload for Migraine (2026-10-22)")
H.clearHalo(); pin(68)
assert(not table.concat(H.halo, " "):find("UI_DanTraits_SensoryOverwhelmed", 1, true), "but not every minute")
p._seen = 0; H.clearHalo()
pin(40); pin(0)
assert(d.siTier == 0 and d.siTold == nil and d.siPeak == nil, "calm clears both")
assert(table.concat(H.halo, " "):find("+UI_DanTraits_SensoryCalm", 1, true), "and the calm line still comes")
H.clearHalo(); p._seen = 10; pin(40)
assert(table.concat(H.halo, " "):find("UI_DanTraits_SensoryCause_crowd", 1, true), "tier 1 from calm names the cause again")
p._seen = 0; pin(0); H.clearHalo()
d.siToll = 1   -- this section's overload is not part of the story below

-- 5b. Take A Bath And Shower: the water drains it faster, and the bath's soaking is no trigger
local bathing = nil
DanTraits_BathingMode = function() return bathing end
DanTraits_BathingWet = function() return bathing ~= nil end
p._st.wetness = 100
d.siLoad = 50
H.minute()
assert(d.siCh.touch > 0, "soaked out of the bath: touch counts")
p._st.wetness = 0
d.siLoad = 50
bathing = "BATH"
H.minute()
near(50 - d.siLoad, S.DRAIN * S.CALM_INDOORS * S.CALM_DARK * S.CALM_BATH, 1e-6, "a bath drains it three times as fast")
bathing = "SHOWER"
d.siLoad = 50
H.minute()
near(50 - d.siLoad, S.DRAIN * S.CALM_INDOORS * S.CALM_DARK * S.CALM_SHOWER, 1e-6, "a shower twice")
p._st.wetness = 100
H.minute()
near(d.siCh.touch, 0, 1e-9, "the bath's soaking is no touch trigger")
p._st.wetness = 0
bathing = nil
DanTraits_BathingMode, DanTraits_BathingWet = nil, nil
H.mins(60)

-- 6. a meltdown when the roll comes up: panic and anger held up
H.rollf = 0.1
p._seen = 10
H.mins(30)
assert(d.siOver == "meltdown", "a meltdown")
assert(p._st.panic >= S.MELT_PANIC - 1e-9 and p._st.anger > 0, "panic and anger held up")
assert(DanTraits_MoodleLevels(p, d).SensoryLoad == 3, "meltdown is the third level")
assert((d.siShouts or 0) > 0 and #H.sounds > 0, "outbursts out loud, heard")
assert(table.concat(H.halo, " "):find("UI_DanTraits_SensoryWornThin", 1, true), "the second overload: worn thin")
assert(d.siToll == 2, "worn thin by two")

-- 6b. everything takes longer; a meltdown throws down what is held; a shutdown cannot sprint
near(DanTraits_SensoryActionTime(p), S.ACTION_TIME[3], 1e-9, "overloaded: actions x1.4")
d.siTier = 2
near(DanTraits_SensoryActionTime(p), 1.2, 1e-9, "overwhelmed: x1.2")
d.siTier = 1
near(DanTraits_SensoryActionTime(p), 1, 1e-9, "on edge: no slower")
d.siTier = 3
near(DanTraits_SensoryActionTime(H.player({})), 1, 1e-9, "no trait: no slower")
local dropped = #p._dropped
H.rollf = 0.05
H.minute()
assert(#p._dropped > dropped, "a meltdown throws down what is held")
d.siOver = "shutdown"
p._sprint = true
H.frame(p)
assert(not p._sprint and p._cantSprint, "a shutdown: no sprinting")
d.siOver = "meltdown"
p._seen = 0
H.mins(90)

-- 6c. worn thin: each overload lowers the input for 100, a night's sleep wears it off
near(DanTraits_SensoryFullInput(d), S.FULL_INPUT * S.TOLL ^ 2, 1e-9, "two overloads: x0.85 twice")
d.siToll = 9
near(DanTraits_SensoryFullInput(d), S.FULL_INPUT * S.TOLL ^ S.TOLL_MAX, 1e-9, "at most three")
d.siToll = 2
p._asleep = true
H.mins(60)
p._asleep = false
H.minute()
assert(d.siToll == 2, "a nap does not wear it off")
p._asleep = true
H.mins(S.TOLL_SLEEP_MIN)
H.clearHalo()
p._asleep = false
H.minute()
assert(d.siToll == nil and H.halo[#H.halo] == "+UI_DanTraits_SensoryRested", "slept it off")

-- 7. sound: a gunshot nearby is heard in full; it fades by half a minute
H.fire("OnWorldSound", 12, 10, 0, 100, 50, nil)
near(d.siSound, 1 - 0.5 * 2 / 100, 1e-9, "a loud shot two tiles off")
H.fire("OnWorldSound", 12, 10, 0, 8, 50, nil)
near(d.siSound, 0.99, 1e-9, "footsteps do not count")
H.fire("OnWorldSound", 300, 10, 0, 100, 50, nil)
near(d.siSound, 0.99, 1e-9, "out of earshot")
H.minute()
near(d.siCh.sound, 0.99, 1e-9, "the sound channel")
near(d.siSound, 0.495, 1e-9, "fading")
d.siSound = 1
p._worn = { { type = "Base.Hat_EarMuff_Protectors", name = "Ear Protectors" } }
near(DanTraits_SensoryEars(p), S.PROTECTORS, 1e-9, "ear protectors")
p._worn = {}
local deaf = person({ traits = { "sensory" }, vanilla = { "base:deaf" } })
near(DanTraits_SensoryEars(deaf), 0, 1e-9, "deaf hears none of it")
local hoh = person({ traits = { "sensory" }, vanilla = { "base:hardofhearing" } })
near(DanTraits_SensoryEars(hoh), S.HARD_OF_HEARING, 1e-9, "hard of hearing: half")
p._worn = { { type = "Base.Hat_EarMuffs", name = "Ear Muffs" } }
near(DanTraits_SensoryEars(p), 0.4, 1e-9, "ear muffs cut 60%")

-- 7b. noise-cancelling headphones: no noise at all, and deaf while worn (anyone)
CharacterTrait.DEAF = "base:deaf"
p._worn = { { type = "DanTraits.NCHeadphones", name = "Noise-Cancelling Headphones" } }
near(DanTraits_SensoryEars(p), 0, 1e-9, "headphones: nothing gets through")
H.clearHalo()
DanTraits_UpdateHeadphones(p, d)
assert(DanTraits_HasVanillaTrait(p, "base:deaf") and d.hpDeaf, "deaf while worn")
assert(H.halo[#H.halo] == "+UI_DanTraits_HeadphonesOn", "silence")
DanTraits_UpdateHeadphones(p, d)
assert(#H.halo == 1, "told once")
p._worn = {}
DanTraits_UpdateHeadphones(p, d)
assert(not DanTraits_HasVanillaTrait(p, "base:deaf") and d.hpDeaf == nil, "hearing back when they come off")
assert(H.halo[#H.halo] == "UI_DanTraits_HeadphonesOff", "sound comes rushing back")
local born = person({ vanilla = { "base:deaf" } })
local bd = DanTraits_Data(born)
born._worn = { { type = "DanTraits.NCHeadphones", name = "Noise-Cancelling Headphones" } }
DanTraits_UpdateHeadphones(born, bd)
born._worn = {}
DanTraits_UpdateHeadphones(born, bd)
assert(DanTraits_HasVanillaTrait(born, "base:deaf") and bd.hpDeaf == nil, "a deaf character stays deaf")
local anyone = person({})
anyone._worn = { { type = "DanTraits.NCHeadphones", name = "Noise-Cancelling Headphones" } }
DanTraits_UpdateHeadphones(anyone, DanTraits_Data(anyone))
assert(DanTraits_HasVanillaTrait(anyone, "base:deaf"), "headphones work without the trait")
p._worn = {}
d.siSound = nil

-- 8. clothes: a jumper scratches, a gas mask presses, denim a little; plain cotton nothing
local function garment(kind, name, loc, fabric)
  return { getType = function() return kind end, getDisplayName = function() return name end,
           getBodyLocation = function() return loc end, getFabricType = function() return fabric end }
end
assert(DanTraits_SensoryGarment(garment("Jumper_RoundNeck", "Jumper", "base:sweater", "Cotton")) == "scratchy", "a jumper")
assert(DanTraits_SensoryGarment(garment("Scarf_Wool", "Wool Scarf", "base:scarf", "Cotton")) == "scratchy", "anything named wool")
assert(DanTraits_SensoryGarment(garment("Hat_GasMask", "Gas Mask", "base:maskeyes", nil)) == "tight", "a gas mask")
assert(DanTraits_SensoryGarment(garment("Hat_RiotHelmet", "Riot Helmet", "base:fullhat", nil)) == "tight", "a helmet")
assert(DanTraits_SensoryGarment(garment("Trousers_Denim", "Jeans", "base:pants", "Denim")) == "denim", "jeans")
assert(DanTraits_SensoryGarment(garment("Tshirt_DefaultTEXTURE", "T-shirt", "base:tshirt", "Cotton")) == nil, "a t-shirt")
-- the tooltip's word for each: soft for cotton or a soft name, nothing for shoes and leather
local tip = DanTraits_SensoryGarmentTip
assert(tip(garment("Jumper_RoundNeck", "Jumper", "base:sweater", "Cotton")) == "scratchy", "tip: scratchy")
assert(tip(garment("Tshirt_DefaultTEXTURE", "T-shirt", "base:tshirt", "Cotton")) == "soft", "tip: a cotton tee is soft")
assert(tip(garment("Shirt_Silk", "Silk Shirt", "base:shirt", nil)) == "soft", "tip: silk by name")
assert(tip(garment("Trousers_Denim", "Jeans", "base:pants", "Denim")) == "denim", "tip: rough")
assert(tip(garment("Jacket_Leather", "Leather Jacket", "base:jacket", "Leather")) == nil, "tip: leather says nothing")

-- 9. a disliked food stresses and upsets; three calm portions of a neither food make it safe
local st0, sad0 = p._st.stress, p._st.unhappy
d.siLoad = 0
DanTraits_RunHooks("eat", nil, p, food("Base.Egg", "Egg"), 1)
near(p._st.stress - st0, S.HATE_STRESS, 1e-9, "stress")
near(p._st.unhappy - sad0, S.HATE_SAD, 1e-9, "and upset")
near(d.siLoad, S.HATE_LOAD, 1e-9, "and load")
d.siLoad = 0
H.clearHalo()
for _ = 1, 5 do DanTraits_RunHooks("eat", nil, p, food("Base.Broccoli", "Vegetables"), 0.5) end
assert(DanTraits_SensoryFood(p, food("Base.Broccoli", "Vegetables")) == nil, "two and a half portions: not yet")
DanTraits_RunHooks("eat", nil, p, food("Base.Broccoli", "Vegetables"), 0.5)
assert(DanTraits_SensoryFood(p, food("Base.Broccoli", "Vegetables")) == "safe", "three portions: safe now")
assert(H.halo[#H.halo] == "+UI_DanTraits_SensoryLearned:Broccoli", "told")
d.siLoad = 50
DanTraits_RunHooks("eat", nil, p, food("Base.Carrots", "Vegetables"), 1)
assert(not (d.siTried or {})["Base.Carrots"], "not learned while on edge")

-- 10. a stim: thirty off, half that again within the hour
assert(DanTraits_SensoryStimKind({ getFullType = function() return "Base.Yoyo" end }) == "fidget", "a yo-yo")
assert(DanTraits_SensoryStimKind({ getFullType = function() return "Base.Dice_6" end }) == "fidget", "dice")
assert(DanTraits_SensoryStimKind({ getFullType = function() return "Base.Spiffo" end }) == "hold", "a Spiffo")
assert(DanTraits_SensoryStimKind({ getFullType = function() return "Base.Axe" end }) == nil, "not an axe")
d.siLoad = 80
near(DanTraits_SensoryStim(p), S.STIM_LOAD, 1e-9, "a stim")
near(d.siLoad, 80 - S.STIM_LOAD, 1e-9, "load down")
near(DanTraits_SensoryStim(p), S.STIM_LOAD / 2, 1e-9, "again within the hour: half")

-- 11. the other systems: spoons cost more with the load, a night begun overwhelmed is worse
d.siLoad = 100
near(DanTraits_RunHooks("spoonSpend", 1, p, d), 1 + S.SPOON_COST, 1e-9, "spoons x1.5 at full load")
d.siSleepLoad = 70
near(DanTraits_RunHooks("nightQuality", 1, p, d), 1 - S.NIGHT_CUT, 1e-9, "a worse night")
assert(d.siSleepLoad == nil, "counted once")

-- 12. the food tooltip (client)
DanShared_Tooltip = { add = function(id, order, fn) DanShared_Tooltip.fn = fn end }
ISInventoryPaneContextMenu = {}
H.load("client/DanTraits_SensoryClient.lua")
local tip = DanShared_Tooltip.fn(p, food("Base.Crackers"))
assert(tip[1][1] == "Tooltip_DanTraits_SensorySafe:UI_DanTraits_SensoryGroup_crunchy", "safe, crunchy")
tip = DanShared_Tooltip.fn(p, food("Base.Egg", "Egg"))
assert(tip[1][1] == "Tooltip_DanTraits_SensoryHate:UI_DanTraits_SensoryGroup_slimy", "can't stand it, slimy")
tip = DanShared_Tooltip.fn(p, food("Base.Broccoli", "Vegetables"))
assert(tip[1][1] == "Tooltip_DanTraits_SensorySafe:UI_DanTraits_SensoryGroup_learned", "learned")
tip = DanShared_Tooltip.fn(p, garment("Jumper_RoundNeck", "Jumper", "base:sweater", "Cotton"))
assert(tip[1][1] == "Tooltip_DanTraits_Sensory_scratchy" and tip[1][2] > 0.8 and tip[1][3] < 0.5, "a jumper: scratchy, in red")
tip = DanShared_Tooltip.fn(p, garment("Tshirt_DefaultTEXTURE", "T-shirt", "base:tshirt", "Cotton"))
assert(tip[1][1] == "Tooltip_DanTraits_Sensory_soft" and tip[1][3] > 0.8, "a t-shirt: soft, in green")
assert(DanShared_Tooltip.fn(p, garment("Jacket_Leather", "Leather Jacket", "base:jacket", "Leather")) == nil, "leather: nothing")
assert(DanShared_Tooltip.fn(p, { getFullType = function() return "Base.Axe" end }) == nil, "neither food nor clothing: nothing")

-- 13. without the trait: nothing
local plain = person({}); H.current = plain
plain._seen = 10
H.mins(30)
local pd = DanTraits_Data(plain)
assert(pd.siLoad == nil and plain._st.stress == 0, "no trait: no load, no stress")
assert(DanTraits_SensoryFood(plain, food("Base.Egg", "Egg")) == nil, "no trait: no verdict")
assert(DanTraits_RunHooks("refuseFood", nil, plain, food("Base.Egg", "Egg")) == nil, "no trait: eats anything")
assert(DanTraits_MoodleLevels(plain, pd).SensoryLoad == 0, "no trait: no moodle")
assert(DanShared_Tooltip.fn(plain, food("Base.Egg", "Egg")) == nil, "no trait: no tooltip")

H.pass()
