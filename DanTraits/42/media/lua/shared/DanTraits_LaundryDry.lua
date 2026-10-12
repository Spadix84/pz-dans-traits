-- Project Zomboid Vitality Project: laundry, drying by the fire and on a
-- clothesline (DanTraits_Laundry.lua has the state and the damp clock).
--
-- What the game already does (42.21, read from its Java): worn clothes dry
-- by body heat; an unworn garment, carried or in any container, dries 20
-- points an hour, worked out for the whole stretch when it is next looked at
-- or moved; washers and dryers run their own cycles. Nothing dries clothes
-- near a fire, and the clotheslines on the map are just scenery.
--
-- By the fire: a damp garment can be held to a lit campfire, fireplace,
-- barbecue or stove within L.FIRE_RANGE tiles (ISLaundryAction "fire"). The
-- bar takes the wetness to nothing, L.FIRE_PER_TICK a tick.
--
-- Clotheslines (sandbox LaundryClotheslines): the pulley-post tiles in yards
-- (appliances_laundry_01_26 to _29: 26 and 27 face each other east-west, 29
-- and 28 north-south) and the ones built from the crafting menu (entity
-- DanTraits.Clothesline, the same posts) each get a container, "clothesline",
-- L.LINE_CAPACITY. Posts near the player are watched (d.lnLines, by square);
-- each ten minutes a loaded one dries its load by the weather:
--
--   outdoors  L.LINE_RATE wetness an hour x temperature (under 0 C x0.2,
--             under 5 C x0.4, over 20 C x1.5) x wind (x1 to x1.5) x light
--             (clear day x1.3, night x0.5) x LaundryLineDryRate; rain of 0.1 or
--             more soaks it L.LINE_RAIN x the rain an hour instead
--   under a roof  x L.LINE_ROOF, no weather
--
-- and airs it: out in daylight without rain, L.AIR_RATE odour an hour off,
-- never under 30. A line that was not loaded catches up (up to a day) when it
-- is next seen, with the weather then. Containers added in this file are the
-- game's own, so they save with the map.
require "DanTraits_Laundry"

local L = DanTraits_Laundry

L.FIRE_RANGE    = 2       -- tiles from a fire to dry by it
L.FIRE_PER_TICK = 0.05    -- wetness off per action tick (a soaked shirt: 2000 ticks)
L.LINE_CAPACITY = 15
L.LINE_RATE     = 40      -- wetness off per hour, outdoors, mild, still, overcast day
L.LINE_RAIN     = 40      -- wetness on per hour at full rain
L.LINE_ROOF     = 0.6
L.AIR_RATE      = 5       -- odour off per hour, out in daylight
L.LINE_RADIUS   = 6       -- tiles around the player searched for posts
L.LINE_CATCHUP_H = 24

L.LINE_SPRITES = {
    appliances_laundry_01_26 = true, appliances_laundry_01_27 = true,
    appliances_laundry_01_28 = true, appliances_laundry_01_29 = true,
}

local function linesOn() return L.on() and DanTraits_SandboxOn("LaundryClotheslines") end
L.linesOn = linesOn

-- (no error path even inside pcall: some objects have no sprite, and debug
-- mode's Break On Error stops the game on a caught error too)
local function spriteName(obj)
    local name = nil
    pcall(function()
        local sprite = obj:getSprite()
        if sprite then name = sprite:getName() end
    end)
    return name
end

-- by the fire --------------------------------------------------------------------------

-- a lit heat source among this square's objects, or nil
function L.litHeatOn(sq)
    if not sq then return nil end
    local found = nil
    pcall(function()
        if CCampfireSystem and CCampfireSystem.instance then
            local fire = CCampfireSystem.instance:getLuaObjectOnSquare(sq)
            if fire and fire.isLit then
                local objects = sq:getObjects()
                found = objects:size() > 0 and objects:get(0) or nil
            end
        end
    end)
    if found then return found end
    pcall(function()
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if (L.is(obj, "IsoFireplace") or L.is(obj, "IsoBarbecue")) and obj:isLit() then
                found = obj
                return
            end
            if L.is(obj, "IsoStove") and obj:Activated() and not obj:isMicrowave() then
                found = obj
                return
            end
        end
    end)
    return found
end

-- the nearest lit fire or stove within reach, or nil
function L.findHeat(player)
    local px, py, pz = 0, 0, 0
    if not pcall(function() px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()) end) then return nil end
    local best, bestD = nil, 99
    local r = L.FIRE_RANGE
    for x = px - r, px + r do
        for y = py - r, py + r do
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, pz) end)
            local heat = L.litHeatOn(sq)
            if heat then
                local dist = math.max(math.abs(x - px), math.abs(y - py))
                if dist < bestD then best, bestD = heat, dist end
            end
        end
    end
    return best
