-- Dan's Vanilla Fixes: when cold packs and coolers get brought up to date
-- (the rules are in shared/DansVanillaFixes_Coolers.lua).
--
--   every ten minutes   everything the players carry, and every pack or
--                       cooler on the watch list
--   inventory refresh   everything in the containers the windows show, so a
--                       pack is current the moment a fridge or cooler opens
--
-- The watch list holds packs and coolers seen out in the world that are still
-- changing (a pack in a freezer, a cold cooler in a car). Each drops off once
-- it settles down, leaves the loaded map, or is gone.

require "DansVanillaFixes_Coolers"

local C = DVF_Coolers
local watch = {}   -- item id -> item

local function watched(item, changing)
    if changing then watch[item:getID()] = item else watch[item:getID()] = nil end
end

function C.loaded(item)
    if not item:getContainer() and not item:getWorldItem() then return false end
    local sq = C.squareOf(item)
    if not sq then return false end
    return getCell():getGridSquare(sq:getX(), sq:getY(), sq:getZ()) == sq
end

-- Settle every pack and cooler in a container, and in the bags inside it.
function C.settleAll(container, now, onWorld)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if C.isPack(it) or C.isCooler(it) then
            local changing = C.settle(it, now)
            if onWorld then watched(it, changing) end
        end
        if not C.isCooler(it) and it:IsInventoryContainer() then
            C.settleAll(it:getInventory(), now, onWorld)
        end
    end
end

function C.everyTen()
    local now = C.now()
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then C.settleAll(p:getInventory(), now, false) end
    end
    local gone = {}
    for id, item in pairs(watch) do
        if not C.loaded(item) or not C.settle(item, now) then gone[#gone + 1] = id end
    end
    for _, id in ipairs(gone) do watch[id] = nil end
end

function C.onRefresh(page, state)
    if state ~= "end" or not page.backpacks then return end
    local now = C.now()
    for _, button in ipairs(page.backpacks) do
        local inv = button.inventory
        if inv then
            local holder = inv:getContainingItem()
            if C.isCooler(holder) then
                watched(holder, C.settle(holder, now))
            else
                C.settleAll(inv, now, not page.onCharacter)
            end
        end
    end
end

function C.watchCount()
    local n = 0
    for _ in pairs(watch) do n = n + 1 end
    return n
end

-- For testing (DanTraits' debug `lua` command): settle and describe every pack
-- and cooler the player carries or that lies within radius squares (default 3),
-- with the food in each cooler. One line per item, joined with " | ".
local function describe(out, it, now)
    C.settle(it, now)
    local s = it:getModData()[C.KEY]
    local line = it:getName() .. " c=" .. string.format("%.2f", s and s.c or 0)
    if C.isPack(it) then
        local place = C.place(it)
        line = line .. " " .. place
        if place == "air" then line = line .. string.format(" %.1fC", C.airTemp(it)) end
    else
        local items = it:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local f = items:get(i)
            if instanceof(f, "Food") then
                line = line .. string.format(" [%s age %.3f/%d%s]", f:getName(), f:getAge(), f:getOffAgeMax(),
                    f:isFrozen() and " frozen" or "")
            end
        end
    end
    out[#out + 1] = line
end

local function collect(out, container, now)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if C.isPack(it) or C.isCooler(it) then describe(out, it, now) end
        if it:IsInventoryContainer() then collect(out, it:getInventory(), now) end
    end
end

function C.report(player, radius)
    local now, out = C.now(), {}
    collect(out, player:getInventory(), now)
    local sq = player:getCurrentSquare()
    local r = radius or 3
    for x = sq:getX() - r, sq:getX() + r do
        for y = sq:getY() - r, sq:getY() + r do
            local g = getCell():getGridSquare(x, y, sq:getZ())
            if g then
                local wos = g:getWorldObjects()
                for i = 0, wos:size() - 1 do
                    local it = wos:get(i):getItem()
                    if it and (C.isPack(it) or C.isCooler(it)) then describe(out, it, now) end
                    if it and it:IsInventoryContainer() and not C.isCooler(it) then collect(out, it:getInventory(), now) end
                end
                local objs = g:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    for k = 0, o:getContainerCount() - 1 do collect(out, o:getContainerByIndex(k), now) end
                end
            end
        end
    end
    return string.format("h=%.2f watch=%d ", now, C.watchCount()) .. table.concat(out, " | ")
end

Events.EveryTenMinutes.Add(C.everyTen)
Events.OnRefreshInventoryWindowContainers.Add(C.onRefresh)
