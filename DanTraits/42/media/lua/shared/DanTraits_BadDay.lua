-- Project Zomboid Vitality Project: A Really Bad Day.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- A Really Bad Day ----------------------------------------------------------
-- The CDDA challenge's opening, as a trait: drunk, sick, a shard of glass in
-- the groin and, if you start indoors, the house on fire. Each part is
-- applied exactly once, tracked in mod data so reloads and respawns are safe.
--
-- What the opening costs under the health overhaul (blood, infection, wound
-- care, hangover, the alcoholism meter): the shard is a deep wound in the
-- groin, a 1.5x bleed site that bleeds through a bandage and carries the top
-- infection hazard until it is pulled (pulling it is a Fear of Blood faint
-- roll); intoxication 100 is a full Drunk 4, which keeps the pain floor at 80
-- (what makes the shard survivable), arms a maximum hangover for when it
-- wears off and feeds the day's alcoholism cap; a cold at strength 50 rides
-- on top. With Hemophilia or Anaemic the start is probably unwinnable.
--
-- BALANCE PENDING PLAY (plans/21-bad-day-balance.md): none of the numbers
-- above has been tuned for the overhaul yet. The dials are listed in the plan
-- (a fixed low bleeding time on the shard, a starting bandage, a zeroed
-- hangover load, Hemophilia exclusion) and wait for a play test. Replay the
-- opening without a new character with the console command `badday`
-- (`badday fire` also relights the house): DanTraits_BadDayReplay.
local function badDayFresh(player)
    if not player or not hasTrait(player, "badday") then return nil end
    if player:getHoursSurvived() > 0 then return nil end
    return traitData(player)
end

-- the body of the opening: drunk, sick, the shard, no clothes and soaking wet
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

    local groin = bd:getBodyPart(BodyPartType.Groin)
    if groin then pcall(function() groin:generateDeepShardWound() end) end

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

local function onBadDayGameStart()
    local player = getSpecificPlayer(0)
    local d = badDayFresh(player)
    if not d or d.badDayFireDone then return end
    d.badDayFireDone = true
    startBadDayFire(player)
end

-- Console `badday [fire]` (Telemetry): replay the opening on the current
-- character, for balancing it without a new game. The applied flags are
-- cleared and the body's part is applied again (it does not undo what is
-- already there: a second shard, another cold), skipping the first-hour gate
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
