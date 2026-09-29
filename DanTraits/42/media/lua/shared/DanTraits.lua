-- Project Zomboid Vitality Project: core.
--
-- The traits declared in media/scripts/DanTraits.txt each live in their own
-- file next to this one (DanTraits_<Trait>.lua) and `require` this file for
-- the shared helpers below. This file holds those helpers, the ten-minute
-- driver, the frame scheduler, DanTraits_Wrap (the one way any file wraps a
-- game method, so several files can layer on the same method), the eat and
-- pill action hooks that several traits share, and the save mod-list fix.
-- Each trait bails out immediately
-- unless the player actually has it, so an unaffected character costs a
-- handful of lookups.
--
-- Lua allows 200 locals per file: new traits go in new files, not here.

-- before any handler is registered, so the dashboard can say which trait
-- moved which stat
require "DanTraits_Attrib"

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
    pcall(function()
        triggerEvent(STORY_EVENT, player, { source = "DanTraits", kind = kind, text = text, tone = tone or "bad" })
    end)
end

local function storyKind(textKey)
    return (string.gsub(textKey, "^UI_DanTraits_", ""))
end

local function notify(player, textKey)
    local text = getText(textKey)
    pcall(function() HaloTextHelper.addBadText(player, text) end)
    DanTraits_Story(player, storyKind(textKey), text, "bad")
end

local function notifyGood(player, textKey)
    local text = getText(textKey)
    pcall(function() HaloTextHelper.addGoodText(player, text) end)
    DanTraits_Story(player, storyKind(textKey), text, "good")
end

local function traitData(player)
    local md = player:getModData()
    md.DanTraits = md.DanTraits or {}
    return md.DanTraits
end

-- vanilla traits by id, as the game names them (lowercase "base:needslesssleep")
local function hasVanillaTrait(player, id)
    local found = false
    pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        for i = 0, known:size() - 1 do
            if string.lower(tostring(known:get(i))) == id then found = true end
        end
    end)
    return found
