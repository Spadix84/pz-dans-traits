-- Project Zomboid Vitality Project: core.
--
-- The traits declared in media/scripts/DanTraits.txt each live in their own
-- file next to this one (DanTraits_<Trait>.lua) and `require` this file for
-- the shared helpers below. This file holds those helpers, the minute /
-- ten-minute / frame drivers (DanTraits_Every), the frame scheduler,
-- DanTraits_Wrap (the one way any file wraps a game method, so several files
-- can layer on the same method), the cached vanilla trait lookup
-- (DanTraits_HasVanillaTrait, DanTraits_TraitsChanged), the one way a file adds or takes off a
-- trait at runtime (DanTraits_SetTrait), the player-ready sequence
-- (DanTraits_OnPlayerReady: one ordered list run by core's one OnCreatePlayer
-- handler and, for every local player, its one OnGameStart handler: the mod-data
-- migration, the retired traits, the trait cache, the starting kits, then each
-- file's own create or grant), the starting kits a new character with a trait
-- begins with (DanTraits_StartingKit), the per-frame movement snapshot
-- (DanTraits_Frame), the eat and pill action hooks that several traits share,
-- the one-time rename of old mod-data keys (DanTraits_MigrateModData), and the
-- save mod-list fix. Each trait bails out immediately unless the player
-- actually has it, so an unaffected character costs a handful of lookups.
--
-- Every place core runs another file's function (a clock system, a value
-- hook, a Later job, an eat or refuse reader, a story listener, a moodle
-- spec) goes through DanTraits_Guard(tag, fn, ...): a pcall that logs the
-- first failure per tag and is then quiet, so a typo cannot fail silently
-- every minute. With DanTraits_STRICT set (the offline tests set it) the
-- error is raised instead, so a broken hook fails the test rather than
-- leaving the value it should have adjusted alone.
--
-- The small copy-and-paste helpers (clamp, floor a stat, dice, body-part
-- lookups, the asleep check, the sandbox toggle, the Moodle Framework updater)
-- and the stat delta pipeline live in DanTraits_Util.lua, required below; the
-- three pipeline hooks (enduranceRegen, catchCold, foodSicknessRise) and the
-- pain-floor applier (minute, order 95, label "PainFloor") are registered here
-- once the drivers exist.
--
-- Lua allows 200 locals per file: new traits go in new files, not here.

-- before any handler is registered, so the dashboard can say which trait
-- moved which stat
require "DanTraits_Attrib"

-- the shared one-liners (clamps, dice, part lookups, sandbox, moodle updater)
require "DanTraits_Util"

-- the one food classifier (wheat, meat, junk, sugar, iron, caffeine by item)
require "DanTraits_Food"

-- Trait lookup goes through the registry when it is available and falls back
-- to the legacy string form, so this keeps working if either API shifts.
-- A key with no registry entry means the game was not restarted after the
-- trait was added (registries and scripts are read at boot): say so once
-- and treat it as not taken. (B42 has no string HasTrait fallback; calling a
-- missing method inside pcall still dumps a stack trace to the log.)
local missingTraitWarned = {}
local function hasTrait(player, key)
    if not player then return false end
    local entry = DanTraitsRegistry and DanTraitsRegistry[key]
    if not entry then
        if not missingTraitWarned[key] then
            missingTraitWarned[key] = true
            print("[DanTraits] trait '" .. tostring(key) .. "' is not registered; restart the game to load it")
        end
        return false
    end
    local ok, res = pcall(function() return player:hasTrait(entry) end)
    return ok and res == true
end

