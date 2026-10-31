-- Project Zomboid Vitality Project: Wound Expansion compatibility.
require "DanTraits"

-- Does nothing unless Wound Expansion (Kaoeutsu, Workshop 3819438691, mod id
-- WoundExpansion; read at 1.1.3) is loaded, and nothing with the sandbox option
-- Wound Expansion Compatibility (WoundExpansionCompat) off. No dependency
-- either way, and nothing of theirs is copied into this mod's files.
--
-- The rule: where both mods model the same thing, this mod's version runs and
-- theirs stands down, each behind the sandbox switch of the system here that
-- takes it over; everything Wound Expansion adds that this mod has no word on
-- (abrasions, punctures, avulsions, frostbite, sprains, dislocations, joint and
-- nerve damage, bruises, embedded debris, maggots, swelling, over-bandaging,
-- the tourniquet, iodine, slings, casts, compression, smelling salts, internal
-- bleeding and the surgery for it, cauterising, scars, the minigames) is left
-- to it. What stands down, and why:
--   Concussion        (ConcussionEnabled) theirs: a head wound from falls, crashes and
--                     knock-downs with its own endurance cut, stress and reading block;
--                     this mod's Concussion is judged from the same damage events.
--   Reopened,         (WoundCareEnabled) theirs tears any fresh stitches or deep wound
--   PoorlyStitched    on a 35% roll per strain (a sprint, a swing, a climb) and rolls
--                     rough stitches in ISStitch.complete; so does this mod's wound
--                     care, and the two stacked.
--   SepticFever       (InfectionEnabled) theirs: an infected wound 24 h without
--                     antibiotics brings a fever with thirst, tiredness and a health
--                     drain; this mod's infection has its own fever, sepsis and shock.
--   Necrotic from     (InfectionEnabled) theirs turns a wound necrotic 12 h after its
--   an infection      infection level passes NECROSIS_INFECTION; the level it reads is
--                     this mod's (0..10, written every minute), so the line is put
--                     above 10. Necrosis from a tourniquet left on or severe
--                     frostbite is still theirs.
--   Their infection   (InfectionEnabled) one in INFECTION_ROLL_BASE / multiplier a
--   roll              minute sets the game's infected flag; this mod's infection
--                     clears a flag it has no record of within the minute, so the
--                     roll only ever flickered. The base is put out of reach. Their
--                     Inflamed warning (the roll's pressure building on a dirty or
--                     debris wound) still works and still clears when it is cleaned.
--   Sickness from     (InfectionEnabled) their per-minute sickness drifts toward a
--   an infection      target that counts every infected wound's level; a local
--                     infection here has no fever. WE.Effects.onMinute (looked up on
--                     the table on every call) is replaced by the same arithmetic
--                     without that term: low health, necrosis, maggots and septic
--                     fever still count as theirs.
-- What is joined up, both ways:
--   Dressings  their Dirty condition sets a bandage's life to 0 every minute (a filthy
--              wound spoils the dressing over it) and Torn Bandage halves it; this
--              mod's wound care puts any drop back as vanilla's own drain. The
--              dressingWear hook (DanTraits_WoundCare.lua) lets this file hand the
--              life to accept instead: 0 under a filthy wound, the halved life after a
--              tear. Their hemostatic gauze holds its own life and is left to it.
--   Infection  their dirt feeds this mod's infection hazard (the infectionHazard hook):
--              a Filthy wound x HAZARD.Dirty, one rinsed with water alone x HAZARD.Rinsed,
--              debris of their own x HAZARD.EmbeddedDebris (glass or a bullet is already
--              counted here as lodged). Their iodine holds the part's alcohol level up
--              for a day, which this mod's infection reads as a cleaned wound for a day.
--   Blood      their blood bag (WE_ApplyItemAction, kind "transfusion") restores health;
--              with Blood Loss on it also puts TRANSFUSION_VOL of blood volume and red
--              cells back. Their tourniquet and hemostatic gauze act on bleeding time,
--              which is what this mod's blood loss reads, so they work as they are; an
--              avulsion's bleeding time of 20 bleeds here as it would in vanilla, fast.
--              Their internal bleeding drains health, not blood, and is left to it.
-- Their sandbox reader (WE_Sandbox.lua) starts Cfg.OFF over at OnGameStart and
-- OnServerStarted, in whichever order the two mods loaded, so the settings here
-- are applied at those events, again a frame later, and again at the top of
-- their own minute (the replaced WE.Effects.onMinute runs for every character
-- they simulate, before that minute's sweep of the parts; a handful of table
-- writes). Their own sandbox switches (allow<Id>) are respected: this file only
-- ever adds to the OFF set. In multiplayer Wound Expansion runs on the server;
-- this file is shared Lua and does the same there.
-- Not play-tested with Wound Expansion loaded (2026-10-31).

