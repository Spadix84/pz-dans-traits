-- Base Unloader: reading the world. The zone (the building you are in or next
-- to, plus a margin, plus a circle round the container being unloaded), every
-- container in it as a plain record for the core, what to call a container and
-- where it is, the items of a source container as records, and finding a
-- container again from its key or a vehicle from its id when a run resumes.

require "BaseUnloader_Core"

local BU = BaseUnloader
BU_Scan = {}
local S = BU_Scan

-- sandbox ---------------------------------------------------------------------------

local function sandbox(name, default)
    local v
    pcall(function()
        local t = SandboxVars and SandboxVars.BaseUnloader
        if t then v = t[name] end
    end)
    if v == nil then return default end
    return v
end

function S.radius() return sandbox("Radius", 12) end
function S.pad() return sandbox("Pad", 4) end
function S.floors() return sandbox("Floors", 3) end

-- squares -----------------------------------------------------------------------------

function S.squareOf(thing)
    local sq
    pcall(function()
        if thing.getCurrentSquare then sq = thing:getCurrentSquare() end
        if not sq and thing.getSquare then sq = thing:getSquare() end
    end)
    return sq
end

-- the footprint of the building a square is in: { x1, y1, x2, y2 } or nil outdoors
function S.buildingBounds(sq)
    if not sq then return nil end
    local b
    pcall(function()
        local def = sq.getBuildingDef and sq:getBuildingDef() or nil
        if not def then
            local building = sq:getBuilding()
            def = building and building:getDef() or nil
        end
        if def then b = { def:getX(), def:getY(), def:getX2(), def:getY2() } end
    end)
    return b
end

-- The zone to list: the building the source (or the player) is in or stands
-- next to, grown by the margin, united with a circle of the radius round the
-- source. Floors: the source's floor and `floors` above and below.
function S.zone(player, sourceSq)
    local sq = sourceSq or S.squareOf(player)
    if not sq then return nil end
    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    local r, pad = S.radius(), S.pad()
    local zone = { x1 = cx - r, y1 = cy - r, x2 = cx + r, y2 = cy + r, cx = cx, cy = cy, cz = cz,
                   z1 = cz - S.floors(), z2 = cz + S.floors(), r = r, pad = pad }
    -- the building: the source's square, else a square round it (a car on the drive)
    local b = S.buildingBounds(sq)
    if not b then
        local cell = getCell()
        for d = 1, pad do
            for _, off in ipairs({ { d, 0 }, { -d, 0 }, { 0, d }, { 0, -d }, { d, d }, { -d, -d }, { d, -d }, { -d, d } }) do
                if not b then
                    local s2 = cell:getGridSquare(cx + off[1], cy + off[2], cz)
                    b = S.buildingBounds(s2)
                end
            end
        end
    end
    if b then
        zone.building = b
        zone.x1 = math.min(zone.x1, b[1] - pad)
        zone.y1 = math.min(zone.y1, b[2] - pad)
        zone.x2 = math.max(zone.x2, b[3] + pad)
        zone.y2 = math.max(zone.y2, b[4] + pad)
    end
    return zone
end

-- a square is in the zone: inside the padded building or within the radius of the source
function S.inZone(zone, x, y)
    if zone.building then
        local b = zone.building
        if x >= b[1] - zone.pad and x <= b[3] + zone.pad and y >= b[2] - zone.pad and y <= b[4] + zone.pad then
            return true
        end
    end
    local dx, dy = x - zone.cx, y - zone.cy
    return dx * dx + dy * dy <= zone.r * zone.r
end

-- names and places --------------------------------------------------------------------------

function S.kindLabel(kind)
    local t = getTextOrNull("IGUI_ContainerTitle_" .. tostring(kind))
    return t or tostring(kind)
end

-- what to call a container: the name on it, else the name saved for its key
-- (put back on it, in case the game did not keep it), else its kind
function S.nameOf(container, key)
    local custom
    pcall(function() custom = container:getCustomName() end)
    if custom and custom ~= "" then return custom, true end
    local saved = BU.store().names[key]
    if saved and saved ~= "" then
        pcall(function() container:setCustomName(saved) end)
        return saved, true
    end
    return S.kindLabel(container:getType()), false
end

function S.rename(container, key, name)
    local names = BU.store().names
    if name == nil or name == "" then
        names[key] = nil
        pcall(function() container:setCustomName(nil) end)
    else
        names[key] = name
        pcall(function() container:setCustomName(name) end)
    end
