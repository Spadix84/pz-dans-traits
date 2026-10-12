-- Project Zomboid Vitality Project: the laundry debug command, for play-testing
-- through the dashboard's command channel (client/DanTraits_Telemetry.lua,
-- debug mode only). Every subcommand returns one line for the log.
--
--   laundry                     report: the moodle, then every worn garment
--                               (wet, odour, MUSTY, damp hours, stain, washes,
--                               protector, condition), then how many are carried
--   laundry all                 the same for every carried garment
--   laundry kit                 a test kit: tee, jeans, socks, shoes, a jacket,
--                               a necklace, soap, bleach, a washboard, fabric
--                               protector, candles and a tin, a garbage bag, a
--                               knife, long sticks and rope, a garbage bag poncho
--   laundry dirty [blood] [dirt]  every worn garment's parts to these (0..1, default 1 1)
--   laundry soak [wet]          worn and carried clothing to this wetness (default 100)
--   laundry odour <n>           worn clothing's odour to n (0..100)
--   laundry musty               worn clothing musty
--   laundry age <hours>         every carried garment's clocks back by this much
--                               (the damp clock and blood first seen), then a tick
--   laundry stain [0..1]        a set-in stain (default 0.2) on every part of the worn clothing
--   laundry tick                run the ten-minute laundry update now
--   laundry clear               every carried garment clean, dry and fresh, state wiped
--   laundry lines               clothesline posts within 6 tiles: built?, load, wetness
--   laundry washers             the washers being watched
--   laundry heat                the lit fire or stove within reach, if any
require "DanTraits_Laundry"
require "DanTraits_LaundryDry"
require "DanTraits_LaundryGear"

local L = DanTraits_Laundry

local KIT = {
    "Base.Tshirt_DefaultTEXTURE", "Base.Trousers_Denim", "Base.Socks_Ankle", "Base.Shoes_Black",
    "Base.Jacket_Padded", "Base.Necklace_Gold", "Base.Soap2", "Base.Bleach", "DanTraits.Washboard",
    "DanTraits.FabricProtector", "Base.Candle", "Base.Candle", "Base.TinCanEmpty", "Base.Garbagebag",
    "Base.KitchenKnife", "Base.LongStick", "Base.LongStick", "Base.Rope", "Base.Rope", "Base.PonchoGarbageBag",
}

local function r1(x) return math.floor((tonumber(x) or 0) * 10 + 0.5) / 10 end

