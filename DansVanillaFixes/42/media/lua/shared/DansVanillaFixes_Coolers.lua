-- Dan's Vanilla Fixes: cold packs and coolers.
--
-- Vanilla's cold pack has no temperature and its cooler is an ordinary bag.
-- Here every cold pack holds a chill budget: the hours of cold it can give a
-- cooler (up to ColdPackHours, default 6, when fully frozen).
--
--   powered freezer      fills it, empty to full in 4 h
--   powered fridge       fills it half way in 3 h; a frozen pack thaws back
--                        down to half over 8 h
--   anywhere else        the air at the pack's square decides: at or below
--                        0 C it freezes (8 h to full), up to 5 C it holds,
--                        warmer it is warm again in 2 h
--   in a cooler          the packs drain together, one hour of budget per
--                        hour, so a cooler stays cold for the sum of its
--                        packs; while it is cold its food ages at the
--                        fridge rate (the FridgeFactor sandbox setting)
--
-- Food decides its own ageing in Java: it slows down only in a powered fridge
-- or freezer, and judges that by its outermost container, which for food in
-- a cooler is the player, the car or the cooler itself, never a fridge. So the
-- cooler takes the difference back off the food's age instead.
--
-- Nothing is ticked per item. A pack or cooler keeps the game hour it was last
-- brought up to date in its mod data, and settle() applies the time since then
-- at the rate for where it is now. The client file settles what the player
-- carries every ten minutes, whatever an inventory window shows when it
-- refreshes, and anything it has seen that is still changing, so a cooler
-- left in a car or a pack left in a freezer catches up when it is next seen.

DVF_Coolers = DVF_Coolers or {}
local C = DVF_Coolers

C.PACKS = { ["Base.Coldpack"] = true }
C.COOLERS = { ["Base.Cooler"] = true }
C.KEY = "DVF_Cold"
C.DEFAULT_HOURS = 6
C.FREEZER_FILL = 4       -- hours from warm to full in a freezer
C.FRIDGE_SHARE = 0.5     -- a fridge chills a pack this far
C.FRIDGE_FILL = 3        -- hours from warm to the fridge's share
C.FRIDGE_THAW = 8        -- hours for a full pack to thaw down to the fridge's share
C.AIR_FILL = 8           -- hours from warm to full lying out below freezing
C.AIR_WARM = 2           -- hours from full to warm in the warm
C.FREEZE_AT = 0          -- C, at or below: a pack in the open freezes
C.HOLD_AT = 5            -- C, at or below: it keeps what it has
C.FROZEN_AT = 0.75       -- share of the full budget named Frozen
C.COLD_AT = 0.34         -- named Cold
C.COOL_AT = 0.01         -- named Cool; below this it is just a cold pack again

-- Food.getFridgeFactor and getFoodRotSpeed are private, so their sandbox
-- tables are copied here (42.21).
local FRIDGE_FACTOR = { 0.4, 0.3, 0.2, 0.1, 0.03, 0 }
local ROT_SPEED = { 1.7, 1.4, 1.0, 0.7, 0.4 }

function C.maxHours()
    local opts = SandboxVars and SandboxVars.DansVanillaFixes
    local v = opts and tonumber(opts.ColdPackHours)
    if v and v > 0 then return v end
    return C.DEFAULT_HOURS
end

function C.fridgeFactor()
    return FRIDGE_FACTOR[SandboxVars and SandboxVars.FridgeFactor] or 0.2
end

function C.rotSpeed()
    return ROT_SPEED[SandboxVars and SandboxVars.FoodRotSpeed] or 1
end

function C.now() return getGameTime():getWorldAgeHours() end

function C.isPack(item) return item ~= nil and C.PACKS[item:getFullType()] == true end
function C.isCooler(item) return item ~= nil and C.COOLERS[item:getFullType()] == true end