local OFF = {   -- their wound or condition id -> the sandbox switch of the system here that takes it over
    { id = "Concussion",     switch = "ConcussionEnabled" },
    { id = "Reopened",       switch = "WoundCareEnabled" },
    { id = "PoorlyStitched", switch = "WoundCareEnabled" },
    { id = "SepticFever",    switch = "InfectionEnabled" },
}
local NECROSIS_NEVER  = 11            -- their necrosis-from-infection line, above this mod's 0..10
local ROLL_NEVER      = 1000000000    -- their infection roll base: one in a billion a minute
local HAZARD          = { Dirty = 3, Rinsed = 1.5, EmbeddedDebris = 2 }   -- x this mod's infection hazard
local TRANSFUSION_VOL = 0.1           -- blood volume and red cells a blood bag puts back (1 is a full body)

local function compatOn() return DanTraits_SandboxOn("WoundExpansionCompat") end

-- their table, or nil when the mod is not loaded (or not what this file read)
local function we()
    local W = WoundExpansion
    if type(W) ~= "table" or type(W.Config) ~= "table" or type(W.Core) ~= "table" or type(W.CONDITION) ~= "table" then return nil end
    return W
end

-- What stands down: added to their OFF set (their minute sweep removes an OFF
-- wound or condition from every part and refuses new ones), and the two
-- numbers that make their infection path inert. Only for the systems that are
-- on here; with this mod's infection off, theirs runs as it is.
local function applySettings()
    local W = we()
    if not W or not compatOn() then return false end
    local Cfg = W.Config
    Cfg.OFF = Cfg.OFF or {}
    for _, entry in ipairs(OFF) do
        if DanTraits_SandboxOn(entry.switch) then Cfg.OFF[entry.id] = true end
    end
    if DanTraits_SandboxOn("InfectionEnabled") then
        Cfg.NECROSIS_INFECTION = NECROSIS_NEVER
        Cfg.INFECTION_ROLL_BASE = ROLL_NEVER
    end
    return true
end
DanTraits_WoundExpansionSettings = applySettings   -- for the tests

-- Their sickness minute without the infected-wound term (WE_Effects.lua 1.1.3,
-- Effects.onMinute and its sicknessTarget). Their flags.sickAdded is the share
-- of the Sick stat they put there, so another system's sickness (this mod's
-- fever) is never taken back by them.
local function installSickness(W)
    local Effects = W.Effects
    if type(Effects) ~= "table" or type(Effects.onMinute) ~= "function" or Effects.DanTraitsOnMinute then return end
    local original = Effects.onMinute
    local Core, Cfg, C = W.Core, W.Config, W.CONDITION
    local function sicknessTarget(character)
        local target = 0
        local health = character:getBodyDamage():getOverallBodyHealth()
        if health < Cfg.SICK_HEALTH_THRESHOLD then
            target = target + (Cfg.SICK_HEALTH_THRESHOLD - health) / Cfg.SICK_HEALTH_THRESHOLD * Cfg.SICK_FROM_HEALTH
        end
        Core.forEachBodyPart(character, function(bodyPart, index)
            if W.Compat and W.Compat.isAmputated and W.Compat.isAmputated(character, bodyPart) then return end
            local entry = Core.peekPart(character, index)
            if not entry then return end
            if entry.conditions[C.NECROTIC] then target = target + Cfg.SICK_FROM_NECROSIS end
            if entry.conditions[C.MAGGOTS] then target = target + Cfg.SICK_FROM_MAGGOTS end
            if entry.conditions[C.SEPTIC_FEVER] then target = target + Cfg.SICK_FROM_SEPSIS end
        end)
        return Core.clamp(target, 0, 1)
    end
    local function onMinute(character)
        local stats = character:getStats()
        local flags = Core.flags(character)
        local current = stats:get(CharacterStat.SICKNESS)
        local added = flags.sickAdded or current
        local room = Cfg.SICK_CEILING - character:getBodyDamage():getApparentInfectionLevel() / 100 - (current - added)
        local target = math.min(sicknessTarget(character), math.max(0, room))
        local step = Core.clamp(target - added, -Cfg.SICK_RECOVER_RATE, Cfg.SICK_RATE)
        step = Core.clamp(step, -current, 1 - current)
        if step ~= 0 then stats:set(CharacterStat.SICKNESS, current + step) end
        flags.sickAdded = added + step
    end
    local function replaced(character, ...)
        applySettings()   -- their reader may have started Cfg.OFF over since; before this minute's sweep
        if not compatOn() or not DanTraits_SandboxOn("InfectionEnabled") then return original(character, ...) end
        DanTraits_Guard("we-sickness", onMinute, character)   -- runs inside their minute: a failure is logged once, never thrown at them
    end
    Effects.onMinute = replaced
    Effects.DanTraitsOnMinute = replaced
