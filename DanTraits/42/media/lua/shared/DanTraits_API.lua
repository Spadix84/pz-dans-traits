-- Vitality Project API for other mods. Everything here is safe to call from a
-- shared or client Lua file; see API.md beside the mod for examples.
--
--   local ok = pcall(require, "DanTraits_API")
--   if ok and VitalityProject and VitalityProject.API_VERSION then
--       VitalityProject.addHook("eat", function(value, player, item, fraction) ... end)
--   end
--
-- The mod itself is 120-odd files talking through DanTraits_* globals; those
-- are internal and may change between versions. This file is the part that is
-- promised: thin wrappers over the seams the companion mods and the Slow
-- Cooker already lean on. Each wrapper checks that the system behind it is
-- loaded (a sandbox switch may have left it idle; a server has no client
-- files) and returns nil when it is not, so a caller never has to.
--
-- API_VERSION goes up only when something here changes meaning or goes away.
require "DanTraits"

VitalityProject = VitalityProject or {}
local V = VitalityProject

V.API_VERSION = 1
V.MOD_ID = "DanTraits"

-- traits ---------------------------------------------------------------------------------

-- does the character have one of this mod's traits (by its short id: "asthma",
-- "diabetes1", "homebody"; the list is V.traits()). Vanilla traits: V.hasVanillaTrait.
function V.hasTrait(player, id) return DanTraits_HasTrait(player, id) == true end
function V.hasVanillaTrait(player, name)
    return DanTraits_HasVanillaTrait ~= nil and DanTraits_HasVanillaTrait(player, name) == true
end

-- the short ids of every trait this mod defines, sorted
function V.traits()
    local out = {}
    for id, entry in pairs(DanTraitsRegistry or {}) do
        if entry ~= nil and type(id) == "string" then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- a sandbox switch of this mod (the option names are in sandbox-options.txt):
-- true unless it is off. V.optionNumber for a number, with a default.
function V.option(name) return DanTraits_SandboxOn(name) end
function V.optionNumber(name, default) return DanTraits_SandboxNum(name, default) end

-- the per-player table this mod keeps (player:getModData().DanTraits). Read
-- it if you must; the keys are not promised and writing to it is yours to
-- regret. Prefer the readers below.
function V.data(player) return DanTraits_Data(player) end

-- is this character one this client runs (false for the other players and NPCs)
function V.isLocalPlayer(character) return DanTraits_IsLocalPlayer(character) == true end

-- clocks and lifecycle -------------------------------------------------------------

-- run fn(player, d) for every local player on this mod's clock: cadence
-- "minute", "ten" or "frame". label names it in the log; order places it among
-- this mod's systems (100 runs after all of them, which is what you usually
-- want; the order table is in DanTraits.lua). opts.trait = "<id>" runs it only
-- while the character has that trait, and opts.clear(player, d) once when the
-- trait goes; a frame entry's opts.active(player, d) says whether it needs
-- frames right now. Returns true when registered.
function V.every(cadence, label, fn, order, opts)
    return DanTraits_Every(cadence, label, fn, order or 100, opts) == true
end

-- run fn(player) once a character is ready to play, on creation and again on
-- each load (write it to run twice without effect). Default order 100: after
-- this mod's own steps.
function V.onPlayerReady(label, fn, order) return DanTraits_OnPlayerReady(label, fn, order or 100) end

-- run fn after that many frames (a tiny scheduler; tag names it in the log)
function V.later(frames, fn, tag) return DanTraits_Later(frames, fn, tag or "api") end

-- value hooks ------------------------------------------------------------------------

-- The names this mod runs and promises to keep: fn(value, <the arguments
-- listed>). A hook returns the new value, or nil to leave it. Where the value
-- is nil the hook is a notification: there is nothing to return.
V.HOOKS = {
    eat            = "nil; player, item, fraction (the share of the item eaten, 0..1)",
    drink          = "nil; player, fluidContainer, litres, fluidName, ratio",
    pill           = "nil; player, kind (this mod's medicine id, 'Antibiotics', 'Painkillers', ...)",
    prePill        = "nil; player, kind, item (about to be taken)",
    nightQuality   = "a night's score (0..1); player, d, hoursSlept",
    foodGrade      = "a food's diet grade (0..1); player, item, why",
    refuseFood     = "nil; player, item: return anything true-ish and the character refuses the food",
    infectionHazard = "a wound's infection chance; player, part",
    infectionGrowth = "x1: how fast infections grow this minute; player",
    woundHeal      = "x1: how fast a wound heals; player, part",
    strainRelief   = "x1: how much a comfort eases burnout; player, d",
    homeGood       = "x1: how much good being at home does this minute (boredom, unhappiness and stress eased); player, d",
    -- the stat pipelines: the stat's rise since the last run (scale it; never add)
    enduranceRegen = "stamina regained this frame; player, d",
    panicRise      = "panic gained this frame; player, d",
    hungerRise     = "hunger gained this minute; player, d",
    fatigueRise    = "fatigue gained this minute; player, d",
    boredomRise    = "boredom gained this minute; player, d",
    catchCold      = "the game's wet-and-cold meter's rise this minute; player, d",
}