end

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
-- the new value or nil to leave it. Errors in a hook are swallowed.
DanTraits_Hooks = DanTraits_Hooks or {}
function DanTraits_AddHook(name, fn)
    local list = DanTraits_Hooks[name] or {}
    DanTraits_Hooks[name] = list
    list[#list + 1] = fn
end
function DanTraits_RunHooks(name, value, ...)
    local list = DanTraits_Hooks[name]
    if not list then return value end
    for _, fn in ipairs(list) do
        local ok, res = pcall(fn, value, ...)
        if ok and res ~= nil then value = res end
    end
    return value
end

-- Tiny frame scheduler shared by the traits: run fn after that many frames.
local laterPending = {}
function DanTraits_Later(frames, fn)
    laterPending[#laterPending + 1] = { frames = frames, fn = fn }
end
local function laterOnTick()
    if #laterPending == 0 then return end
    for i = #laterPending, 1, -1 do
        local job = laterPending[i]
        job.frames = job.frames - 1
        if job.frames <= 0 then
            table.remove(laterPending, i)
            pcall(job.fn)
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

-- Ten-minute driver (the trait files hook in through globals) --------------------------------------------------------
local function onTenMinutes()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    local d = traitData(player)
    local track = DanTraits_Track or function(_, fn, ...) return fn(...) end
    if DanTraits_updateDependent then track("Dependent", DanTraits_updateDependent, player, d) end
    if DanTraits_updateMddTen then track("MDD", DanTraits_updateMddTen, player, d) end
    if DanTraits_updateSchizophrenia then track("Hallucinations", DanTraits_updateSchizophrenia, player, d) end
end
Events.EveryTenMinutes.Add(onTenMinutes)


-- Called by the eat action wrapper below with the portion actually eaten.
-- Each trait that cares hooks in through a global (the trait files load
-- after this one, so every call is guarded). Returns the gluten result so
-- the offline tests can see it.
function DanTraits_OnEat(player, item, fraction)
    if not player or not item then return false end
    if DanTraits_MddOnEat then pcall(function() DanTraits_MddOnEat(player, item) end) end
    if DanTraits_DiaOnEat then pcall(function() DanTraits_DiaOnEat(player, item, fraction) end) end
    if DanTraits_VitalityOnEat then pcall(function() DanTraits_VitalityOnEat(player, item, fraction) end) end
    DanTraits_RunHooks("eat", nil, player, item, fraction)
    if not DanTraits_GlutenOnEat then return false end
    local ok, res = pcall(DanTraits_GlutenOnEat, player, item, fraction)
    return ok and res == true
end

-- Hook the eat action. complete() runs when a meal is finished; eat() runs
-- with the progress so far when it is interrupted. Both call Eat on the
-- character; the dose is read before that, since eating shrinks the item.
local function wrapEatAction()
    local function refused(action)
        if not DanTraits_RefusesFood then return false end
        local ok, res = pcall(function() return DanTraits_RefusesFood(action.character, action.item) end)
        return ok and res == true
    end
    for _, name in ipairs({ "isValidStart", "isValid" }) do
        DanTraits_Wrap(ISEatFoodAction, name, "core-refuse-food", function(original, self, ...)
            if refused(self) then
                if not self.danTraitsRefusedShown then
                    self.danTraitsRefusedShown = true
                    notify(self.character, "UI_DanTraits_VegetarianRefuse")
                end
                return false
            end
            return original(self, ...)
        end)
    end
    DanTraits_Wrap(ISEatFoodAction, "complete", "core-eat", function(original, self, ...)
        if refused(self) then return true end
        pcall(function() DanTraits_OnEat(self.character, self.item, self.percentage or 1) end)
        return original(self, ...)
    end)
    DanTraits_Wrap(ISEatFoodAction, "eat", "core-eat", function(original, self, food, percentage, ...)
        if refused(self) then return end
        pcall(function()
            local progress = percentage or 0
            if progress > 0.95 then progress = 1 end
            DanTraits_OnEat(self.character, self.item, (self.percentage or 1) * progress)
        end)
        return original(self, food, percentage, ...)
    end)
end
wrapEatAction()
Events.OnGameStart.Add(wrapEatAction)

-- Antidepressants go through the pill action. The vanilla effect is applied
-- inside complete() (JustTookPill), so it is cancelled straight after.
local function wrapPillAction()
    DanTraits_Wrap(ISTakePillAction, "complete", "core-pill", function(original, self, ...)
        -- before the vanilla effect, for anything that wants the state it acts on
        -- (cigarettes from a pack and chewing tobacco also come through here)
        pcall(function()
            if self.item then DanTraits_RunHooks("prePill", nil, self.character, tostring(self.item:getType()), self.item) end
        end)
        local result = original(self, ...)
        pcall(function()
            if not self.item then return end
            local kind = tostring(self.item:getType())
            if kind == "PillsAntiDep" and DanTraits_MddOnPill then DanTraits_MddOnPill(self.character) end
            DanTraits_RunHooks("pill", nil, self.character, kind)
        end)
        return result
    end)
end
wrapPillAction()
Events.OnGameStart.Add(wrapPillAction)

-- Log the traits the character actually carries once the world is up, so a
-- wiped character shows up in the log immediately.
local function danTraitsLogCharacterTraits()
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
-- Diagnose, and if "currentGame" is empty while mods are active, fill it
-- from "default" before the world finishes loading.
local function danTraitsModListCheck(stage)
    pcall(function()
        local current = ActiveMods.getById("currentGame")
        local default = ActiveMods.getById("default")
        local nCurrent = current and current:getMods():size() or -1
        local nDefault = default and default:getMods():size() or -1
        print("[DanTraits] active mods at " .. stage .. ": currentGame=" .. nCurrent .. " default=" .. nDefault)
        if current and default and nCurrent == 0 and nDefault > 0 then
            current:copyFrom(default)
            print("[DanTraits] currentGame mod list was empty; copied " .. nDefault .. " mods from default")
        end
    end)
end
Events.OnGameBoot.Add(function() danTraitsModListCheck("OnGameBoot") end)
Events.OnInitWorld.Add(function() danTraitsModListCheck("OnInitWorld") end)
Events.OnGameStart.Add(function() danTraitsModListCheck("OnGameStart") end)
