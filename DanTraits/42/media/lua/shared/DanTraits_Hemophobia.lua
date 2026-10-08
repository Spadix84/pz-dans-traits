-- Project Zomboid Vitality Project: Fear of Blood (vanilla Hemophobic,
-- reworked; health overhaul, phase 6).
--
-- The vanilla trait stays the carrier (its definition is replaced in
-- media/scripts/DanTraits.txt: cost and description), so a character who
-- already has it gets the rework, and vanilla's own effects stay:
--   Java (IsoGameCharacter.updateInternal, updateStress): panic from your
--     own bleeding at twice the rate (0.4 against 0.2 x (1 - health/100) x
--     bleeding parts, a tick), and stress from blood on you (total blood x
--     3.3e-7, defines.lua StressFromHemophobic); no medical check on others
--     (ISWorldObjectContextMenuLogic).
--   Lua: +50 panic after bandaging or poulticing a bleeding wound,
--     stitching, pulling out glass or a bullet, cleaning a burn; a little
--     stress handling or crafting with bloody things.
-- Added here:
--   fainting (DanTraits_Faint.lua: down about 8 seconds, woken by anything
--     that wounds you): a chance when that first aid is done (HB_FAINT), and
--     each minute your own blood is running out fast (HB_BLEED_*); once
--     down, not again for HB_GAP minutes
--   first aid on a wound takes longer, the hands shaking (HB_SLOW)
-- The action classes are wrapped through DanTraits_Wrap (DanTraits.lua) with
-- the tags "fear-faint" (complete), "fear-slow" (getDuration) and
-- "fear-splint-slow" (ISSplint.new).
require "DanTraits"

local hasVanillaTrait = DanTraits_HasVanillaTrait
local traitData = DanTraits_Data

local HB_TRAIT        = "base:hemophobic"
local HB_FAINT = {          -- chance of fainting when it's done
    ISApplyBandage = 0.10,  -- (on a bleeding wound)
    ISPlantainCataplasm = 0.10, ISComfreyCataplasm = 0.10, ISGarlicCataplasm = 0.10,
    ISStitch = 0.25,
    ISRemoveGlass = 0.20,
    ISRemoveBullet = 0.35,
    ISCleanBurn = 0.10,
    ISVitalityClotAction = 0.10,  -- clotting powder (on a bleeding wound)
}
local HB_NEEDS_BLEEDING = { ISApplyBandage = true, ISPlantainCataplasm = true, ISComfreyCataplasm = true, ISGarlicCataplasm = true,
                            ISVitalityClotAction = true }
local HB_SLOW_ACTIONS = { "ISApplyBandage", "ISStitch", "ISRemoveGlass", "ISRemoveBullet", "ISCleanBurn", "ISDisinfect",
                          "ISPlantainCataplasm", "ISComfreyCataplasm", "ISGarlicCataplasm", "ISVitalityClotAction" }
local HB_SLOW         = 1.25    -- first aid takes this much longer
local HB_BLEED_FROM   = 0.003   -- losing this much blood a minute (0.3%) and more...
local HB_BLEED_FAINT  = 0.03    -- ...a chance a minute of fainting
local HB_FAINT_MIN    = 1       -- game minutes out (the real-time floor makes it about 8 s)
local HB_GAP          = 10      -- minutes before fainting again

local function afraid(player)
    return player ~= nil and hasVanillaTrait(player, HB_TRAIT)
end

local roll = DanTraits_Roll

local function faint(player, chance)
    chance = tonumber(DanTraits_RunHooks("fearFaint", chance, player)) or chance   -- Seen It All
    if not DanTraits_PassOut or not roll(chance) then return false end
    local d = traitData(player)
    if (d.hbGap or 0) > 0 then return false end
    if DanTraits_PassOut(player, HB_FAINT_MIN, "UI_DanTraits_FaintBlood") then
        d.hbGap = HB_GAP
        return true
    end
    return false
end

-- the actions by name (built when wrapping: the classes may load after this file)
local function actionClasses()
    return {
        ISApplyBandage = ISApplyBandage, ISPlantainCataplasm = ISPlantainCataplasm, ISComfreyCataplasm = ISComfreyCataplasm,
        ISGarlicCataplasm = ISGarlicCataplasm, ISStitch = ISStitch, ISRemoveGlass = ISRemoveGlass,
        ISRemoveBullet = ISRemoveBullet, ISCleanBurn = ISCleanBurn, ISDisinfect = ISDisinfect,
        ISVitalityClotAction = ISVitalityClotAction,
    }
end

-- the action, done: a chance of fainting
local function wrapComplete(class, name)
    DanTraits_Wrap(class, "complete", "fear-faint", function(original, self, ...)
        local bleeding = true
        if HB_NEEDS_BLEEDING[name] then
            pcall(function() bleeding = self.bodyPart:getBleedingTime() > 0 end)
        end
        local result = original(self, ...)
        pcall(function()
            if self.doIt ~= false and bleeding and afraid(self.character) then faint(self.character, HB_FAINT[name]) end
        end)
        return result
    end)
end


local function wrapAll()
    local classes = actionClasses()
    for name in pairs(HB_FAINT) do wrapComplete(classes[name], name) end
    -- the hands shaking: longer to do (getDuration on each, and the splint's own time)
    local slow = {}
    for _, name in ipairs(HB_SLOW_ACTIONS) do slow[#slow + 1] = classes[name] end
    DanTraits_ScaleActionTime(slow, "fear-slow", afraid, HB_SLOW)
end
wrapAll()
Events.OnGameStart.Add(wrapAll)

-- your own blood running out fast
local function updateFearMinute(player, d)
    if (d.hbGap or 0) > 0 then d.hbGap = d.hbGap - 1 end
    if not afraid(player) then return end
    local asleep = DanTraits_Asleep(player)
    if asleep then return end
    if (d.bloodLossMin or 0) >= HB_BLEED_FROM then faint(player, HB_BLEED_FAINT) end
end

-- console: fearofblood on | off
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.fearofblood = function(player, args)
    local on = args[1] ~= "off"
    pcall(function()
        local traits = player:getCharacterTraits()
        if on and not traits:get(CharacterTrait.HEMOPHOBIC) then traits:add(CharacterTrait.HEMOPHOBIC) end
        if not on and traits:get(CharacterTrait.HEMOPHOBIC) then traits:remove(CharacterTrait.HEMOPHOBIC) end
    end)
    DanTraits_TraitsChanged(player)
    return "fear of blood: " .. tostring(afraid(player))
end

DanTraits_Every("minute", "FearOfBlood", updateFearMinute, 25)
