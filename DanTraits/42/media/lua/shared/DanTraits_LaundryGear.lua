-- Project Zomboid Vitality Project: laundry, keeping clothes clean in the
-- first place (sandbox LaundryPoncho, on top of LaundryEnabled).
--
-- Ponchos. The game has four (green, yellow, tarp, garbage bag, each with its
-- hood up or down), and a recipe for the garbage bag one (Tailoring 1, two
-- bags, duct tape); Vitality adds a rough one with no skill (one bag, a knife
-- or scissors: DanTraits.txt). Worn, a poncho takes the blood and dirt for
-- the parts it covers: whatever lands on the clothes under it there is taken
-- back off each minute. The garbage bag poncho tears as it is used: a chance
-- at a condition point each time it takes a hit (L.TEAR_HIT) and each ten
-- minutes of hard work in it (L.TEAR_WORK); at nothing it falls apart.
--
-- Fabric protector (a spray, found with cleaning supplies) and fabric wax
-- (made from candles) treat one garment per use: while it holds, only
-- L.PROTECT_KEEP of the blood and dirt that lands on it stays. It wears off:
-- L.PROTECT_PER_WASH a wash (three washes) and L.PROTECT_WEAR each minute it
-- takes a hit.
--
-- Both work the same way: each worn garment keeps its last reading per part
-- (DTL.pb); a rise since then is the hit, and the poncho or the protector
-- takes its share back off. A wash clears the reading.
require "DanTraits_Laundry"

local L = DanTraits_Laundry

L.PROTECT_KEEP     = 0.5
L.PROTECT_PER_WASH = 0.34
L.PROTECT_WEAR     = 0.02
L.TEAR_HIT         = 0.2
L.TEAR_WORK        = 0.1
L.HIT_EPS          = 0.0001

L.PONCHOS = {
    ["Base.PonchoGarbageBag"] = "bag", ["Base.PonchoGarbageBagDOWN"] = "bag",
    ["Base.PonchoGreen"] = true, ["Base.PonchoGreenDOWN"] = true,
    ["Base.PonchoYellow"] = true, ["Base.PonchoYellowDOWN"] = true,
    ["Base.PonchoTarp"] = true, ["Base.PonchoTarpDOWN"] = true,
}

local function gearOn() return L.on() and DanTraits_SandboxOn("LaundryPoncho") end
L.gearOn = gearOn

local function fullType(item)
    local t = nil
    pcall(function() t = item:getFullType() end)
    return t
end

function L.isPoncho(item) return L.PONCHOS[fullType(item) or ""] ~= nil end
function L.isBagPoncho(item) return L.PONCHOS[fullType(item) or ""] == "bag" end

-- treat a garment
function L.protect(item)
    local s = L.state(item, true)
    if not s then return end
    s.pr = 1
    s.pb = nil
end

function L.protection(item)
    local s = L.state(item, false)
    return (s and s.pr) or 0
end

-- the garbage bag poncho: a condition point off, and gone at nothing
local function tear(player, poncho)
    pcall(function()
        local c = poncho:getCondition()
        if c > 1 then
            poncho:setCondition(c - 1)
            return
        end
        player:removeWornItem(poncho)
        poncho:getContainer():Remove(poncho)
        pcall(function() player:resetModel() end)
        pcall(function() triggerEvent("OnClothingUpdated", player) end)
        DanTraits_Notify(player, "UI_DanTraits_PonchoTore")
    end)
end
L.tear = tear

-- each minute: what landed on the clothes under a poncho or a protector comes back off
function L.shield(player, d)
    if not gearOn() then return end
    local worn = L.worn(player)
    local cover, any = {}, false
    for _, item in ipairs(worn) do
        if L.isPoncho(item) then
            for _, p in ipairs(L.snapshot(item)) do cover[p.key] = item end
            any = true
        end
    end
    local hitBag = nil
    for _, item in ipairs(worn) do
        if L.isClothing(item) and not L.isPoncho(item) then
            local s = L.state(item, false)
            local protected = s ~= nil and (s.pr or 0) > 0
            if any or protected then
                s = s or L.state(item, true)
                local snap = L.snapshot(item)
                local readings, changed, hit = {}, false, false
                for _, p in ipairs(snap) do
                    local last = s.pb and s.pb[p.key]
                    local b, dirt = p.blood, p.dirt
                    if last then
                        local db, dd = b - last[1], dirt - last[2]
                        if db > L.HIT_EPS or dd > L.HIT_EPS then
                            local poncho = cover[p.key]
                            local keep = poncho and 0 or (protected and L.PROTECT_KEEP or 1)
                            if keep < 1 then
                                b = last[1] + math.max(0, db) * keep
                                dirt = last[2] + math.max(0, dd) * keep
                                pcall(function()
                                    item:setBlood(p.part, b)
                                    item:setDirt(p.part, dirt)
                                end)
                                changed = true
                                if poncho then
                                    if L.isBagPoncho(poncho) then hitBag = poncho end
                                else
                                    hit = true
                                end
                            end
                        end
                    end
                    readings[p.key] = { b, dirt }
                end
                s.pb = readings
                if hit and protected then
                    s.pr = s.pr - L.PROTECT_WEAR
                    if s.pr <= 0 then s.pr = nil end
                end
                if changed then
                    L.recount(item, snap)
                    pcall(function() syncItemFields(player, item) end)
                end
            end
        end
    end
    if hitBag and DanTraits_Roll(L.TEAR_HIT) then tear(player, hitBag) end
end

-- each ten minutes: hard work wears a garbage bag poncho
function L.wearPonchos(player, working)
    if not gearOn() or not working then return end
    for _, item in ipairs(L.worn(player)) do
        if L.isBagPoncho(item) and DanTraits_Roll(L.TEAR_WORK) then tear(player, item) end
    end
end

-- the carried fabric protector or wax with a use left, or nil
L.PROTECTORS = { ["DanTraits.FabricProtector"] = true, ["DanTraits.FabricWax"] = true }
function L.findProtector(player)
    for _, item in ipairs(L.carried(player)) do
        if L.PROTECTORS[fullType(item) or ""] and DanTraits_ItemUses(item) > 0 then return item end
    end
    return nil
end