-- adjust a value this mod offers: fn(value, ...) returns the new value or nil.
-- order: lower runs first (default 100, after this mod's own subscribers).
function V.addHook(name, fn, order) return DanTraits_AddHook(name, fn, order) end

-- offer a value of your own under your own name (prefix it with your mod's),
-- adjusted by everyone who registered for it. Returns the adjusted value.
function V.runHooks(name, value, ...) return DanTraits_RunHooks(name, value, ...) end

-- layer on a method of a game class: fn(original, self, ...) and must return
-- what the original would. Keyed by method and tag, so the same wrap twice
-- is a no-op; never for new() (multiplayer reads its parameter names).
function V.wrap(class, method, tag, fn) return DanTraits_Wrap(class, method, tag, fn) == true end

-- notices ------------------------------------------------------------------------------

-- a line over the character's head (ten seconds, red or green) that is also
-- published as a story event (below). textKey is a translation key; extra
-- arguments format it.
function V.notify(player, textKey, good, ...)
    if good then return DanTraits_NotifyFmtGood(player, textKey, ...) end
    return DanTraits_NotifyFmt(player, textKey, ...)
end

-- publish a story moment without a halo: the Lua event OnStoryEvent fires with
-- (player, { source = "DanTraits", kind, text, tone }). Listen with
-- Events.OnStoryEvent.Add(fn); PZ Chronicle and the companion app do. Your
-- own mod can trigger the same event with its own source.
function V.story(player, kind, text, tone) return DanTraits_Story(player, kind, text, tone) end

-- the body ---------------------------------------------------------------------------

-- a knock on the head: chance (0..1) that it concusses, score (0..1) how hard.
-- Helmets and the Concussion sandbox switch are honoured. Returns 0 when it
-- did nothing. (Vitality Challenges' Pile-Up crash uses this.)
function V.knockHead(player, chance, score)
    if not DanTraits_KnockHead then return nil end
    return DanTraits_KnockHead(player, chance, score)
end

-- the character passes out for that many minutes; textKey is the line shown
-- on coming to. Returns true when it took.
function V.passOut(player, minutes, textKey)
    if not DanTraits_PassOut then return nil end
    return DanTraits_PassOut(player, minutes, textKey) == true
end

-- a pain floor on the head from your source: the head's pain is at least floor
-- (0..100), reached over ramp minutes and held for hold minutes after you stop
-- registering it. Call it each minute while the cause lasts. The largest
-- registered floor wins.
function V.painFloor(player, source, floor, ramp, hold)
    if not DanTraits_PainFloor or not player then return nil end
    return DanTraits_PainFloor(player, DanTraits_Data(player), source, floor, ramp, hold)
end

-- blood: { vol, cells (both 0..1, 1 is a full body), loss (per minute), tier
-- (0 fine .. 4 shock), ... }, or nil with Blood Loss off
function V.blood(player)
    if not DanTraits_BloodState then return nil end
    return DanTraits_BloodState(player)
end

-- living ---------------------------------------------------------------------------------

V.VITALITY_TIERS = { "Run Down", "Sluggish", "Steady", "Fit", "Thriving" }   -- tier 0..4 is [tier + 1]

-- the Vitality score: { score (0..1), tier (0..4), name, effect (-1..1: the
-- strength of the tier's lifts or drags) }, or nil with Vitality off
function V.vitality(player)
    if not DanTraits_VitalityEffect or not player or not DanTraits_SandboxOn("VitalityEnabled") then return nil end
    local d = DanTraits_Data(player)
    local score = tonumber(d.vitality) or 0.5
    local tier = DanTraits_VitalityTier and DanTraits_VitalityTier(score) or 2
    return { score = score, tier = tier, name = V.VITALITY_TIERS[tier + 1], effect = DanTraits_VitalityEffect(player) }
end

-- is this food home cooking (the Slow Cooker's crock, or anything you mark):
-- home (true/false), dish id or nil. The marks are plain mod data on the item:
-- item:getModData().slowCookerHome = true, and .slowCookerDish = "<id>" for a
-- named dish that should count as variety of its own. Set them on your own
-- dishes and Vitality treats them the same.
function V.homeCooked(item)
    if not DanTraits_VitalityHomeCooked then return nil end
    return DanTraits_VitalityHomeCooked(item)
end

-- what this mod makes of a food: a table of tags (fresh, cooked, junk, rotten,
-- meat, fish, dairy, wheat, alcohol, caffeine, ...) read by nine of its systems
function V.foodTags(item) return DanTraits_FoodTags(item) end

-- burnout ---------------------------------------------------------------------------------

V.BURNOUT_TIERS = { "At Ease", "Frayed", "Worn Down", "Burnt Out", "Breaking Point" }   -- tier 0..4 is [tier + 1]
V.COMFORTS = { "shower", "laundry", "read", "pumped", "game", "breathe", "walk", "pet" }

-- burnout now: { level (0..100), tier (0..4), name }, or nil with it off
function V.burnout(player)
    if not DanTraits_StrainLevel or not player or not DanTraits_SandboxOn("StrainEnabled") then return nil end
    local tier = DanTraits_StrainTier(player)
    return { level = DanTraits_StrainLevel(player), tier = tier, name = V.BURNOUT_TIERS[tier + 1] }
end

-- a comfort eases burnout: kind is one of V.COMFORTS (or your own word, with an
-- amount); the first of a kind today counts in full, the second at half, then
-- nothing; x1.5 at home. Returns what it eased (0 when nothing).
function V.comfort(player, kind, amount)
    if not DanTraits_StrainComfort then return nil end
    return DanTraits_StrainComfort(player, kind, amount)
end

-- raw burnout: add some (source names it; combat = true counts it as fighting,
-- which hardening cuts) or ease some
function V.strainAdd(player, source, amount, combat)
    if not DanTraits_StrainAdd then return nil end
    return DanTraits_StrainAdd(player, source, amount, combat)
end
function V.strainEase(player, source, amount)
    if not DanTraits_StrainEase then return nil end
    return DanTraits_StrainEase(player, source, amount)
end

-- illness and fever -------------------------------------------------------------------

V.ILLNESSES = { "cold", "flu", "pneumonia", "strep", "stomach", "food" }
V.RELIEF_KINDS = { "nausea", "cramps", "ache", "cold" }

-- what is running: a list of { id, kind ("viral"/"bacterial"), brewing = true,
-- inH } for one still hidden, or { id, kind, day, rising, sev (0..1), leftH }
function V.illness(player)
    if not DanTraits_IllnessState then return nil end
    return DanTraits_IllnessState(player)
end

-- catch one by id, hidden for its incubation (now = true starts the symptoms at
-- once). Immunity, a running course and the sandbox switches are honoured;
-- true when it took.
function V.catchIllness(player, id, now)
    if not DanTraits_IllnessCatch then return nil end
    return DanTraits_IllnessCatch(player, id, now) == true
end

-- the one fever as the character feels it, 0..1 (the game's sick moodle
-- follows it; past 1 it drains health)
function V.fever(player)
    if not DanTraits_Fever then return nil end
    return DanTraits_Fever(player)
end

-- add a fever source of your own: fn(player, d) returns 0..1 each minute; the
-- worst source counts in full and the rest at half
function V.feverSource(name, fn)
    if not DanTraits_FeverSource then return nil end
    DanTraits_FeverSource(name, fn)
    return true
end

-- the best relief working for one kind of symptom (V.RELIEF_KINDS): 1 none,
-- lower is better (a medicine or a herb of this mod's)
function V.relief(player, kind)
    if not DanTraits_IllnessRelief then return nil end
    return DanTraits_IllnessRelief(player, kind)
end

-- the guide ---------------------------------------------------------------------------

-- a page in the Guide tab: { id, title, body (lines: "## heading", "- bullet",
-- a paragraph, ""), order?, picture?, mod? }. Works from a shared or client
-- file, with or without the Guide loaded yet (it reads the list when the
-- window opens). True when the page is well formed.
function V.guidePage(page)
    if DanTraits_GuideAddPage then return DanTraits_GuideAddPage(page) end
    if type(page) ~= "table" or type(page.id) ~= "string" or page.id == "" then return false end
    if type(page.title) ~= "string" or type(page.body) ~= "table" then return false end
    DanTraits_GuideExtra = DanTraits_GuideExtra or {}
    table.insert(DanTraits_GuideExtra, page)
    return true
end
