-- Central heating and cooling the player installs: an electric furnace, a central air
-- conditioner and vents. No UI here: the actions call this, and the menu
-- (client/DansClimate_CentralMenu.lua) offers them.
--
-- All three are built from the build menu (scripts/DansClimate_entities.txt), and the
-- recipes have to be learned from a book and need Welding, Maintenance and Electrical.
-- A furnace and a central air conditioner are also heavy items to find and haul home
-- (Base.HVACFurnace, Base.HVACCondenser); the recipe uses one up, and taking the unit
-- out again (Central.remove) gives it back.
--
-- Tiles, all in appliances_hvac_01:
--   0-3    furnace, facing S, E, N, W            4-7    the same, working
--   8-11   central air conditioner               12-15  the same, working
--   16-17  vent (a floor register, two ways round)
-- The working tiles are only ever drawn over a unit.
--
-- How it works (the Java room model: Units, GameBridge):
--   * A furnace stands in a room of a map building and heats that building. A central
--     air conditioner stands outdoors, right against a wall of the building it cools.
--   * A room gets none of it without a vent. The units' output is shared over the
--     floor of the rooms that have one: past 120 tiles for each unit, every extra room
--     makes all of them slower.
--   * They work through the building's thermostat, and don't need the grid: a
--     generator reaching the unit is enough.
--   * A unit is switched on until somebody switches it off (ModData DansClimateHVAC,
--     on = false). It burns generator fuel only while it is working.
require "DansClimate_Climate"

DansClimate = DansClimate or {}
local Central = {}
DansClimate.Central = Central

Central.TILESET = "appliances_hvac_01"
Central.MODDATA = "DansClimateHVAC"
Central.RUN_OFFSET = 4
-- kind = first and last tile, the item it is installed from and given back as
Central.KINDS = {
    furnace = { first = 0, last = 3, item = "Base.HVACFurnace" },
    condenser = { first = 8, last = 11, item = "Base.HVACCondenser" },
    vent = { first = 16, last = 17 },
}
-- The build recipes, by kind (the entity names in DansClimate_entities.txt).
Central.RECIPES = { furnace = "DansClimate_Furnace", condenser = "DansClimate_CentralAC", vent = "DansClimate_Vent" }
-- A working central air conditioner is louder than a window unit: this many times the
-- sandbox's Window Air Conditioner Noise, every HUM_MINUTES game minutes.
Central.NOISE_FACTOR = 1.5
Central.HUM_MINUTES = 5

