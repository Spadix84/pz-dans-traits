-- Dan's Traits: A Really Bad Day.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- A Really Bad Day ----------------------------------------------------------
-- The CDDA challenge's opening, as a trait: drunk, sick, a shard of glass in
-- the groin and, if you start indoors, the house on fire. Each part is
-- applied exactly once, tracked in mod data so reloads and respawns are safe.
local function badDayFresh(player)
    if not player or not hasTrait(player, "badday") then return nil end
    if player:getHoursSurvived() > 0 then return nil end
    return traitData(player)
end

local function onBadDayCreatePlayer(playerNum, player)
    local d = badDayFresh(player)
    if not d or d.badDayApplied then return end
    d.badDayApplied = true

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

local function onBadDayGameStart()
    local player = getSpecificPlayer(0)
    local d = badDayFresh(player)
    if not d or d.badDayFireDone then return end
    d.badDayFireDone = true

    local square = player:getCurrentSquare()
    local room = square and square:getRoom()
    local building = room and room:getBuilding()
    if not building then return end   -- outdoors: no house to burn

    local tile = badDayFireSquare(player, building, room)
    if not tile then return end       -- nowhere far enough away: no fire

    pcall(function() IsoFireManager.explode(getCell(), tile, 100000) end)
    notify(player, "UI_DanTraits_BadDayFire")
end

Events.OnCreatePlayer.Add(onBadDayCreatePlayer)
Events.OnGameStart.Add(onBadDayGameStart)