-- This item's { c = chill hours, t = game hour last settled }, made on first sight
-- (found packs start warm).
function C.state(item, now)
    local md = item:getModData()
    local s = md[C.KEY]
    if type(s) ~= "table" or type(s.t) ~= "number" then
        s = { c = 0, t = now }
        md[C.KEY] = s
    end
    s.c = tonumber(s.c) or 0
    return s
end

-- The square an item is on (for the air temperature), and the car it is in.
function C.squareOf(item)
    local w = item:getWorldItem()
    if w then return w:getSquare() end
    local c = item:getContainer()
    while c do
        local holder = c:getContainingItem()
        if not holder then break end
        w = holder:getWorldItem()
        if w then return w:getSquare() end
        c = holder:getContainer()
    end
    if not c then return nil end
    local who = c:getCharacter()
    if who then return who:getCurrentSquare(), who:getVehicle() end
    local part = c:getVehiclePart()
    if part and part:getVehicle() then
        local car = part:getVehicle()
        return car:getSquare(), car
    end
    local parent = c:getParent()
    if parent then return parent:getSquare() end
    return c:getSourceGrid()
end

function C.airTemp(item)
    local sq, car = C.squareOf(item)
    if not sq then return 20 end
    local climate = getClimateManager()
    if car then return climate:getAirTemperatureForSquare(sq, car) end
    return climate:getAirTemperatureForSquare(sq)
end

-- Where a pack is: "freezer" or "fridge" (outermost container, powered, as
-- vanilla judges food), "cooler" (lying directly in one; the cooler is the
-- second result), or "air".
function C.place(item)
    local outer = item:getOutermostContainer()
    if outer and outer:isPowered() then
        if outer:isFreezer() then return "freezer" end
        if outer:isFridge() then return "fridge" end
    end
    local c = item:getContainer()
    local holder = c and c:getContainingItem()
    if C.isCooler(holder) then return "cooler", holder end
    return "air"
end

-- A loose pack's chill after dt hours in place (temp: the air, for "air").
function C.stepPack(chill, dt, place, temp, max)
    if place == "freezer" then
        return math.min(max, chill + dt * max / C.FREEZER_FILL)
    elseif place == "fridge" then
        local cap = max * C.FRIDGE_SHARE
        if chill < cap then return math.min(cap, chill + dt * cap / C.FRIDGE_FILL) end
        return math.max(cap, chill - dt * (max - cap) / C.FRIDGE_THAW)
    end
    if temp <= C.FREEZE_AT then return math.min(max, chill + dt * max / C.AIR_FILL) end
    if temp <= C.HOLD_AT then return chill end
    return math.max(0, chill - dt * max / C.AIR_WARM)
end

-- Whether a loose pack would still change where it is.
function C.packChanging(chill, place, temp, max)
    if place == "freezer" then return chill < max end
    if place == "fridge" then return math.abs(chill - max * C.FRIDGE_SHARE) > 1e-6 end
    if temp <= C.FREEZE_AT then return chill < max end
    if temp <= C.HOLD_AT then return false end
    return chill > 0
end

-- Packs in one cooler drain together, smallest first, dt hours of budget in
-- all. states: their state tables (changed in place). Returns the hours the
-- cooler was cold.
function C.drainPool(states, dt)
    table.sort(states, function(a, b) return a.c < b.c end)
    local left = dt
    for _, s in ipairs(states) do
        local take = math.min(s.c, left)
        s.c = s.c - take
        left = left - take
    end
    return dt - left
end

-- Take back what the food aged over the cold hours beyond the fridge rate.
function C.coolFood(food, coldHours)
    if coldHours <= 0 or food:isFrozen() then return end
    if food:getOffAgeMax() >= 1000000000 then return end   -- never spoils
    local back = coldHours * (1 - C.fridgeFactor()) * C.rotSpeed() / 24
    food:setAge(math.max(0, food:getAge() - back))
end

