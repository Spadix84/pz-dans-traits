-- The Last Broadcast (plans/last-broadcast.md): day 14, the dial has been
-- static for days. You start in a small house by the lake on the south side of
-- Louisville (12240, 3683). A few hundred metres east is Jackie Jaye's studio,
-- the LBMW reporter's (12480-12483, 3908-3914): put LBMW back on the air, on
-- its own 93.2, at six every evening, for thirty shows. More than two days
-- between shows fails the challenge; the game carries on. One life. Power and
-- water are off from the start.
--
-- The studio is earned: when it first loads, its dead are inside and more are
-- in the street, drawn by the last broadcast; a generator stands outside,
-- connected, a third full. Going on air needs the studio room, power, and the
-- hour (VitalityChallenges_OnAir.lua); the score is
-- VitalityChallenges_Broadcast.lua. While on air the station is loud: a sound
-- every few minutes, carrying further the more people listen.
--
-- Vanilla's own stations would still be on their first day's scripts (the
-- radio counts days from the save's start), so every channel the radio knows
-- is switched off on load and on the hour: the only voice on the dial is yours
-- (and the emergency broadcast's).

require "VitalityChallenges_Core"
require "VitalityChallenges_Kit"
require "VitalityChallenges_Rules"
require "VitalityChallenges_Broadcast"
local VC = VitalityChallenges
local B = VC.broadcast

local ID = "VC_LastBroadcast"
local START_X, START_Y = 12240, 3683            -- the hall of the lakeside house (rooms 12237-12244, 3680-3687)
local STATION = { x = 12482, y = 3912 }
local STUDIO_ROOM = "jackiejayestudio"
local BUILDING = { 12480, 3908, 12483, 3914 }          -- the studio, its office and bathroom
local YARD = { 12470, 3898, 12495, 3924 }              -- the street around it, for the crowd
local GEN_SEARCH = 8                                   -- tiles round the building to look for an outdoor spot
local DEAD_INSIDE = 3
local DEAD_YARD = 8
local GEN_FUEL = 30
local GEN_CONDITION = 70
local BEACON_EVERY = 5                                 -- game minutes between the station's sounds on air
local BEACON_RADIUS = { 20, 70 }                       -- from this, a tile more for each BEACON_PER listeners, to this
local BEACON_PER = 20
local MAP_ID = "VC_LastBroadcastMap"
local MAP_BOUNDS = { 11950, 3450, 12850, 4400 }
local HOST_COLOUR = { 0.95, 0.85, 0.55 }

local FOOD = {
    { "Base.TunaTin" }, { "Base.CannedChili" }, { "Base.GranolaBar", count = 2 },
    { "Base.Crackers" }, { "Base.Peanuts" }, { "Base.TinOpener" },
}

local LB = {}
VC.lastBroadcast = LB

local function challenge() return VC.challenges[ID] end

-- the test scaffolding (VitalityChallenges_Dev.lua): nothing without the file
local function dev(name, ...)
    local fn = VC.dev and VC.dev[name]
    if fn then return fn(...) end
    return nil
end
function LB.testing() return VC.dev ~= nil end

-- this challenge's saved table, when it is the one being played
function LB.state()
    local c = VC.current()
    if not c or c.id ~= ID then return nil end
    return VC.context(c).state
end

local function today() return B.dayKey(getGameTime()) end

local function halo(player, key, good, ...)
    local s = getText(key, ...)
    pcall(function()
        if good then HaloTextHelper.addGoodText(player, s) else HaloTextHelper.addBadText(player, s) end
    end)
end

local function roomName(sq)
    local name
    pcall(function()
        local room = sq and sq:getRoom()
        name = room and room:getName()
    end)
    return name
end

function LB.inStudio(player)
    return LB.state() ~= nil and roomName(player:getCurrentSquare()) == STUDIO_ROOM
end

local function powered(sq)
    local on = false
    pcall(function() on = sq:haveElectricity() or sq:hasGridPower() end)
    return on
end

local function channel()
    return DynamicRadio and DynamicRadio.cache and DynamicRadio.cache[B.CHANNEL]
end

-- the radio ------------------------------------------------------------------------------

-- every channel the radio script manager knows (RadioData.xml and any mod's),
-- so a station a game update adds cannot leak onto the dial
local function dial()
    local out = {}
    pcall(function()
        local list = getZomboidRadio():getScriptManager():getChannelsList()
        for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    end)
    return out
end

-- their uuids, for the tests
function LB.channels()
    local out = {}
    for _, ch in ipairs(dial()) do pcall(function() out[#out + 1] = ch:getGUID() end) end
    return out
end

-- every channel off, ours too unless it is on air, so the dial is quiet
local function silenceVanilla(state)
    for _, ch in ipairs(dial()) do
        pcall(function()
            if ch:getGUID() == B.CHANNEL and state and state.onAir then return end
            if ch:getCurrentScript() then ch:setActiveScriptNull() end
        end)
    end
end

local function airText(s, colour)
    local ch = channel()
    if not ch then return false end
    local ok = pcall(function()
        local bc = RadioBroadCast.new("VCLB-" .. tostring(ZombRand(100000, 999999)), -1, -1)
        bc:AddRadioLine(RadioLine.new(s, colour[1], colour[2], colour[3]))
        -- a vanilla script that started on the channel since the hour's silencing goes before the line
        pcall(function() if ch:getCurrentScript() then ch:setActiveScriptNull() end end)
        ch:setAiringBroadcast(bc)
    end)
    return ok
end

-- why the character cannot go on air now (a translation key), or nil
function LB.blocked(player)
    local state = LB.state()
    if not state then return "IGUI_VC_LB_NotHere" end
    if state.onAir then return "IGUI_VC_LB_OnAirNow" end
    local sq = player:getCurrentSquare()
    if roomName(sq) ~= STUDIO_ROOM then return "IGUI_VC_LB_NotStudio" end
    if state.lastShowKey == today() then return "IGUI_VC_LB_DoneTonight" end
    local h = VC.hour()
    if h < B.SLOT_HOUR or h >= B.SLOT_END then return "IGUI_VC_LB_NotTime" end
    if not powered(sq) then return "IGUI_VC_LB_NoPower" end
    if not channel() then return "IGUI_VC_LB_NoSignal" end
    return nil
end

-- still able to carry on with a show already started: in the studio, with power
function LB.canCarryOn(player)
    local sq = player:getCurrentSquare()
    return roomName(sq) == STUDIO_ROOM and powered(sq)
end

local function clock()
    local gt = getGameTime()
    local h, m = gt:getHour(), gt:getMinutes()
    local h12 = h % 12
    if h12 == 0 then h12 = 12 end
    return string.format("%d:%02d", h12, m)
end

function LB.beginShow(player, order)
    local state = LB.state()
    if not state then return {} end
    state.onAir = true
    state.showKey = today()
    local forecast
    pcall(function() forecast = getClimateManager():getClimateForecaster():getForecast(1) end)
    return B.lines(state, order, state.showKey, { station = STATION, clock = clock(), forecast = forecast })
end

function LB.airLine(player, line)
    airText(line.text, HOST_COLOUR)
    if line.host then pcall(function() player:Say(line.text) end) end
end

local function summaryText(state, player)
    local c = challenge()
    local s = VC.summary(VC.context(c), player)
    return getText("IGUI_VC_LB_Summary", tostring(state.shows or 0), tostring(state.missed or 0), tostring(state.peak or 0))
        .. " <LINE> " .. getText("IGUI_VC_SummaryKills", tostring(s.kills), s.profession), s
end

local function finish(state, player, result)
    local text, s = summaryText(state, player)
    VC.record(ID, result, s)
    local title = result == "won" and "IGUI_VC_LastBroadcast_Won" or "IGUI_VC_LastBroadcast_Failed"
    VC.dialog(getText(title) .. " <LINE> <LINE> " .. text)
end

function LB.endShow(player, order, complete)
    local state = LB.state()
    if not state or not state.onAir then return end
    state.onAir = false
    if not complete then
        airText(getText("IGUI_VC_LB_Static"), HOST_COLOUR)
        halo(player, "IGUI_VC_LB_Cut", false)
        return
    end
    B.aired(state, order, state.showKey)
    halo(player, "IGUI_VC_LB_OffAir", true, tostring(state.listeners))
    if B.wonNow(state) then finish(state, player, "won") end
end

-- the studio, the first time it loads ------------------------------------------------------

local function outdoorSpot()
    local best, bestD
    for x = BUILDING[1] - GEN_SEARCH, BUILDING[3] + GEN_SEARCH do
        for y = BUILDING[2] - GEN_SEARCH, BUILDING[4] + GEN_SEARCH do
            local sq = getCell():getGridSquare(x, y, 0)
            local free = false
            pcall(function() free = sq and not sq:getRoom() and sq:getFloor() ~= nil and sq:isFree(false) end)
            if free then
                local d = math.abs(x - STATION.x) + math.abs(y - STATION.y)
                if not bestD or d < bestD then best, bestD = sq, d end
            end
        end
    end
    return best
end

local function generator()
    local sq = outdoorSpot()
    if not sq then return false end
    return pcall(function()
        local gen = IsoGenerator.new(instanceItem("Base.Generator"), getCell(), sq)
        gen:setConnected(true)
        gen:setFuel(GEN_FUEL)
        gen:setCondition(GEN_CONDITION)
    end)
end

local function studioLoaded()
    local cell = getCell()
    return cell and cell:getGridSquare(STATION.x, STATION.y, 0) ~= nil
        and cell:getGridSquare(YARD[1], YARD[2], 0) ~= nil and cell:getGridSquare(YARD[3], YARD[4], 0) ~= nil
end

local function setUpStudio(state)
    if state.studioReady or not studioLoaded() then return end
    state.studioReady = true
    local inside, yard = dev("dead", DEAD_INSIDE, DEAD_YARD)
    inside, yard = inside or DEAD_INSIDE, yard or DEAD_YARD
    VC.zombies(BUILDING[1], BUILDING[2], BUILDING[3], BUILDING[4], 0, inside)
    -- the street: north and south of the building, not on it
    VC.zombies(YARD[1], YARD[2], YARD[3], BUILDING[2] - 3, 0, math.ceil(yard / 2))
    VC.zombies(YARD[1], BUILDING[4] + 3, YARD[3], YARD[4], 0, math.floor(yard / 2))
    generator()
    pcall(function()
        getCell():getGridSquare(STATION.x, STATION.y, 0):AddWorldInventoryItem("Base.Microphone", 0.5, 0.5, 0)
    end)
    dev("stock", BUILDING, getCell():getGridSquare(STATION.x, STATION.y, 0))
end

-- places you have been --------------------------------------------------------------------

local function stockIn(room)
    local n = 0
    pcall(function()
        local squares = room:getSquares()
        for i = 0, squares:size() - 1 do
            local objects = squares:get(i):getObjects()
            for j = 0, objects:size() - 1 do
                local obj = objects:get(j)
                for k = 0, obj:getContainerCount() - 1 do
                    n = n + obj:getContainerByIndex(k):getItems():size()
                end
            end
        end
    end)
    return n
end

local function lookAround(state, player)
    pcall(function()
        local room = player:getCurrentSquare():getRoom()
        if not room then return end
        local name = room:getName()
        if not B.PLACES[name] then return end
        local def = room:getRoomDef()
        local key = def:getX() .. "," .. def:getY() .. "," .. def:getZ()
        for _, p in ipairs(state.places or {}) do
            if p.key == key then return end
        end
        B.visit(state, key, name, def:getX(), def:getY(), stockIn(room) >= B.STOCKED_AT)
    end)
end

-- the kit ------------------------------------------------------------------------------------

VC.paperMap(MAP_ID, MAP_BOUNDS, { { x = STATION.x, y = STATION.y } })   -- the studio circled

local function kit(player)
    local inv = player:getInventory()
    local bag = VC.containerOf(VC.wear(player, "Base.Bag_Schoolbag")) or inv
    for _, entry in ipairs(FOOD) do VC.put(bag, entry) end
    VC.put(bag, { "Base.WaterBottle", water = 1 })
    VC.put(bag, "Base.HandTorch")
    local radio = VC.put(bag, "Base.RadioRed")
    pcall(function() radio:getDeviceData():setChannel(93200) end)
    local map = VC.put(bag, "Base.Map")
    pcall(function()
        map:setMapID(MAP_ID)
        map:setName(getText("IGUI_VC_LB_Map"))
        map:setCustomName(true)
    end)
    -- a weapon from home by profession, the second one in the bag
    local w = VC.weaponsFor(player)
    local held = VC.put(inv, w.main)
    VC.used(held)
    VC.hold(player, held)
    VC.used(VC.put(bag, w.belt))
end

-- the challenge --------------------------------------------------------------------------------

local function settle(state, player)
    local result = B.settle(state, today())
    if result == "missed" then
        halo(player, "IGUI_VC_LB_Missed", false)
    elseif result == "failed" then
        halo(player, "IGUI_VC_LB_Missed", false)
        finish(state, player, "failed")
    end
end

VC.define({
    id = ID,
    mode = "LastBroadcast",
    world = "Muldraugh, KY",
    x = START_X, y = START_Y, z = 0,
    image = "media/lua/client/Challenge/28_minutes_later.png",   -- placeholder art
    video = "28_minutes_later.bik",
    everyCharacter = false,
    oneLife = true,

    sandbox = function()
        local t = {
            StartMonth = 7, StartDay = 23,          -- two weeks after the 9th of July
            WaterShutModifier = -1, ElecShutModifier = -1,
            TimeSinceApo = 1,
        }
        if SandboxVars and SandboxVars.DanTraits then t.DanTraits = { StartingMedication = true } end
        dev("population", t)
        return t
    end,

    start = { hour = 8 },

    player = function(player)
        kit(player)
    end,

    firstMinute = function(ctx)
        B.init(ctx.state, today())
        VC.dialog(getText("IGUI_VC_LB_Start"))
    end,

    everyMinute = function(ctx)
        local state = ctx.state
        if not state.lbStarted then return end
        local player = getSpecificPlayer(0)
        if not player or player:isDead() then return end
        setUpStudio(state)
        dev("spawnVan", state, player)
        lookAround(state, player)
        if state.onAir then
            state.beaconTick = ((state.beaconTick or 0) + 1) % BEACON_EVERY
            if state.beaconTick == 0 then
                local r = math.min(BEACON_RADIUS[2], BEACON_RADIUS[1] + math.floor((state.listeners or 0) / BEACON_PER))
                pcall(function() addSound(player, STATION.x, STATION.y, 0, r, r) end)
            end
        end
    end,

    everyHour = function(ctx)
        local state = ctx.state
        silenceVanilla(state)
        if not state.lbStarted or VC.hour() ~= B.SETTLE_HOUR then return end
        local player = getSpecificPlayer(0)
        if player and not player:isDead() then settle(state, player) end
    end,
})

-- every load: a show cannot be mid-air in a fresh session, and the dial goes quiet
Events.OnGameStart.Add(function()
    local state = LB.state()
    if not state then return end
    state.onAir = false
    silenceVanilla(state)
end)

LB.STATION, LB.STUDIO_ROOM, LB.MAP_ID = STATION, STUDIO_ROOM, MAP_ID   -- tests
