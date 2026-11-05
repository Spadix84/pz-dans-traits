-- Project Zomboid Vitality Project: Swarmed.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- Swarmed -------------------------------------------------------------------
-- The neighbourhood you wake in is crawling: the map cell you start in (256
-- tiles a side) holds four times the zombies it would. A start for points in
-- the family of Hunted: get out of the cell, or clear it.
--
-- The game keeps the population in native code and gives Lua no count of a
-- cell, so it is measured. SW_WAIT_MIN game minutes after waking (the ground
-- around you loaded, its zombies made real) the cell is surveyed in 8 x 8
-- blocks of SW_BLOCK tiles: how many of each block's chunks are loaded, and
-- how many zombies stand in it. A block at least SW_SEEN loaded keeps its own
-- count (scaled up to the whole block); every other block takes the density
-- of the loaded ones. Each block then gets (SW_FACTOR - 1) times its count
-- more, at least SW_FLOOR over the cell (so a quiet count is not free
-- points), added to the game's own population in groups of SW_GROUP
-- (createHordeInAreaTo: virtual zombies, dropped in an SW_SPOT patch and
-- walking a few tiles inside it, made real when you come near). No group
-- lands within SW_CLEAR tiles of where you woke or in that building, so the
-- first moments are the vanilla ones. Once, tracked in mod data; reloads and
-- respawns are safe. The extra zombies are part of the world from then on:
-- they wander, migrate and stay dead like any other; respawn refills a cell
-- to the plain population only. Singleplayer (zombies are the server's to
-- make; the trait script disables it in multiplayer, this guard covers a
-- character carried in). Console: `swarmed [now]`.
local SW_CELL     = 256   -- tiles to a map cell
local SW_BLOCK    = 32    -- the survey's block, a side
local SW_CHUNK    = 8     -- tiles to a chunk, a side
local SW_FACTOR   = 4     -- the cell's population times this
local SW_WAIT_MIN = 1     -- game minutes after waking before the survey
local SW_SEEN     = 0.5   -- share of a block's chunks loaded for its own count to stand
local SW_FLOOR    = 60    -- at least this many more over the cell
local SW_GROUP    = 4     -- zombies to a group
local SW_SPOT     = 8     -- a group's patch, a side
local SW_CLEAR    = 12    -- tiles around where you woke that no group lands in
local SW_HOUSE    = 3     -- tiles around that building, likewise
local SW_TRIES    = 8     -- patches tried for a group before it is dropped

local function multiplayer()
    return (isClient and isClient()) or (isServer and isServer()) or false
end

local function houseOf(player)
    local box = nil
    pcall(function()
        local def = player:getCurrentSquare():getBuildingDef()
        if def then box = { x = def:getX(), y = def:getY(), x2 = def:getX2(), y2 = def:getY2() } end
    end)
    return box
end

local function cellOf(x, y)
    return math.floor(x / SW_CELL), math.floor(y / SW_CELL)
end

-- the survey of cell (cx, cy): per block (0-based index bx + by * n) the chunks,
-- the loaded chunks and the zombies standing in it
local function survey(cx, cy)
    local cell = getCell()
    local x0, y0 = cx * SW_CELL, cy * SW_CELL
    local n = SW_CELL / SW_BLOCK
    local per = SW_BLOCK / SW_CHUNK
    local blocks = {}
    for i = 0, n * n - 1 do blocks[i] = { chunks = 0, loaded = 0, count = 0 } end
    for gx = 0, SW_CELL / SW_CHUNK - 1 do
        for gy = 0, SW_CELL / SW_CHUNK - 1 do
            local b = blocks[math.floor(gx / per) + math.floor(gy / per) * n]
            b.chunks = b.chunks + 1
            local sq = nil
            pcall(function() sq = cell:getGridSquare(x0 + gx * SW_CHUNK + 4, y0 + gy * SW_CHUNK + 4, 0) end)
            if sq then b.loaded = b.loaded + 1 end
        end
    end
    local list, size = nil, 0
    pcall(function() list = cell:getZombieList(); size = list:size() end)
    for i = 0, size - 1 do
        local x, y = nil, nil
        pcall(function() local z = list:get(i); x, y = z:getX(), z:getY() end)
        if x and y then
            local bx, by = math.floor((x - x0) / SW_BLOCK), math.floor((y - y0) / SW_BLOCK)
            if bx >= 0 and bx < n and by >= 0 and by < n then
                local b = blocks[bx + by * n]
                b.count = b.count + 1
            end
        end
    end
    return blocks, n
end

