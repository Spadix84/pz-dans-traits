-- Project Zomboid Vitality Project: Robbed.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- Robbed --------------------------------------------------------------------
-- You were robbed and shot, and left for dead. A start to nurse your way out
-- of, for points, in the family of A Really Bad Day and Wounded: a bullet
-- still in you, nothing on, nothing in your pockets, and the house you wake
-- in stripped bare. Applied exactly once, tracked in mod data so reloads and
-- respawns are safe; replayed from the console with `robbed` (`robbed house`
-- also empties the house again).
--
-- What it costs under the health overhaul: the bullet wound is a deep wound
-- with the bullet left in (DanTraits_Blood.lua: it bleeds at the deep-wound
-- rate, a third of it through a bandage, until tweezers get the bullet out
-- and the wound is stitched), on an arm, a leg or the torso, never the head,
-- neck or groin. The rag you tied round it yourself is a bandage of ripped
-- sheet already on the wound with RB_RAG_LIFE of life left (a fresh bandage
-- has 4, a ripped sheet 2). With the bullet in, the blood through it soaks
-- it in a few minutes (DanTraits_WoundCare.lua: 1.5 life per 1% of blood
-- through), and spent it still halves the bleed, so left alone you are pale
-- in about twenty minutes, in shock in about fifty and dead in about an
-- hour: a fresh bandage buys a quarter of an hour more each, tweezers and
-- stitches end it. Every open wound takes the hourly infection roll. The
-- stripping runs as a player-ready step (DanTraits_OnPlayerReady) at order
-- RB_READY_ORDER, before the starting kits at 40: the robbers took what you
-- had on you, not the medication the Starting Medication option deals out
-- after (a Type 1 diabetic still starts with insulin). The house: every
-- container in the building you wake in is emptied at the first game start
-- and kept empty for RB_GUARD_H hours (the game fills containers the first
-- time they are looked in, so OnFillContainer is watched too); the fridge,
-- freezer and stove keep what is in them, the robbers were not after your
-- dinner. The building is told by its definition's origin, not only its
-- rectangle (BuildingDef.x2/y2 are one past the last tile, and a row house
-- shares its party wall with the neighbour). Exclusive with A Really Bad Day
-- (both strip the clothes, and Bad Day plants supplies next door) and Hemophilia.
local RB_PARTS = { "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R",
    "Torso_Upper", "Torso_Lower", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }
local RB_RAG_LIFE = 1.5
local RB_RAG_TYPE = "Base.RippedSheets"
local RB_GUARD_H = 48            -- hours the house stays emptied against the game's lazy fill
local RB_READY_ORDER = 35        -- the stripping, before the starting kits (40)
local RB_FLOORS = 8              -- building floors looked at (z 0..7)
local RB_KEEP = { fridge = true, freezer = true, stove = true, microwave = true, oven = true }
local RB_NOTICE = "UI_DanTraits_RobbedWake"

local function robbedFresh(player)
    if not player or not hasTrait(player, "robbed") then return nil end
    if player:getHoursSurvived() > 0 then return nil end
    return traitData(player)
end

local function partOf(player, name)
    local part = nil
    pcall(function() part = player:getBodyDamage():getBodyPart(BodyPartType[name]) end)
    return part
end

