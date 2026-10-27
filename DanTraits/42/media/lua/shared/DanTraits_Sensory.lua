-- Project Zomboid Vitality Project: Sensory Issues.
--
-- Too much input, and it adds up. Six senses feed one sensory load (0..100)
-- every minute awake, each a 0..1 reading:
--   touch   scratchy garments against the skin (jumpers, wooly hats, anything
--           named wool or knit; denim a little), tight headgear (helmets, gas
--           and face masks, a welding mask), Laundry's itch count (damp, musty,
--           never washed, dryer-sheet perfume: the same count Sensitive Skin
--           feels) and being wet through
--   grime   Germaphobe's reading (DanTraits_GermGrime): blood and dirt on the
--           skin and clothes, a bloody weapon in the hand
--   sound   the loudest world sound heard lately (OnWorldSound: gunshots,
--           alarms, horns, banging; it fades by half each minute), ringing ears
--           (Tinnitus), a running engine around you, thunder. Deaf hears none
--           of it, Hard of Hearing half, Keen Hearing more; ear muffs cut it
--           by 60%, shooting ear protectors by 80%, and noise-cancelling
--           headphones (DanTraits.NCHeadphones) shut it all out, along with
--           every other sound: they make the wearer deaf while worn
--   crowd   zombies in sight (the game's own count, one or two hardly
--           register, ten is the most) and right on top of you
--   light   bright sun outdoors (Migraine's reading); sunglasses cut it
--   smell   corpses close by
-- The load heads for a target set by the weighted sum (S.FULL_INPUT or more
-- sends it to 100): up a share of the gap a minute, down at a steady drain
-- that only works while the input is low. Calm makes the drain faster:
-- indoors with nothing in sight, at home (Home's moodle), a dark room,
-- sitting down, in a bath (x3) or shower (x2) with Take A Bath And Shower,
-- and asleep most of all. The bath's soaking is not a touch trigger. A stim (a fidget toy or something
-- to hold, ISSensoryStimAction) and a safe food take a chunk off at once.
-- Every minute the input itself also adds a little stress.
--
-- Tiers on the load: On Edge (30: stress held up), Overwhelmed (60: more,
-- unhappiness held up, stamina back slower, timed actions x1.2), Overloaded
-- (90, until it falls back under 50; actions x1.4). An overload is one of
-- two, rolled as it starts: a meltdown (panic and anger held up: Anger's
-- rough, loud, sloppy; a tenth of minutes what is in the hands is thrown
-- down, a fifth an outburst out loud that zombies hear) or a shutdown
-- (stamina back at half, no sprinting, bored and low). Overloaded, the only
-- food that goes down is a safe one (the core's refuseFood hook). Each
-- overload wears you thin: until a night's sleep (four hours in one go) the
-- input that sends the load to 100 is x0.85 per overload (up to three).
--
-- Food. At creation the character gets two safe and two disliked texture
-- groups out of eight (crunchy, mushy, slimy, chewy, mixed, strong, plain,
-- sweet; at least one safe group keeps: crunchy, mushy, plain or sweet). A
-- food is in every group its name or food type puts it in, and a cooked dish
-- of three things or more is mixed; any disliked group wins. A safe food
-- lifts the mood and takes load off, a disliked one stresses, upsets and may
-- be gagged on halfway (the eat action stops; what went down counts). A food
-- in neither, eaten calmly (load under the first tier) three whole times,
-- becomes a safe food of its own (by type).
--
-- Hooks into other traits: Migraine (an overload is a trigger), Spoons (the
-- load makes every minute cost more), the night (going to sleep overwhelmed
-- scores the night lower), Sensitive Skin (both feel Laundry's itch, each
-- its own way), Germaphobe (both read the same grime).
--
-- Mod data: siLoad, siTier, siOver ("meltdown"/"shutdown" while overloaded),
-- siSafe and siHate (group keys), siSound (the fading loudness), siIn and
-- siCh (last minute's input and channels, for the console), siTold (the tier
-- whose notice was given) and siPeak (the highest tier since calm, for the calm
-- line), siHoldMin (the console's hold), siStimAt (hours), siTried and siLearned
-- (by full type), siKitGiven, siAsleep, siSleepLoad, siToll (overloads since the
-- last night's sleep), siSleptMin, siShouts; hpDeaf (the headphones made the
-- wearer deaf).
-- Console: sensory | sensory load <0..100> | sensory foods | sensory reroll
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01
local over = DanTraits_Over
local foodTags = DanTraits_FoodTags

local S = {
    TIER          = { 30, 60, 90 },
    OVER_END      = 50,      -- an overload lasts until the load falls under this (70 until 2026-10-20)
    FULL_INPUT    = 1.5,     -- weighted input that sends the load to 100
    RISE          = 0.1,     -- share of the gap to the target closed a minute, climbing
    DRAIN         = 0.75,    -- load a minute back down at full calm (1.5 until 2026-10-20)...
    DRAIN_BLOCK   = 1.0,     -- ...none at this input or more
    STRESS_MIN    = 0.0015,  -- stress a minute per unit of input
    W = { touch = 1, grime = 1, sound = 1.5, crowd = 2, light = 0.7, smell = 1 },
    -- touch
    SCRATCHY      = 0.5,     -- a wool garment against the skin
    DENIM         = 0.15,
    TIGHT         = 0.3,     -- a helmet or a mask
    ITCH          = 0.2,     -- per point of Laundry's itch count
    WET_FROM      = 0.3,     -- wetness (0..1) from which it counts
    WET           = 0.5,     -- at wet through
    -- grime
    GRIME_FROM    = 0.1,
    GRIME_FULL    = 0.6,
    -- sound
    SOUND_MIN     = 12,      -- sounds of a smaller radius do not count (footsteps)
    SOUND_FULL    = 60,      -- radius of a full-strength sound
    SOUND_FADE    = 0.5,     -- the remembered loudness x this a minute
    RINGING       = 0.5,
    ENGINE        = 0.3,
    THUNDER       = 0.3,
    HARD_OF_HEARING = 0.5,
    KEEN          = 1.25,
    EARMUFFS      = 0.4,     -- noise through ear muffs (was 0.6 until 2026-10-19)
    PROTECTORS    = 0.2,     -- through shooting ear protectors (was 0.3)
    -- crowd
    CROWD_FREE    = 1,       -- this many in sight count for nothing
    CROWD_FULL    = 10,      -- this many is the most
    CROWD_CLOSE   = 0.15,    -- each one very close
    -- light
    SUN           = 0.6,
    SHADES        = 0.4,
    -- smell
    CORPSE_TILES  = 4,
    CORPSE_FULL   = 6,
    -- calm (drain multipliers)
    CALM_INDOORS  = 1.5,     -- indoors with nothing in sight
    CALM_HOME     = 1.5,
    CALM_DARK     = 1.3,
    CALM_SITTING  = 1.2,
    CALM_ASLEEP   = 4,
    CALM_BATH     = 3,       -- in a bath (Take A Bath And Shower)
    CALM_SHOWER   = 2,       -- in a shower
    CALM_BREATHE  = 2,       -- Still Water at full calm (DanTraits_SpiffBoy.lua): x (1 + (this - 1) x calm)
    ASLEEP_TOUCH  = 0.5,     -- asleep, only the touch channel counts, at this
    -- effects by tier
    STRESS_FLOOR  = { 0.25, 0.5, 0.75 },
    STRESS_RAMP   = 0.02,    -- stress a minute toward the floor
    SAD_FLOOR     = { 0, 25, 40 },
    SAD_RAMP      = 1,
    ENDURANCE     = { 1, 0.8, 0.6 },   -- stamina regained x this
    MELT_PANIC    = 40,      -- panic held at this in a meltdown (0..100)
    MELT_PANIC_RAMP = 10,
    MELT_ANGER    = 0.5,     -- anger held at this (0..1)
    MELT_ANGER_RAMP = 0.1,
    SHUT_ENDURANCE = 0.5,
    SHUT_BORED    = 50,
    SHUT_SAD      = 50,
    MELTDOWN      = 0.5,     -- the chance an overload is a meltdown
    ACTION_TIME   = { 1, 1.2, 1.4 },   -- timed actions started at each tier take this much longer
    MELT_DROP     = 0.1,     -- a meltdown: the chance a minute of throwing down what is in the hands
    MELT_SHOUT    = 0.2,     -- ...and of an outburst out loud
    MELT_SHOUT_RADIUS = 20,  -- tiles the outburst carries (zombies hear it)
    SHOUT_LINES   = 4,
    TOLL          = 0.85,    -- each overload since the last night's sleep: the input for 100 x this
    TOLL_MAX      = 3,       -- counting up to this many
    TOLL_SLEEP_MIN = 240,    -- this long asleep in one go and it is slept off
    -- stim
    STIM_LOAD     = 30,
    STIM_STRESS   = 0.1,
    STIM_AGAIN_H  = 1,       -- another stim within this many hours does half
    -- food
    SAFE_LOAD     = 20,      -- off the load for a whole safe portion
    SAFE_SAD      = 10,
    SAFE_STRESS   = 0.05,
    HATE_LOAD     = 10,
    HATE_SAD      = 15,
    HATE_STRESS   = 0.1,
    GAG_AT        = 0.35,    -- the eat action's progress when a gag is rolled
    GAG           = 0.5,
    LEARN_PORTIONS = 3,
    MIXED_PARTS   = 3,       -- a dish of this many ingredients is mixed
    -- other traits
    NIGHT_AT      = 60,      -- falling asleep at this load or more...
    NIGHT_CUT     = 0.15,    -- ...the night scores this much lower
    SPOON_COST    = 0.5,     -- spoons a minute x (1 + this x load/100)
}
DanTraits_SensoryC = S

-- the eight texture groups: words in the item's type (lowercase), whole food
-- types, and words that cancel the group (checked against the game's 722 foods)
local function words(s)
    local t, at = {}, 1
    while true do
        local from, to = string.find(s, "%S+", at)
        if not from then return t end
        t[#t + 1] = string.sub(s, from, to)
        at = to + 1
    end
end
local function set(s)
    local t = {}
    for _, w in ipairs(words(s)) do t[w] = true end
    return t
end
local GROUPS = {
    crunchy = { words = words("cracker chips crisps cereal pretzel cookie popcorn granola peanut almond pecan walnut cashew pistachio sunflowerseeds pumpkinseed apple carrot celery cucumber radish toast crouton biscuit wafer nachos porkrinds"),
                types = set("nut"), safe = words("pineapple pieapple cakecarrot cannedcarrot chocolatechips peanutbutter dough") },
    mushy   = { words = words("soup stew oatmeal porridge mashed smashed babyfood pudding yogurt yoghurt applesauce custard beans refried chili cannedcorn cannedpeas cannedpotato cannedpeach fruitcocktail cannedbroccoli cannedcabbage cannedeggplant cannedleek mixedvegetables tvdinner pasta macaroni spaghetti ramen noodle lasagn macandcheese dumpling banana avocado guacamole gravy sourcream"),
                types = set("bean"), safe = words("cookiesoatmeal coffeebean jellybean seed cornedbeef") },
    slimy   = { words = words("egg mushroom oyster sardine anchov squid octopus clam mussel snail slug worm leech okra tofu jelly jello roe caviar tomato olives seaweed maki sushi liver kidney"),
                types = set("egg mushroom roe"), safe = words("eggplant jellybean cookiejelly doughnutjelly jellyroll gummy kidneybean") },
    chewy   = { words = words("steak beef pork jerky ham bacon sausage salami baloney chicken turkey venison rabbitmeat mutton meatpatty mincedmeat hotdog meatstick smallanimalmeat smallbirdmeat licorice caramel taffy toffee bagel"),
                types = set("meat beef poultry game sausage bacon venison"), safe = words("graham chickennuggets cornedbeef chamomile feather dung _head buns porkrinds turkeyegg") },
    mixed   = { words = words("sandwich burger pizza taco burrito casserole stirfry salad omelette pie stew soup chili lasagn friedvegetables springroll cabbageroll hotdog corndog smore perogies"),
                types = {}, safe = words("crappie poppies buns icecreamsandwich tacoshell pastaco") },
    strong  = { words = words("fish salmon trout tuna sardine anchov herring crab shrimp lobster cheese garlic onion pickle kimchi sauerkraut hotsauce jalapeno chili pepper wasabi horseradish mustard vinegar curry liver salsa bbqsauce soysauce ginger"),
                types = set("fish seafood hotpepper cheese"), safe = words("bellpepper gummy cheesecake gingerbread") },
    plain   = { words = words("bread bagel baguette rice pasta macaroni spaghetti noodle potato tortilla cracker toast plain bun muffin oatmeal croissant fries tatodots onigiri chickennuggets"),
                types = set("bread rice pasta"), safe = words("potatochips sweetpotato shortbread gingerbread licorice bundle vinegar cookiesoatmeal") },
    sweet   = { words = words("candy chocolate cookie cake donut doughnut cupcake marshmallow lollipop gum gummy toffee fudge caramel soda cola pop icecream jam honey syrup sugar twinkie poptart pie muffin danish cinnamonroll lemonbar creamocle waffle cannedpeach fruitcocktail smore jujubes allsorts"),
                types = set("candy chocolate sugar"), safe = words("popcorn sugarcane crappie soupopen popp potatopancake sugarbeet") },
}
local GROUP_ORDER = { "crunchy", "mushy", "slimy", "chewy", "mixed", "strong", "plain", "sweet" }
local STABLE = { crunchy = true, mushy = true, plain = true, sweet = true }   -- food that keeps
S.GROUPS, S.GROUP_ORDER, S.STABLE = GROUPS, GROUP_ORDER, STABLE

local function hasWord(name, list)
    for _, w in ipairs(list) do
        if string.find(name, w, 1, true) then return true end
    end
    return false
end

-- the groups a name and food type earn, as a set
local function groupsOfName(name, foodType)
    local out = {}
    for _, key in ipairs(GROUP_ORDER) do
        local g = GROUPS[key]
        local hit = hasWord(name, g.words) or (foodType ~= "" and g.types[foodType] == true)
        if hit and hasWord(name, g.safe) then hit = false end
        if hit then out[key] = true end
    end
    return out
end

local nameMemo = {}   -- full type -> the name and food-type groups
local function foodGroups(item)
    if not item then return {} end
    local full
    pcall(function() full = item:getFullType() end)
    local base = full and nameMemo[full]
    if not base then
        local name, ft = "", ""
        pcall(function() name = string.lower(tostring(item:getType() or "")) end)
        pcall(function() ft = string.lower(tostring(item:getFoodType() or "")):gsub("^.*:", "") end)
        base = groupsOfName(name, ft)
        if full then nameMemo[full] = base end
    end
    local out = {}
    for k in pairs(base) do out[k] = true end
    local parts = 0
    pcall(function() parts = tonumber(foodTags(item).ingredients) or 0 end)
    if parts >= S.MIXED_PARTS then out.mixed = true end
    return out
end
DanTraits_SensoryGroups = foodGroups
DanTraits_SensoryGroupsOfName = groupsOfName

local function inList(list, key)
    for _, k in ipairs(list or {}) do if k == key then return true end end
    return false
end

-- draw two safe and two disliked groups, once; the first safe group keeps
local function rollFoods(d, force)
    if d.siSafe and not force then return end
    local pool = {}
    for _, k in ipairs(GROUP_ORDER) do pool[#pool + 1] = k end
    local function take(test)
        local options = {}
        for i, k in ipairs(pool) do if not test or test(k) then options[#options + 1] = i end end
        local i = options[ZombRand(#options) + 1]
        return table.remove(pool, i)
    end
    d.siSafe = { take(function(k) return STABLE[k] end), take() }
    d.siHate = { take(), take() }
end
DanTraits_SensoryRollFoods = rollFoods

-- only food is judged: asked about anything else (the refuseFood hook runs on
-- every right-clicked item) a food method would be called on an item without
-- it, which B42 logs as an error even inside pcall
local function isFood(item)
    local ok, res = pcall(instanceof, item, "Food")
    return ok and res == true
end

-- "safe", "disliked" or nil, and the group that decided it (or "learned")
local function foodVerdict(player, item)
    if not player or not item or not isFood(item) or not hasTrait(player, "sensory") then return nil end
    local d = DanTraits_Data(player)
    rollFoods(d)
    local groups = foodGroups(item)
    for _, k in ipairs(d.siHate) do if groups[k] then return "disliked", k end end
    for _, k in ipairs(d.siSafe) do if groups[k] then return "safe", k end end
    local full
    pcall(function() full = item:getFullType() end)
    if full and d.siLearned and d.siLearned[full] then return "safe", "learned" end
    return nil
end
DanTraits_SensoryFood = foodVerdict

-- channels -------------------------------------------------------------------------

local function worn(player)
    local L = DanTraits_Laundry
    if L and L.worn then return L.worn(player) end
    local out = {}
    pcall(function()
        local list = player:getWornItems()
        for i = 0, list:size() - 1 do
            local item = list:getItemByIndex(i)
            if item then out[#out + 1] = item end
        end
    end)
    return out
end

local TIGHT_AT = set("fullhat mask maskfull maskeyes scba fullsuithead gorget")

local locationOf = DanTraits_BodyLocation

-- how a garment feels: "scratchy", "denim", "tight" or nil
local function garmentFeel(item)
    local kind, name, loc, fabric = "", "", locationOf(item), ""
    pcall(function() kind = string.lower(tostring(item:getType() or "")) end)
    pcall(function() name = string.lower(tostring(item:getDisplayName() or "")) end)
    if TIGHT_AT[loc] or string.find(kind, "helmet", 1, true) then return "tight" end
    if string.find(kind, "jumper_", 1, true) == 1 or string.find(kind, "wooly", 1, true) or string.find(kind, "balaclava", 1, true)
        or string.find(name, "wool", 1, true) or string.find(name, "knit", 1, true) then return "scratchy" end
    pcall(function() fabric = tostring(item:getFabricType() or "") end)
    if fabric == "Denim" then return "denim" end
    return nil
end
DanTraits_SensoryGarment = garmentFeel

-- what a garment's tooltip says to a character with the trait
-- (client/DanTraits_SensoryClient.lua): its feel, or "soft" for one that is
-- easy on the skin (cotton, or named silk, satin, fleece, flannel, velvet or
-- cashmere); nil for what has no fabric to speak of (shoes, leather, jewellery)
local SOFT_WORDS = { "silk", "satin", "fleece", "flannel", "velvet", "cashmere" }
function DanTraits_SensoryGarmentTip(item)
    local feel = garmentFeel(item)
    if feel then return feel end
    local name, fabric = "", ""
    pcall(function() name = string.lower(tostring(item:getDisplayName() or "")) end)
    pcall(function() fabric = tostring(item:getFabricType() or "") end)
    if fabric == "Cotton" then return "soft" end
    for _, w in ipairs(SOFT_WORDS) do
        if string.find(name, w, 1, true) then return "soft" end
    end
    return nil
end

local FEEL = { scratchy = "SCRATCHY", denim = "DENIM", tight = "TIGHT" }

local function touchOf(player)
    local n = 0
    for _, item in ipairs(worn(player)) do
        local feel = garmentFeel(item)
        if feel then n = n + S[FEEL[feel]] end
    end
    local L = DanTraits_Laundry
    if L and L.on and L.itch and L.on() then n = n + S.ITCH * (tonumber(L.itch(player)) or 0) end
    local wet = 0
    -- a bath or shower's soaking is chosen, not suffered (Take A Bath And Shower,
    -- DanTraits_Bathing.lua): it does not count until that mod calls you dry
    local bathing = DanTraits_BathingWet and DanTraits_BathingWet(player)
    if not bathing then pcall(function() wet = DanTraits_StatFraction(player:getStats(), CharacterStat.WETNESS) end) end
    if wet > S.WET_FROM then n = n + S.WET * over(wet, S.WET_FROM, 1) end
    return clamp01(n)
end

local function grimeOf(player, d)
    if not DanTraits_GermGrime then return 0 end
    local grime = 0
    pcall(function() grime = tonumber(DanTraits_GermGrime(player, d)) or 0 end)
    return over(grime, S.GRIME_FROM, S.GRIME_FULL)
end

local function wearing(player, fullType)
    local found = false
    for _, item in ipairs(worn(player)) do
        pcall(function() if item:getFullType() == fullType then found = true end end)
        if found then return true end
    end
    return false
end

-- Noise-cancelling headphones (DanTraits.NCHeadphones), for anyone: worn, they
-- shut out every sound. The game's own Deaf trait does the muting (its audio
-- listens for it): put on while they are worn, taken back off after. A
-- character who is deaf anyway is left alone (hpDeaf marks the one we gave).
-- Checked every minute and whenever the clothes change.
local HEADPHONES = "DanTraits.NCHeadphones"
local function wearingHeadphones(player) return wearing(player, HEADPHONES) end
DanTraits_WearingHeadphones = wearingHeadphones

local function updateHeadphones(player, d)
    local on = wearingHeadphones(player)
    if on and not d.hpDeaf and not hasVanillaTrait(player, "base:deaf") then
        if DanTraits_SetTrait(player, "base:DEAF", true) then
            d.hpDeaf = true
            DanTraits_NotifyGood(player, "UI_DanTraits_HeadphonesOn")
        end
    elseif not on and d.hpDeaf then
        d.hpDeaf = nil
        DanTraits_SetTrait(player, "base:DEAF", false)
        notify(player, "UI_DanTraits_HeadphonesOff")
    end
end
DanTraits_UpdateHeadphones = updateHeadphones
DanTraits_Every("minute", "Headphones", updateHeadphones, 41)
if Events and Events.OnClothingUpdated then
    Events.OnClothingUpdated.Add(function(character)
        local mine = false
        pcall(function() mine = instanceof(character, "IsoPlayer") and character:isLocalPlayer() and not character:isDead() end)
        if mine then DanTraits_Guard("Headphones (clothing)", updateHeadphones, character, DanTraits_Data(character)) end
    end)
end

-- how much of the noise gets through: the ears, then what is over them
-- (noise-cancelling headphones: none)
local function earsOf(player)
    if hasVanillaTrait(player, "base:deaf") or wearingHeadphones(player) then return 0 end
    local k = 1
    if hasVanillaTrait(player, "base:hardofhearing") then k = S.HARD_OF_HEARING
    elseif hasVanillaTrait(player, "base:keenhearing") then k = S.KEEN end
    if wearing(player, "Base.Hat_EarMuff_Protectors") then k = k * S.PROTECTORS
    elseif wearing(player, "Base.Hat_EarMuffs") then k = k * S.EARMUFFS end
    return k
end
DanTraits_SensoryEars = earsOf

local function soundOf(player, d)
    local n = d.siSound or 0
    if DanTraits_TinnitusRinging then n = n + S.RINGING * DanTraits_Strength("DanTraits_TinnitusRinging", player) end
    pcall(function()
        local v = player:getVehicle()
        if v and v:isEngineRunning() then n = n + S.ENGINE end
    end)
    pcall(function() if getClimateManager():getIsThunderStorming() then n = n + S.THUNDER end end)
    return clamp01(n * earsOf(player))
end

local function zombieCounts(player)
    local seen, close = 0, 0
    pcall(function()
        local stats = player:getStats()
        seen = tonumber(stats:getNumVisibleZombies()) or 0
        close = tonumber(stats:getNumVeryCloseZombies()) or 0
    end)
    return seen, close
end

local function crowdOf(player)
    local seen, close = zombieCounts(player)
    local n = math.max(0, seen - S.CROWD_FREE) / (S.CROWD_FULL - S.CROWD_FREE) + S.CROWD_CLOSE * close
    return clamp01(n)
end

local function lightOf(player)
    if not DanTraits_InBrightLight or not DanTraits_InBrightLight(player) then return 0 end
    local n = S.SUN
    if DanTraits_WearingShades and DanTraits_WearingShades(player) then n = n * S.SHADES end
    return n
end

local function smellOf(player)
    if not DanTraits_CorpsesNearby then return 0 end
    return clamp01(DanTraits_CorpsesNearby(player, S.CORPSE_TILES) / S.CORPSE_FULL)
end

-- every channel now (0..1 each), and the weighted input; asleep, only touch counts
local function channelsOf(player, d, asleep)
    local ch = { touch = touchOf(player) }
    if asleep then
        ch.touch = ch.touch * S.ASLEEP_TOUCH
    else
        ch.grime = grimeOf(player, d)
        ch.sound = soundOf(player, d)
        ch.crowd = crowdOf(player)
        ch.light = lightOf(player)
        ch.smell = smellOf(player)
    end
    local input = 0
    for k, v in pairs(ch) do input = input + (S.W[k] or 0) * v end
    return ch, input
end
DanTraits_SensoryChannels = channelsOf

-- the channel doing the most, for the first notice
local function topChannel(ch)
    local best, most = nil, 0
    for k, v in pairs(ch) do
        local w = (S.W[k] or 0) * v
        if w > most then best, most = k, w end
    end
    return best
end

-- how fast it drains: indoors and clear, at home, in the dark, sitting, in a
-- bath or shower (Take A Bath And Shower), asleep
local function calmOf(player, d, asleep)
    if asleep then return S.CALM_ASLEEP end
    local k = 1
    local seen = zombieCounts(player)
    local outside = true
    pcall(function() outside = player:isOutside() end)
    if not outside and seen == 0 then k = k * S.CALM_INDOORS end
    if (d.hmMoodle or 0) < 0 then k = k * S.CALM_HOME end
    pcall(function()
        local sq = player:getCurrentSquare()
        if sq and sq:getLightLevel(player:getPlayerNum()) < DanTraits_NIGHT.dark then k = k * S.CALM_DARK end
    end)
    pcall(function() if player:isSitOnGround() then k = k * S.CALM_SITTING end end)
    local bath = DanTraits_BathingMode and DanTraits_BathingMode(player)
    if bath == "BATH" then k = k * S.CALM_BATH elseif bath == "SHOWER" then k = k * S.CALM_SHOWER end
    local breathe = DanTraits_StillWaterCalm and DanTraits_StillWaterCalm(player) or 0
    if breathe > 0 then k = k * (1 + (S.CALM_BREATHE - 1) * breathe) end
    return k
end

-- the load ---------------------------------------------------------------------------

-- the input that sends the load to 100: lower with every overload since the
-- last night's sleep (worn thin, the next one comes sooner)
local function fullInput(d)
    return S.FULL_INPUT * S.TOLL ^ math.min(S.TOLL_MAX, d.siToll or 0)
end
DanTraits_SensoryFullInput = fullInput

local function step(player, d, input, calm)
    local load = d.siLoad or 0
    local target = 100 * clamp01(input / fullInput(d))
    if target > load then
        load = load + (target - load) * S.RISE
    else
        local drain = S.DRAIN * calm * math.max(0, 1 - input / S.DRAIN_BLOCK)
        load = math.max(target, load - drain)
    end
    d.siLoad = math.max(0, math.min(100, load))
end
DanTraits_SensoryStep = step

local function setTier(player, d, tier, ch)
    local was = d.siTier or 0
    d.siTier = tier
    if tier == 3 and was < 3 then
        d.siOver = DanTraits_Roll(S.MELTDOWN) and "meltdown" or "shutdown"
        notify(player, d.siOver == "meltdown" and "UI_DanTraits_SensoryMeltdown" or "UI_DanTraits_SensoryShutdown")
        if (d.siToll or 0) > 0 then notify(player, "UI_DanTraits_SensoryWornThin") end
        if DanTraits_StrainAdd then DanTraits_StrainAdd(player, "overload", DanTraits_StrainST.OVERLOAD, false) end   -- DanTraits_Strain.lua
        d.siToll = math.min(S.TOLL_MAX, (d.siToll or 0) + 1)
        d.siTold = 3
    elseif tier < 3 then
        d.siOver = nil
    end
    if tier < was then
        -- on the way down: the notices come again on the next climb, and the calm
        -- line remembers how high it went (2026-10-22: siTold stuck at 3 after an
        -- overload until calm, so a day spent between tiers 1 and 2 said nothing)
        d.siPeak = math.max(d.siPeak or 0, was)
        d.siTold = math.min(d.siTold or 0, tier)
    end
    if tier == 2 and (d.siTold or 0) < 2 then
        notify(player, "UI_DanTraits_SensoryOverwhelmed")
        d.siTold = 2
    elseif tier == 1 and (d.siTold or 0) < 1 then
        local top = ch and topChannel(ch)
        if top then notify(player, "UI_DanTraits_SensoryCause_" .. top) end
        d.siTold = 1
    elseif tier == 0 then
        if math.max(d.siTold or 0, d.siPeak or 0) >= 2 then DanTraits_NotifyGood(player, "UI_DanTraits_SensoryCalm") end
        d.siTold, d.siPeak = nil, nil
    end
end

local function applyTier(player, d, tier, input)
    local stats = player:getStats()
    if input > 0 then DanTraits_StatAdd(stats, CharacterStat.STRESS, S.STRESS_MIN * input) end
    if tier <= 0 then return end
    DanTraits_FloorUp(stats, CharacterStat.STRESS, S.STRESS_FLOOR[tier], S.STRESS_RAMP)
    local sad = S.SAD_FLOOR[tier]
    if d.siOver == "shutdown" then sad = math.max(sad, S.SHUT_SAD) end
    if sad > 0 then DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, sad, S.SAD_RAMP) end
    if d.siOver == "meltdown" then
        DanTraits_FloorUp(stats, CharacterStat.PANIC, S.MELT_PANIC, S.MELT_PANIC_RAMP)
        DanTraits_FloorUp(stats, CharacterStat.ANGER, S.MELT_ANGER, S.MELT_ANGER_RAMP)
        if DanTraits_Roll(S.MELT_DROP) then DanTraits_DropHeld(player, true, "UI_DanTraits_SensoryDrop") end
        if DanTraits_Roll(S.MELT_SHOUT) then
            local line = getText("UI_DanTraits_SensoryShout" .. tostring(ZombRand(S.SHOUT_LINES) + 1))
            pcall(function() player:Say(line) end)
            pcall(function() addSound(player, player:getX(), player:getY(), player:getZ(), S.MELT_SHOUT_RADIUS, S.MELT_SHOUT_RADIUS) end)
            d.siShouts = (d.siShouts or 0) + 1
        end
    elseif d.siOver == "shutdown" then
        DanTraits_FloorUp(stats, CharacterStat.BOREDOM, S.SHUT_BORED, S.SAD_RAMP)
    end
end

local function updateSensoryMinute(player, d)
    rollFoods(d)
    local asleep = DanTraits_Asleep(player)
    if asleep and not d.siAsleep then d.siSleepLoad = d.siLoad or 0 end
    if asleep then
        d.siSleptMin = (d.siSleptMin or 0) + 1
    elseif d.siSleptMin then
        -- woke: a night's sleep in one go wears the day's overloads off
        if d.siSleptMin >= S.TOLL_SLEEP_MIN and d.siToll then
            d.siToll = nil
            DanTraits_NotifyGood(player, "UI_DanTraits_SensoryRested")
        end
        d.siSleptMin = nil
    end
    d.siAsleep = asleep or nil
    local ch, input = channelsOf(player, d, asleep)
    d.siCh, d.siIn = ch, input
    if d.siSound then
        d.siSound = d.siSound * S.SOUND_FADE
        if d.siSound < 0.01 then d.siSound = nil end
    end
    if d.siHoldMin and d.siHoldMin > 0 then
        d.siHoldMin = d.siHoldMin - 1
    else
        d.siHoldMin = nil
        step(player, d, input, calmOf(player, d, asleep))
    end
    local load = d.siLoad or 0
    local tier = DanTraits_TierOf(load, S.TIER)
    if (d.siTier or 0) == 3 and load >= S.OVER_END then tier = 3 end
    setTier(player, d, tier, ch)
    if not asleep then applyTier(player, d, tier, input) end
end

local function clearSensory(player, d)
    for _, k in ipairs({ "siLoad", "siTier", "siOver", "siSound", "siIn", "siCh", "siTold", "siPeak", "siAsleep", "siSleepLoad",
                         "siHoldMin", "siToll", "siSleptMin", "siShouts" }) do d[k] = nil end
end

DanTraits_Every("minute", "Sensory", updateSensoryMinute, 41, { trait = "sensory", clear = clearSensory })

-- A: everything takes longer. A timed action started Overwhelmed or overloaded
-- takes S.ACTION_TIME of the time (vanilla's own slow-downs, unhappy and drunk,
-- live in the same adjustMaxTime; wrapped again on OnGameStart in case the
-- class loads late)
local function actionTimeOf(character)
    if not character or not hasTrait(character, "sensory") then return 1 end
    local d = character:getModData().DanTraits
    return S.ACTION_TIME[d and d.siTier or 0] or 1
end
DanTraits_SensoryActionTime = actionTimeOf
local function wrapActionTime()
    DanTraits_Wrap(ISBaseTimedAction, "adjustMaxTime", "sensory-slow", function(original, self, maxTime, ...)
        local t = original(self, maxTime, ...)
        if type(t) == "number" and t > 1 and self.character then t = t * actionTimeOf(self.character) end
        return t
    end)
end
wrapActionTime()
if Events and Events.OnGameStart then Events.OnGameStart.Add(wrapActionTime) end

-- a shutdown: no sprinting (the Restricted Movement moodle on an attempt, as
-- Blood does it: set every frame the icon would blink)
local function updateShutdownFrame(player, d)
    if d.siOver ~= "shutdown" then return end
    local tried = false
    pcall(function() tried = player:isSprinting() == true end)
    if not tried then return end
    pcall(function() player:setSprinting(false) end)
    pcall(function() player:setMoodleCantSprint(true) end)
end
DanTraits_Every("frame", "SensoryShutdown", updateShutdownFrame, 40, { trait = "sensory" })

-- 0..1 for the other systems (Migraine's trigger): how far into an overload,
-- and only during one (the meltdown or shutdown, including its hold down to
-- OVER_END); Overwhelmed is 0 (2026-10-22: it read from tier 2 up)
function DanTraits_SensoryOverload(player)
    local d = player and player:getModData().DanTraits
    if not d or not d.siLoad or (d.siTier or 0) < 3 then return 0 end
    return over(d.siLoad, S.OVER_END, 100)
end

-- the world's sounds: remember the loudest heard, per local player with the trait
local function onWorldSound(x, y, z, radius, volume, source)
    radius = tonumber(radius) or 0
    if radius < S.SOUND_MIN then return end
    for i = 0, 3 do
        local player = getSpecificPlayer(i)
        if player and hasTrait(player, "sensory") then
            local dx, dy = (tonumber(x) or 0) - player:getX(), (tonumber(y) or 0) - player:getY()
            local dist = math.sqrt(dx * dx + dy * dy)
            if math.abs((tonumber(z) or 0) - player:getZ()) >= 1 then dist = dist * 2 end
            if dist <= radius then
                local loud = clamp01(radius / S.SOUND_FULL) * (1 - 0.5 * dist / radius)
                local d = DanTraits_Data(player)
                if loud > (d.siSound or 0) then d.siSound = loud end
            end
        end
    end
end
DanTraits_SensoryOnWorldSound = onWorldSound
if Events and Events.OnWorldSound then Events.OnWorldSound.Add(function(...) DanTraits_Guard("Sensory sound", onWorldSound, ...) end) end

-- relief -------------------------------------------------------------------------------

local function relieve(player, d, amount)
    d.siLoad = math.max(0, (d.siLoad or 0) - amount)
end

-- a stim: a fidget toy turned over in the hands, or something soft held close
local STIM_ITEMS = set("Base.Yoyo Base.Cube Base.RubberBand Base.Rubberducky Base.TennisBall Base.GolfBall Base.PoolBall Base.ToyCar Base.ToyPlane Base.CatToy Base.RubberSpider")
local HOLD_ITEMS = set("Base.Spiffo Base.SpiffoBig Base.ToyBear Base.ToyBear_Crafted_Burlap Base.ToyBear_Crafted_Cotton Base.Plushabug Base.Doll")

-- "fidget", "hold" or nil
function DanTraits_SensoryStimKind(item)
    local full = ""
    pcall(function() full = tostring(item:getFullType() or "") end)
    if HOLD_ITEMS[full] then return "hold" end
    if STIM_ITEMS[full] or string.find(full, "Base.Dice_", 1, true) == 1 or string.find(full, "Base.KeyRing_", 1, true) == 1 then return "fidget" end
    return nil
end

function DanTraits_SensoryStim(player)
    if not player or not hasTrait(player, "sensory") then return 0 end
    local d = DanTraits_Data(player)
    local now = 0
    pcall(function() now = getGameTime():getWorldAgeHours() end)
    local k = (d.siStimAt and now - d.siStimAt < S.STIM_AGAIN_H) and 0.5 or 1
    d.siStimAt = now
    relieve(player, d, S.STIM_LOAD * k)
    DanTraits_StatAdd(player:getStats(), CharacterStat.STRESS, -S.STIM_STRESS * k)
    DanTraits_NotifyGood(player, k < 1 and "UI_DanTraits_SensoryStimLess" or "UI_DanTraits_SensoryStim")
    return S.STIM_LOAD * k
end

-- eating ------------------------------------------------------------------------------

local function displayName(item)
    local name = "?"
    pcall(function() name = item:getDisplayName() or name end)
    return name
end

DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not hasTrait(player, "sensory") then return nil end
    local d = DanTraits_Data(player)
    fraction = math.max(0, math.min(1, tonumber(fraction) or 1))
    local verdict = foodVerdict(player, item)
    local stats = player:getStats()
    if verdict == "safe" then
        relieve(player, d, S.SAFE_LOAD * fraction)
        DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -S.SAFE_SAD * fraction)
        DanTraits_StatAdd(stats, CharacterStat.STRESS, -S.SAFE_STRESS * fraction)
    elseif verdict == "disliked" then
        d.siLoad = math.min(100, (d.siLoad or 0) + S.HATE_LOAD * fraction)
        DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, S.HATE_SAD * fraction)
        DanTraits_StatAdd(stats, CharacterStat.STRESS, S.HATE_STRESS * fraction)
    elseif (d.siLoad or 0) < S.TIER[1] then
        -- calmly eaten, a food that is neither becomes familiar
        local full
        pcall(function() full = item:getFullType() end)
        if full then
            d.siTried = d.siTried or {}
            d.siTried[full] = (d.siTried[full] or 0) + fraction
            if d.siTried[full] >= S.LEARN_PORTIONS - 1e-6 then
                d.siTried[full] = nil
                d.siLearned = d.siLearned or {}
                d.siLearned[full] = true
                DanTraits_NotifyFmtGood(player, "UI_DanTraits_SensoryLearned", displayName(item))
            end
        end
    end
    return nil
end)

-- overloaded, only a safe food goes down
DanTraits_AddHook("refuseFood", function(reason, player, item)
    if reason or not hasTrait(player, "sensory") then return nil end
    local d = DanTraits_Data(player)
    if (d.siTier or 0) < 3 or not item or not isFood(item) then return nil end
    if foodVerdict(player, item) == "safe" then return nil end
    return "UI_DanTraits_SensoryRefuse"
end)

-- halfway through a disliked food, a chance to gag on it: the action stops,
-- and what went down so far counts (the core's eat wrapper)
local function wrapGag()
    DanTraits_Wrap(ISEatFoodAction, "update", "sensory-gag", function(original, self, ...)
        local result = original(self, ...)
        if self.danSensoryGag == nil and self.character and self.item then
            local delta = 0
            pcall(function() delta = self:getJobDelta() or 0 end)
            if delta >= S.GAG_AT then
                self.danSensoryGag = false
                if foodVerdict(self.character, self.item) == "disliked" and DanTraits_Roll(S.GAG) then
                    self.danSensoryGag = true
                    notify(self.character, "UI_DanTraits_SensoryGag")
                    pcall(function() self:forceStop() end)
                end
            end
        end
        return result
    end)
end
wrapGag()
if Events and Events.OnGameStart then Events.OnGameStart.Add(wrapGag) end

-- the other traits ----------------------------------------------------------------------

DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or not d.siTier or d.siTier <= 0 or not hasTrait(player, "sensory") then return nil end
    local k = S.ENDURANCE[d.siTier] or 1
    if d.siOver == "shutdown" then k = math.min(k, S.SHUT_ENDURANCE) end
    return delta * k
end)

DanTraits_AddHook("spoonSpend", function(cost, player, d)
    if not d or not d.siLoad or not hasTrait(player, "sensory") then return nil end
    return cost * (1 + S.SPOON_COST * d.siLoad / 100)
end)

DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or (d.siSleepLoad or 0) < S.NIGHT_AT or not hasTrait(player, "sensory") then return nil end
    d.siSleepLoad = nil
    return quality * (1 - S.NIGHT_CUT)
end)

-- the character's food groups, rolled with the starting kit, and the outfit
-- they start in counts as washed (it is theirs: no new-clothes itch)
DanTraits_StartingKit({
    trait = "sensory",
    flag = "siKitGiven",
    setup = function(player, d)
        rollFoods(d)
        local L = DanTraits_Laundry
        if L and L.carried and L.isClothing and L.state then
            for _, item in ipairs(L.carried(player)) do
                if L.isClothing(item) then
                    local s = L.state(item, true)
                    if s then s.ok = true end
                end
            end
        end
        DanTraits_Later(120, function() DanTraits_SensoryTellFoods(player) end, "sensory-foods")
    end,
})

local function groupName(key) return getText("UI_DanTraits_SensoryGroup_" .. tostring(key)) end

function DanTraits_SensoryTellFoods(player)
    local d = DanTraits_Data(player)
    rollFoods(d)
    DanTraits_NotifyFmtGood(player, "UI_DanTraits_SensorySafe", groupName(d.siSafe[1]), groupName(d.siSafe[2]))
    DanTraits_NotifyFmt(player, "UI_DanTraits_SensoryHate", groupName(d.siHate[1]), groupName(d.siHate[2]))
end

-- the safe and disliked groups by name and how many foods were learned, for
-- the health panel (the notice above is easily missed); nil without the trait
function DanTraits_SensoryFoodSummary(player)
    if not player or not hasTrait(player, "sensory") then return nil end
    local d = DanTraits_Data(player)
    rollFoods(d)
    local learned = 0
    for _ in pairs(d.siLearned or {}) do learned = learned + 1 end
    return {
        safe = { groupName(d.siSafe[1]), groupName(d.siSafe[2]) },
        hate = { groupName(d.siHate[1]), groupName(d.siHate[2]) },
        learned = learned,
    }
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.sensory = function(player, args)
    local d = DanTraits_Data(player)
    rollFoods(d)
    local sub = args[1]
    if sub == "load" then
        local n = tonumber(args[2])
        if not n then return "sensory load <0..100>" end
        d.siLoad, d.siHoldMin = math.max(0, math.min(100, n)), 60
        return "load held at " .. tostring(d.siLoad) .. " for an hour"
    elseif sub == "foods" or sub == "reroll" then
        if sub == "reroll" then rollFoods(d, true) end
        local learned = {}
        for full in pairs(d.siLearned or {}) do learned[#learned + 1] = full end
        return "safe " .. table.concat(d.siSafe, ", ") .. "; disliked " .. table.concat(d.siHate, ", ")
            .. "; learned " .. (#learned > 0 and table.concat(learned, ", ") or "none")
    end
    local parts = {}
    for _, k in ipairs({ "touch", "grime", "sound", "crowd", "light", "smell" }) do
        parts[#parts + 1] = k .. " " .. tostring(DanTraits_Round((d.siCh or {})[k] or 0, 2))
    end
    return "load " .. tostring(DanTraits_Round(d.siLoad or 0, 1)) .. ", tier " .. tostring(d.siTier or 0)
        .. (d.siOver and (" (" .. d.siOver .. ")") or "") .. ", input " .. tostring(DanTraits_Round(d.siIn or 0, 2)) .. " of " .. tostring(DanTraits_Round(fullInput(d), 2))
        .. (d.siToll and (", worn thin x" .. d.siToll) or "")
        .. "; " .. table.concat(parts, ", ")
end
