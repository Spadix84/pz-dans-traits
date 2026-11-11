-- Window air conditioner: finding units and windows, which way a unit faces, putting
-- one in a window and taking it out. No UI here: the actions call this, and the menu
-- (client/DansClimate_WindowACMenu.lua) offers them.
--
-- A unit is a plain IsoObject on the window's own square, tile appliances_windowac_01_N:
--   0-3 off, facing S, E, N, W; 4-7 the same switched on.
-- The facing is the way the front grille points, so the room it cools is on that side.
-- S and N sit in a window on the square's north edge, E and W in its west edge.
-- Its ModData (DansClimateAC) keeps the item's condition, so taking it out gives the
-- same unit back, and its controls: level ("LOW" or "HIGH", the fan) and set (the
-- temperature its dial is at, in C). The Java room model reads the same table (Units).
-- Taken out of the window, the item carries the fan and the dial in its own ModData,
-- so the unit goes back in as it was set, switched off.

DansClimate = DansClimate or {}
local AC = {}
DansClimate.WindowAC = AC

AC.TILESET = "appliances_windowac_01"
AC.ITEM = "Base.WindowAC"
AC.FACINGS = { "S", "E", "N", "W" }    -- tile order
AC.ON_OFFSET = 4
AC.MODDATA = "DansClimateAC"
AC.LEVELS = { "LOW", "HIGH" }
AC.DEFAULT_LEVEL = "HIGH"
AC.DEFAULT_SET = 22
AC.SETPOINTS = { 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 }
-- How far zombies hear one running on High, in squares, when the sandbox doesn't say
-- (Window Air Conditioner Noise); on Low it carries LOW_NOISE of that. It hums every
-- HUM_MINUTES game minutes (server/DansClimate_WindowACServer.lua).
AC.NOISE = 8
AC.LOW_NOISE = 0.6
AC.HUM_MINUTES = 5

local INDEX = { S = 0, E = 1, N = 2, W = 3 }

function AC.spriteName(facing, on)
    return AC.TILESET .. "_" .. (INDEX[facing] + (on and AC.ON_OFFSET or 0))
end