end

function S.roomName(sq)
    local name
    pcall(function()
        local room = sq:getRoom()
        if room then
            name = room:getName()
            if (not name or name == "") and room.getRoomDef and room:getRoomDef() then name = room:getRoomDef():getName() end
        end
    end)
    return BU.roomWords(name)
end

function S.floorLabel(z)
    local which, n = BU.floorKey(z)
    if n then return getText("IGUI_BU_Floor_" .. which, n) end
    return getText("IGUI_BU_Floor_" .. which)
end

-- "Kitchen, ground floor" or, with no room, "12 tiles north-east, ground floor"
function S.placeLabel(row, zone)
    local parts = {}
    if row.room then
        parts[#parts + 1] = row.room
    elseif zone then
        local dx, dy = row.x - zone.cx, row.y - zone.cy
        local dir = BU.compass(dx, dy)
        local tiles = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
        if dir and tiles > 0 then
            parts[#parts + 1] = getText("IGUI_BU_Tiles", tiles, getText("IGUI_BU_Dir_" .. dir))
        else
            parts[#parts + 1] = getText("IGUI_BU_Here")
        end
    end
    parts[#parts + 1] = S.floorLabel(row.z)
    return table.concat(parts, ", ")
end

-- containers ----------------------------------------------------------------------------------

local SKIP_KINDS = { floor = true }

local function histograms(container)
    local contents, cats, n = {}, {}, 0
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local ft = it:getFullType()
            contents[ft] = (contents[ft] or 0) + 1
            local cat = it:getDisplayCategory()
            if cat then cats[cat] = (cats[cat] or 0) + 1 end
            n = n + 1
        end
    end)
    return contents, cats, n
end

-- the record for one container of a world object
function S.row(obj, container, index, sq, zone)
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local kind = container:getType()
    local key = BU.key(x, y, z, kind, index)
    local name, named = S.nameOf(container, key)
    local contents, cats, count = histograms(container)
    local capacity, used = 0, 0
    pcall(function()
        capacity = container:getCapacity()
        used = container:getCapacityWeight()
    end)
    local row = { key = key, container = container, object = obj, x = x, y = y, z = z, kind = kind,
                  kindLabel = S.kindLabel(kind), name = name, named = named, room = S.roomName(sq),
                  contents = contents, cats = cats, count = count, capacity = capacity, used = used,
                  free = math.max(0, capacity - used) }
    row.place = S.placeLabel(row, zone)
    return row
end

local function rowsOnSquare(sq, zone, out, skipContainer)
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local ok, has = pcall(function() return obj:getContainer() ~= nil end)
        if ok and has then
            local n = 1
            pcall(function() if obj.getContainerCount then n = obj:getContainerCount() end end)
            for ci = 0, n - 1 do
                local c
                if ci == 0 then
                    c = obj:getContainer()
                else
                    pcall(function() c = obj:getContainerByIndex(ci) end)
                end
                if c and c ~= skipContainer and not SKIP_KINDS[c:getType()] then
                    out[#out + 1] = S.row(obj, c, ci, sq, zone)
                end
            end
        end
    end
end

-- every container in the zone, as records, sorted by room then name; the
-- source's own container is left out (it gets its own row)
function S.containers(zone, skipContainer)
    local out = {}
    if not zone then return out end
    local cell = getCell()
    for z = zone.z1, zone.z2 do
        for y = zone.y1, zone.y2 do
            for x = zone.x1, zone.x2 do
                if S.inZone(zone, x, y) then
                    local sq = cell:getGridSquare(x, y, z)
                    if sq then rowsOnSquare(sq, zone, out, skipContainer) end
                end
            end
        end
    end
    S.sort(out)
    return out
end

function S.sort(rows)
    table.sort(rows, function(a, b)
        local ra, rb = a.room or "~", b.room or "~"
        if a.z ~= b.z then return math.abs(a.z) < math.abs(b.z) end
        if ra ~= rb then return ra < rb end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
end

-- the container a key names, if it is still there (the object may have gone)
function S.resolve(key)
    local k = BU.parseKey(key)
    if not k then return nil end
    local sq = getCell():getGridSquare(k.x, k.y, k.z)
    if not sq then return nil end
    local found
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local ok, has = pcall(function() return obj:getContainer() ~= nil end)
        if ok and has and not found then
            local c
            if k.index == 0 then
                c = obj:getContainer()
            else
                pcall(function() c = obj:getContainerByIndex(k.index) end)
            end
            if c and c:getType() == k.kind then found = { container = c, object = obj, square = sq } end
        end
    end
    return found
end

-- items -----------------------------------------------------------------------------------------

-- an item as the core sees it
function S.itemRecord(it)
    local r = { item = it }
    pcall(function()
        r.id = it:getID()
        r.fullType = it:getFullType()
        r.category = it:getDisplayCategory()
        r.name = it:getDisplayName()
        r.weight = it:getActualWeight()
        r.favorite = it:isFavorite()
        r.equipped = it:isEquipped() or it:isWorn()
        r.food = it:IsFood()
        if r.food and it.getOffAgeMax then r.perishable = it:getOffAgeMax() < BU.NEVER_OFF end
    end)
    if not r.fullType then return nil end
    r.weight = r.weight or 0
    r.name = r.name or r.fullType
    return r
end

-- the items of a container as records; the player's own inventory also skips
-- the bags being worn and what is inside them
function S.items(container)
    local out = {}
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local r = S.itemRecord(items:get(i))
            if r then out[#out + 1] = r end
        end
    end)
    return out
end

-- sources ---------------------------------------------------------------------------------------

-- the trunk, else the first vpart of the vehicle with a container
function S.vehiclePart(vehicle)
    local vpart
    pcall(function()
        vpart = vehicle:getPartById("TruckBed")
        if not (vpart and vpart:getItemContainer()) then
            vpart = nil
            for i = 0, vehicle:getPartCount() - 1 do
                local vp = vehicle:getPartByIndex(i)
                if not vpart and vp:getItemContainer() then vpart = vp end
            end
        end
    end)
    return vpart
end

-- A source: { kind = "vehicle" | "object" | "self", container, label, x, y, z,
-- vehicle/vpart or object/key }. save() makes the plain table the plan keeps;
-- load() finds the thing again.
function S.vehicleSource(vehicle, vpart)
    vpart = vpart or S.vehiclePart(vehicle)
    if not vpart then return nil end
    local sq = S.squareOf(vehicle)
    local src = { kind = "vehicle", vehicle = vehicle, vpart = vpart, container = vpart:getItemContainer(),
                  label = getText("IGUI_BU_Trunk"), id = nil }
    pcall(function() src.id = vehicle:getId() end)
    pcall(function() src.label = getText("IGUI_VehiclePart" .. vpart:getItemContainer():getType()) end)
    if sq then src.x, src.y, src.z = sq:getX(), sq:getY(), sq:getZ() end
    return src
end

function S.objectSource(obj, container, zone)
    local sq = obj:getSquare()
    if not sq or not container then return nil end
    local index = 0
    pcall(function()
        if obj.getContainerCount then
            for ci = 0, obj:getContainerCount() - 1 do
                if obj:getContainerByIndex(ci) == container then index = ci end
            end
        end
    end)
    local row = S.row(obj, container, index, sq, zone)
    return { kind = "object", object = obj, container = container, key = row.key, label = row.name, row = row,
             x = row.x, y = row.y, z = row.z }
end

function S.selfSource(player)
    local sq = S.squareOf(player)
    local src = { kind = "self", container = player:getInventory(), label = getText("IGUI_BU_Carrying") }
    if sq then src.x, src.y, src.z = sq:getX(), sq:getY(), sq:getZ() end
    return src
end

function S.saveSource(src)
    return { kind = src.kind, id = src.id, key = src.key, x = src.x, y = src.y, z = src.z, label = src.label }
end

function S.loadSource(saved, player)
    if not saved then return nil end
    if saved.kind == "self" then return S.selfSource(player) end
    if saved.kind == "object" then
        local found = S.resolve(saved.key)
        if not found then return nil end
        return S.objectSource(found.object, found.container, nil)
    end
    if saved.kind == "vehicle" then
        local vehicle
        pcall(function()
            local list = getCell():getVehicles()
            for i = 0, list:size() - 1 do
                local v = list:get(i)
                if v:getId() == saved.id then vehicle = v end
            end
        end)
        if not vehicle then return nil end
        return S.vehicleSource(vehicle)
    end
    return nil
end

-- the square to measure the zone from
function S.sourceSquare(src)
    if src.kind == "vehicle" then return S.squareOf(src.vehicle) end
    if src.kind == "object" then return src.object:getSquare() end
    return nil
end
