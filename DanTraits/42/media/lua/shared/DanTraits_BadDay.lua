-- Project Zomboid Vitality Project: A Really Bad Day.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- A Really Bad Day ----------------------------------------------------------
-- The CDDA challenge's opening, as a trait: drunk, sick, an infected
-- laceration on the left forearm and, if you start indoors, the house on
-- fire. Each part is applied exactly once, tracked in mod data so reloads
-- and respawns are safe.
--
-- What the opening costs under the health overhaul (blood, infection, wound
-- care, hangover, the alcoholism meter): the laceration is a cut on a plain
-- bleed site (x1.0) that is already infected at BAD_DAY_INFECTION, the
-- local stage (it does not heal, and spreads into the body at 5, about a day
-- and a half untreated); disinfectant pushes it back, antibiotics always do.
-- Intoxication 100 is a full Drunk 4: a pain floor of 80, a maximum hangover
-- armed for when it wears off, and the day's alcoholism cap fed; a cold at
-- strength 50 rides on top. Hemophilia and Bad Day are mutually exclusive
-- (scripts/DanTraits.txt).
--
-- BALANCE PENDING (README, Status and known issues). Until 2026-10-07 the
-- wound was a glass shard in the groin (generateDeepShardWound); played
-- 2026-09-30 it bled 1.6% a minute and killed even a plain character
-- without stitching supplies. The user swapped it for the infected
-- laceration and cut the trait from 12 points to 8 "so it's at least
-- survivable", until proper balance is worked out. Replay the opening
-- without a new character with the console command `badday` (`badday fire`
-- also relights the house): DanTraits_BadDayReplay.
-- Disinfectant and a bandage wait in a nearby house (below).
local function badDayFresh(player)
    if not player or not hasTrait(player, "badday") then return nil end
    if player:getHoursSurvived() > 0 then return nil end
    return traitData(player)
end

local BAD_DAY_PART      = "ForeArm_L"
local BAD_DAY_INFECTION = 2      -- the wound's infection level (Infection.lua: 2 stops healing, 5 spreads)

-- the infected laceration
local function badDayWound(player, bd)
    local part = bd:getBodyPart(BodyPartType[BAD_DAY_PART])
    if not part then return end
    pcall(function() part:setCut(true) end)
    if DanTraits_InfectWound then
        DanTraits_InfectWound(player, part, BAD_DAY_INFECTION)
    else
        pcall(function()
            part:setInfectedWound(true)
            part:setWoundInfectionLevel(BAD_DAY_INFECTION)
        end)
    end
end

-- the body of the opening: drunk, sick, the laceration, no clothes and soaking wet
local function applyBadDay(player)
    local stats = player:getStats()
    pcall(function() stats:set(CharacterStat.INTOXICATION, 100) end)

    local bd = player:getBodyDamage()
    pcall(function()
        bd:setCatchACold(0.0)
        bd:setHasACold(true)
        bd:setColdStrength(50.0)
        bd:setTimeToSneezeOrCough(0)
    end)

    badDayWound(player, bd)

    -- Straight out of the shower: nothing on, and soaked. Worn clothes are
    -- removed from the inventory too, not just unequipped, so there is
    -- nothing to put back on. The rest of the inventory is left alone.
    pcall(function()
        local worn = player:getWornItems()
        local inv = player:getInventory()
        for i = worn:size() - 1, 0, -1 do
            local item = worn:getItemByIndex(i)
            if item then
                player:removeWornItem(item)
                inv:Remove(item)
            end
        end
    end)
    pcall(function() player:clearWornItems() end)
    pcall(function()
        local wet = CharacterStat.WETNESS:getMaximumValue()
        stats:set(CharacterStat.WETNESS, wet)
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            parts:get(i):setWetness(wet)
        end
    end)
end

local function onBadDayCreatePlayer(playerNum, player)
    local d = badDayFresh(player)
    if not d or d.badDayApplied then return end
    d.badDayApplied = true
    applyBadDay(player)
