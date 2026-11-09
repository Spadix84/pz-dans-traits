-- Vanilla test commands for the companion app's test bench: skills, time,
-- game speed, weather and air temperature. They ride the same command channel
-- as DanTraits_Telemetry.lua (debug mode only, single player), registered in
-- DanTraits_ExtraCommands, and DanTraits_WorldSnapshot hands the telemetry the
-- skill levels and the weather so the companion can show what it is changing.
--
--   skill                          every skill and its level
--   skill <id|name|all> <0..10>    set a skill (Carpentry, Woodwork, first aid, all)
--   time                           the clock, the date and the world hours
--   time <H[:MM]>                  move the clock forward to the next H:MM
--   time +<hours>                  move the clock forward by that much
--   speed <0..4|pause|play|fast|faster|wait>
--   weather                        what the sky is doing and which overrides are on
--   weather clear | storm [h] | tropical [h] | blizzard [h]
--   weather rain <0..1> | snow <0..1> | fog <0..1> | clouds <0..1> | wind <kph>
--   weather natural                every override off (temperature too)
--   temp <C> | temp natural        hold the outside air at a temperature
--
-- The clock only ever moves forward: the minute and hour timers every trait
-- keeps read the world hours, and a clock going backwards would fool them.
-- The skipped hours are not simulated (nothing eats, heals or sleeps through
-- them); for that, use a faster game speed. Overrides set here are the admin
-- climate values the game's own admin panel sets, and stay on until released.

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}

local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function round(x, places)
    local m = 10 ^ (places or 0)
    return math.floor(x * m + 0.5) / m
end
local function lower(s) return string.lower(tostring(s or "")) end
local function squash(s) return (string.gsub(lower(s), "[%s_%-]", "")) end

-- Skills ---------------------------------------------------------------------------
-- every skill on the character screen: the perks with a parent category (the
-- categories themselves, Combat or Crafting, have Perks.None for a parent)
local function eachSkill(fn)
    local list = PerkFactory and PerkFactory.PerkList
    if not list then return end
    for i = 0, list:size() - 1 do
        local perk = list:get(i)
        if perk and perk:getParent() ~= Perks.None then fn(perk) end
    end
end

local function findSkill(word)
    local want = squash(word)
    local found = nil
    eachSkill(function(perk)
        if found then return end
        if squash(perk:getId()) == want or squash(perk:getName()) == want then found = perk end
    end)
    return found
end

local function setSkill(player, perk, level)
    player:setPerkLevelDebug(perk, level)
    pcall(function() player:getXp():setXPToLevel(perk, level) end)   -- the XP bar matches the level, as the debug panel does
    return player:getPerkLevel(perk)
end