-- how many more each block gets, whole numbers; returns the list, the zombies
-- seen and the total to add
local function plan(blocks, n)
    local area = SW_BLOCK * SW_BLOCK
    local seenArea, seenCount = 0, 0
    for i = 0, n * n - 1 do
        local b = blocks[i]
        b.share = b.chunks > 0 and b.loaded / b.chunks or 0
        if b.share >= SW_SEEN then
            seenArea = seenArea + b.share * area
            seenCount = seenCount + b.count
        end
    end
    local density = seenArea > 0 and seenCount / seenArea or 0
    local want, total = {}, 0
    for i = 0, n * n - 1 do
        local b = blocks[i]
        local here = b.share >= SW_SEEN and b.count / b.share or density * area
        want[i] = (SW_FACTOR - 1) * here
        total = total + want[i]
    end
    if total < SW_FLOOR then
        local each = (SW_FLOOR - total) / (n * n)
        for i = 0, n * n - 1 do want[i] = want[i] + each end
        total = SW_FLOOR
    end
    -- whole zombies, the fractions carried from block to block
    local carry, sum = 0, 0
    for i = 0, n * n - 1 do
        local exact = want[i] + carry
        want[i] = math.floor(exact + 0.5)
        carry = exact - want[i]
        sum = sum + want[i]
    end
    return want, seenCount, sum
end

local function clashes(px, py, home, house)
    if home then
        local dx, dy = px + SW_SPOT / 2 - home.x, py + SW_SPOT / 2 - home.y
        if dx * dx + dy * dy < (SW_CLEAR + SW_SPOT / 2) ^ 2 then return true end
    end
    if house then
        if px + SW_SPOT > house.x - SW_HOUSE and px < house.x2 + SW_HOUSE
            and py + SW_SPOT > house.y - SW_HOUSE and py < house.y2 + SW_HOUSE then return true end
    end
    return false
end

-- a patch for a group inside the square (x0, y0, side) clear of the start; nil when none was found
local function patchIn(x0, y0, side, home, house)
    for _ = 1, SW_TRIES do
        local px, py = x0 + ZombRand(side - SW_SPOT + 1), y0 + ZombRand(side - SW_SPOT + 1)
        if not clashes(px, py, home, house) then return px, py end
    end
    return nil
end

-- drop `count` zombies into block (bx, by) of cell (cx, cy) in groups; how many were asked for.
-- A group the start leaves no room for in its block (the block you woke in) goes anywhere in the cell.
local function fillBlock(cx, cy, bx, by, count, home, house)
    local x0, y0 = cx * SW_CELL + bx * SW_BLOCK, cy * SW_CELL + by * SW_BLOCK
    local asked = 0
    while count > 0 do
        local k = math.min(SW_GROUP, count)
        count = count - k
        local px, py = patchIn(x0, y0, SW_BLOCK, home, house)
        if not px then px, py = patchIn(cx * SW_CELL, cy * SW_CELL, SW_CELL, home, house) end
        if px then
            local tx, ty = px + ZombRand(SW_SPOT), py + ZombRand(SW_SPOT)
            if pcall(function() createHordeInAreaTo(px, py, SW_SPOT, SW_SPOT, tx, ty, k) end) then asked = asked + k end
        end
    end
    return asked
end

-- survey cell (cx, cy) and fill it; returns the zombies seen and added
local function swarm(cx, cy, home, house)
    local blocks, n = survey(cx, cy)
    local want, seen = plan(blocks, n)
    local added = 0
    for i = 0, n * n - 1 do
        if want[i] > 0 then
            added = added + fillBlock(cx, cy, i % n, math.floor(i / n), want[i], home, house)
        end
    end
    return seen, added
end

local function onSwarmedCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "swarmed") then return end
    if player:getHoursSurvived() > 0 then return end
    local d = traitData(player)
    if d.swCell then return end
    local x, y = math.floor(player:getX()), math.floor(player:getY())
    local cx, cy = cellOf(x, y)
    d.swCell = { x = cx, y = cy }
    d.swHome = { x = x, y = y }
    d.swHouse = houseOf(player)
end

local function swarmedMinute(player, d)
    if multiplayer() or d.swDone or not d.swCell then return end
    if (player:getHoursSurvived() or 0) * 60 < SW_WAIT_MIN then return end
    d.swDone = true
    d.swSeen, d.swAdded = swarm(d.swCell.x, d.swCell.y, d.swHome, d.swHouse)
    if d.swAdded > 0 then notify(player, "UI_DanTraits_SwarmedWake") end
end

-- Console `swarmed [now]` (Telemetry, via DanTraits_ExtraCommands): no argument
-- reports the cell and what was added; `now` surveys and fills the cell you
-- stand in again (where you stand kept clear), for balancing without a new game.
function DanTraits_SwarmedReplay(player, what)
    if not player then return "swarmed: no player" end
    local d = traitData(player)
    if what == "now" then
        local x, y = math.floor(player:getX()), math.floor(player:getY())
        local cx, cy = cellOf(x, y)
        local seen, added = swarm(cx, cy, { x = x, y = y }, houseOf(player))
        return "swarmed: cell " .. cx .. "," .. cy .. ", " .. seen .. " zombies seen, " .. added .. " added"
    end
    local c = d.swCell
    return "swarmed: cell " .. (c and (c.x .. "," .. c.y) or "none") .. ", "
        .. (d.swDone and (tostring(d.swSeen) .. " seen, " .. tostring(d.swAdded) .. " added") or "not yet surveyed")
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.swarmed = function(player, args) return DanTraits_SwarmedReplay(player, args[1]) end

Events.OnCreatePlayer.Add(onSwarmedCreatePlayer)
DanTraits_Every("minute", "Swarmed", swarmedMinute, 60, { trait = "swarmed" })
