-- Room temperatures: the Lua side of the Java model (GameBridge and ZoneModel in
-- java/src). The model runs in Java, because the game asks for a square's
-- temperature in Java many times a tick; Lua drives it once a game minute, keeps the
-- thermostats in global ModData, and hands them over.
--
-- DansClimateJava is the Java API (Api.java, exposed by ZombieBuddy). Without
-- ZombieBuddy or the approved jar it's nil, and everything here does nothing.
--
-- A thermostat belongs to a map building, named by its BuildingDef's corner (x, y).
-- Buildings never set run on the default: Auto, heat to 21 C, cool to 24 C.

DansClimate = DansClimate or {}
local C = {}
DansClimate.Climate = C

C.MODDATA = "DansClimate"
C.MODES = { "OFF", "HEAT", "COOL", "AUTO" }
C.DEFAULT = { mode = "AUTO", heat = 21, cool = 24 }
C.HEAT_SETPOINTS = { 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26 }
C.COOL_SETPOINTS = { 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 }
C.NO_READING = -999

function C.java() return DansClimateJava end

-- the Java model is there and running
function C.available()
    local java = DansClimateJava
    return java ~= nil and java.enabled() == true
end

-- the map building a square is in, as its BuildingDef corner; nil outdoors
function C.buildingOf(sq)
    local building = sq and sq:getBuilding()
    local def = building and building:getDef()
    if not def then return nil end
    return def:getX(), def:getY()
end

function C.key(bx, by) return bx .. "," .. by end

local function parseKey(key)
    local comma = string.find(key, ",", 1, true)
    if not comma then return nil end
    return tonumber(string.sub(key, 1, comma - 1)), tonumber(string.sub(key, comma + 1))
end

local function stored()
    local data = ModData.getOrCreate(C.MODDATA)
    data.thermostats = data.thermostats or {}
    return data.thermostats
end

-- mode, heat, cool for a building
function C.getThermostat(bx, by)
    local t = stored()[C.key(bx, by)]
    if t then return t.mode, t.heat, t.cool end
    return C.DEFAULT.mode, C.DEFAULT.heat, C.DEFAULT.cool
end

function C.setThermostat(bx, by, mode, heat, cool)
    if cool < heat then cool = heat end
    stored()[C.key(bx, by)] = { mode = mode, heat = heat, cool = cool }
    local java = DansClimateJava
    if java then java.setThermostat(bx, by, mode, heat, cool) end
end

-- every saved thermostat to Java (the model keeps none of its own across a load)
function C.pushAll()
    local java = DansClimateJava
    if not java then return end
    for key, t in pairs(stored()) do
        local bx, by = parseKey(key)
        if bx and by then java.setThermostat(bx, by, t.mode, t.heat, t.cool) end
    end
end

-- the room temperature at a square in C, or nil outdoors or without the model
function C.temperatureAt(sq)
    local java = DansClimateJava
    if not java or not sq then return nil end
    local t = java.temperatureAt(sq:getX(), sq:getY(), sq:getZ())
    if not t or t <= C.NO_READING then return nil end
    return t
end

-- the model's readout for the room at a square, or nil
function C.readout(sq)
    local java = DansClimateJava
    if not java or not sq then return nil end
    local text = java.readout(sq:getX(), sq:getY(), sq:getZ())
    if not text or text == "" then return nil end
    return text
end

-- look at the windows and units around a square again (after one changes)
function C.refresh(sq)
    local java = DansClimateJava
    if java and sq then java.refreshAt(sq:getX(), sq:getY(), sq:getZ()) end
end

-- the building's heating and cooling has power: the grid, or a generator reaching it
function C.powered(sq)
    if not sq then return false end
    return getWorld():isHydroPowerOn() or sq:haveElectricity()
end

function C.tick()
    local java = DansClimateJava
    if java then java.tick() end
end

-- a temperature in the player's chosen unit, rounded: "21 °C" or "70 °F"
function C.format(celsius)
    local value = celsius
    local key = "IGUI_DansClimate_Celsius"
    if not getCore():getOptionDisplayAsCelsius() then
        value = celsius * 9 / 5 + 32
        key = "IGUI_DansClimate_Fahrenheit"
    end
    return getText(key, tostring(math.floor(value + 0.5)))
end

Events.OnInitGlobalModData.Add(C.pushAll)
if not isClient() then Events.EveryOneMinute.Add(C.tick) end

return C
