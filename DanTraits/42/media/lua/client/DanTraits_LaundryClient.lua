-- Project Zomboid Vitality Project: laundry, the menus and the tooltip lines
-- (shared/DanTraits_Laundry*.lua do the work).
--
-- The wash menu. The game builds Wash and Wash All in Java and hands the
-- garments to ISWorldObjectContextMenu.onWashClothing. Garments that a hand
-- wash here could not get any cleaner (or fresher) are taken out before
-- anything is queued, so Wash All does not walk over and spend water and
-- time on them; if that leaves nothing, the character says why and stays put.
-- The action checks again when it finishes, since the soap can run out.
--
-- At a water source, two more options:
--   Freshen Up Clothes (N)  carried garments that are stale or musty but not
--                           dirty or bloody (the game's menu leaves those out)
--   Bleach Stains (N)       carried garments with a set-in stain, with bleach
--                           carried (0.1 L each)
-- At a lit fire or stove, or on a damp garment within reach of one:
--   Dry by the Fire (N)     carried damp garments, one action each
-- On a garment, with fabric protector or fabric wax carried:
--   Protect Fabric
-- Anywhere on the ground (clotheslines on):
--   Put up a clothesline > Running east-west / north-south (offered with two
--                           long sticks, planks or saplings and two rope, twine,
--                           sheet or denim strips or wire carried; greyed when
--                           the two squares are not clear floor)
--   Take down clothesline   on one put up that way
-- A clothesline post right-clicked gets its container at once (the clock
-- would give it one within ten minutes anyway).
--
-- Garment tooltips get the laundry state in the shared strip under the
-- tooltip (DanShared_Tooltip.lua, with Reading's lines and Dan's Vanilla
-- Fixes' item info): damp (and how long before musty), stale or musty, a
-- set-in stain, fabric protector left, washes so far.
require "ISUI/ISWorldObjectContextMenu"
require "DanShared_Tooltip"
require "DanTraits_Laundry"
require "DanTraits_LaundryWash"
require "DanTraits_LaundryDry"
require "DanTraits_LaundryGear"

local L = DanTraits_Laundry

local function soapOf(playerObj)
    local list, uses = nil, 0
    pcall(function()
        list = playerObj:getInventory():getSoapList(nil, true)
        uses = ISWashClothing.GetSoapRemaining(list)
    end)
    return list, (uses or 0) > 0
end

-- the wash menu: only what this wash can improve
local vanillaOnWash = ISWorldObjectContextMenu.onWashClothing
ISWorldObjectContextMenu.onWashClothing = function(playerObj, sink, soapList, washList, singleClothing)
    if not L.on() then return vanillaOnWash(playerObj, sink, soapList, washList, singleClothing) end
    local soap = false
    pcall(function() soap = soapList ~= nil and ISWashClothing.GetSoapRemaining(soapList) > 0 end)
    local method = L.methodFor(playerObj)
    local skilled = L.skilled(playerObj)
    local keep = {}
    for _, item in ipairs(washList or { singleClothing }) do
        if L.canGain(item, method, soap, skilled) then keep[#keep + 1] = item end
    end
    if #keep == 0 then
        L.message(playerObj, method, soap)
        return
    end
    return vanillaOnWash(playerObj, sink, soapList, keep, nil)
end

-- helpers -----------------------------------------------------------------------------

local function greyOut(option, key)
    option.notAvailable = true
    pcall(function()
        local tip = ISWorldObjectContextMenu.addToolTip()
        tip.description = getText(key)
        option.toolTip = tip
    end)
end

-- the water source among the clicked objects (the game's own fetch first)
local function waterSource(worldobjects)
    local candidates = {}
    pcall(function()
        local sw = ISWorldObjectContextMenu.fetchVars and ISWorldObjectContextMenu.fetchVars.storeWater
        if type(sw) == "table" then
            for _, o in pairs(sw) do candidates[#candidates + 1] = o end
        elseif sw then
            candidates[1] = sw
        end
    end)
    for _, o in ipairs(worldobjects or {}) do candidates[#candidates + 1] = o end
    for _, o in ipairs(candidates) do
        local ok, water = pcall(function() return o:hasWater() end)
        if ok and water == true then return o end
    end
    return nil
end

local function notWorn(playerObj, item)
    local worn = false
    pcall(function() worn = playerObj:isEquippedClothing(item) == true end)
    if not worn then pcall(function() worn = playerObj:isEquipped(item) == true end) end
    return not worn
end

local function clean(item)
    local dirty = false
    pcall(function() dirty = item:getDirtiness() > 0 or item:getBloodlevel() > 0 end)
    return not dirty
end

-- carried clothing that passes the test; worn clothing too when includeWorn
-- (washing and bleaching take what you wear, as the game's own Wash does;
-- drying by the fire does not: worn clothes dry on the body)
local function carriedClothing(playerObj, test, includeWorn)
    local out = {}
    for _, item in ipairs(L.carried(playerObj)) do
        if L.isClothing(item) and (includeWorn or notWorn(playerObj, item)) and test(item) then out[#out + 1] = item end
    end
    return out
end

local function damp(item) return L.wetness(item) >= L.C.DRY_AT end

-- at a water source ----------------------------------------------------------------------

local function onFreshen(playerObj, source, items)
    local soapList = soapOf(playerObj)
    ISWorldObjectContextMenu.onWashClothing(playerObj, source, soapList, items, nil)
end

local function onBleach(playerObj, source, items)
    if not luautils.walkAdjObject(playerObj, source, true, true) then return end
    for _, item in ipairs(items) do
        local bleach = L.findBleach(playerObj)
        if not bleach then break end
        ISTimedActionQueue.add(ISLaundryAction:new(playerObj, item, "bleach", source, bleach, L.waterFor(item)))
    end
end

local function waterMenu(playerObj, context, source)
    local stale = carriedClothing(playerObj, function(item) return clean(item) and L.isStale(L.state(item, false)) end, true)
    if #stale > 0 then
        context:addOption(getText("ContextMenu_DanTraits_Freshen", #stale), playerObj, onFreshen, source, stale)
    end
    local stained = carriedClothing(playerObj, L.hasStain, true)
    if #stained > 0 then
        local option = context:addOption(getText("ContextMenu_DanTraits_BleachStainsN", #stained), playerObj, onBleach, source, stained)
        if not L.findBleach(playerObj) then greyOut(option, "Tooltip_DanTraits_NeedBleach") end
    end
end

-- by the fire --------------------------------------------------------------------------

local function onDryByFire(playerObj, heat, items)
    for _, item in ipairs(items) do
        if damp(item) then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
            ISTimedActionQueue.add(ISLaundryAction:new(playerObj, item, "fire", heat))
        end
    end
end

local function clickedHeat(worldobjects)
    for _, o in ipairs(worldobjects or {}) do
        local sq = nil
        pcall(function() sq = o:getSquare() end)
        local heat = L.litHeatOn(sq)
        if heat then return heat end
    end
    return nil
end

local function fireMenu(playerObj, context, heat)
    local wet = carriedClothing(playerObj, damp)
    if #wet == 0 then return end
    context:addOption(getText("ContextMenu_DanTraits_DryByFireN", #wet), playerObj, function()
        if luautils.walkAdj(playerObj, heat:getSquare(), true) then onDryByFire(playerObj, heat, wet) end
    end)
end

-- clotheslines: put one up on the clicked square, or take a built one down.
-- The walk goes to a square off the line (L.lineStandSquare): the action
-- re-checks every line square is free each tick, and walkAdj could end on
-- the first wire square and cancel it.
local function onPutUp(playerObj, sq, dir)
    local mats = L.lineMaterials(playerObj)
    if not mats then return end
    local stand = L.lineStandSquare(playerObj, sq, dir)
    if not stand then return end
    local there = false
    pcall(function() there = playerObj:getCurrentSquare() == stand end)
    if not there then ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, stand)) end
    ISTimedActionQueue.add(ISLaundryAction:new(playerObj, mats.posts[1], "putup", sq, dir))
end

local function onTakeDown(playerObj, post)
    if not luautils.walkAdj(playerObj, post:getSquare(), true) then return end
    ISTimedActionQueue.add(ISLaundryAction:new(playerObj, nil, "takedown", post))
end

local function lineMenu(playerObj, context, worldobjects)
    local sq, built = nil, nil
    for _, o in ipairs(worldobjects or {}) do
        pcall(function()
            sq = sq or o:getSquare()
            local objects = o:getSquare():getObjects()
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                L.ensureLine(obj)
                if not built and L.isBuiltLine(obj) then built = obj end
            end
        end)
    end
    if built then
        context:addOption(getText("ContextMenu_DanTraits_TakeDownLine"), playerObj, onTakeDown, built)
        return
    end
    -- offered only with the materials to hand (every right-click on the ground would carry it otherwise)
    local mats = sq and L.lineMaterials(playerObj)
    if not mats then return end
    local parent = context:addOption(getText("ContextMenu_DanTraits_PutUpLine"))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)
    for _, dir in ipairs({ "ew", "ns" }) do
        local option = sub:addOption(getText("ContextMenu_DanTraits_Line_" .. dir), playerObj, onPutUp, sq, dir)
        if not L.lineSquares(sq, dir) then greyOut(option, "Tooltip_DanTraits_LineBlocked") end
    end
    pcall(function()
        local tip = ISWorldObjectContextMenu.addToolTip()
        tip.description = getText("Tooltip_DanTraits_ClotheslineBuild")
        parent.toolTip = tip
    end)
end

-- the world menu
local function onWorldMenu(playerNum, context, worldobjects, test)
    if test or not L.on() then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not context then return end
    if L.linesOn() then lineMenu(playerObj, context, worldobjects) end
    local source = waterSource(worldobjects)
    if source then waterMenu(playerObj, context, source) end
    local heat = clickedHeat(worldobjects)
    if heat then fireMenu(playerObj, context, heat) end
end
Events.OnFillWorldObjectContextMenu.Add(onWorldMenu)

-- the inventory menu --------------------------------------------------------------------

local function actualItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then return ISInventoryPane.getActualItems(items) end
    return items
end

local function onProtect(playerObj, garments)
    for _, item in ipairs(garments) do
        local agent = L.findProtector(playerObj)
        if not agent then break end
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, agent)
        ISTimedActionQueue.add(ISLaundryAction:new(playerObj, item, "protect", nil, agent))
    end
end

local function onInventoryMenu(playerNum, context, items)
    if not L.on() then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    local garments = {}
    for _, item in ipairs(actualItems(items)) do
        if L.isClothing(item) then garments[#garments + 1] = item end
    end
    if #garments == 0 then return end
    local wet = {}
    for _, item in ipairs(garments) do if damp(item) and notWorn(playerObj, item) then wet[#wet + 1] = item end end
    if #wet > 0 then
        local heat = L.findHeat(playerObj)
        if heat then context:addOption(getText("ContextMenu_DanTraits_DryByFire"), playerObj, onDryByFire, heat, wet) end
    end
    -- only offered with a protector or wax to hand (every garment would carry a grey line otherwise)
    if L.gearOn() and L.findProtector(playerObj) then
        context:addOption(getText("ContextMenu_DanTraits_ProtectFabric"), playerObj, onProtect, garments)
    end
end
Events.OnFillInventoryObjectContextMenu.Add(onInventoryMenu)

-- tooltip lines ------------------------------------------------------------------------

local GOOD = { r = 0.55, g = 0.8, b = 1 }
local BAD = { r = 1, g = 0.75, b = 0.45 }

-- { { text, bad } } for a garment, or nil
function L.tooltipLines(item)
    if not L.on() or not L.isClothing(item) then return nil end
    local s = L.state(item, false)
    local lines = {}
    local level = L.levelOf(s)
    if level == 2 then lines[#lines + 1] = { getText("Tooltip_DanTraits_Musty"), true }
    elseif level == 1 then lines[#lines + 1] = { getText("Tooltip_DanTraits_Stale"), true } end
    local hours = L.mustyIn(item)
    if hours then lines[#lines + 1] = { getText("Tooltip_DanTraits_DampHours", math.max(1, math.floor(hours + 0.5))), true } end
    if L.hasStain(item) then lines[#lines + 1] = { getText("Tooltip_DanTraits_Stain"), true } end
    local pr = (s and s.pr) or 0
    if pr > 0 then lines[#lines + 1] = { getText("Tooltip_DanTraits_ProtectorLeft", math.floor(pr * 100 + 0.5)), false } end
    if s and (s.n or 0) > 0 then lines[#lines + 1] = { getText("Tooltip_DanTraits_Washes", s.n), false } end
    lines = DanTraits_RunHooks("laundryTooltip", lines, item) or lines
    if #lines == 0 then return nil end
    return lines
end

-- into the shared strip (one strip for every feature, lowest order first, so
-- nothing draws over anything; a wrap of its own here painted a second box
-- over item info's "Covers:" line)
DanShared_Tooltip.add("laundry", 22, function(_, item)
    local lines = L.tooltipLines(item)
    if not lines then return nil end
    local out = {}
    for i, line in ipairs(lines) do
        local c = line[2] and BAD or GOOD
        out[i] = { line[1], c.r, c.g, c.b }
    end
    return out
end)