-- Name an item "<name> (<state>)", or just "<name>" when state is nil. Names
-- the player gave it themselves are left alone.
function C.label(item, state)
    local script = item:getScriptItem()
    local base = script and script:getDisplayName()
    if not base then return end
    local name = item:getName()
    if name ~= base and string.sub(name, 1, string.len(base) + 2) ~= base .. " (" then return end
    local want = state and (base .. " (" .. state .. ")") or base
    if name ~= want then
        item:setName(want)
        item:setCustomName(state ~= nil)
    end
end

function C.packLabel(chill, max)
    local f = chill / max
    if f >= C.FROZEN_AT then return getText("IGUI_DVF_PackFrozen") end
    if f >= C.COLD_AT then return getText("IGUI_DVF_PackCold") end
    if f >= C.COOL_AT then return getText("IGUI_DVF_PackCool") end
    return nil
end

function C.coolerLabel(total)
    if total <= 0 then return nil end
    return getText("IGUI_DVF_CoolerCold", tostring(math.max(1, math.floor(total + 0.5))))
end

local function settlePack(item, now, place, max)
    local s = C.state(item, now)
    local temp = place == "air" and C.airTemp(item) or nil
    local dt = now - s.t
    s.c = math.min(s.c, max)
    if dt > 0 then s.c = C.stepPack(s.c, dt, place, temp, max) end
    s.t = now
    C.label(item, C.packLabel(s.c, max))
    return C.packChanging(s.c, place, temp, max)
end

-- Bring a cooler and everything in it up to date. Returns whether it is still
-- cold (or charging, when it sits in a powered fridge or freezer).
function C.settleCooler(cooler, now)
    now = now or C.now()
    local max = C.maxHours()
    local cs = C.state(cooler, now)
    local dt = math.max(0, now - cs.t)
    cs.t = now
    local items = cooler:getInventory():getItems()
    local packs, foods = {}, {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if C.isPack(it) then
            packs[#packs + 1] = it
        elseif instanceof(it, "Food") then
            foods[#foods + 1] = it
        end
    end
    local outer = cooler:getOutermostContainer()
    if outer and outer:isPowered() and (outer:isFridge() or outer:isFreezer()) then
        -- in a fridge or freezer the packs charge, and the food is the fridge's
        local changing = false
        for _, p in ipairs(packs) do
            if settlePack(p, now, outer:isFreezer() and "freezer" or "fridge", max) then changing = true end
        end
        C.label(cooler, nil)
        return changing
    end
    local states, total = {}, 0
    for i, p in ipairs(packs) do
        local s = C.state(p, now)
        s.c = math.min(s.c, max)
        s.t = now
        states[i] = s
    end
    local cold = C.drainPool(states, dt)
    for _, f in ipairs(foods) do C.coolFood(f, cold) end
    for i, p in ipairs(packs) do
        total = total + states[i].c
        C.label(p, C.packLabel(states[i].c, max))
    end
    C.label(cooler, C.coolerLabel(total))
    return total > 0
end

-- Bring a pack or cooler up to date. Returns whether it is still changing
-- (worth settling again later), nil for anything else.
function C.settle(item, now)
    now = now or C.now()
    if C.isCooler(item) then return C.settleCooler(item, now) end
    if not C.isPack(item) then return nil end
    local place, cooler = C.place(item)
    if place == "cooler" then return C.settleCooler(cooler, now) end
    return settlePack(item, now, place, C.maxHours())
end

function C.patchScripts()
    local sm
    pcall(function() sm = getScriptManager() end)
    if not sm then return end
    for fullType, tip in pairs({ ["Base.Coldpack"] = "Tooltip_DVF_Coldpack", ["Base.Cooler"] = "Tooltip_DVF_Cooler" }) do
        pcall(function()
            local item = sm:getItem(fullType)
            if item then item:DoParam("Tooltip = " .. tip) end
        end)
    end
end

Events.OnGameBoot.Add(C.patchScripts)