local function line(item)
    local s = L.state(item, false) or {}
    local cond = "?"
    pcall(function() cond = item:getCondition() .. "/" .. item:getConditionMax() end)
    local name = "?"
    pcall(function() name = item:getName() end)
    local parts = {}
    for _, p in ipairs(L.snapshot(item)) do
        if p.blood > 0.005 or p.dirt > 0.005 then parts[#parts + 1] = p.key .. " " .. math.floor(p.blood * 100 + 0.5) .. "/" .. math.floor(p.dirt * 100 + 0.5) end
    end
    return string.format("%s [wet %d odour %d%s dh %s%s n %d%s cond %s%s]", name, math.floor(L.wetness(item) + 0.5),
        math.floor((s.o or 0) + 0.5), s.m and " MUSTY" or "", r1(s.dh), L.hasStain(item) and " STAIN" or "",
        s.n or 0, (s.pr and (" prot " .. math.floor(s.pr * 100) .. "%") or ""), cond,
        #parts > 0 and (" b/d " .. table.concat(parts, ",")) or "")
end

local function wornClothing(player)
    local out = {}
    for _, item in ipairs(L.worn(player)) do if L.isClothing(item) then out[#out + 1] = item end end
    return out
end

local function carriedClothing(player)
    local out = {}
    for _, item in ipairs(L.carried(player)) do if L.isClothing(item) then out[#out + 1] = item end end
    return out
end

local function sync(player, items)
    for _, item in ipairs(items) do pcall(function() syncItemFields(player, item) end) end
    pcall(function() syncVisuals(player) end)
    pcall(function() player:resetModelNextFrame() end)
end

local SUB = {}

function SUB.report(player)
    local d = DanTraits_Data(player)
    local worn = wornClothing(player)
    local out = { "moodle " .. tostring(d.lnMoodle or 0) .. ", on " .. tostring(L.on()) }
    for _, item in ipairs(worn) do out[#out + 1] = line(item) end
    out[#out + 1] = (#carriedClothing(player) - #worn) .. " more carried"
    return table.concat(out, " | ")
end

function SUB.all(player)
    local out = {}
    for _, item in ipairs(carriedClothing(player)) do out[#out + 1] = line(item) end
    if #out == 0 then return "no clothing carried" end
    return table.concat(out, " | ")
end

function SUB.kit(player)
    local inv = player:getInventory()
    local n = 0
    for _, t in ipairs(KIT) do
        if pcall(function() inv:AddItem(t) end) then n = n + 1 end
    end
    return "kit: " .. n .. " of " .. #KIT .. " items given"
end

function SUB.dirty(player, args)
    local blood, dirt = tonumber(args[1]) or 1, tonumber(args[2]) or 1
    local worn = wornClothing(player)
    for _, item in ipairs(worn) do
        local snap = L.snapshot(item)
        for _, p in ipairs(snap) do
            pcall(function()
                item:setBlood(p.part, blood)
                item:setDirt(p.part, dirt)
            end)
        end
        L.recount(item, snap)
        local s = L.state(item, false)
        if s then s.pb = nil end
    end
    sync(player, worn)
    return "dirty: " .. #worn .. " worn garments at blood " .. blood .. ", dirt " .. dirt
end

function SUB.soak(player, args)
    local wet = tonumber(args[1]) or 100
    local items = carriedClothing(player)
    for _, item in ipairs(items) do L.setWetness(item, wet) end
    sync(player, items)
    return "soak: " .. #items .. " garments at wetness " .. wet
end

function SUB.odour(player, args)
    local n = tonumber(args[1]) or 60
    local worn = wornClothing(player)
    for _, item in ipairs(worn) do
        local s = L.state(item, true)
        if s then s.o = n end
    end
    L.tenNow(player, DanTraits_Data(player))
    return "odour: " .. #worn .. " worn garments at " .. n .. ", moodle " .. tostring(DanTraits_Data(player).lnMoodle)
end

function SUB.musty(player)
    local worn = wornClothing(player)
    for _, item in ipairs(worn) do
        local s = L.state(item, true)
        if s then s.m, s.o = true, math.max(s.o or 0, L.C.MUSTY) end
    end
    L.tenNow(player, DanTraits_Data(player))
    return "musty: " .. #worn .. " worn garments, moodle " .. tostring(DanTraits_Data(player).lnMoodle)
end

function SUB.age(player, args)
    local h = tonumber(args[1]) or 6
    local items = carriedClothing(player)
    for _, item in ipairs(items) do
        local s = L.state(item, true)
        if s then
            s.ls = (s.ls or L.now()) - h
            for k, v in pairs(s.bs or {}) do s.bs[k] = v - h end
        end
    end
    L.tenNow(player, DanTraits_Data(player))
    return "age: " .. #items .. " garments' clocks back " .. h .. " h, then a tick"
end

function SUB.stain(player, args)
    local v = tonumber(args[1]) or 0.2
    local worn = wornClothing(player)
    for _, item in ipairs(worn) do
        local s = L.state(item, true)
        if s then
            s.st = s.st or {}
            for _, p in ipairs(L.snapshot(item)) do
                s.st[p.key] = v
                if p.blood < v then pcall(function() item:setBlood(p.part, v) end) end
            end
            L.recount(item, L.snapshot(item))
        end
    end
    sync(player, worn)
    return "stain: " .. v .. " on every part of " .. #worn .. " worn garments"
end

function SUB.tick(player)
    L.tenNow(player, DanTraits_Data(player))
    return "tick: moodle " .. tostring(DanTraits_Data(player).lnMoodle)
end

function SUB.clear(player)
    local items = carriedClothing(player)
    for _, item in ipairs(items) do
        local snap = L.snapshot(item)
        for _, p in ipairs(snap) do
            pcall(function()
                item:setBlood(p.part, 0)
                item:setDirt(p.part, 0)
            end)
        end
        L.recount(item, snap)
        L.setWetness(item, 0)
        pcall(function() item:getModData().DTL = nil end)
    end
    sync(player, items)
    L.tenNow(player, DanTraits_Data(player))
    return "clear: " .. #items .. " garments clean, dry and fresh"
end

function SUB.lines(player)
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local out = {}
    for x = px - 6, px + 6 do
        for y = py - 6, py + 6 do
            local sq = getCell():getGridSquare(x, y, pz)
            if sq then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if L.isLinePost(obj) then
                        local c = L.ensureLine(obj)
                        local n, wet = 0, {}
                        if c then
                            local items = c:getItems()
                            n = items:size()
                            for j = 0, n - 1 do wet[#wet + 1] = math.floor(L.wetness(items:get(j)) + 0.5) end
                        end
                        out[#out + 1] = string.format("%d,%d %s%s %d item(s) wet %s", x, y,
                            L.isBuiltLine(obj) and "built" or "map", c and "" or " NO CONTAINER", n, table.concat(wet, "/"))
                    end
                end
            end
        end
    end
    local w = L.lineWeather(player:isOutside())
    out[#out + 1] = string.format("weather here: dry %.1f/h rain %.1f/h airing %s", w.rate, w.rain, tostring(w.airing))
    return "lines: " .. table.concat(out, " | ")
end

function SUB.washers(player)
    local d = DanTraits_Data(player)
    local keys = {}
    for k in pairs(d.lnWashers or {}) do keys[#keys + 1] = k end
    return "washers watched: " .. (#keys > 0 and table.concat(keys, " ") or "none")
end

function SUB.heat(player)
    local heat = L.findHeat(player)
    if not heat then return "heat: nothing lit within " .. L.FIRE_RANGE .. " tiles" end
    local name = "?"
    pcall(function() name = heat:getObjectName() end)
    return "heat: " .. tostring(name) .. " at " .. heat:getSquare():getX() .. "," .. heat:getSquare():getY()
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.laundry = function(player, args)
    local sub = SUB[args[1] or "report"]
    if not sub then return "laundry: report | all | kit | dirty | soak | odour | musty | age | stain | tick | clear | lines | washers | heat" end
    local rest = {}
    for i = 2, #args do rest[#rest + 1] = args[i] end
    return sub(player, rest)
end
