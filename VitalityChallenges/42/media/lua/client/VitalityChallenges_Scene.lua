-- Vitality Challenges: what a challenge's scene and character setup are made
-- of. Every call is guarded on its own, so one missing square or a method a
-- build renamed costs that one piece, not the rest of the scene.
--
--   VC.dir(name)              "N" .. "SW" -> dx, dy, IsoDirections value
--   VC.ahead(x, y, dir, n, lane)  the tile n along dir from x, y, lane tiles to its side
--   VC.vehicle(script, x, y, z, dir)  a car facing dir; nil if the square is not loaded
--   VC.wreck(vehicle, opts)   every part battered (opts.min..max), storage left whole
--                             (a battered TruckBed holds nothing), opts.engine, opts.fuel {lo, hi}
--   VC.load(vehicle, items)   items into the trunk (glove box if there is none);
--                             an entry is a type, or { type, water = litres }
--   VC.bodies(x1, y1, x2, y2, z, n)   corpses with blood, at random in the box
--   VC.zombies(x1, y1, x2, y2, z, n)
--   VC.side(part)             "LowerLeg" -> "LowerLeg_L" or "LowerLeg_R"
--   VC.fracture(player, part, severity, pain)   broken, not splinted
--   VC.cut(player, part, damage)
--   VC.stats(player, { FATIGUE = 0.75, ... })   CharacterStat names
--   VC.setTime(hour)          VC.weather(stage, hours)  ("storm", "tropical", ...)

VitalityChallenges = VitalityChallenges or {}
local VC = VitalityChallenges

local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

-- places --------------------------------------------------------------------------

local DIRS = {
    N  = { 0, -1 }, S  = { 0, 1 },  E  = { 1, 0 },  W  = { -1, 0 },
    NE = { 1, -1 }, NW = { -1, -1 }, SE = { 1, 1 }, SW = { -1, 1 },
}

function VC.dir(name)
    local d = DIRS[name] or DIRS.N
    return d[1], d[2], IsoDirections[name] or IsoDirections.N
end

function VC.ahead(x, y, dir, n, lane)
    local dx, dy = VC.dir(dir)
    lane = lane or 0
    -- the lane offset is perpendicular to the road
    return x + dx * n - dy * lane, y + dy * n + dx * lane
end

-- vehicles ------------------------------------------------------------------------

function VC.vehicle(script, x, y, z, dir)
    local sq = getCell():getGridSquare(x, y, z or 0)
    if not sq then return nil end
    local _, _, facing = VC.dir(dir)
    -- addVehicleDebug(script, facing, nil, square) is how the game's own
    -- scenarios place a car facing a way; despite the name it is not debug-only
    local v = try(function() return addVehicleDebug(script, facing, nil, sq) end)
    if v then return v end
    v = try(function() return addVehicle(script, x, y, z or 0) end)
    if v then try(function() v:setDir(facing) end) end
    return v
end

-- trunk capacity scales with the TruckBed part's condition, so storage stays whole
local STORAGE_PARTS = { TruckBed = true, TrunkDoor = true, GloveBox = true }

local function setPart(vehicle, id, condition)
    local vp = vehicle:getPartById(id)
    if vp then try(function() vp:setCondition(condition) end) end
end

function VC.wreck(vehicle, opts)
    if not vehicle then return end
    opts = opts or {}
    local lo, hi = opts.min or 5, opts.max or 25
    try(function()
        for i = 0, vehicle:getPartCount() - 1 do
            local vp = vehicle:getPartByIndex(i)
            local id = vp and vp:getId()
            if id and not STORAGE_PARTS[id] then
                try(function() vp:setCondition(ZombRand(lo, hi + 1)) end)
            end
        end
    end)
    for id in pairs(STORAGE_PARTS) do setPart(vehicle, id, 100) end
    if opts.engine then setPart(vehicle, "Engine", opts.engine) end
    if opts.fuel then
        local tank = vehicle:getPartById("GasTank")
        if tank then try(function() tank:setContainerContentAmount(ZombRand(opts.fuel[1], opts.fuel[2] + 1)) end) end
    end
    try(function() vehicle:setHeadlightsOn(false) end)
    if opts.locked ~= nil then try(function() vehicle:setLocked(opts.locked) end) end
end

local function trunkOf(vehicle)
    for _, id in ipairs({ "TruckBed", "TrunkDoor", "GloveBox" }) do
        local vp = vehicle:getPartById(id)
        local container = vp and vp:getItemContainer()
        if container then return container end
    end
    return nil
end

function VC.load(vehicle, items)
    if not vehicle then return 0 end
    local container = try(trunkOf, vehicle)
    if not container then return 0 end
    local added = 0
    for _, entry in ipairs(items) do
        local itemType = type(entry) == "table" and entry[1] or entry
        local item = try(function() return container:AddItem(itemType) end)
        if item then
            added = added + 1
            if type(entry) == "table" and entry.water then
                try(function() item:getFluidContainer():addFluid(Fluid.Water, entry.water) end)
            end
        end
    end
    return added
end

-- the dead ----------------------------------------------------------------------------

function VC.bodies(x1, y1, x2, y2, z, n)
    for _ = 1, n or 0 do
        local sq = getCell():getGridSquare(ZombRand(x1, x2 + 1), ZombRand(y1, y2 + 1), z or 0)
        if sq then
            try(function()
                createRandomDeadBody(sq, 10)
                addBloodSplat(sq, 15)
            end)
        end
    end
end

function VC.zombies(x1, y1, x2, y2, z, n)
    if (n or 0) <= 0 then return end
    try(function() addZombiesInOutfitArea(x1, y1, x2, y2, z or 0, n, nil, nil) end)
end

-- the character -------------------------------------------------------------------

function VC.side(part)
    return part .. (ZombRand(2) == 0 and "_L" or "_R")
end

local function bodyPart(player, part)
    return try(function() return player:getBodyDamage():getBodyPart(BodyPartType[part]) end)
end

function VC.fracture(player, part, severity, pain)
    local bp = bodyPart(player, part)
    if not bp then return false end
    try(function() bp:setFractureTime(severity or 30) end)
    try(function() bp:setSplint(false, 0) end)
    if pain then try(function() bp:setAdditionalPain(pain) end) end
    return true
end

function VC.cut(player, part, damage)
    local bp = bodyPart(player, part)
    if not bp then return false end
    try(function() bp:setCut(true, false) end)   -- false: a cut with no Knox roll (setCut(b) alone rolls 25%)
    if damage then try(function() bp:AddDamage(damage) end) end
    return true
end

function VC.stats(player, values)
    local stats = player:getStats()
    for name, value in pairs(values) do
        local stat = CharacterStat[name]
        if stat then try(function() stats:set(stat, value) end) end
    end
end

-- the world ---------------------------------------------------------------------

function VC.setTime(hour)
    getGameTime():setTimeOfDay(hour)
end

local STAGES = { storm = "STAGE_STORM", tropical = "STAGE_TROPICAL_STORM", blizzard = "STAGE_BLIZZARD",
                 rain = "STAGE_HEAVY_PRECIP", clear = "STAGE_CLEARING" }

function VC.weather(stage, hours)
    local key = STAGES[stage] or stage
    getClimateManager():triggerCustomWeatherStage(WeatherPeriod[key], hours or 6)
end
