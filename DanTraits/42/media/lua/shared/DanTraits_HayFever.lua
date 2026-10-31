-- Project Zomboid Vitality Project: Hay Fever (Age 2.0, 2026-10-31; any age).
--
-- A season you can hear. From March to August the pollen is out (HF_MONTHS,
-- by month: peaking May and June), worst on dry, windy days (the climate's
-- wind), cleared by rain (rain cuts it to a fifth), and a third as bad
-- indoors. The load (hfLoad, 0..1) follows that target a little each minute.
-- While it is up: sneezing fits (a chance each waking minute, HF_SNEEZE
-- percent at a full load) that make a sound zombies hear (the one shared
-- cough, DanTraits_Util.lua, so the gap is kept) and interrupt whatever you
-- were doing (the action queue is cleared). Antihistamines (new, common in
-- bathrooms; the shared medication system's "antihistamine", a rescue drug)
-- take the load away while they are in the system and make you drowsy
-- (tiredness while taking). From autumn to spring nothing happens. A new
-- character starts with a bottle (Starting Medication).
--
-- Mod data: hfLoad, hfSneezes, hfTold, hfKitGiven.
-- Console: hayfever [sneeze|load <0..1>].
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local clamp01 = DanTraits_Clamp01

local HF_MONTHS     = { [2] = 0.3, [3] = 0.8, [4] = 1, [5] = 1, [6] = 0.8, [7] = 0.4 }   -- getMonth is 0-based: March to August
local HF_RAIN_FROM  = 0.1     -- rain intensity from which the air is washed...
local HF_RAIN       = 0.2     -- ...the pollen x this
local HF_WIND       = 0.6     -- the pollen x (1 - this/2 + this x wind): a still day 0.7, a gale 1.3
local HF_INDOORS    = 0.3     -- indoors x this
local HF_SMOOTH     = 0.05    -- the load moves this share of the way to its target each minute
local HF_SNEEZE     = 3       -- percent a waking minute at a full load
local HF_SNEEZE_RADIUS = 12   -- tiles zombies hear a sneeze from
local HF_TOLD_AT    = 0.6     -- the load crossing this upward: a notice
local HF_START_PILLS = "DanTraits.Antihistamines"

local function has(player) return player ~= nil and hasTrait(player, "hayfever") end

-- 0..1 pollen in the air for this character now
local function pollen(player)
    local month = nil
    pcall(function() month = getGameTime():getMonth() end)
    local base = HF_MONTHS[month or -1] or 0
    if base <= 0 then return 0 end
    local rain, wind = 0, 0.5
    pcall(function()
        local c = getClimateManager()
        rain = c:getRainIntensity() or 0
        wind = c:getWindIntensity() or 0.5
    end)
    local p = base * (1 - HF_WIND / 2 + HF_WIND * clamp01(wind))
    if rain >= HF_RAIN_FROM then p = p * HF_RAIN end
    local outside = true
    pcall(function() outside = player:isOutside() end)
    if not outside then p = p * HF_INDOORS end
    return clamp01(p)
end
DanTraits_HayFeverPollen = pollen

local function loadOf(player)
    local d = player and player:getModData().DanTraits
    if not d or not has(player) then return 0 end
    return d.hfLoad or 0
end
DanTraits_HayFeverLoad = loadOf

local function sneeze(player, d)
    if not DanTraits_Cough(player, HF_SNEEZE_RADIUS, "sneeze") then return false end
    d.hfSneezes = (d.hfSneezes or 0) + 1
    pcall(function()
        if DanTraits_QueueHead(player) then ISTimedActionQueue.clear(player) end
    end)
    return true
end

local function updateHayFeverMinute(player, d)
    local target = pollen(player)
    if DanTraits_MedEffect then
        target = target * (1 - clamp01(tonumber(DanTraits_MedEffect(player, "antihistamine")) or 0))
    end
    local load = d.hfLoad or 0
    load = load + (target - load) * HF_SMOOTH
    if load < 0.001 then load = 0 end
    if (d.hfLoad or 0) < HF_TOLD_AT and load >= HF_TOLD_AT and not d.hfTold then
        d.hfTold = true
        notify(player, "UI_DanTraits_HayFeverBad")
    elseif load < HF_TOLD_AT then
        d.hfTold = nil
    end
    d.hfLoad = load
    if load <= 0 or DanTraits_Asleep(player) then return end
    if DanTraits_RollPercent(HF_SNEEZE * load) then sneeze(player, d) end
end

local function clearHayFever(player, d)
    if d then d.hfLoad, d.hfTold = nil, nil end
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.hayfever = function(player, args)
    local d = traitData(player)
    if args[1] == "sneeze" then sneeze(player, d)
    elseif args[1] == "load" then d.hfLoad = clamp01(tonumber(args[2]) or d.hfLoad or 0) end
    return "hayfever: pollen " .. string.format("%.2f", pollen(player)) .. ", load " .. string.format("%.2f", d.hfLoad or 0)
        .. ", sneezes " .. tostring(d.hfSneezes or 0)
end

DanTraits_Every("minute", "HayFever", updateHayFeverMinute, 40, { trait = "hayfever", clear = clearHayFever })

DanTraits_StartingKit({ trait = "hayfever", flag = "hfKitGiven", items = { HF_START_PILLS } })
