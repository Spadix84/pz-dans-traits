-- Electric space heater: which objects are heaters, their switch, their low/high
-- setting and their dial, power, the glow and the warmth beside one. No UI here: the
-- actions call this, and the menu (client/DansClimate_HeaterMenu.lua) offers them.
--
-- A heater is a vanilla moveable, tile appliances_spaceheater_01_0-3 (facing S, E, N,
-- W), item Base.Mov_SpaceHeater: the game's own furniture tools pick it up, place it
-- and turn it. Tiles 4-7 are the same views with the elements glowing, drawn over the
-- heater while it runs.
--
-- Its ModData (DansClimateHeater) keeps on, level ("LOW" or "HIGH") and set (the
-- temperature its dial is at, in C). The Java room model (Units, GameBridge) reads the
-- same table: a switched-on, powered heater warms the room it stands in toward its
-- setting. Picked up and put down again it is switched off, but keeps its low/high
-- setting and its dial: those are also kept in the object's movableData, the one table
-- the game's furniture tools carry from an object to its item and back (Heater.restore).
--
-- Standing next to a running one is warm whatever the room is doing: while its
-- elements are on it is a small heat source of the game's own (IsoHeatSource), which
-- the game doesn't save, so the watcher (server/DansClimate_HeaterServer.lua) gives it
-- back as heaters load.
require "DansClimate_Climate"

DansClimate = DansClimate or {}
local Heater = {}
DansClimate.Heater = Heater

Heater.TILESET = "appliances_spaceheater_01"
Heater.ITEM = "Base.Mov_SpaceHeater"
Heater.FACINGS = { "S", "E", "N", "W" }   -- tile order
Heater.ON_OFFSET = 4
Heater.MODDATA = "DansClimateHeater"
Heater.LEVELS = { "LOW", "HIGH" }
Heater.DEFAULT_LEVEL = "HIGH"
Heater.DEFAULT_SET = 21
Heater.SETPOINTS = { 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 }
-- The warmth beside a running heater: an IsoHeatSource's radius in squares and its
-- temperature in C. The game fades it to nothing at the radius, and indoors takes up
-- to 7 off the temperature in a cold room: on High, one square away in a 15 C room,
-- it feels like 26 C.
Heater.HEAT = { LOW = { radius = 2, temperature = 34 }, HIGH = { radius = 3, temperature = 38 } }
-- The elements cut out once the room is this far over the dial's setting.
Heater.CUT_OUT = 0.5

Heater.sources = Heater.sources or setmetatable({}, { __mode = "k" })