function AC.spriteNames()
    local names = {}
    for i = 0, 2 * AC.ON_OFFSET - 1 do names[#names + 1] = AC.TILESET .. "_" .. i end
    return names
end

-- facing, on for a unit's object; nil for anything else
function AC.parse(obj)
    local sprite = obj and obj.getSprite and obj:getSprite()
    local name = sprite and sprite:getName()
    if not name or name:sub(1, #AC.TILESET + 1) ~= AC.TILESET .. "_" then return nil end
    local n = tonumber(name:sub(#AC.TILESET + 2))
    if not n or n < 0 or n >= 2 * AC.ON_OFFSET then return nil end
    return AC.FACINGS[(n % AC.ON_OFFSET) + 1], n >= AC.ON_OFFSET
end

function AC.isUnit(obj) return AC.parse(obj) ~= nil end

-- S and N sit in the square's north edge
function AC.isNorthEdge(facing) return facing == "S" or facing == "N" end

-- the unit in this window, if there is one
function AC.inWindow(window)
    local sq = window and window:getSquare()
    if not sq then return nil end
    local north = window:isNorth()
    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local facing = AC.parse(obj)
        if facing and AC.isNorthEdge(facing) == north then return obj end
    end
    return nil
end

-- the window a unit sits in
function AC.windowOf(unit)
    local facing = AC.parse(unit)
    local sq = facing and unit:getSquare()
    if not sq then return nil end
    local north = AC.isNorthEdge(facing)
    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoWindow") and obj:isNorth() == north then return obj end
    end
    return nil
end

-- The facing for a unit put in from the character's side: the front grille faces them.
-- getAddSheetSquare is the square on the character's side of the window (vanilla
-- uses it for hanging a sheet on the inside).
function AC.facingFor(window, character)
    local side = window:getAddSheetSquare(character)
    local own = side == nil or side == window:getSquare()
    if window:isNorth() then return own and "S" or "N" end
    return own and "E" or "W"
end

-- the square in front of the unit: the room it cools
function AC.roomSquare(unit)
    local facing = AC.parse(unit)
    local sq = facing and unit:getSquare()
    if not sq then return nil end
    if facing == "S" or facing == "E" then return sq end
    local dx, dy = 0, 0
    if facing == "N" then dy = -1 else dx = -1 end
    return getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
end

-- Why a unit can't go in this window, as a translation key, or nil if it can.
-- Open windows are fine (the action closes them); smashed or glass-removed ones too:
-- the unit and its side panels fill the opening.
function AC.installProblem(window)
    if not window or not instanceof(window, "IsoWindow") or window:getObjectIndex() == -1 then
        return "Tooltip_DansClimate_NotAWindow"
    end
    if AC.inWindow(window) then return "Tooltip_DansClimate_HasUnit" end
    if window:isBarricaded() then return "Tooltip_DansClimate_Barricaded" end
    return nil
end

local function notBroken(item) return not item:isBroken() end

function AC.findScrewdriver(inv)
    return inv:getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, notBroken)
end

function AC.findUnitItem(inv)
    return inv:getFirstTypeRecurse(AC.ITEM)
end

-- Tell the room model a unit changed, so it looks at the window now rather than within
-- ten game minutes (DansClimate_Climate.lua; nothing without the Java side).
local function changed(sq)
    local climate = DansClimate.Climate
    if climate and sq then climate.refresh(sq) end
end

-- After the window on the same square, so it draws over the window and frame.
local function insertIndex(sq, window)
    local objects = sq:getObjects()
    local index = objects:size()
    for i = 0, objects:size() - 1 do
        if objects:get(i) == window then index = i + 1 end
    end
    return index
end

-- Put a unit in the window, switched off. Closes the window first, at once:
-- character:closeWindow only queues the character's close animation, which the install
-- action never lets play. Returns the object.
function AC.install(window, facing, item, character)
    if window:IsOpen() and not window:isSmashed() then window:ToggleWindow(character) end
    local sq = window:getSquare()
    local unit = IsoObject.new(getCell(), sq, AC.spriteName(facing, false))
    local carried = item and item:getModData()[AC.MODDATA]
    unit:getModData()[AC.MODDATA] = {
        condition = item and item:getCondition() or nil,
        level = carried and carried.level or nil,
        set = carried and tonumber(carried.set) or nil,
    }
    sq:AddSpecialObject(unit, insertIndex(sq, window))
    if isServer() then unit:transmitCompleteItemToClients() end
    sq:RecalcProperties()
    sq:RecalcAllWithNeighbours(true)
    triggerEvent("OnObjectAdded", unit)
    changed(sq)
    return unit
end

-- Take a unit out of its window. Returns a new item with the unit's condition.
function AC.remove(unit)
    local sq = unit:getSquare()
    local data = unit:getModData()[AC.MODDATA]
    triggerEvent("OnObjectAboutToBeRemoved", unit)
    sq:transmitRemoveItemFromSquare(unit)
    sq:RecalcProperties()
    sq:RecalcAllWithNeighbours(true)
    changed(sq)
    local item = instanceItem(AC.ITEM)
    if item and data and data.condition then item:setCondition(data.condition) end
    if item and data and (data.level or data.set) then
        item:getModData()[AC.MODDATA] = { level = data.level, set = data.set }
    end
    return item
end

-- Power: a generator reaching the window's square or the room's, or the grid while
-- the room side is indoors.
function AC.isPowered(unit)
    local sq = unit:getSquare()
    local front = AC.roomSquare(unit)
    if (sq and sq:haveElectricity()) or (front and front:haveElectricity()) then return true end
    return front ~= nil and front:getRoom() ~= nil and getWorld():isHydroPowerOn()
end

function AC.isOn(unit)
    local _, on = AC.parse(unit)
    return on == true
end

-- Switch it on or off. The tile is the state: the Java model (GameBridge) cools the
-- room for a unit showing an "on" tile that has power.
function AC.setOn(unit, on)
    local facing = AC.parse(unit)
    if not facing then return end
    unit:setSpriteFromName(AC.spriteName(facing, on))
    if isServer() then unit:transmitUpdatedSpriteToClients() end
    changed(AC.roomSquare(unit) or unit:getSquare())
end

local function data(unit, create)
    local md = unit:getModData()
    local d = md[AC.MODDATA]
    if not d and create then
        d = {}
        md[AC.MODDATA] = d
    end
    return d
end

-- the fan: "LOW" or "HIGH"
function AC.level(unit)
    local d = data(unit)
    return d and d.level == "LOW" and "LOW" or AC.DEFAULT_LEVEL
end

-- the temperature its dial is at, in C: it cools the room down to this and no further
function AC.setpoint(unit)
    local d = data(unit)
    return d and tonumber(d.set) or AC.DEFAULT_SET
end

local function controlsChanged(unit)
    if isServer() then unit:transmitModData() end
    changed(AC.roomSquare(unit) or unit:getSquare())
end

function AC.setLevel(unit, level)
    if not AC.isUnit(unit) or (level ~= "LOW" and level ~= "HIGH") then return end
    data(unit, true).level = level
    controlsChanged(unit)
end

function AC.setSetpoint(unit, value)
    value = tonumber(value)
    if not AC.isUnit(unit) or not value then return end
    data(unit, true).set = value
    controlsChanged(unit)
end

-- How far zombies hear this unit, in squares: 0 switched off, without power, or with
-- the sandbox's noise at 0.
function AC.noiseRadius(unit)
    if not AC.isOn(unit) or not AC.isPowered(unit) then return 0 end
    local climate = DansClimate.Climate
    local radius = climate and climate.sandbox("ACNoise", AC.NOISE) or AC.NOISE
    if AC.level(unit) == "LOW" then radius = radius * AC.LOW_NOISE end
    return math.max(0, math.ceil(radius))
end

-- One hum: a world sound at the unit that zombies in range turn towards. (What the
-- player hears is a loop the Java side plays, UnitHum.) Returns the radius, 0 for none.
function AC.hum(unit)
    local radius = AC.noiseRadius(unit)
    local sq = unit:getSquare()
    if radius <= 0 or not sq then return 0 end
    addSound(unit, sq:getX(), sq:getY(), sq:getZ(), radius, radius)
    return radius
end

return AC
