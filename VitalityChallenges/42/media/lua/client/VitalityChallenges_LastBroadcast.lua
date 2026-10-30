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
-- radio counts days from the save's start), so every one of them is switched
-- off on load and on the hour: the only voice on the dial is yours (and the
-- emergency broadcast's).

require "VitalityChallenges_Core"
require "VitalityChallenges_Kit"
require "VitalityChallenges_Rules"
require "VitalityChallenges_Broadcast"
require "ISUI/Maps/ISMapDefinitions"
local VC = VitalityChallenges
local B = VC.broadcast

-- TESTING, off before release: the lowest zombie population, one dead in the
-- studio and none in the street, the studio stocked with a bit of everything,
-- and a step van near the start, as new, full tank, the same stock in the back,
-- its key in your pocket
local TEST = true
local TEST_VAN = { script = "Base.StepVan", x = 12287, y = 3803, dir = "S" }

local ID = "VC_LastBroadcast"
local START_X, START_Y = 12240, 3683            -- the hall of the lakeside house (rooms 12237-12244, 3680-3687)
local STATION = { x = 12482, y = 3912 }
local STUDIO_ROOM = "jackiejayestudio"
local BUILDING = { 12480, 3908, 12483, 3914 }          -- the studio, its office and bathroom
local YARD = { 12470, 3898, 12495, 3924 }              -- the street around it, for the crowd
local GEN_SEARCH = 8                                   -- tiles round the building to look for an outdoor spot
local DEAD_INSIDE = TEST and 1 or 3
local DEAD_YARD = TEST and 0 or 8
local GEN_FUEL = 30
local GEN_CONDITION = 70
local BEACON_EVERY = 5                                 -- game minutes between the station's sounds on air
local BEACON_RADIUS = { 20, 70 }                       -- from this, a tile more for each BEACON_PER listeners, to this
local BEACON_PER = 20
local MAP_ID = "VC_LastBroadcastMap"
local MAP_BOUNDS = { 11950, 3450, 12850, 4400 }
local USED = { 0.6, 0.8 }
local HOST_COLOUR = { 0.95, 0.85, 0.55 }

-- every vanilla channel in RadioData.xml: off, so the dial is quiet
local VANILLA = {
    B.CHANNEL,                                     -- LBMW - Kentucky Radio (ours while on air)
    "50fff513-f439-409f-b3f0-5f0ac62d6fb1",        -- NNR Radio
    "f259242a-38bf-4b4a-bab3-b389591fad35",        -- KnoxTalk Radio
    "4d59ad8e-dcde-49d9-a6c9-cf0e6beb0399",        -- Hitz FM
    "0aadc2e0-4612-4c0a-a3ad-1f1518e7d18d",        -- Triple-N
    "3c967105-cbc3-4907-bb49-26968d99e451",        -- WBLN News
    "9f7e57f1-461c-4600-a8a1-0f5d2ee27889",        -- Life and Living TV
    "502e5991-cb16-4513-b80b-07e048e32a36",        -- TURBO
    "56f6116d-83ff-41e3-b21f-9490646c6e01",        -- PawsTV
    "ea0dd044-cefa-4463-b06b-73f133c1ebaf",        -- Civilian Radio
    "d1915795-be10-4803-9ac2-81f38648779b",        -- Unknown Frequency
    "82017c87-54ef-4639-bc4e-bd067f3dc0c2",        -- Classified M1A1
    "4566107c-57e1-4f6d-90ba-b38c43c9b3ab",        -- KPATV
    "853f39a9-2e60-4109-961a-09b869ad51f5",        -- Music Video Channel
    "2441ecd2-646a-4458-8181-863ff732d9a0",        -- National Sports TV
    "791b1e9f-6bf7-4aa8-ac2c-5839bae5038f",        -- Brennan Movie Channel
    "b6b21405-ce1b-4f1a-8ec6-5ca5b506caf8",        -- GBC
    "6c8a38ce-0e53-46f5-9861-c44a25b46fc3",        -- USR
}

local FOOD = {
    { "Base.TunaTin" }, { "Base.CannedChili" }, { "Base.GranolaBar", count = 2 },
    { "Base.Crackers" }, { "Base.Peanuts" }, { "Base.TinOpener" },
}

-- the test stock: a bit of everything, spread over the studio's containers
local TEST_STOCK = {
    -- food and water
    { "Base.TinnedSoup", count = 4 }, { "Base.TinnedBeans", count = 4 }, { "Base.CannedBolognese", count = 3 },
    { "Base.CannedCorn", count = 3 }, { "Base.TunaTin", count = 3 }, { "Base.CannedChili", count = 3 },
    { "Base.Crackers", count = 2 }, { "Base.PeanutButter" }, { "Base.GranolaBar", count = 4 },
    { "Base.Pop", count = 4 }, { "Base.WaterBottle", count = 4, water = 1 }, { "Base.TinOpener" },
    -- medical
    { "Base.Bandage", count = 6 }, { "Base.AlcoholBandage", count = 2 }, { "Base.Disinfectant" },
    { "Base.AlcoholWipes" }, { "Base.Pills" }, { "Base.PillsBeta" }, { "Base.PillsVitamins" },
    { "Base.PillsAntiDep" }, { "Base.Antibiotics" }, { "Base.Splint", count = 2 },
    { "Base.SutureNeedle", count = 2 }, { "Base.SutureNeedleHolder" }, { "Base.Tweezers" },
    -- fuel and light
    { "Base.PetrolCan", count = 2 }, { "Base.Battery", count = 6 }, { "Base.HandTorch" },
    { "Base.Candle", count = 2 }, { "Base.Lighter" }, { "Base.Matches" },
    -- tools
    { "Base.Hammer" }, { "Base.NailsBox" }, { "Base.Saw" }, { "Base.Screwdriver" }, { "Base.Wrench" },
    { "Base.DuctTape" }, { "Base.Rope" }, { "Base.Plank", count = 6 }, { "Base.ElectronicsScrap", count = 4 },
    -- weapons
    { "Base.Axe" }, { "Base.Machete" }, { "Base.Crowbar" }, { "Base.BaseballBat" },
    { "Base.Shotgun" }, { "Base.ShotgunShellsBox", count = 2 },
    { "Base.Pistol" }, { "Base.9mmClip", count = 2 }, { "Base.Bullets9mmBox", count = 2 },
    -- carrying
    { "Base.Bag_DuffelBag" }, { "Base.Bag_ALICEpack" },
}

local LB = {}
VC.lastBroadcast = LB

local function challenge() return VC.challenges[ID] end

-- this challenge's saved table, when it is the one being played
function LB.state()
    local c = VC.current()
    if not c or c.id ~= ID then return nil end
    return VC.context(c).state
end

local function hour()
    local h = 0
    pcall(function() h = getGameTime():getHour() end)
    return h
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

local function silenceVanilla(state)
    local sm
    pcall(function() sm = getZomboidRadio():getScriptManager() end)
    if not sm then return end
    for _, uuid in ipairs(VANILLA) do
        if not (uuid == B.CHANNEL and state and state.onAir) then
            pcall(function()
                local ch = sm:getRadioChannel(uuid)
                if ch and ch:getCurrentScript() then ch:setActiveScriptNull() end
            end)
        end
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
    local h = hour()
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

-- the test stock, dealt out over the containers in the building (the floor by
-- the desk when there are none)
local function stock()
    local containers = {}
    for x = BUILDING[1], BUILDING[3] do
        for y = BUILDING[2], BUILDING[4] do
            pcall(function()
                local objects = getCell():getGridSquare(x, y, 0):getObjects()
                for j = 0, objects:size() - 1 do
                    local obj = objects:get(j)
                    for k = 0, obj:getContainerCount() - 1 do
                        containers[#containers + 1] = obj:getContainerByIndex(k)
                    end
                end
            end)
        end
    end
    local floor = getCell():getGridSquare(STATION.x, STATION.y, 0)
    for i, entry in ipairs(TEST_STOCK) do
        if #containers > 0 then
            VC.put(containers[(i - 1) % #containers + 1], entry)
        elseif floor then
            for _ = 1, entry.count or 1 do
                pcall(function()
                    local item = floor:AddWorldInventoryItem(entry[1], ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
                    if entry.water then item:getFluidContainer():addFluid(Fluid.Water, entry.water) end
                end)
            end
        end
    end
end

-- the test van, once its square has loaded
local function testVan(state, player)
    if state.vanReady or not getCell():getGridSquare(TEST_VAN.x, TEST_VAN.y, 0) then return end
    local van = VC.vehicle(TEST_VAN.script, TEST_VAN.x, TEST_VAN.y, 0, TEST_VAN.dir)
    if not van then return end
    state.vanReady = true
    pcall(function() van:repair() end)
    pcall(function()
        local tank = van:getPartById("GasTank")
        tank:setContainerContentAmount(tank:getContainerCapacity())
    end)
    pcall(function() van:setLocked(false) end)
    pcall(function() player:getInventory():AddItem(van:createVehicleKey()) end)
    local back
    pcall(function() back = van:getPartById("TruckBed"):getItemContainer() end)
    if back then
        for _, entry in ipairs(TEST_STOCK) do VC.put(back, entry) end
    end
end

local function studioLoaded()
    local cell = getCell()
    return cell and cell:getGridSquare(STATION.x, STATION.y, 0) ~= nil
        and cell:getGridSquare(YARD[1], YARD[2], 0) ~= nil and cell:getGridSquare(YARD[3], YARD[4], 0) ~= nil
end

local function setUpStudio(state)
    if state.studioReady or not studioLoaded() then return end
    state.studioReady = true
    VC.zombies(BUILDING[1], BUILDING[2], BUILDING[3], BUILDING[4], 0, DEAD_INSIDE)
    -- the street: north and south of the building, not on it
    VC.zombies(YARD[1], YARD[2], YARD[3], BUILDING[2] - 3, 0, math.ceil(DEAD_YARD / 2))
    VC.zombies(YARD[1], BUILDING[4] + 3, YARD[3], YARD[4], 0, math.floor(DEAD_YARD / 2))
    generator()
    pcall(function()
        getCell():getGridSquare(STATION.x, STATION.y, 0):AddWorldInventoryItem("Base.Microphone", 0.5, 0.5, 0)
    end)
    if TEST then stock() end
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

LootMaps.Init[MAP_ID] = function(mapUI)
    local mapAPI = mapUI.javaObject:getAPIv1()
    MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
    MapUtils.initDefaultStyleV3(mapUI)
    mapAPI:setBoundsInSquares(MAP_BOUNDS[1], MAP_BOUNDS[2], MAP_BOUNDS[3], MAP_BOUNDS[4])
    MapUtils.overlayPaper(mapUI)
    VC.stampMap(mapUI, "Circle", STATION.x, STATION.y, VC.MAP_RED)
end

local function used(item) VC.condition(item, USED[1] + (USED[2] - USED[1]) * ZombRandFloat(0, 1)) end

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
    -- a weapon from home by profession (Nomad's table), the second one in the bag
    local main, belt = "Base.BaseballBat", "Base.KitchenKnife"
    if VC.nomadWeapons then
        local w = VC.nomadWeapons(player)
        main, belt = w.main, w.belt
    end
    local held = VC.put(inv, main)
    used(held)
    VC.hold(player, held)
    used(VC.put(bag, belt))
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
        if TEST then
            t.Zombies = 5                   -- Low, the thinnest crowd short of none
            t.ZombieConfig = {
                PopulationMultiplier = ZombiePopulationMultiplier and ZombiePopulationMultiplier.Low or "0.15",
                PopulationStartMultiplier = 0.5,
                PopulationPeakMultiplier = 0.5,
            }
        end
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
        if TEST then testVan(state, player) end
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
        if not state.lbStarted or hour() ~= B.SETTLE_HOUR then return end
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

LB.STATION, LB.STUDIO_ROOM, LB.MAP_ID, LB.VANILLA, LB.TEST = STATION, STUDIO_ROOM, MAP_ID, VANILLA, TEST   -- tests