DanTraits_ExtraCommands.skill = function(player, args)
    local which, level = args[1], tonumber(args[2])
    if not which then
        local parts = {}
        eachSkill(function(perk) parts[#parts + 1] = perk:getName() .. " " .. tostring(player:getPerkLevel(perk)) end)
        return "skills: " .. table.concat(parts, ", ")
    end
    if level == nil then return "skill <id|name|all> <0..10>" end
    level = clamp(math.floor(level), 0, 10)
    if lower(which) == "all" then
        local n = 0
        eachSkill(function(perk) setSkill(player, perk, level); n = n + 1 end)
        return "all " .. tostring(n) .. " skills set to " .. tostring(level)
    end
    local perk = findSkill(which)
    if not perk then return "skill: no skill called " .. tostring(which) end
    return perk:getName() .. " now " .. tostring(setSkill(player, perk, level))
end

-- Time -----------------------------------------------------------------------------
-- GameTime's own day rollover (advanceOneDay is private): day, month, year
local function advanceDay(gt)
    gt:setDay(gt:getDay() + 1)
    if gt:getDay() >= gt:daysInMonth(gt:getYear(), gt:getMonth()) then
        gt:setDay(0)
        gt:setMonth(gt:getMonth() + 1)
        if gt:getMonth() >= 12 then
            gt:setMonth(0)
            gt:setYear(gt:getYear() + 1)
        end
    end
end

-- forward by `hours`, as the game's update would have got there: a night is
-- counted when the clock passes 07:00 (getWorldAgeHours counts nights from
-- 07:00) and a day when it passes midnight
function DanTraits_JumpClock(hours)
    local gt = getGameTime()
    local t = gt:getTimeOfDay()
    local target = t + hours
    local nights, k = 0, 0
    while 7 + 24 * k < target do
        if 7 + 24 * k >= t then nights = nights + 1 end
        k = k + 1
    end
    local days = math.floor(target / 24)
    for _ = 1, days do advanceDay(gt) end
    gt:setTimeOfDay(target - days * 24)
    if nights > 0 then gt:setNightsSurvived(gt:getNightsSurvived() + nights) end
    return nights, days
end

local function two(n) n = math.floor(n); return (n < 10 and "0" or "") .. tostring(n) end
local function clockLine()
    local gt = getGameTime()
    local t = gt:getTimeOfDay()
    local h = math.floor(t)
    return string.format("%s:%s, day %d of month %d, %d nights, world hours %.1f", two(h), two((t - h) * 60),
        gt:getDay() + 1, gt:getMonth() + 1, gt:getNightsSurvived(), gt:getWorldAgeHours())
end

DanTraits_ExtraCommands.time = function(player, args)
    local word = args[1]
    if not word then return "time: " .. clockLine() end
    local hours
    if string.sub(word, 1, 1) == "+" then
        hours = tonumber(string.sub(word, 2))
        if not hours or hours <= 0 then return "time +<hours>" end
    else
        local colon = string.find(word, ":", 1, true)
        local h = tonumber(colon and string.sub(word, 1, colon - 1) or word)
        local m = colon and tonumber(string.sub(word, colon + 1)) or 0
        if not h or not m or h < 0 or h >= 24 or m < 0 or m >= 60 then return "time <H[:MM]> | time +<hours>" end
        local now = getGameTime():getTimeOfDay()
        hours = (h + m / 60) - now
        if hours <= 0 then hours = hours + 24 end   -- forward only: the next time the clock reads H:MM
    end
    hours = math.min(hours, 24 * 60)
    DanTraits_JumpClock(hours)
    return "time +" .. tostring(round(hours, 2)) .. " h: " .. clockLine()
end

local SPEEDS = { pause = 0, play = 1, normal = 1, fast = 2, faster = 3, wait = 4 }
local SPEED_NAMES = { [0] = "paused", "play", "fast forward", "faster forward", "wait" }
DanTraits_ExtraCommands.speed = function(player, args)
    local controls = UIManager and UIManager.getSpeedControls and UIManager.getSpeedControls()
    if not controls then return "speed: no speed controls" end
    local n = tonumber(args[1]) or SPEEDS[lower(args[1])]
    if n == nil then return "speed <0..4|pause|play|fast|faster|wait> (now " .. tostring(SPEED_NAMES[controls:getCurrentGameSpeed()]) .. ")" end
    n = clamp(math.floor(n), 0, 4)
    controls:SetCurrentGameSpeed(n)
    return "speed " .. tostring(SPEED_NAMES[n])
end

-- Weather --------------------------------------------------------------------------
local function cm() return getClimateManager() end
local function const(name, fallback) return (ClimateManager and ClimateManager[name]) or fallback end
local F = {
    temperature = const("FLOAT_TEMPERATURE", 4), precipitation = const("FLOAT_PRECIPITATION_INTENSITY", 3),
    fog = const("FLOAT_FOG_INTENSITY", 5), wind = const("FLOAT_WIND_INTENSITY", 6), clouds = const("FLOAT_CLOUD_INTENSITY", 8),
}
local SNOW = const("BOOL_IS_SNOW", 0)
local STAGES = { storm = 3, blizzard = 7, tropical = 8 }
local STAGE_NAMES = { [0] = "start", "showers", "heavy rain", "storm", "clearing", "moderate", "drizzle", "blizzard",
    "tropical storm", "lull", "modded", "kateBob storm" }

local function hold(which, value)
    local f = cm():getClimateFloat(F[which])
    f:setEnableAdmin(true)
    f:setAdminValue(value)
end
local function release(which) cm():getClimateFloat(F[which]):setEnableAdmin(false) end
local function holdSnow(on)
    local b = cm():getClimateBool(SNOW)
    if on == nil then b:setEnableAdmin(false) return end
    b:setEnableAdmin(true)
    b:setAdminValue(on)
end
local function releaseSky()
    for _, which in ipairs({ "precipitation", "fog", "wind", "clouds" }) do release(which) end
    holdSnow(nil)
end

-- what the companion shows: the sky, the clock, the speed, the overrides held
function DanTraits_WeatherReport()
    local c = cm()
    local out = {
        airTemp = c:getTemperature(), precip = c:getPrecipitationIntensity(), snow = c:getPrecipitationIsSnow(),
        fog = c:getFogIntensity(), clouds = c:getCloudIntensity(), windKph = c:getWindspeedKph(),
        humidity = c:getHumidity(), thunder = c:getIsThunderStorming(),
    }
    local held = {}
    for which, id in pairs(F) do
        local f = c:getClimateFloat(id)
        if f and f:isEnableAdmin() then
            local v = f:getAdminValue()
            if which == "wind" then v = v * c:getMaxWindspeedKph() end
            held[which] = round(v, 2)
        end
    end
    local b = c:getClimateBool(SNOW)
    if b and b:isEnableAdmin() then held.snow = b:getAdminValue() end
    out.held = held
    pcall(function()
        local period = c:getWeatherPeriod()
        if period and period:isRunning() then out.stage = STAGE_NAMES[period:getCurrentStageID()] or tostring(period:getCurrentStageID()) end
    end)
    return out
end

local function weatherLine()
    local r = DanTraits_WeatherReport()
    local held = {}
    for k, v in pairs(r.held) do held[#held + 1] = k .. " " .. tostring(v) end
    table.sort(held)
    return string.format("%.1f C, %s %.2f, fog %.2f, clouds %.2f, wind %.0f kph%s%s", r.airTemp, r.snow and "snow" or "rain", r.precip,
        r.fog, r.clouds, r.windKph, r.stage and (", " .. r.stage) or "", #held > 0 and ("; held: " .. table.concat(held, ", ")) or "")
end

DanTraits_ExtraCommands.weather = function(player, args)
    local what, n = lower(args[1]), tonumber(args[2])
    if what == "" then return "weather: " .. weatherLine() end
    if what == "clear" then
        releaseSky()
        cm():stopWeatherAndThunder()
    elseif STAGES[what] then
        releaseSky()
        cm():triggerCustomWeatherStage(STAGES[what], clamp(n or 12, 1, 240))
    elseif what == "rain" or what == "snow" then
        hold("precipitation", clamp(n or 0.6, 0, 1))
        holdSnow(what == "snow")
    elseif what == "fog" or what == "clouds" then
        hold(what, clamp(n or 0.8, 0, 1))
    elseif what == "wind" then
        local max = cm():getMaxWindspeedKph()
        hold("wind", clamp((n or 60) / max, 0, 1))
    elseif what == "natural" then
        releaseSky()
        release("temperature")
    else
        return "weather clear | storm [h] | tropical [h] | blizzard [h] | rain <0..1> | snow <0..1> | fog <0..1> | clouds <0..1> | wind <kph> | natural"
    end
    return "weather " .. what .. ": " .. weatherLine()
end

DanTraits_ExtraCommands.temp = function(player, args)
    local word = lower(args[1])
    if word == "natural" or word == "off" then
        release("temperature")
        return "air temperature back to the weather's: " .. weatherLine()
    end
    local c = tonumber(args[1])
    if not c then return "temp <C> | temp natural (now " .. tostring(round(cm():getTemperature(), 1)) .. " C)" end
    hold("temperature", clamp(c, -50, 60))
    return "air held at " .. tostring(clamp(c, -50, 60)) .. " C"
end

-- Telemetry ------------------------------------------------------------------------
-- skills by category, the clock, the speed and the weather; DanTraits_Telemetry
-- puts it in the snapshot as `world`
function DanTraits_WorldSnapshot(player)
    local out = {}
    pcall(function()
        local skills = {}
        eachSkill(function(perk)
            skills[#skills + 1] = { id = perk:getId(), name = perk:getName(), cat = perk:getParent():getName(), level = player:getPerkLevel(perk) }
        end)
        out.skills = skills
    end)
    pcall(function()
        local gt = getGameTime()
        out.clock = { timeOfDay = gt:getTimeOfDay(), day = gt:getDay() + 1, month = gt:getMonth() + 1, year = gt:getYear(),
            nights = gt:getNightsSurvived(), worldHours = gt:getWorldAgeHours() }
    end)
    pcall(function() out.speed = UIManager.getSpeedControls():getCurrentGameSpeed() end)
    pcall(function() out.weather = DanTraits_WeatherReport() end)
    return out
end