-- the bullet wound, with your own rag round it; returns the part's name
local function shoot(player)
    local name = RB_PARTS[ZombRand(#RB_PARTS) + 1]
    local part = partOf(player, name)
    if not part then return nil end
    pcall(function() part:generateDeepWound() end)
    if not pcall(function() part:setHaveBullet(true, 0) end) then
        pcall(function() part:setHaveBullet(true) end)
    end
    if not pcall(function() part:setBandaged(true, RB_RAG_LIFE, false, RB_RAG_TYPE) end) then
        pcall(function() part:setBandaged(true, RB_RAG_LIFE) end)
    end
    return name
end

-- nothing on, nothing in the pockets: worn clothes are removed from the
-- inventory too, not just unequipped, and then the rest of the inventory goes
local function strip(player)
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
    pcall(function() player:getInventory():clear() end)
end

local function applyRobbed(player)
    local shot = shoot(player)
    strip(player)
    notify(player, RB_NOTICE)
    return shot
end

local function onRobbedReady(player)
    local d = robbedFresh(player)
    if not d or d.rbApplied then return end
    d.rbApplied = true
    d.rbShot = applyRobbed(player)
end

-- The house. Its footprint (the building definition's rectangle) is kept in
-- mod data as rbHouse so the fill guard can tell its containers from the
-- ones next door.
local function houseOf(player)
    local box = nil
    pcall(function()
        local def = player:getCurrentSquare():getBuildingDef()
        if def then box = { x = def:getX(), y = def:getY(), x2 = def:getX2(), y2 = def:getY2() } end
    end)
    return box
end

local function inHouse(box, x, y)
    return box and x >= box.x and x <= box.x2 and y >= box.y and y <= box.y2
end

-- a square of the house: in its rectangle, in a room, and that room's building
-- is this one (its definition starts where the house's does); a square whose
-- building cannot be read is taken on the rectangle and the room alone.
-- x, y when the caller knows them, else read from the square.
local function houseSquare(sq, box, x, y)
    local inside = false
    pcall(function()
        if sq == nil then return end
        if x == nil then x, y = sq:getX(), sq:getY() end
        if not inHouse(box, x, y) or sq:getRoom() == nil then return end
        local building = sq.getBuilding and sq:getBuilding() or nil
        local def = building and building:getDef() or nil
        inside = def == nil or (def:getX() == box.x and def:getY() == box.y)
    end)
    return inside
end

local function keep(cont)
    local kind = nil
    pcall(function() kind = cont:getType() end)
    return kind and RB_KEEP[string.lower(kind)] == true
end

-- empty a container and mark it looked in, so the game does not fill it later
local function ransack(cont)
    if keep(cont) then return false end
    pcall(function() cont:setExplored(true) end)
    if not pcall(function() cont:removeAllItems() end) then
        pcall(function() cont:clear() end)
    end
    return true
end

-- every container in the house's footprint, on every floor; returns how many were emptied
local function ransackHouse(box)
    if not box then return 0 end
    local n = 0
    local cell = getCell()
    for z = 0, RB_FLOORS - 1 do
        for x = box.x, box.x2 do
            for y = box.y, box.y2 do
                local sq = nil
                pcall(function() sq = cell:getGridSquare(x, y, z) end)
                if houseSquare(sq, box, x, y) then
                    pcall(function()
                        local objs = sq:getObjects()
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            local count = obj and obj.getContainerCount and obj:getContainerCount() or 0
                            for c = 0, count - 1 do
                                local cont = obj:getContainerByIndex(c)
                                if cont and ransack(cont) then n = n + 1 end
                            end
                        end
                    end)
                end
            end
        end
    end
    return n
end

local function onRobbedGameStart()
    local player = getSpecificPlayer(0)
    local d = robbedFresh(player)
    if not d or d.rbHouseDone then return end
    d.rbHouseDone = true
    d.rbHouse = houseOf(player)
    ransackHouse(d.rbHouse)
end

-- the game filled a container in the house after it was emptied: empty it again
local function onRobbedFillContainer(roomName, containerType, container)
    if not container or not instanceof(container, "ItemContainer") then return end   -- the game sometimes passes a loot-table entry
    local player = getSpecificPlayer(0)
    local d = player and hasTrait(player, "robbed") and traitData(player)
    local box = d and d.rbHouse
    if not box or player:getHoursSurvived() > RB_GUARD_H then return end
    local sq = nil
    pcall(function() sq = container:getParent():getSquare() end)
    if houseSquare(sq, box) then ransack(container) end
end

-- Console `robbed [house]` (Telemetry, via DanTraits_ExtraCommands): replay
-- the opening on the current character, for balancing it without a new
-- game. Skips the first-hour gate and the trait check and does not undo
-- what is already there. `house` also empties the building you stand in.
function DanTraits_RobbedReplay(player, withHouse)
    if not player then return "robbed: no player" end
    local d = traitData(player)
    d.rbApplied = true
    d.rbShot = applyRobbed(player)
    local text = "robbed: opening replayed, shot in the " .. tostring(d.rbShot or "nothing (no body parts)")
    if withHouse then
        d.rbHouseDone = true
        d.rbHouse = houseOf(player)
        text = text .. (d.rbHouse and (", house emptied (" .. tostring(ransackHouse(d.rbHouse)) .. " containers)") or ", no house (outdoors)")
    end
    return text
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.robbed = function(player, args) return DanTraits_RobbedReplay(player, args[1] == "house") end

DanTraits_OnPlayerReady("Robbed", onRobbedReady, RB_READY_ORDER)   -- before the kits (40)
Events.OnGameStart.Add(onRobbedGameStart)
Events.OnFillContainer.Add(onRobbedFillContainer)