end

-- still lit and still close
function L.heatStillThere(player, heat)
    if not heat then return false end
    local ok, close = pcall(function()
        local sq = heat:getSquare()
        local dx, dy = math.abs(sq:getX() - player:getX()), math.abs(sq:getY() - player:getY())
        return dx <= L.FIRE_RANGE + 1 and dy <= L.FIRE_RANGE + 1 and sq:getZ() == math.floor(player:getZ()) and L.litHeatOn(sq) ~= nil
    end)
    return ok and close == true
end

-- clotheslines --------------------------------------------------------------------------

function L.isLinePost(obj)
    if obj == nil then return false end
    if L.LINE_SPRITES[spriteName(obj) or ""] then return true end
    -- one put up from Lua: its sprite name can read empty, its mod data cannot
    local post = false
    pcall(function()
        local md = obj:getModData()
        post = md.dtlBuilt == true and not md.dtlWire
    end)
    return post
end

-- give a post its container if it has none; returns the container. 42.21's
-- only matching constructor is ItemContainer(type, square, parent) (the
-- campfire's five-argument call is stale). A failure is not retried this
-- session: it would throw again every ten minutes for every post in reach.
local lineFailed = false
function L.ensureLine(obj)
    if lineFailed or not L.isLinePost(obj) then return nil end
    local container = nil
    pcall(function() container = obj:getContainer() end)
    if container then return container end
    local ok = pcall(function()
        container = ItemContainer.new("clothesline", obj:getSquare(), obj)
        container:setCapacity(L.LINE_CAPACITY)
        container:setExplored(true)
        obj:setContainer(container)
    end)
    if not ok then
        lineFailed = true
        container = nil
        print("[DanTraits] laundry: a clothesline post could not be given a container; clotheslines are off this session")
    end
    return container
end

local function squareAt(x, y, z)
    local sq = nil
    pcall(function() sq = getCell():getGridSquare(x, y, z) end)
    return sq
end

local function postsOn(sq, fn)
    pcall(function()
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if L.isLinePost(obj) then fn(obj) end
        end
    end)
end

-- putting one up ---------------------------------------------------------------------
-- Not a build-menu entity: an entity whose sprites are the map's own posts
-- claims every clothesline the map loads, and those then fail to load
-- ("EntityScript not found", 2026-10-11). So the line is placed from Lua as
-- plain objects, laid out like the map's: a post, L.LINE_WIRES wire tiles,
-- a post (north-south 29, 31, 31, 31, 28; east-west 26, 30, 30, 30, 27).
-- Every piece carries dtlBuilt and dtlLine (the first square's "x,y,z") in its
-- mod data, the wires dtlWire, the posts dtlSprite, so a line put up can be
-- found and taken down again. (IsoObject.new(square, name) draws the sprite
-- but leaves its name empty, which is how the first put-up posts got no
-- container: the sprite is looked up by name with getSprite first.)

L.LINE_WIRES = 3
L.LINE_POSTS = { ["Base.LongStick"] = true, ["Base.Plank"] = true, ["Base.Sapling"] = true }
L.LINE_TIES = { ["Base.Rope"] = true, ["Base.Twine"] = true, ["Base.RippedSheets"] = true,
                ["Base.DenimStrips"] = true, ["Base.Wire"] = true }
L.LINE_LAYOUT = {
    ew = { dx = 1, dy = 0, first = "appliances_laundry_01_26", wire = "appliances_laundry_01_30", second = "appliances_laundry_01_27" },
    ns = { dx = 0, dy = 1, first = "appliances_laundry_01_29", wire = "appliances_laundry_01_31", second = "appliances_laundry_01_28" },
}

local function typeOf(item)
    local t = nil
    pcall(function() t = item:getFullType() end)
    return t
end

local function keyOf(sq) return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() end

-- two posts and two ties carried (bags included), or nil
function L.lineMaterials(player)
    local posts, ties = {}, {}
    for _, item in ipairs(L.carried(player)) do
        local t = typeOf(item) or ""
        if L.LINE_POSTS[t] and #posts < 2 then posts[#posts + 1] = item
        elseif L.LINE_TIES[t] and #ties < 2 then ties[#ties + 1] = item end
    end
    if #posts < 2 or #ties < 2 then return nil end
    return { posts = posts, ties = ties }
end

-- the squares a line from sq would stand on (first post, wires, second post),
-- if every one is clear floor; else nil
function L.lineSquares(sq, dir)
    local lay = L.LINE_LAYOUT[dir]
    if not sq or not lay then return nil end
    local out = {}
    for n = 0, L.LINE_WIRES + 1 do
        local s = nil
        pcall(function() s = getCell():getGridSquare(sq:getX() + lay.dx * n, sq:getY() + lay.dy * n, sq:getZ()) end)
        if not s then return nil end
        local ok, clear = pcall(function() return s:hasFloor() and s:isFree(false) end)
        if not ok or not clear then return nil end
        out[#out + 1] = s
    end
    return out
end

local function addPiece(sq, spriteName, line, wire)
    local sprite = getSprite and getSprite(spriteName)
    local obj = sprite and IsoObject.new(getCell(), sq, sprite) or IsoObject.new(sq, spriteName)
    sq:AddTileObject(obj)
    local md = obj:getModData()
    md.dtlBuilt, md.dtlLine = true, line
    if wire then md.dtlWire = true else md.dtlSprite = spriteName end
    if isServer() then pcall(function() obj:transmitCompleteItemToClients() end) end
    if not wire then L.ensureLine(obj) end
    return obj
end

-- use the materials and put the line up; true when it worked
function L.putUpLine(player, sq, dir, mats)
    local squares = L.lineSquares(sq, dir)
    if not squares then return false end
    local lay = L.LINE_LAYOUT[dir]
    local line = keyOf(squares[1])
    local ok = pcall(function()
        for n, s in ipairs(squares) do
            if n == 1 then addPiece(s, lay.first, line)
            elseif n == #squares then addPiece(s, lay.second, line)
            else addPiece(s, lay.wire, line, true) end
        end
    end)
    if not ok then return false end
    for _, item in ipairs(mats.posts) do pcall(function() item:getContainer():Remove(item) end) end
    for _, item in ipairs(mats.ties) do pcall(function() item:getContainer():Remove(item) end) end
    return true
end

local function builtMd(obj)
    local md = nil
    pcall(function()
        local m = obj:getModData()
        if m.dtlBuilt == true then md = m end
    end)
    return md
end

function L.isBuiltLine(obj)
    local md = builtMd(obj)
    return md ~= nil and not md.dtlWire
end

local function piecesOn(sq, fn)
    pcall(function()
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local o = objects:get(i)
            local m = builtMd(o)
            if m then fn(o, m) end
        end
    end)
end

-- the whole line down (posts and wires), whatever hung on it on the floor,
-- two long sticks and two lengths of twine back
function L.takeDownLine(player, obj)
    local md = builtMd(obj)
    if not md then return false end
    local pieces = {}
    local x, y, z = (md.dtlLine or ""):match("^(-?%d+),(-?%d+),(-?%d+)$")
    if x then
        for _, lay in pairs(L.LINE_LAYOUT) do
            for n = 0, L.LINE_WIRES + 1 do
                local sq = squareAt(tonumber(x) + lay.dx * n, tonumber(y) + lay.dy * n, tonumber(z))
                if sq then piecesOn(sq, function(o, m) if m.dtlLine == md.dtlLine then pieces[#pieces + 1] = o end end) end
            end
        end
    else
        -- a post from the first version (one tile apart: dtlPair, no dtlLine)
        pieces[1] = obj
        local px, py, pz = (md.dtlPair or ""):match("^(-?%d+),(-?%d+),(-?%d+)$")
        local sq = px and squareAt(tonumber(px), tonumber(py), tonumber(pz))
        if sq then piecesOn(sq, function(o) pieces[#pieces + 1] = o end) end
    end
    local seen = {}
    for _, piece in ipairs(pieces) do
        if not seen[piece] then
            seen[piece] = true
            pcall(function()
                local sq = piece:getSquare()
                local c = piece:getContainer()
                if c then
                    local items = c:getItems()
                    for i = items:size() - 1, 0, -1 do
                        local item = items:get(i)
                        c:Remove(item)
                        sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
                    end
                end
                sq:transmitRemoveItemFromSquare(piece)
                sq:RemoveTileObject(piece)
            end)
        end
    end
    pcall(function()
        local inv = player:getInventory()
        for _ = 1, 2 do inv:AddItem("Base.LongStick"); inv:AddItem("Base.Twine") end
    end)
    return true
end

-- 0..1 daylight
local function daylight(cm)
    local day = nil
    pcall(function() day = cm:getDayLightStrength() end)
    if type(day) == "number" then return math.max(0, math.min(1, day)) end
    local h = 12
    pcall(function() h = getGameTime():getTimeOfDay() end)
    return (h >= 7 and h <= 19) and 1 or 0
end

-- the weather on a line now: { outside, rate (wetness off per hour), rain (wetness on per hour), airing }
function L.lineWeather(outside)
    local w = { outside = outside, rate = 0, rain = 0, airing = false }
    local mult = math.max(0, L.num("LaundryLineDryRate", 100)) / 100
    if not outside then
        w.rate = L.LINE_RATE * L.LINE_ROOF * mult
        return w
    end
    local temp, rain, wind, cloud, day = 15, 0, 0, 0, 1
    local cm = getClimateManager and getClimateManager()
    if cm then
        pcall(function() temp = cm:getTemperature() end)
        pcall(function() rain = cm:getRainIntensity() end)
        pcall(function() wind = cm:getWindIntensity() end)
        pcall(function() cloud = cm:getCloudIntensity() end)
        day = daylight(cm)
    end
    if (rain or 0) >= 0.1 then
        w.rain = L.LINE_RAIN * rain
        return w
    end
    local tf = 1
    if temp < 0 then tf = 0.2 elseif temp < 5 then tf = 0.4 elseif temp > 20 then tf = 1.5 end
    local lf = day > 0.5 and (1 + 0.3 * (1 - (cloud or 0))) or 0.5
    w.rate = L.LINE_RATE * tf * (1 + 0.5 * math.max(0, math.min(1, wind or 0))) * lf * mult
    w.airing = day > 0.5
    return w
end

-- one garment on a line for this many hours of this weather
function L.lineItem(item, w, hours)
    if w.rain > 0 then
        L.setWetness(item, L.wetness(item) + w.rain * hours)
    else
        L.dry(item, w.rate * hours)
        if w.airing then
            L.air(item, L.AIR_RATE * hours)
            -- dried in the sun: counts toward Line-Dried until the next wash
            local s = L.state(item, true)
            if s and hours > 0 then s.sun = true end
        end
    end
end

-- a post's load, since it was last done (capped)
function L.tendLine(obj, t)
    local container = L.ensureLine(obj)
    if not container then return 0 end
    local md = nil
    pcall(function() md = obj:getModData() end)
    md = md or {}
    local last = md.dtlLast or t
    local hours = math.max(0, math.min(L.LINE_CATCHUP_H, t - last))
    md.dtlLast = t
    local n = 0
    local outside = false
    pcall(function() outside = obj:getSquare():isOutside() end)
    local w = L.lineWeather(outside)
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if L.isClothing(item) then
                n = n + 1
                if hours > 0 then L.lineItem(item, w, hours) end
                L.sight(item, false, t)
            end
        end
    end)
    return n
end

-- posts near the player get their containers and are watched; every watched
-- post still loaded is tended, and drops off the list while it is empty
function L.watchLines(player, d)
    if not linesOn() then
        d.lnLines = nil
        return
    end
    d.lnLines = d.lnLines or {}
    local px, py, pz = 0, 0, 0
    pcall(function() px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()) end)
    local r = L.LINE_RADIUS
    for x = px - r, px + r do
        for y = py - r, py + r do
            local sq = squareAt(x, y, pz)
            if sq then postsOn(sq, function(obj)
                L.ensureLine(obj)
                d.lnLines[x .. "," .. y .. "," .. pz] = true
            end) end
        end
    end
    local t = L.now()
    for key in pairs(d.lnLines) do
        local x, y, z = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
        local sq = x and squareAt(tonumber(x), tonumber(y), tonumber(z))
        if sq then
            local n = 0
            postsOn(sq, function(obj) n = n + L.tendLine(obj, t) end)
            local near = math.abs(tonumber(x) - px) <= r and math.abs(tonumber(y) - py) <= r
            if n == 0 and not near then d.lnLines[key] = nil end
        end
    end
end