-- The one guarded call. Returns what pcall returns (ok, result). The first
-- failure under each tag is printed; later ones are quiet. Under
-- DanTraits_STRICT (the offline tests) the error is raised again instead.
local guardFailed = {}
function DanTraits_Guard(tag, fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        if not guardFailed[tag] then
            guardFailed[tag] = true
            print("[DanTraits] " .. tostring(tag) .. " failed: " .. tostring(res))
        end
        if DanTraits_STRICT then error(tostring(tag) .. " failed: " .. tostring(res), 0) end
    end
    return ok, res
end

-- Every local player (singleplayer has one; split-screen up to four, each a
-- distinct object: the same player reached through two indices counts once).
local function eachLocalPlayer(fn)
    local seen = {}
    for i = 0, 3 do
        local player = getSpecificPlayer(i)
        if player and not seen[player] then
            seen[player] = true
            if not player:isDead() then fn(player) end
        end
    end
end

-- Player ready: the one ordered sequence that runs when a character is
-- created or loaded (OnCreatePlayer, with the player the game hands over)
-- and again once the world is up (OnGameStart, for every local player: the
-- game fires OnCreatePlayer before some tables are in place, so each step
-- is written to run twice without effect). Core registers the only two
-- handlers; every file that used to have its own puts its fn(player) here:
--
--   DanTraits_OnPlayerReady(label, fn, order)
--     label  the step's name for the log ("kits")
--     fn     fn(player), run under DanTraits_Guard("ready:" .. label)
--     order  lower runs first, default 100; equal orders in load order
--
--   10  migrate     the mod-data renames (DanTraits_MigrateModData), before any
--                   step reads the new names
--   20  retire      the retired traits swapped out (DanTraits_RetireTraits)
--   30  traits      the vanilla trait cache dropped (DanTraits_TraitsChanged), so
--                   the steps below see the traits as the character now has them
--   40  kits        the starting kits (DanTraits_StartingKit), in registration order
--   50  Age         the age band's trait and starting levels
--   55  AgeTraits   Reading Glasses' pair
--   60  GymRegular  the exercise regularity
--   65  Positives   Fast Recovery's fold-in, Early Riser's and Meal Prepper's starts
--   70  Sleep       Deep Sleeper's Wakeful
--   75  SteadyHands Dexterous
local ready = {}
DanTraits_ReadyList = ready   -- read-only view for the tests
function DanTraits_OnPlayerReady(label, fn, order)
    if type(fn) ~= "function" then return false end
    order = order or 100
    local entry = { label = tostring(label or ""), fn = fn, order = order }
    local at = #ready
    while at >= 1 and ready[at].order > order do at = at - 1 end
    table.insert(ready, at + 1, entry)
    return true
end

local function runReady(player)
    if not player then return end
    for i = 1, #ready do
        local entry = ready[i]
        DanTraits_Guard("ready:" .. entry.label, entry.fn, player)
    end
end
DanTraits_RunPlayerReady = runReady   -- the sequence for one player, for the tests and the console

Events.OnCreatePlayer.Add(function(playerNum, player) runReady(player) end)
Events.OnGameStart.Add(function() eachLocalPlayer(runReady) end)

-- Story events: every notice is also published as the Lua event
--   OnStoryEvent(player, { source, kind, text, tone })
-- so a diary (PZ Chronicle), the dashboard, or any other mod can tell the
-- day's story. kind is the text key without its "UI_DanTraits_" prefix
-- ("SmokerCraving"), tone is "good" or "bad". Other mods are welcome to
-- publish their own the same way: register the event if it is missing, then
-- triggerEvent. Listeners never see our errors and we never see theirs.
local STORY_EVENT = "OnStoryEvent"
pcall(function()
    if LuaEventManager and not Events[STORY_EVENT] then LuaEventManager.AddEvent(STORY_EVENT) end
end)

function DanTraits_Story(player, kind, text, tone)
    if not player or not triggerEvent then return end
    DanTraits_Guard("story", triggerEvent, STORY_EVENT, player, { source = "DanTraits", kind = kind, text = text, tone = tone or "bad" })
end

-- How long a notice stays over the head. The game keeps one halo display
-- time per character (128 by default, about 2 real seconds: the clock counts
-- down about 60 a second, measured 2026-10-01). Only character creation and
-- a locked or barricaded door set it, so setting it once does not hold.
-- Instead a notice that finds nothing over the head shows itself with our
-- time (which the game's own next halos then share); one that finds the
-- halo busy joins the game's HaloTextHelper queue and shows after it.
local HALO_TICKS = 600   -- about 10 real seconds

local function showHalo(player, text, good)
    local shown = false
    pcall(function()
        if player:getHaloTimerCount() > 0.2 then return end
        local c = good and getCore():getGoodHighlitedColor() or getCore():getBadHighlitedColor()
        player:setHaloNote(text, math.floor(c:getR() * 255), math.floor(c:getG() * 255), math.floor(c:getB() * 255), HALO_TICKS)
        shown = true
    end)
    if shown then return end
    pcall(function()
        if good then HaloTextHelper.addGoodText(player, text) else HaloTextHelper.addBadText(player, text) end
    end)
end

local function storyKind(textKey)
    return (string.gsub(textKey, "^UI_DanTraits_", ""))
end

-- the one notice: the halo over the head and the story event. A text that
-- takes arguments is formatted by getText(key, ...) and the story event
-- gets the formatted text.
local function announce(player, good, textKey, ...)
    local text = getText(textKey, ...)
    showHalo(player, text, good)
    DanTraits_Story(player, storyKind(textKey), text, good and "good" or "bad")
end

local function notify(player, textKey) announce(player, false, textKey) end
local function notifyGood(player, textKey) announce(player, true, textKey) end
function DanTraits_NotifyFmt(player, textKey, ...) announce(player, false, textKey, ...) end
function DanTraits_NotifyFmtGood(player, textKey, ...) announce(player, true, textKey, ...) end

local function traitData(player)
    local md = player:getModData()
    md.DanTraits = md.DanTraits or {}
    return md.DanTraits
end

-- Mod-data key hygiene: every key carries its system's prefix. Keys renamed
-- for that (old -> new) are moved once per save, when the player loads (the
-- first player-ready step, so it runs before the trait files' own starts
-- read the new names): copied only if the new key is not
-- already set, then the old one is cleared. Keys no system reads any more
-- (MODDATA_DROPPED) are cleared the same way. One log line with the count.
-- Add a pair here whenever a saved key is renamed, a name whenever one is
-- retired.
local MODDATA_RENAMES = {
    withdrawing        = "alcWithdrawing",
    dryHours           = "alcDryHours",
    depTolerance       = "alcMeter",
    earlyRiserApplied  = "posEarlyRiser",
    mealPrepperApplied = "posMealPrepper",
    gymRegularApplied  = "gymApplied",
    deepSleeperWakeful = "slWakefulGranted",
}
local MODDATA_DROPPED = {
    "hcCovered", "epCovered",   -- the wearing-off notices moved to the drug registry (2026-10-08)
    "vitCarryDelta",            -- Vitality's carry weight is applied against a remembered base now
}
function DanTraits_MigrateModData(player)
    if not player then return 0 end
    local d = player:getModData().DanTraits
    if not d then return 0 end
    local n = 0
    for old, new in pairs(MODDATA_RENAMES) do
        if d[old] ~= nil then
            if d[new] == nil then d[new] = d[old] end
            d[old] = nil
            n = n + 1
        end
    end
    for _, old in ipairs(MODDATA_DROPPED) do
        if d[old] ~= nil then
            d[old] = nil
            n = n + 1
        end
    end
    if n > 0 then print("[DanTraits] mod data: renamed or dropped " .. n .. " old key(s)") end
    return n
end
DanTraits_OnPlayerReady("migrate", DanTraits_MigrateModData, 10)

-- A trait reference, as every runtime add or remove names one: a mod key
-- ("dependent", the registry entry) or "base:" and a CharacterTrait
-- constant's name ("base:SMOKER"). nil when it names nothing.
local function traitEntry(ref)
    if type(ref) ~= "string" then return nil end
    if string.sub(ref, 1, 5) == "base:" then return CharacterTrait and CharacterTrait[string.sub(ref, 6)] end
    return DanTraitsRegistry and DanTraitsRegistry[ref]
end

-- The one way a file gives or takes a trait at runtime (an Alcoholic's
-- relapse, the smoker's cure, tinnitus deafness, a migraine's blur, the
-- retired traits, the console). on = true adds it, false takes it off; a
-- trait already as asked is left alone. The game call is guarded and the
-- vanilla trait cache is refreshed either way. Returns true when the
-- character has the trait as asked afterwards (false for an unknown ref or
-- a game call that failed).
function DanTraits_SetTrait(player, ref, on)
    if not player then return false end
    local entry = traitEntry(ref)
    if not entry then return false end
    on = on == true
    local ok, have = pcall(function()
        local traits = player:getCharacterTraits()
        local have = traits:get(entry) == true
        if on and not have then traits:add(entry) elseif have and not on then traits:remove(entry) end
        return traits:get(entry) == true
    end)
    DanTraits_TraitsChanged(player)
    return ok and have == on
end

-- Retired traits (2026-10-07): still registered and defined, so a save that
-- has one loads, and hidden at creation (DanTraits_Client.lua). A loaded
-- character has it taken off and, where one took its place, gets that
-- instead: a mod key, or "base:" and the CharacterTrait constant's name.
-- false: nothing replaces it.
DanTraits_RETIRED = {
    jinxed      = false,
    ironstomach = "base:IRON_GUT",
    bouncesback = "thickskull",
    green       = false,   -- Age 2.0 (2026-10-31): the 20s band takes the levels itself; the lost levels are not given back
}
-- Traits another mod declares that ours stand in for (Dynamic Traits'
-- Alcoholic, DanTraits_DTEM.lua): hidden at creation by their lowercase id
-- ("dynamictraits:alcoholic", the CharacterTrait's tostring). The creation
-- screen filter in DanTraits_Client.lua reads the set.
DanTraits_HIDDEN_AT_CREATION = {}
function DanTraits_HideAtCreation(id)
    if type(id) ~= "string" or id == "" then return false end
    DanTraits_HIDDEN_AT_CREATION[string.lower(id)] = true
    return true
end

function DanTraits_RetireTraits(player)
    if not player or not DanTraitsRegistry then return 0 end
    local n = 0
    for key, into in pairs(DanTraits_RETIRED) do
        if hasTrait(player, key) then
            DanTraits_SetTrait(player, key, false)
            if into then DanTraits_SetTrait(player, into, true) end
            n = n + 1
        end
    end
    if n > 0 then print("[DanTraits] retired " .. n .. " trait(s) swapped out") end
    return n
end
DanTraits_OnPlayerReady("retire", DanTraits_RetireTraits, 20)

-- Starting kits: what a new character with a trait begins with (a bottle of
-- beta blockers, an inhaler, the glucose meter). Each file registers a spec:
--
--   DanTraits_StartingKit(spec)
--     spec.trait    a mod key ("heart"), or fn(player) -> bool (Diabetes: either type)
--     spec.flag     mod-data key set once the kit was dealt with ("hcKitGiven"),
--                   whether or not the sandbox let it give anything
--     spec.setup    fn(player, d), optional: anything to roll first (Migraine's triggers)
--     spec.meds     drug ids the character starts built up on (DanTraits_MedStart),
--                   a list or fn(player) -> list
--     spec.always   item types given whatever the sandbox says (the meter and strips),
--                   a list or fn(player) -> list
--     spec.items    item types given only with the Starting Medication option on
--     spec.prepare  fn(item), optional: run on every item given (a full bottle, the
--                   part-used pack)
--
-- The kits step of the player-ready sequence (order 40: after the mod-data
-- migration, the retired traits and the trait cache, before the files' own
-- creates) runs every kit in registration order for a character who has the
-- trait, has not survived an hour yet and has not had the kit. Each kit runs
-- under DanTraits_Guard.
local kits = {}
function DanTraits_StartingKit(spec)
    kits[#kits + 1] = spec
    return spec
end

local function kitList(x, player)
    if type(x) == "function" then x = x(player) end
    return x or {}
end

local function giveKit(player, spec)
    local has = spec.trait
    if type(has) == "function" then has = has(player) == true else has = hasTrait(player, has) end
    if not has then return false end
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    if hours > 0 then return false end
    local d = traitData(player)
    if spec.flag then
        if d[spec.flag] then return false end
        d[spec.flag] = true
    end
    if spec.setup then spec.setup(player, d) end
    if DanTraits_MedStart then
        for _, id in ipairs(kitList(spec.meds, player)) do DanTraits_MedStart(player, id) end
    end
    local function give(list)
        for _, fullType in ipairs(list) do
            pcall(function()
                local item = player:getInventory():AddItem(fullType)
                if item and spec.prepare then spec.prepare(item) end
            end)
        end
    end
    give(kitList(spec.always, player))
    if DanTraits_SandboxOn("StartingMedication") then give(kitList(spec.items, player)) end
    return true
end
DanTraits_GiveStartingKit = giveKit   -- tests

DanTraits_OnPlayerReady("kits", function(player)
    for _, spec in ipairs(kits) do
        DanTraits_Guard("kit:" .. tostring(spec.flag or spec.trait), giveKit, player, spec)
    end
end, 40)

-- vanilla traits by id, as the game names them (lowercase "base:needslesssleep").
-- Walking getKnownTraits is a Java list walk with a tostring and a lowercase
-- per element, and the trait files ask several times a minute, so the walk is
-- cached: one snapshot { player, minute, set } for the (single) local player,
-- rebuilt when the game minute changes, when the player object changes, or
-- when a file that adds or removes a trait at runtime calls
-- DanTraits_TraitsChanged(player) (also a player-ready step, order 30).
-- A trait added by anything else shows up within a game minute. If the game
-- clock cannot be read the snapshot is never reused.
local vanillaCache = { player = nil, minute = nil, set = nil }

local function gameMinute()
    local ok, h = pcall(function() return getGameTime():getWorldAgeHours() end)
    if ok and type(h) == "number" then return math.floor(h * 60) end
    return nil
end

local function vanillaSet(player)
    local minute = gameMinute()
    local c = vanillaCache
    if c.set and c.player == player and minute ~= nil and c.minute == minute then return c.set end
    local set = {}
    pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        for i = 0, known:size() - 1 do set[string.lower(tostring(known:get(i)))] = true end
    end)
    c.player, c.minute, c.set = player, minute, set
    return set
end

local function hasVanillaTrait(player, id)
    if not player then return false end
    return vanillaSet(player)[id] == true
end

-- a trait was added or removed: the next lookup walks the list again
function DanTraits_TraitsChanged(player)
    vanillaCache.set = nil
end
DanTraits_OnPlayerReady("traits", DanTraits_TraitsChanged, 30)

-- shared with the trait files
DanTraits_HasTrait = hasTrait
DanTraits_HasVanillaTrait = hasVanillaTrait
DanTraits_Notify = notify
DanTraits_NotifyGood = notifyGood
DanTraits_Data = traitData

-- Value hooks: a system (Vitality, mostly) offers a value, every file that
-- registered for that name gets to adjust it, in load order, or by order
-- where one is given (DanTraits_AddHook(name, fn, order): lower runs first,
-- default 100, equal orders in load order; Sleep's free wake at 10 comes off
-- before Age scales the rest). A hook returns the new value or nil to leave
-- it. A hook that errors is logged once (DanTraits_Guard) and leaves the
-- value alone. DanTraits_Hooks[name] stays a plain list of the functions.
DanTraits_Hooks = DanTraits_Hooks or {}
local hookOrder = {}   -- fn -> order
function DanTraits_AddHook(name, fn, order)
    local list = DanTraits_Hooks[name] or {}
    DanTraits_Hooks[name] = list
    order = order or 100
    hookOrder[fn] = order
    local at = #list
    while at >= 1 and (hookOrder[list[at]] or 100) > order do at = at - 1 end
    table.insert(list, at + 1, fn)
end
function DanTraits_RunHooks(name, value, ...)
    local list = DanTraits_Hooks[name]
    if not list then return value end
    for i, fn in ipairs(list) do
        local ok, res = DanTraits_Guard("hook:" .. name .. "#" .. i, fn, value, ...)
        if ok and res ~= nil then value = res end
    end
    return value
end

-- Tiny frame scheduler shared by the traits: run fn after that many frames.
-- tag names the job in the log when it fails; every job should give one, as
-- untagged jobs share the one "later" slot and only the first failure of
-- any of them is ever printed.
local laterPending = {}
DanTraits_LaterPending = laterPending   -- read-only view for the tests
function DanTraits_Later(frames, fn, tag)
    laterPending[#laterPending + 1] = { frames = frames, fn = fn, tag = tag }
end
local function laterOnTick()
    if #laterPending == 0 then return end
    for i = #laterPending, 1, -1 do
        local job = laterPending[i]
        job.frames = job.frames - 1
        if job.frames <= 0 then
            table.remove(laterPending, i)
            DanTraits_Guard(job.tag or "later", job.fn)
        end
    end
end
Events.OnTick.Add(laterOnTick)

-- Wrap a method on a game class so several files can each add their own
-- layer. `tag` is unique per caller (file + purpose); wrapping twice with
-- the same tag is a no-op, so calling at load and again on OnGameStart is
-- safe. `fn(original, self, ...)` must call original and return its result.
-- (The tag table is read with rawget: a class that derives from another
-- must not see its parent's tags and skip its own wrap.)
-- Never a timed action's new(): in multiplayer the game reads new()'s own
-- parameter names to know which fields to send, then rebuilds the action on
-- the server by calling new() with them. A (self, ...) wrapper has none, so
-- the server's new() gets no character and every such action fails. Hook
-- getDuration, adjustMaxTime or start instead.
function DanTraits_Wrap(class, method, tag, fn)
    if method == "new" then return false end
    if not class or type(class[method]) ~= "function" then return false end
    local wraps = rawget(class, "DanTraitsWraps")
    if not wraps then
        wraps = {}
        class.DanTraitsWraps = wraps
    end
    local key = method .. ":" .. tag
    if wraps[key] then return true end
    wraps[key] = true
    local original = class[method]
    class[method] = function(self, ...) return fn(original, self, ...) end
    return true
end

-- Experience: one event, one multiplier ------------------------------------------------------
-- Several systems listen to Events.AddXP and adjust what the game just added (Age,
-- AgeTraits, Fitness, Strain, ADHD). Each applies its factor k through
-- DanTraits_XpFactor, which keeps a running product for the event in hand, so the
-- factors multiply (x0.8 and then x0.15 is x0.12 of the gain, not a loss of half of
-- it) and the penalties together can never take more than the gain. Core's listener
-- below is registered first, so it opens the record before any system's handler
-- runs; the event the game fires for the quiet adjustment itself (DanTraits_AgeXpBusy)
-- is not a new one, and a handler called for it does nothing. A loud addition made
-- by a handler (Vitality's Thriving) is a new event inside the first: the first's
-- record is kept one deep, so the handlers still to run on it find it again. A
-- handler that finds no record for its event starts one, which is the old sum
-- behaviour for that handler.
local xpEvent, xpOuter = nil, nil
Events.AddXP.Add(function(player, perk, amount)
    if DanTraits_AgeXpBusy and DanTraits_AgeXpBusy() then return end
    xpOuter = xpEvent
    xpEvent = { player = player, perk = perk, amount = amount, p = 1 }
end)

local function xpMatches(ev, player, perk, amount)
    return ev ~= nil and ev.player == player and ev.perk == perk and ev.amount == amount
end

-- apply factor k to the experience this event added: the difference goes through
-- Age's quiet adjust (never under the level held) or, without Age, a quiet AddXP
-- of its own (a bonus only; a take-back needs the level floor)
function DanTraits_XpFactor(player, perk, amount, k)
    k = tonumber(k) or 1
    amount = tonumber(amount) or 0
    if not player or not perk or amount <= 0 or k == 1 then return end
    if DanTraits_AgeXpBusy and DanTraits_AgeXpBusy() then return end   -- the quiet adjust's own event
    local ev = xpEvent
    if not xpMatches(ev, player, perk, amount) then
        if xpMatches(xpOuter, player, perk, amount) then
            ev = xpOuter   -- back in the event a loud addition interrupted
        else
            ev = { player = player, perk = perk, amount = amount, p = 1 }
        end
        xpEvent = ev
    end
    local was = ev.p
    ev.p = was * k
    local extra = amount * (ev.p - was)
    if DanTraits_AgeXpAdjust then
        DanTraits_AgeXpAdjust(player, perk, extra)
    elseif extra > 0 then
        pcall(function() player:getXp():AddXP(perk, extra, false, false, false, false) end)
    end
end

-- The drivers: one minute handler, one ten-minute handler, one frame handler ----------------------------------------
-- Every system that runs on the clock registers here instead of on
-- Events.EveryOneMinute / EveryTenMinutes / OnPlayerUpdate:
--
--   DanTraits_Every(cadence, label, fn, order, opts)
--     cadence  "minute" | "ten" | "frame"
--     label    the system's name for the dashboard's attribution card ("Blood")
--     fn       fn(player, d), d = the player's mod data
--     order    number, lower runs first, default 100; equal orders run by label
--     opts     optional. opts.trait: the trait the system belongs to, a mod key
--              ("asthma") or fn(player, d) -> bool; fn then runs only while the
--              character has it. opts.clear: fn(player, d), run once when that
--              stops holding (the trait taken off mid-game by the console or
--              another mod, or a save loaded without it; also once at the
--              first sight of a character without it, so a stale save is put
--              right): the system takes back what it left on the character,
--              its moodle, its floors on the parts, the attack in progress.
--              Blood, Infection, Concussion and WoundCare stand down on their
--              sandbox switch and hand-roll the same thing.
--
-- Core registers the only three handlers. Each does the preamble once (every
-- local player, the dead check; the frame one also skips non-local players), then
-- runs every registration in order through DanTraits_Track(label, ...) inside
-- DanTraits_Guard, so one system's error is logged once and never stops the next.
-- Order decides which system sees which other system's floors and stat writes
-- in the same minute, so it is written down here:
--
--   minute   0  the stat delta pipeline (DanTraits_DeltaHook in Util): catchCold and
--               foodSicknessRise, hungerRise (and boredomRise, registered by ADHD), so subscribers
--               see the game's rise, not floors written later in the same minute
--           10  Sleep (light reading, wakes)
--           11  Home (where the night was slept, the home's pull; before the floors of the mood systems)
--           19  Clotting (expires clots), GoodClotter (Positives: cuts bleeding time before Blood reads it)
--           20  Blood (loss this minute, sets bloodLossMin), HotWaterBottle (the bottle's warmth clock)
--           21  Hemophilia (holds bleed times)
--           22  WoundCare (reads BloodPartRate)
--           23  Infection
--           23.5 Age (paces the fall of scratch and cut clocks and of stiffness; after
--               Infection's hold, before the stiffness floors of Arthritis and MS)
--           24  Concussion
--           25  FearOfBlood (reads bloodLossMin)
--           30  Meds (the levels every medicated system reads this minute)
--           35  Adrenaline (the rush, the crash and its heart risk, before Heart reads them)
--           39  Spoons (the energy budget MS spends; reads the night Vitality scored)
--           40  ADHD, AgeTraits, Alcohol, Anemia, Anger, Arthritis, Asthma, Brittle, Caffeine, CarpalTunnel, Cooking, Dehydration, Diabetes,
--               Epilepsy, Fitness, Germaphobe, Gluten, Gout, Hangover, HayFever, Heart, Lactose, Laundry, MDD, Migraine,
--               MS, Smoker, Sunburn, Thyroid, Tinnitus, Tremor, Triptan (floors and rates; among themselves by label)
--               (Iron Stomach in Positives is a foodSicknessRise pipeline hook, not a clock system)
--           41  Grit (Positives: its share of the pain reduction, after the order-40 floors),
--               Headphones (Sensory: the deaf swap while they are worn),
--               SensitiveSkin (LaundryTraits: reads the garment state Laundry left at 40),
--               Sensory (reads Germaphobe's grime, Laundry's itch and Tinnitus from 40, Home from 11)
--           42  Knox (the Resilient roll against the zombie infection)
--           44  SpiffBoy (the hours on each cartridge; puts the console away asleep)
--           45  Strain (reads the fever, withdrawal, the Good Meal, Pumped, fresh
--               clothes and the hangover the systems above left; its unhappiness floors)
--           50  AgeWants (what each age wants: the cell, the slow morning, the routine's day; reads Home from 11)
--           60  Hunted (the horde, the house's call, the helicopter, the dawn packs), Relaxant (baclofen's clock)
--           90  SleepMenu (the outfit record for Undress and Sleep), Vitality (reads everything above, scores the night, applies lifts)
--           95  PainFloor (Util: applies the largest pain floor the systems above registered)
--           96  Moodles (reads what every system above left in mod data; changes nothing)
--          100  DTEM (Dynamic Traits and Expanded Moodles: hands the duplicated traits over, after Moodles)
--   ten     10  Dependent
--           40  Laundry (the wash and the washers), MDD, Migraine
--           90  Hallucinations
--   frame    0  the stat delta pipeline: enduranceRegen (Vitality, Smoker lungs, Blood,
--               Anemia, Concussion, Asthma, Heart, Dehydration, Age subscribe; the cuts multiply)
--               and panicRise (Seen It All)
--           20  Blood        22  WoundCare (movement sampling)    24  Concussion
--           40  AgeTraits (Bad Knees, Pace Yourself), Alcohol (panic decay), Arthritis, ArthritisGrip,
--               Dependent (held anger), Gout (no running in a flare), Heart (the angina surcharge), Meds (diazepam),
--               SensoryShutdown (a shutdown's stillness), Smoker (held anger), StrainKnock (knocked down)
--           45  Anger (part of every fall put back where the angerFall hook says so: Hot-Headed)
--   (Faint stays on OnTick; OnTick, OnWeaponSwing and OnPlayerGetDamage handlers
--   are still registered by their own files.)
local drivers = { minute = {}, ten = {}, frame = {} }
DanTraits_Drivers = drivers      -- read-only view for the tests and the dashboard

function DanTraits_Every(cadence, label, fn, order, opts)
    local list = drivers[cadence]
    if not list or type(fn) ~= "function" then return false end
    label = tostring(label or "")
    order = order or 100
    local entry = { cadence = cadence, label = label, fn = fn, order = order }
    local trait = opts and opts.trait
    if type(trait) == "string" then
        local key = trait
        entry.has = function(player) return hasTrait(player, key) end
    elseif type(trait) == "function" then
        entry.has = trait
    end
    if entry.has then
        entry.clear = opts.clear
        entry.had = {}   -- per player: whether the trait held the last time this ran
    end
    local at = #list
    while at >= 1 and (list[at].order > order or (list[at].order == order and list[at].label > label)) do at = at - 1 end
    table.insert(list, at + 1, entry)
    return true
end

-- one registration for one player: the system while its trait holds, its
-- clear once when that stops (see opts above)
local function runEntry(entry, track, player, d)
    local tag = entry.label .. " (" .. entry.cadence .. ")"
    if not entry.has then
        DanTraits_Guard(tag, track, entry.label, entry.fn, player, d)
        return
    end
    local ok, has = DanTraits_Guard(tag .. " trait", entry.has, player, d)
    if ok and has == true then
        entry.had[player] = true
        DanTraits_Guard(tag, track, entry.label, entry.fn, player, d)
    elseif entry.had[player] ~= false then
        entry.had[player] = false
        if entry.clear then DanTraits_Guard(tag .. " clear", track, entry.label, entry.clear, player, d) end
    end
end

-- The player the drivers are running for right now (nil between runs), so
-- a helper called from inside a system can tell whose data to write without
-- being handed the player (DanTraits_FloorUp's floor flag in Util reads it).
DanTraits_RunningFor = nil

local function runDrivers(list, player, d)
    local track = DanTraits_Track or function(_, fn, ...) return fn(...) end
    DanTraits_RunningFor = player
    for i = 1, #list do runEntry(list[i], track, player, d) end
    DanTraits_RunningFor = nil
end

local function runClock(list)
    eachLocalPlayer(function(player) runDrivers(list, player, traitData(player)) end)
end
Events.EveryOneMinute.Add(function() runClock(drivers.minute) end)
Events.EveryTenMinutes.Add(function() runClock(drivers.ten) end)

-- The movement snapshot: what the legs and arms are doing, read once per
-- frame per local player before the frame systems run, instead of each
-- system (some per body part) pcall'ing the same getters.
--
--   DanTraits_Frame(player) -> { sprinting, running, moving, attacking }
--
-- Booleans, false where the game call failed. Inside the frame driver it is
-- the frame's snapshot; anywhere else (a minute system, an event handler) it
-- is read on the spot. Callers read it and never write to it.
local frameSnap = { player = nil, state = nil }

local function readFrame(player)
    local f = { sprinting = false, running = false, moving = false, attacking = false }
    pcall(function() f.sprinting = player:isSprinting() == true end)
    pcall(function() f.running = player:isRunning() == true end)
    pcall(function() f.moving = player:isPlayerMoving() == true end)
    pcall(function() f.attacking = player:isAttacking() == true end)
    return f
end

function DanTraits_Frame(player)
    if player ~= nil and frameSnap.player == player then return frameSnap.state end
    return readFrame(player)
end

Events.OnPlayerUpdate.Add(function(player)
    if not player or player:isDead() then return end
    if player.isLocalPlayer and not player:isLocalPlayer() then return end
    frameSnap.player, frameSnap.state = player, readFrame(player)
    local ok, err = pcall(runDrivers, drivers.frame, player, traitData(player))
    frameSnap.player, frameSnap.state = nil, nil
    if not ok then error(err, 0) end   -- only under DanTraits_STRICT: the drivers guard every system
end)

-- The stat delta pipeline (see DanTraits_Util.lua): one place that scales how
-- fast a stat recovers. Order 0, so it runs before every system that writes
-- the stat in the same tick.
DanTraits_DeltaHook(CharacterStat and CharacterStat.ENDURANCE, "enduranceRegen", "frame")
DanTraits_DeltaHook(nil, "catchCold", "minute", {
    get = function(player) return player:getBodyDamage():getCatchACold() or 0 end,
    set = function(player, value) player:getBodyDamage():setCatchACold(value) end,
})
DanTraits_DeltaHook(CharacterStat and CharacterStat.FOOD_SICKNESS, "foodSicknessRise", "minute")
DanTraits_DeltaHook(CharacterStat and CharacterStat.HUNGER, "hungerRise", "minute")   -- Age: a metabolism
DanTraits_DeltaHook(CharacterStat and CharacterStat.PANIC, "panicRise", "frame")      -- Seen It All
DanTraits_DeltaHook(CharacterStat and CharacterStat.FATIGUE, "fatigueRise", "minute")  -- Deep Sleeper
-- and the pain floors (Util): systems register floors, this applies the largest once
DanTraits_Every("minute", "PainFloor", DanTraits_ApplyPainFloors, 95)


-- Called by the eat action wrapper below with the portion actually eaten.
-- Each trait that cares hooks in through a global (the trait files load
-- after this one, so every call is guarded; never throws). Returns the
-- gluten result so the offline tests can see it.
function DanTraits_OnEat(player, item, fraction)
    if not player or not item then return false end
    if DanTraits_MddOnEat then DanTraits_Guard("eat:MDD", DanTraits_MddOnEat, player, item, fraction) end
    if DanTraits_DiaOnEat then DanTraits_Guard("eat:Diabetes", DanTraits_DiaOnEat, player, item, fraction) end
    if DanTraits_VitalityOnEat then DanTraits_Guard("eat:Vitality", DanTraits_VitalityOnEat, player, item, fraction) end
    DanTraits_RunHooks("eat", nil, player, item, fraction)
    if not DanTraits_GlutenOnEat then return false end
    local ok, res = DanTraits_Guard("eat:Gluten", DanTraits_GlutenOnEat, player, item, fraction)
    return ok and res == true
end

-- Hook the eat action. complete() runs when a meal is finished; eat() runs
-- with the progress so far when it is interrupted. Both call Eat on the
-- character; the dose is read before that, since eating shrinks the item.
local function wrapEatAction()
    -- the reason (a text key) this character will not eat it, or nil
    local function refused(action)
        if not DanTraits_RefuseReason then return nil end
        local ok, res = DanTraits_Guard("refuse", DanTraits_RefuseReason, action.character, action.item)
        if ok and type(res) == "string" then return res end
        return nil
    end
    for _, name in ipairs({ "isValidStart", "isValid" }) do
        DanTraits_Wrap(ISEatFoodAction, name, "core-refuse-food", function(original, self, ...)
            local reason = refused(self)
            if reason then
                if not self.danTraitsRefusedShown then
                    self.danTraitsRefusedShown = true
                    notify(self.character, reason)
                end
                return false
            end
            return original(self, ...)
        end)
    end
    DanTraits_Wrap(ISEatFoodAction, "complete", "core-eat", function(original, self, ...)
        if refused(self) then return true end
        DanTraits_OnEat(self.character, self.item, tonumber(self.percentage) or 1)
        return original(self, ...)
    end)
    DanTraits_Wrap(ISEatFoodAction, "eat", "core-eat", function(original, self, food, percentage, ...)
        if refused(self) then return end
        local progress = tonumber(percentage) or 0
        if progress > 0.95 then progress = 1 end
        -- vanilla's stop() calls eat(item, jobDelta) on every cancel: at 0 nothing went down
        if progress <= 0 then return original(self, food, percentage, ...) end
        DanTraits_OnEat(self.character, self.item, (tonumber(self.percentage) or 1) * progress)
        return original(self, food, percentage, ...)
    end)
end
wrapEatAction()
Events.OnGameStart.Add(wrapEatAction)

-- Antidepressants go through the pill action. The vanilla effect is applied
-- inside complete() (JustTookPill), so it is cancelled straight after.
local function wrapPillAction()
    -- the item's type, as the hooks are keyed on it ("PillsAntiDep"); nil without an item
    local function pillKind(action)
        local kind = nil
        pcall(function() if action.item then kind = tostring(action.item:getType()) end end)
        return kind
    end
    DanTraits_Wrap(ISTakePillAction, "complete", "core-pill", function(original, self, ...)
        local kind = pillKind(self)
        -- before the vanilla effect, for anything that wants the state it acts on
        -- (cigarettes from a pack and chewing tobacco also come through here)
        if kind then DanTraits_RunHooks("prePill", nil, self.character, kind, self.item) end
        local result = original(self, ...)
        if kind then
            if kind == "PillsAntiDep" and DanTraits_MddOnPill then DanTraits_Guard("pill:MDD", DanTraits_MddOnPill, self.character) end
            DanTraits_RunHooks("pill", nil, self.character, kind)
        end
        return result
    end)
end
wrapPillAction()
Events.OnGameStart.Add(wrapPillAction)

-- Debug mode only: log the traits the character actually carries once the
-- world is up, so a wiped character shows up in the log immediately.
local function danTraitsLogCharacterTraits()
    if not (isDebugEnabled and isDebugEnabled()) then return end
    local player = getSpecificPlayer(0)
    if not player then return end
    local names = {}
    pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        for i = 0, known:size() - 1 do names[#names + 1] = tostring(known:get(i)) end
    end)
    print("[DanTraits] character traits (" .. #names .. "): " .. table.concat(names, ", "))
end
Events.OnGameStart.Add(danTraitsLogCharacterTraits)

-- Empty save mod list fix ----------------------------------------------------
-- The game writes <save>/mods.txt from ActiveMods "currentGame" when a world
-- finishes loading. If that list is empty the save records no mods; the next
-- in-session load then applies the empty list, unloads every mod, and the
-- character loses its mod traits (and everything after them in the file).
-- If "currentGame" is empty while mods are active, fill it from "default"
-- before the world finishes loading (and in debug mode, log both counts).
local function danTraitsModListCheck(stage)
    pcall(function()
        local current = ActiveMods.getById("currentGame")
        local default = ActiveMods.getById("default")
        local nCurrent = current and current:getMods():size() or -1
        local nDefault = default and default:getMods():size() or -1
        if isDebugEnabled and isDebugEnabled() then print("[DanTraits] active mods at " .. stage .. ": currentGame=" .. nCurrent .. " default=" .. nDefault) end
        if current and default and nCurrent == 0 and nDefault > 0 then
            current:copyFrom(default)
            print("[DanTraits] currentGame mod list was empty; copied " .. nDefault .. " mods from default")
        end
    end)
end
Events.OnGameBoot.Add(function() danTraitsModListCheck("OnGameBoot") end)
Events.OnInitWorld.Add(function() danTraitsModListCheck("OnInitWorld") end)
Events.OnGameStart.Add(function() danTraitsModListCheck("OnGameStart") end)