local function tileIndex(obj)
    local sprite = obj and obj.getSprite and obj:getSprite()
    local name = sprite and sprite:getName()
    if not name or name:sub(1, #Central.TILESET + 1) ~= Central.TILESET .. "_" then return nil end
    return tonumber(name:sub(#Central.TILESET + 2))
end

-- "furnace", "condenser" or "vent" for one of the mod's central objects; nil otherwise
function Central.kind(obj)
    local n = tileIndex(obj)
    if not n then return nil end
    for kind, k in pairs(Central.KINDS) do
        if n >= k.first and n <= k.last then return kind end
    end
    return nil
end

-- a furnace or a central air conditioner
function Central.isUnit(obj)
    local kind = Central.kind(obj)
    return kind == "furnace" or kind == "condenser"
end

function Central.isVent(obj) return Central.kind(obj) == "vent" end

-- every tile an object of ours can be (the working tiles are never an object's own sprite)
function Central.spriteNames()
    local names = {}
    for _, kind in ipairs({ "furnace", "condenser", "vent" }) do
        local k = Central.KINDS[kind]
        for i = k.first, k.last do names[#names + 1] = Central.TILESET .. "_" .. i end
    end
    return names
end

local function data(obj, create)
    local md = obj:getModData()
    local d = md[Central.MODDATA]
    if not d and create then
        d = {}
        md[Central.MODDATA] = d
    end
    return d
end

-- A unit is switched on until somebody switches it off.
function Central.isOn(obj)
    if not Central.isUnit(obj) then return false end
    local d = data(obj)
    return not (d and d.on == false)
end

-- The indoor square a central air conditioner is hooked up through: the first of the
-- four squares beside it that is in a map building's room (north, west, south, east,
-- the order Units.condenserInner uses). Nil if it stands away from any building.
function Central.inner(obj)
    local sq = obj:getSquare()
    if not sq then return nil end
    local cell = getCell()
    for _, d in ipairs({ { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 0 } }) do
        local n = cell:getGridSquare(sq:getX() + d[1], sq:getY() + d[2], sq:getZ())
        if n and n:getRoom() then return n end
    end
    return nil
end

-- The square in the building this object belongs to: a furnace's or a vent's own
-- square when it is in a room, the square a central air conditioner is hooked up
-- through. Nil when it serves nothing where it stands.
function Central.servedSquare(obj)
    local kind = Central.kind(obj)
    if not kind then return nil end
    if kind == "condenser" then return Central.inner(obj) end
    local sq = obj:getSquare()
    if sq and sq:getRoom() then return sq end
    return nil
end

-- Power: a generator reaching it, or the grid through the building it serves.
function Central.isPowered(obj)
    local sq = obj:getSquare()
    if not sq or not Central.isUnit(obj) then return false end
    if sq:haveElectricity() then return true end
    local served = Central.servedSquare(obj)
    if not served then return false end
    return served:haveElectricity() or getWorld():isHydroPowerOn() == true
end

-- A number about the building this object serves (C.central); 0 where it serves none.
function Central.info(obj, what)
    local served = Central.servedSquare(obj)
    if not served then return 0 end
    return DansClimate.Climate.central(served, what)
end

-- Working right now: on, powered, a room has a vent, and the thermostat is asking.
function Central.running(obj)
    if not Central.isUnit(obj) then return false end
    return DansClimate.Climate.centralRunning(obj:getSquare())
end

-- The working tile drawn over a unit while it works.
function Central.syncOverlay(obj)
    local n = Central.isUnit(obj) and tileIndex(obj)
    if not n then return end
    local want = Central.running(obj) and (Central.TILESET .. "_" .. (n + Central.RUN_OFFSET)) or nil
    local current = obj:getOverlaySprite()
    local have = current and current:getName() or nil
    if have ~= want then obj:setOverlaySprite(want, isServer()) end
end

-- Tell the room model and the generators that something changed, so they look now
-- rather than within ten game minutes (nothing without the Java side).
local function changed(obj, sq)
    DansClimate.Climate.refresh(sq or obj:getSquare())
end

function Central.setOn(obj, on)
    if not Central.isUnit(obj) then return end
    data(obj, true).on = on and true or false
    if isServer() then obj:transmitModData() end
    changed(obj)
    Central.syncOverlay(obj)
end

-- Take a unit or a vent out. A furnace or a central air conditioner comes back as the
-- item it was installed from; a vent's sheet metal doesn't.
function Central.remove(obj)
    local kind = Central.kind(obj)
    local sq = obj:getSquare()
    if not kind or not sq then return nil end
    triggerEvent("OnObjectAboutToBeRemoved", obj)
    sq:transmitRemoveItemFromSquare(obj)
    sq:RecalcProperties()
    sq:RecalcAllWithNeighbours(true)
    changed(obj, sq)
    local item = Central.KINDS[kind].item
    return item and instanceItem(item) or nil
end

-- How far away zombies hear a working central air conditioner, in squares (0: not at all).
function Central.noiseRadius(obj)
    if Central.kind(obj) ~= "condenser" or not Central.running(obj) then return 0 end
    local base = DansClimate.Climate.sandbox("ACNoise", 8)
    return math.max(0, math.ceil(base * Central.NOISE_FACTOR))
end

function Central.hum(obj)
    local radius = Central.noiseRadius(obj)
    local sq = obj:getSquare()
    if radius <= 0 or not sq then return 0 end
    addSound(obj, sq:getX(), sq:getY(), sq:getZ(), radius, radius)
    return radius
end

-- What a unit is doing, as a translation key's suffix and its arguments:
--   NoBuilding, Off, NoPower, NoVents, Idle, Running, or Thin (working, but the vented
--   floor is this many times what its kind serves at full strength: "2.5")
function Central.state(obj)
    local kind = Central.kind(obj)
    if kind ~= "furnace" and kind ~= "condenser" then return nil end
    if not Central.servedSquare(obj) then return "NoBuilding" end
    if not Central.isOn(obj) then return "Off" end
    if not Central.isPowered(obj) then return "NoPower" end
    if Central.info(obj, "vents") <= 0 then return "NoVents" end
    if not Central.running(obj) then return "Idle" end
    local share = Central.info(obj, kind == "furnace" and "heatShare" or "coolShare")
    if share > 0 and share < 0.95 then return "Thin", string.format("%.1f", 1 / share) end
    return "Running"
end

-- What a vent is connected to: NoRoom, None, Heat, Cool or Both.
function Central.ventState(obj)
    local served = Central.servedSquare(obj)
    if not served then return "NoRoom" end
    return DansClimate.Climate.centralKinds(served) or "None"
end

return Central