end

-- A blood bag's health goes in as theirs; the blood goes into this mod's volume.
-- WE_ApplyItemAction:treat calls the treatment and, when it took, consumes the
-- item, which leaves the bag with no container.
local function installTransfusion()
    if type(WE_ApplyItemAction) ~= "table" then return end
    DanTraits_Wrap(WE_ApplyItemAction, "treat", "we-transfusion", function(original, self, ...)
        local result = original(self, ...)
        if self.kind ~= "transfusion" or not compatOn() or not (DanTraits_BloodActive and DanTraits_BloodActive()) then return result end
        local given = false
        pcall(function() given = self.item == nil or self.item:getContainer() == nil end)
        local d = given and self.patient and DanTraits_Data(self.patient)
        if d and d.bloodVol ~= nil then
            d.bloodVol = math.min(1, d.bloodVol + TRANSFUSION_VOL)
            d.bloodCells = math.min(1, (d.bloodCells or 1) + TRANSFUSION_VOL)
        end
        return result
    end)
end

-- the dressing: their filth spoils it, their tear halves it (DanTraits_WoundCare.lua)
DanTraits_AddHook("dressingWear", function(_, player, part, life, was)
    local W = we()
    if not W or not compatOn() then return nil end
    local accept = nil
    pcall(function()
        local Core, C = W.Core, W.CONDITION
        local index = part:getIndex()
        local dirty = Core.getCondition(player, index, C.DIRTY)
        if dirty and dirty.bandagedDirty then accept = 0 return end
        local torn = Core.getCondition(player, index, C.TORN_BANDAGE)
        if torn and tonumber(torn.life) then accept = tonumber(torn.life) end
    end)
    return accept
end)

-- their dirt in this mod's infection hazard (DanTraits_Infection.lua)
DanTraits_AddHook("infectionHazard", function(h, player, part)
    local W = we()
    if not W or not compatOn() then return nil end
    local k = 1
    pcall(function()
        local Core, C = W.Core, W.CONDITION
        local index = part:getIndex()
        if Core.hasCondition(player, index, C.DIRTY) then k = k * HAZARD.Dirty
        elseif Core.hasCondition(player, index, C.RINSED) then k = k * HAZARD.Rinsed end
        local debris = Core.getCondition(player, index, C.EMBEDDED_DEBRIS)
        if debris and debris.source ~= "vanilla" then k = k * HAZARD.EmbeddedDebris end
    end)
    if k == 1 then return nil end
    return h * k
end)

local installed = false
local function install()
    local W = we()
    if not W then return end
    applySettings()
    if DanTraits_Later then DanTraits_Later(1, applySettings, "we-settings") end   -- after their reader, whichever ran first
    if installed then return end
    installed = true
    installSickness(W)
    installTransfusion()
end
Events.OnGameStart.Add(install)
if Events.OnServerStarted then Events.OnServerStarted.Add(install) end