-- 0-3 for a heater's object, its facing's place in the tile order; nil for anything else
function Heater.index(obj)
    local sprite = obj and obj.getSprite and obj:getSprite()
    local name = sprite and sprite:getName()
    if not name or name:sub(1, #Heater.TILESET + 1) ~= Heater.TILESET .. "_" then return nil end
    local n = tonumber(name:sub(#Heater.TILESET + 2))
    if not n or n < 0 or n >= Heater.ON_OFFSET then return nil end
    return n
end

function Heater.isUnit(obj) return Heater.index(obj) ~= nil end

function Heater.facing(obj)
    local n = Heater.index(obj)
    return n and Heater.FACINGS[n + 1]
end

-- the four tiles a heater can be (the glowing ones are never an object's own sprite)
function Heater.spriteNames()
    local names = {}
    for i = 0, Heater.ON_OFFSET - 1 do names[#names + 1] = Heater.TILESET .. "_" .. i end
    return names
end

local function data(obj, create)
    local md = obj:getModData()
    local d = md[Heater.MODDATA]
    if not d and create then
        d = {}
        md[Heater.MODDATA] = d
    end
    return d
end

function Heater.isOn(obj)
    if not Heater.isUnit(obj) then return false end
    local d = data(obj)
    return d ~= nil and d.on == true
end

function Heater.level(obj)
    local d = data(obj)
    return d and d.level == "LOW" and "LOW" or Heater.DEFAULT_LEVEL
end

function Heater.setpoint(obj)
    local d = data(obj)
    return d and tonumber(d.set) or Heater.DEFAULT_SET
end

-- Power: a generator reaching its square, or the grid while it stands indoors.
function Heater.isPowered(obj)
    local sq = obj:getSquare()
    if not sq then return false end
    if sq:haveElectricity() then return true end
    return sq:getRoom() ~= nil and getWorld():isHydroPowerOn()
end

-- The temperature its thermostat feels: the room's from the model, else the weather's
-- (outdoors, a room the player built, or no Java side).
function Heater.airAt(obj)
    local sq = obj:getSquare()
    local t = sq and DansClimate.Climate.temperatureAt(sq)
    if t then return t end
    local climate = getClimateManager and getClimateManager()
    return climate and climate:getTemperature() or nil
end

-- The elements are glowing: switched on, powered, and the room not yet over its setting.
function Heater.heating(obj)
    if not Heater.isOn(obj) or not Heater.isPowered(obj) then return false end
    local air = Heater.airAt(obj)
    return air == nil or air < Heater.setpoint(obj) + Heater.CUT_OUT
end

-- The glowing tile drawn over a heater that is switched on.
function Heater.syncOverlay(obj)
    local n = Heater.index(obj)
    if not n then return end
    local want = Heater.isOn(obj) and (Heater.TILESET .. "_" .. (n + Heater.ON_OFFSET)) or nil
    local current = obj:getOverlaySprite()
    local have = current and current:getName() or nil
    if have ~= want then obj:setOverlaySprite(want, isServer()) end
end

local function dropSource(obj)
    local have = Heater.sources[obj]
    if not have then return end
    getCell():removeHeatSource(have.source)
    Heater.sources[obj] = nil
end

-- Give a heater the heat source it should have now, or take it away.
function Heater.syncHeat(obj)
    local sq = Heater.isUnit(obj) and obj:getObjectIndex() ~= -1 and obj:getSquare()
    local want = sq and Heater.heating(obj) and Heater.HEAT[Heater.level(obj)] or nil
    local have = Heater.sources[obj]
    if have and (not want or have.radius ~= want.radius or have.temperature ~= want.temperature) then
        dropSource(obj)
        have = nil
    end
    if want and not have then
        local source = IsoHeatSource.new(sq:getX(), sq:getY(), sq:getZ(), want.radius, want.temperature)
        getCell():addHeatSource(source)
        Heater.sources[obj] = { source = source, radius = want.radius, temperature = want.temperature }
    end
end

-- A heater is gone (picked up, or its chunk unloaded): its warmth goes with it.
function Heater.forget(obj)
    dropSource(obj)
end

-- Tell the room model and the generators that a heater changed, so they look now
-- rather than within ten game minutes (nothing without the Java side).
local function changed(obj)
    Heater.syncOverlay(obj)
    Heater.syncHeat(obj)
    if isServer() then obj:transmitModData() end
    DansClimate.Climate.refresh(obj:getSquare())
end

function Heater.setOn(obj, on)
    if not Heater.isUnit(obj) then return end
    data(obj, true).on = on and true or nil
    changed(obj)
end

-- keep the controls where the furniture tools carry them
local function carry(obj)
    local d = data(obj, true)
    local md = obj:getModData()
    md.movableData = md.movableData or {}
    md.movableData[Heater.MODDATA] = { level = d.level, set = d.set }
end

function Heater.setLevel(obj, level)
    if not Heater.isUnit(obj) or (level ~= "LOW" and level ~= "HIGH") then return end
    data(obj, true).level = level
    carry(obj)
    changed(obj)
end

function Heater.setSetpoint(obj, value)
    value = tonumber(value)
    if not Heater.isUnit(obj) or not value then return end
    data(obj, true).set = value
    carry(obj)
    changed(obj)
end

-- A heater just put down: take its low/high setting and its dial back out of what the
-- furniture tools carried. It is switched off.
function Heater.restore(obj)
    if not Heater.isUnit(obj) then return end
    local md = obj:getModData()
    local carried = md.movableData and md.movableData[Heater.MODDATA]
    if md[Heater.MODDATA] or type(carried) ~= "table" then return end
    md[Heater.MODDATA] = { level = carried.level, set = tonumber(carried.set) }
end

return Heater
