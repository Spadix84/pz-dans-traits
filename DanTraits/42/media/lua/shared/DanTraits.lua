-- Project Zomboid Vitality Project: core.
--
-- The traits declared in media/scripts/DanTraits.txt each live in their own
-- file next to this one (DanTraits_<Trait>.lua) and `require` this file for
-- the shared helpers below. This file holds those helpers, the minute /
-- ten-minute / frame drivers (DanTraits_Every), the frame scheduler,
-- DanTraits_Wrap (the one way any file wraps a game method, so several files
-- can layer on the same method), the cached vanilla trait lookup
-- (DanTraits_HasVanillaTrait, DanTraits_TraitsChanged), the eat and pill action hooks that several
-- traits share, the one-time rename of old mod-data keys (DanTraits_MigrateModData),
-- and the save mod-list fix. Each trait bails out immediately
-- unless the player actually has it, so an unaffected character costs a
-- handful of lookups.
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
-- for that (old -> new) are moved once per save, when the player loads
-- (OnCreatePlayer runs before the trait files' own starts read the new
-- names, OnGameStart covers the rest): copied only if the new key is not
-- already set, then the old one is cleared. One log line with the count.
-- Add a pair here whenever a saved key is renamed.
local MODDATA_RENAMES = {
    withdrawing        = "alcWithdrawing",
    dryHours           = "alcDryHours",
    depTolerance       = "alcMeter",
    earlyRiserApplied  = "posEarlyRiser",
    mealPrepperApplied = "posMealPrepper",
    gymRegularApplied  = "gymApplied",
    deepSleeperWakeful = "slWakefulGranted",
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
    if n > 0 then print("[DanTraits] mod data: renamed " .. n .. " old key(s)") end
    return n
end
Events.OnCreatePlayer.Add(function(playerNum, player) DanTraits_MigrateModData(player) end)
Events.OnGameStart.Add(function() DanTraits_MigrateModData(getSpecificPlayer(0)) end)

-- Retired traits (2026-10-07): still registered and defined, so a save that
-- has one loads, and hidden at creation (DanTraits_Client.lua). A loaded
-- character has it taken off and, where one took its place, gets that
-- instead: a mod key, or "base:" and the CharacterTrait constant's name.
-- false: nothing replaces it.
DanTraits_RETIRED = {
    jinxed      = false,
    ironstomach = "base:IRON_GUT",
    bouncesback = "thickskull",
}
function DanTraits_RetireTraits(player)
    if not player or not DanTraitsRegistry then return 0 end
    local n = 0
    for key, into in pairs(DanTraits_RETIRED) do
        local entry = DanTraitsRegistry[key]
        if entry and hasTrait(player, key) then
            pcall(function()
                local traits = player:getCharacterTraits()
                traits:remove(entry)
                local new = nil
                if into and string.sub(into, 1, 5) == "base:" then new = CharacterTrait[string.sub(into, 6)]
                elseif into then new = DanTraitsRegistry[into] end
                if new and not traits:get(new) then traits:add(new) end
            end)
            n = n + 1
        end
    end
    if n > 0 then
        DanTraits_TraitsChanged(player)
        print("[DanTraits] retired " .. n .. " trait(s) swapped out")
    end
    return n
end
Events.OnCreatePlayer.Add(function(playerNum, player) DanTraits_RetireTraits(player) end)
Events.OnGameStart.Add(function() DanTraits_RetireTraits(getSpecificPlayer(0)) end)

-- vanilla traits by id, as the game names them (lowercase "base:needslesssleep").
-- Walking getKnownTraits is a Java list walk with a tostring and a lowercase
-- per element, and the trait files ask several times a minute, so the walk is
-- cached: one snapshot { player, minute, set } for the (single) local player,
-- rebuilt when the game minute changes, when the player object changes, or
-- when a file that adds or removes a trait at runtime calls
-- DanTraits_TraitsChanged(player) (also called on OnCreatePlayer / OnGameStart).
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
Events.OnCreatePlayer.Add(DanTraits_TraitsChanged)
Events.OnGameStart.Add(DanTraits_TraitsChanged)

-- shared with the trait files
DanTraits_HasTrait = hasTrait
DanTraits_HasVanillaTrait = hasVanillaTrait
DanTraits_Notify = notify
DanTraits_NotifyGood = notifyGood
DanTraits_Data = traitData

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

-- Value hooks: a system (Vitality, mostly) offers a value, every file that
-- registered for that name gets to adjust it, in load order. A hook returns
-- the new value or nil to leave it. A hook that errors is logged once
-- (DanTraits_Guard) and leaves the value alone.
DanTraits_Hooks = DanTraits_Hooks or {}
function DanTraits_AddHook(name, fn)
    local list = DanTraits_Hooks[name] or {}
    DanTraits_Hooks[name] = list
    list[#list + 1] = fn
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
-- tag (optional) names the job in the log when it fails.
local laterPending = {}
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
function DanTraits_Wrap(class, method, tag, fn)
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

-- The drivers: one minute handler, one ten-minute handler, one frame handler ----------------------------------------
-- Every system that runs on the clock registers here instead of on
-- Events.EveryOneMinute / EveryTenMinutes / OnPlayerUpdate:
--
--   DanTraits_Every(cadence, label, fn, order)
--     cadence  "minute" | "ten" | "frame"
--     label    the system's name for the dashboard's attribution card ("Blood")
--     fn       fn(player, d), d = the player's mod data
--     order    number, lower runs first, default 100; equal orders run by label
--
-- Core registers the only three handlers. Each does the preamble once (the
-- local player, dead check; the frame one also skips non-local players), then
-- runs every registration in order through DanTraits_Track(label, ...) inside
-- DanTraits_Guard, so one system's error is logged once and never stops the next.
-- Order decides which system sees which other system's floors and stat writes
-- in the same minute, so it is written down here:
--
--   minute   0  the stat delta pipeline (DanTraits_DeltaHook in Util): catchCold and
--               foodSicknessRise, so subscribers see the game's rise, not floors written
--               later in the same minute
--           10  Sleep (light reading, wakes)
--           19  GoodClotter (Positives: cuts bleeding time before Blood reads it)
--           20  Blood (loss this minute, sets bloodLossMin)
--           21  Hemophilia (holds bleed times)
--           22  WoundCare (reads BloodPartRate)
--           23  Infection
--           23.5 Age (paces the fall of scratch and cut clocks and of stiffness; after
--               Infection's hold, before the stiffness floors of Arthritis and MS)
--           24  Concussion
--           25  FearOfBlood (reads bloodLossMin)
--           30  Meds (the levels every medicated system reads this minute)
--           39  Spoons (the energy budget MS spends; reads the night Vitality scored)
--           40  Alcohol, Anemia, Anger, Arthritis, Asthma, Caffeine, Dehydration, Diabetes,
--               Epilepsy, Germaphobe, Gluten, Hangover, Heart, Lactose, MDD, Migraine,
--               MS, Smoker, Sunburn, Tinnitus, Triptan (floors and rates; among themselves by label)
--               (Iron Stomach in Positives is a foodSicknessRise pipeline hook, not a clock system)
--           90  Vitality (reads everything above, scores the night, applies lifts)
--           95  PainFloor (Util: applies the largest pain floor the systems above registered)
--           96  Moodles (reads what every system above left in mod data; changes nothing)
--   ten     10  Dependent
--           40  MDD, Migraine
--           90  Hallucinations
--   frame    0  the stat delta pipeline: enduranceRegen (Vitality, Smoker lungs, Blood,
--               Anemia, Concussion, Asthma, Heart, Dehydration, Age subscribe; the cuts multiply)
--           20  Blood        22  WoundCare (movement sampling)    24  Concussion
--           40  Alcohol (panic decay), Arthritis, ArthritisGrip, Meds (diazepam), Smoker (held anger)
--   (Faint stays on OnTick; OnTick, OnWeaponSwing and OnPlayerGetDamage handlers
--   are still registered by their own files.)
local drivers = { minute = {}, ten = {}, frame = {} }
DanTraits_Drivers = drivers      -- read-only view for the tests and the dashboard

function DanTraits_Every(cadence, label, fn, order)
    local list = drivers[cadence]
    if not list or type(fn) ~= "function" then return false end
    label = tostring(label or "")
    order = order or 100
    local at = #list
    while at >= 1 and (list[at].order > order or (list[at].order == order and list[at].label > label)) do at = at - 1 end
    table.insert(list, at + 1, { cadence = cadence, label = label, fn = fn, order = order })
    return true
end

local function runDrivers(list, player, d)
    local track = DanTraits_Track or function(_, fn, ...) return fn(...) end
    for i = 1, #list do
        local entry = list[i]
        DanTraits_Guard(entry.label .. " (" .. entry.cadence .. ")", track, entry.label, entry.fn, player, d)
    end
end

local function runClock(list)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    runDrivers(list, player, traitData(player))
end
Events.EveryOneMinute.Add(function() runClock(drivers.minute) end)
Events.EveryTenMinutes.Add(function() runClock(drivers.ten) end)
Events.OnPlayerUpdate.Add(function(player)
    if not player or player:isDead() then return end
    if player.isLocalPlayer and not player:isLocalPlayer() then return end
    runDrivers(drivers.frame, player, traitData(player))
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
-- and the pain floors (Util): systems register floors, this applies the largest once
DanTraits_Every("minute", "PainFloor", DanTraits_ApplyPainFloors, 95)


-- Called by the eat action wrapper below with the portion actually eaten.
-- Each trait that cares hooks in through a global (the trait files load
-- after this one, so every call is guarded; never throws). Returns the
-- gluten result so the offline tests can see it.
function DanTraits_OnEat(player, item, fraction)
    if not player or not item then return false end
    if DanTraits_MddOnEat then DanTraits_Guard("eat:MDD", DanTraits_MddOnEat, player, item) end
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