end

-- Pick where the fire starts: another room, never the kitchen or garage,
-- and always at least BAD_DAY_FIRE_DISTANCE tiles from the player. Falls
-- back to the farthest square of the player's own room, and gives up if
-- even that is too close (a one-room shack).
local BAD_DAY_FIRE_DISTANCE = 6

local function badDayFireSquare(player, building, playerRoom)
    local px, py = player:getX(), player:getY()
    local function dist(sq)
        return math.abs(sq:getX() - px) + math.abs(sq:getY() - py)
    end

    local badRooms = ArrayList.new()
    badRooms:add("kitchen")
    badRooms:add("garage")
    if playerRoom then
        pcall(function() badRooms:add(playerRoom:getName()) end)
    end

    for _ = 1, 10 do
        local room = building:getRandomRoomExcluding(badRooms)
        local sq = room and room:getRandomSquare()
        if sq and dist(sq) >= BAD_DAY_FIRE_DISTANCE then
            return sq
        end
    end

    -- Fallback: farthest square in the player's own room.
    local best, bestDist = nil, 0
    if playerRoom then
        pcall(function()
            local squares = playerRoom:getSquares()
            for i = 0, squares:size() - 1 do
                local sq = squares:get(i)
                local d = sq and dist(sq) or 0
                if d > bestDist then best, bestDist = sq, d end
            end
        end)
    end
    if best and bestDist >= BAD_DAY_FIRE_DISTANCE then
        return best
    end
    return nil
end

-- light the fire; returns true if one was lit
local function startBadDayFire(player)
    local square = player:getCurrentSquare()
    local room = square and square:getRoom()
    local building = room and room:getBuilding()
    if not building then return false end   -- outdoors: no house to burn

    local tile = badDayFireSquare(player, building, room)
    if not tile then return false end       -- nowhere far enough away: no fire

    pcall(function() IsoFireManager.explode(getCell(), tile, 100000) end)
    notify(player, "UI_DanTraits_BadDayFire")
    return true
end

-- The way out: disinfectant and a bandage in a drawer or cupboard of another
-- house nearby, so the laceration can be cleaned and dressed if you go
-- looking (it was a needle and thread for the old glass shard; a cut can't
-- be stitched). No notice in the game; the trait's description says there
-- is one. Picked once, from the containers 15 to 40 tiles away in buildings
-- other than your own (then out to 60, then your own house's far rooms);
-- kitchen appliances, bins and the like are skipped. Put back if the game
-- fills that container with loot afterwards.
local BAD_DAY_KIT_ITEMS = { "Base.Disinfectant", "Base.Bandage" }
local BAD_DAY_KIT_NEAR, BAD_DAY_KIT_FAR, BAD_DAY_KIT_FARTHEST = 15, 40, 60
local BAD_DAY_KIT_SKIP = { fridge = true, freezer = true, stove = true, microwave = true, oven = true,
    bin = true, toilet = true, clothingwasher = true, clothingdryer = true, barbecue = true,
    fireplace = true, woodstove = true, vendingsnack = true, vendingpop = true, corpse = true }

local function roomBuilding(sq)
    local b = nil
    pcall(function() local r = sq:getRoom(); b = r and r:getBuilding() end)
    return b
end

-- every container on a square that could hold a sewing kit
local function kitContainers(sq, out)
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            local n = obj and obj.getContainerCount and obj:getContainerCount() or 0
            for c = 0, n - 1 do
                local cont = obj:getContainerByIndex(c)
                local kind = cont and cont:getType()
                if kind and not BAD_DAY_KIT_SKIP[string.lower(kind)] then out[#out + 1] = cont end
            end
        end
    end)
end

-- the containers around the player, sorted into other houses and their own
local function kitCandidates(player)
    local px, py = math.floor(player:getX()), math.floor(player:getY())
    local own = roomBuilding(player:getCurrentSquare())
    local near, far, home = {}, {}, {}
    local cell = getCell()
    for z = 0, 2 do
        for x = px - BAD_DAY_KIT_FARTHEST, px + BAD_DAY_KIT_FARTHEST do
            for y = py - BAD_DAY_KIT_FARTHEST, py + BAD_DAY_KIT_FARTHEST do
                local dist = math.max(math.abs(x - px), math.abs(y - py))
                local sq = nil
                pcall(function() sq = cell:getGridSquare(x, y, z) end)
                local building = sq and roomBuilding(sq)
                if building then
                    if own and building == own then
                        if dist >= BAD_DAY_FIRE_DISTANCE then kitContainers(sq, home) end
                    elseif dist >= BAD_DAY_KIT_NEAR then
                        kitContainers(sq, dist <= BAD_DAY_KIT_FAR and near or far)
                    end
                end
            end
        end
    end
    return near, far, home
end

local function hasItem(cont, fullType)
    local found = false
    local short = (string.gsub(fullType, "^Base%.", ""))
    pcall(function() found = cont:containsType(short) == true end)
    return found
end

local function stockKit(cont)
    for _, fullType in ipairs(BAD_DAY_KIT_ITEMS) do
        if not hasItem(cont, fullType) then
            pcall(function() cont:AddItem(fullType) end)
        end
    end
end

local function containerSpot(cont)
    local spot = nil
    pcall(function()
        local sq = cont:getParent():getSquare()
        spot = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), kind = cont:getType() }
    end)
    return spot
end

-- place the kit; returns the spot (x, y, z, container type) or nil
function DanTraits_BadDayPlaceKit(player)
    local near, far, home = kitCandidates(player)
    local pool = (#near > 0 and near) or (#far > 0 and far) or home
    if #pool == 0 then return nil end
    local cont = pool[ZombRand(#pool) + 1]
    stockKit(cont)
    return containerSpot(cont)
end

-- the game filled the chosen container after the kit went in: put it back,
-- once (then forget the spot, or loot respawn there would restock it forever)
local function onBadDayFillContainer(roomName, containerType, container)
    if not container or not instanceof(container, "ItemContainer") then return end   -- the game sometimes passes a loot-table entry
    local player = getSpecificPlayer(0)
    local d = player and hasTrait(player, "badday") and traitData(player)
    local spot = d and d.badDayKit
    if not spot then return end
    local here = containerSpot(container)
    if here and here.x == spot.x and here.y == spot.y and here.z == spot.z and here.kind == spot.kind then
        stockKit(container)
        d.badDayKit = nil
    end
end

local function onBadDayGameStart()
    local player = getSpecificPlayer(0)
    local d = badDayFresh(player)
    if not d then return end
    if not d.badDayFireDone then
        d.badDayFireDone = true
        startBadDayFire(player)
    end
    if not d.badDayKitDone then
        d.badDayKitDone = true
        d.badDayKit = DanTraits_BadDayPlaceKit(player)
    end
end

-- Console `badday [fire]` (Telemetry): replay the opening on the current
-- character, for balancing it without a new game. The applied flags are
-- cleared and the body's part is applied again (it does not undo what is
-- already there: another cold), skipping the first-hour gate
-- and the trait check. The fire only with `fire`. Returns a line for the log.
function DanTraits_BadDayReplay(player, withFire)
    if not player then return "badday: no player" end
    local d = traitData(player)
    d.badDayApplied, d.badDayFireDone = true, nil
    applyBadDay(player)
    local text = "badday: opening replayed"
    if withFire then
        d.badDayFireDone = true
        text = text .. (startBadDayFire(player) and ", fire started" or ", no fire (outdoors or no room far enough)")
    end
    return text
end

Events.OnCreatePlayer.Add(onBadDayCreatePlayer)
Events.OnGameStart.Add(onBadDayGameStart)
Events.OnFillContainer.Add(onBadDayFillContainer)
