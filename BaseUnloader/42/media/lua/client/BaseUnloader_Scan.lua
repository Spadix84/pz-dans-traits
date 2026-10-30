-- Base Unloader: reading the world. The zone (the base zones drawn near the
-- container being unloaded; with none drawn, the building you are in or next
-- to, plus a margin, plus a circle round the container), every container in
-- it as a plain record for the core, a container's key (S.identify, the one
-- place keys are built; S.resolve finds the container again from one), what
-- to call it and where it is, what every base zone holds (the stock, kept for
-- when you are away), the items of a source container as records, and finding
-- a vehicle again from its id when a run resumes. Also the two small world
-- writes the windows and menus share: lighting a container up (S.highlight)
-- and taking a new name from the name box (S.renamed).

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
function S.laundryOn() return sandbox("Laundry", true) end
function S.maxLoad() return sandbox("MaxLoad", BU.MAX_LOAD_LEVEL) end
function S.zoneReach() return sandbox("ZoneReach", 40) end

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

-- the base zones drawn (BaseUnloader_Zones), as areas for the core: one per name
function S.drawnAreas()
    return BU.zoneAreas(BU.store().zones)
end

-- The zone to list. With base zones drawn within reach of the source, those zones
-- and nothing else (each on its floor and `floors` above and below). With
-- none, the building the source (or the player) is in or stands next to,
-- grown by the margin, united with a circle of the radius round the source;
-- floors: the source's floor and `floors` above and below.
function S.zone(player, sourceSq)
    local sq = sourceSq or S.squareOf(player)
    if not sq then return nil end
    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    local areas = BU.nearAreas(S.drawnAreas(), cx, cy, S.zoneReach())
    if #areas > 0 then
        return { cx = cx, cy = cy, cz = cz, areas = areas, floors = S.floors() }
    end
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

-- categories ------------------------------------------------------------------------------------

function S.categoryLabel(cat)
    return getTextOrNull("IGUI_ItemCat_" .. cat) or cat
end

-- a short list of category names for a menu: the first few, then "+N"
function S.categoryNames(list, most)
    most = most or 3
    local names = {}
    for i, cat in ipairs(list) do
        if i > most then
            names[#names + 1] = "+" .. tostring(#list - most)
            break
        end
        names[#names + 1] = S.categoryLabel(cat)
    end
    return table.concat(names, ", ")
end

-- the categories offered for tagging: the standard list plus any extra ones
-- found (on the groups being unloaded, and in the containers' contents)
function S.categories(groups, rows)
    local seen, out = {}, {}
    for _, cat in ipairs(BU.CATEGORIES) do seen[cat] = true; out[#out + 1] = cat end
    for _, g in ipairs(groups or {}) do
        if g.category and not seen[g.category] then seen[g.category] = true; out[#out + 1] = g.category end
    end
    for _, row in ipairs(rows or {}) do
        for cat in pairs(row.cats or {}) do
            if not seen[cat] then seen[cat] = true; out[#out + 1] = cat end
        end
    end
    table.sort(out, function(a, b) return S.categoryLabel(a) < S.categoryLabel(b) end)
    return out
end

-- names and places --------------------------------------------------------------------------

function S.kindLabel(kind)
    local t = getTextOrNull("IGUI_ContainerTitle_" .. tostring(kind))
    return t or tostring(kind)
end

-- the name Smarter Storage (steam 3290232938) gave the container's object, if any
function S.smarterStorageName(container)
    local name
    pcall(function()
        local parent = container:getParent()
        local data = parent and parent.getModData and parent:getModData() or nil
        name = data and data.SmarterStorage_Name or nil
    end)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function customName(container)
    local custom
    pcall(function() custom = container:getCustomName() end)
    if custom and custom ~= "" then return custom end
    return nil
end

-- what to call a container: the name on it, else the name saved for its key,
-- else the one Smarter Storage gave it, else its kind. A getter only: the scan
-- puts a saved name back on the container (S.restoreName)
function S.nameOf(container, key)
    local custom = customName(container)
    if custom then return custom, true end
    local saved = BU.store().names[key]
    if saved and saved ~= "" then return saved, true end
    local smarter = S.smarterStorageName(container)
    if smarter then return smarter, true end
    return S.kindLabel(container:getType()), false
end

-- the name saved for a container's key goes back on the container, in case the
-- game did not keep it: once per scan (S.row), not on every look at the name
function S.restoreName(container, key)
    if customName(container) then return end
    local saved = BU.store().names[key]
    if saved and saved ~= "" then pcall(function() container:setCustomName(saved) end) end
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

-- The name box closed (BU_Window:rename, BU_Menu.onRenameObject): on OK the
-- container takes the name typed (its kind's own label clears it) and the
-- inventory windows redraw. Returns true when a name was taken.
function S.renamed(button, playerNum, row)
    if button.internal ~= "OK" then return false end
    local text = button.parent.entry:getText() or ""
    if text == row.kindLabel then text = "" end
    S.rename(row.container, row.key, text)
    pcall(function()
        local pdata = getPlayerData(playerNum)
        pdata.playerInventory:refreshBackpacks()
        pdata.lootInventory:refreshBackpacks()
    end)
    return true
end

-- a world object lit up (or not) for a player, as the loot window lights its container
function S.highlight(playerNum, obj, on)
    if not obj then return end
    pcall(function()
        obj:setHighlighted(playerNum, on, false)
        if on then obj:setHighlightColor(playerNum, getCore():getObjectHighlitedColor()) end
    end)
end

-- the game's name for the room a square is in ("kitchen", "garagestorage"), lower
-- case; nil outdoors and in a base you built (the game gives those no rooms)
function S.roomId(sq)
    local name
    pcall(function()
        local room = sq:getRoom()
        if room then
            name = room:getName()
            if (not name or name == "") and room.getRoomDef and room:getRoomDef() then name = room:getRoomDef():getName() end
        end
    end)
    if not name or name == "" then return nil end
    return string.lower(name)
end

-- which object of this kind on the square obj is (0 the first, in the square's
-- order): crates stack, and each needs a key of its own (BU.key's ordinal)
local function sameKindBefore(sq, obj, kind, index)
    local n = 0
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o == obj then return end
            local c
            pcall(function() c = index == 0 and o:getContainer() or o:getContainerByIndex(index) end)
            if c and c:getType() == kind then n = n + 1 end
        end
    end)
    return n
end
S.ordinalOf = sameKindBefore

-- A world object's container identified: its key (BU.key, with the ordinal
-- among same-kind objects on the square) and which of the object's containers
-- it is (a fridge has two). The one place keys are built; S.resolve is the
-- inverse. nil when the container is not one of the object's, or the object
-- has no square (sq: the object's square, looked up when not given).
function S.identify(obj, container, sq)
    sq = sq or obj:getSquare()
    if not sq then return nil end
    local index
    pcall(function()
        local n = obj.getContainerCount and obj:getContainerCount() or 1
        for ci = 0, n - 1 do
            local c = ci == 0 and obj:getContainer() or obj:getContainerByIndex(ci)
            if c == container then index = ci end
        end
    end)
    if not index then return nil end
    local kind = container:getType()
    return BU.key(sq:getX(), sq:getY(), sq:getZ(), kind, index, sameKindBefore(sq, obj, kind, index)), index
end

-- the key of a world object's container, nil for a character's, a bag's or a vehicle's
function S.keyOf(container)
    local key
    pcall(function()
        if container:getContainingItem() or container:getVehiclePart() then return end
        local obj = container:getParent()
        if not obj or instanceof(obj, "IsoGameCharacter") or instanceof(obj, "BaseVehicle") then return end
        key = S.identify(obj, container)
    end)
    return key
end

-- a container got something put in by hand or by a run: remembered as used,
-- inside a base zone (anywhere while no zone is drawn)
function S.noteTouched(container)
    local key = container and S.keyOf(container) or nil
    local k = key and BU.parseKey(key) or nil
    if not k or k.kind == "floor" then return end
    local store = BU.store()
    if #store.zones > 0 and not BU.areaAt(BU.zoneAreas(store.zones), k.x, k.y, k.z, S.floors()) then return end
    BU.touch(store, key)
end

function S.floorLabel(z)
    local which, n = BU.floorKey(z)
    if n then return getText("IGUI_BU_Floor_" .. which, n) end
    return getText("IGUI_BU_Floor_" .. which)
end

-- "12 tiles north-east" of the zone's centre (the source), nil on its very square
function S.offsetLabel(row, zone)
    local dx, dy = row.x - zone.cx, row.y - zone.cy
    local dir = BU.compass(dx, dy)
    local tiles = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
    if dir and tiles > 0 then return getText("IGUI_BU_Tiles", tiles, getText("IGUI_BU_Dir_" .. dir)) end
    return nil
end

-- "Kitchen, ground floor" or, with no room, "12 tiles north-east, ground floor"
-- (row.offset, set by S.row from S.offsetLabel; "here" on the source's square)
function S.placeLabel(row, zone)
    local parts = {}
    if row.room then
        parts[#parts + 1] = row.room
    elseif zone then
        parts[#parts + 1] = row.offset or getText("IGUI_BU_Here")
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

-- what a container takes for this character: the game scales capacity by
-- Organized and Disorganized, and hasRoomFor judges by that scaled figure
function S.capacity(container, player)
    local capacity = 0
    pcall(function()
        if player and container.getEffectiveCapacity then
            capacity = container:getEffectiveCapacity(player)
        else
            capacity = container:getCapacity()
        end
    end)
    return capacity
end

-- the record for one container of a world object (sq: its square); nil when
-- the container is not the object's (S.identify). The scan is where a saved
-- name goes back on the container.
function S.row(obj, container, sq, zone, player)
    local key = S.identify(obj, container, sq)
    if not key then return nil end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local kind = container:getType()
    S.restoreName(container, key)
    local name, named = S.nameOf(container, key)
    local contents, cats, count = histograms(container)
    local capacity, used = S.capacity(container, player), 0
    pcall(function() used = container:getCapacityWeight() end)
    local roomId = S.roomId(sq)
    local row = { key = key, container = container, object = obj, x = x, y = y, z = z, kind = kind,
                  kindLabel = S.kindLabel(kind), name = name, named = named, roomId = roomId, room = BU.roomWords(roomId),
                  contents = contents, cats = cats, count = count, capacity = capacity, used = used,
                  free = math.max(0, capacity - used), touched = BU.store().touched[key] == true }
    if not row.room and zone then row.offset = S.offsetLabel(row, zone) end
    row.place = S.placeLabel(row, zone)
    return row
end

local function rowsOnSquare(sq, zone, out, skipContainer, player)
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
                    out[#out + 1] = S.row(obj, c, sq, zone, player)
                end
            end
        end
    end
end

-- every loaded square of one piece of zone ({ x1, y1, x2, y2, z }, on its
-- floor and `floors` above and below) not yet in `seen` (shared between pieces,
-- so a square two pieces cover is walked once): fn(square, x, y, z)
local function eachPieceSquare(piece, floors, seen, fn)
    local cell = getCell()
    for z = piece.z - floors, piece.z + floors do
        for y = piece.y1, piece.y2 do
            for x = piece.x1, piece.x2 do
                local at = x .. "," .. y .. "," .. z
                if not seen[at] then
                    seen[at] = true
                    local sq = cell:getGridSquare(x, y, z)
                    if sq then fn(sq, x, y, z) end
                end
            end
        end
    end
end

-- every loaded square of some areas, once each: fn(square, index of the area it belongs to)
function S.eachAreaSquare(areas, floors, fn)
    local seen = {}
    for _, area in ipairs(areas) do
        for _, r in ipairs(area.rects) do
            eachPieceSquare(r, floors, seen, function(sq, x, y, z) fn(sq, BU.areaAt(areas, x, y, z, floors)) end)
        end
    end
end

-- every container in the zone, as records, sorted by room then name; the
-- source's own container is left out (it gets its own row). In drawn zones a
-- record carries `area`, the index of its zone in zone.areas.
function S.containers(zone, skipContainer, player)
    local out = {}
    if not zone then return out end
    local cell = getCell()
    if zone.areas then
        S.eachAreaSquare(zone.areas, zone.floors, function(sq, which)
            local first = #out + 1
            rowsOnSquare(sq, zone, out, skipContainer, player)
            for k = first, #out do out[k].area = which end
        end)
        S.sort(out)
        return out
    end
    for z = zone.z1, zone.z2 do
        for y = zone.y1, zone.y2 do
            for x = zone.x1, zone.x2 do
                if S.inZone(zone, x, y) then
                    local sq = cell:getGridSquare(x, y, z)
                    if sq then rowsOnSquare(sq, zone, out, skipContainer, player) end
                end
            end
        end
    end
    S.sort(out)
    return out
end

-- stock ----------------------------------------------------------------------------------------

function S.worldHours()
    local h
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end

-- a piece is counted only while it is all loaded: its four corners on the
-- ground floor (upstairs a corner may be open air, with no square at all)
function S.pieceLoaded(zone)
    local cell = getCell()
    for _, c in ipairs({ { zone.x1, zone.y1 }, { zone.x2, zone.y1 }, { zone.x1, zone.y2 }, { zone.x2, zone.y2 } }) do
        if not cell:getGridSquare(c[1], c[2], 0) then return false end
    end
    return true
end

-- the items of a container as stock records, bags opened three deep, all
-- counted at the container they sit in
local function stockOfContainer(inv, depth, key, name, out)
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        pcall(function()
            out[#out + 1] = { fullType = it:getFullType(), name = it:getDisplayName(), category = it:getDisplayCategory(),
                              containerKey = key, containerName = name }
        end)
        if depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then
            stockOfContainer(it:getInventory(), depth + 1, key, name, out)
        end
    end
end

-- everything on a square: in its containers, and lying on the floor
function S.stockOnSquare(sq, out)
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local n = 0
        pcall(function()
            if obj:getContainer() then n = obj.getContainerCount and obj:getContainerCount() or 1 end
        end)
        for ci = 0, n - 1 do
            local c
            pcall(function() c = ci == 0 and obj:getContainer() or obj:getContainerByIndex(ci) end)
            if c and not SKIP_KINDS[c:getType()] then
                local key = S.identify(obj, c, sq)
                if key then pcall(function() stockOfContainer(c, 0, key, (S.nameOf(c, key)), out) end) end
            end
        end
    end
    pcall(function()
        local floor = sq:getWorldObjects()
        local label = getText("IGUI_BU_OnFloor")
        for i = 0, floor:size() - 1 do
            local it = floor:get(i):getItem()
            if it then
                out[#out + 1] = { fullType = it:getFullType(), name = it:getDisplayName(), category = it:getDisplayCategory(),
                                  containerKey = nil, containerName = label }
            end
        end
    end)
end

-- Count every loaded piece of every base zone again, into store.stock; a
-- piece out of range keeps its last count. Returns { [piece key] = true } for
-- the pieces counted now.
function S.refreshStock(store)
    store = store or BU.store()
    BU.dropStaleStock(store)
    local floors = S.floors()
    local now = S.worldHours()
    local fresh, seen = {}, {}
    for _, zone in ipairs(store.zones) do
        if S.pieceLoaded(zone) then
            local records = {}
            eachPieceSquare(zone, floors, seen, function(sq) S.stockOnSquare(sq, records) end)
            local key = BU.pieceKey(zone)
            store.stock[key] = { zone = zone.name, at = now, items = BU.stockOf(records) }
            fresh[key] = true
        end
    end
    return fresh
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
    local found, seen = nil, 0   -- the ordinal-th object of that kind, in the square's order
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
            if c and c:getType() == k.kind then
                if seen == (k.ordinal or 0) then found = { container = c, object = obj, square = sq } end
                seen = seen + 1
            end
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
    end)
    -- a bag weighs what is in it too (getActualWeight is the empty bag's own)
    pcall(function()
        if instanceof(it, "InventoryContainer") and it:getInventory() then
            r.bag = true
            r.weight = it:getUnequippedWeight()
        end
    end)
    pcall(function()
        if r.food and it.getOffAgeMax then
            local max = it:getOffAgeMax()
            r.perishable = max < BU.NEVER_OFF
            r.longLife = r.perishable and max >= BU.LONG_LIFE_DAYS
        end
    end)
    -- fresh, stale or rotten: frozen food keeps, so it counts as fresh
    if r.food and r.perishable then
        pcall(function()
            r.rotten = it:isRotten() == true
            local frozen = false
            pcall(function() frozen = it:isFrozen() == true end)
            if not r.rotten and not frozen then
                local age, off = it:getAge() or 0, it:getOffAge() or BU.NEVER_OFF
                r.stale = age >= off
            end
        end)
    end
    -- dirty or bloody clothing is laundry, when the option is on
    pcall(function()
        if S.laundryOn() and it:IsClothing() then
            local dirty, blood = false, 0
            pcall(function() dirty = it:isDirty() == true end)
            pcall(function() blood = it:getBloodLevel() or 0 end)
            r.laundry = dirty or blood > 0
        end
    end)
    if not r.fullType then return nil end
    r.weight = r.weight or 0
    r.name = r.name or r.fullType
    return r
end

-- every item of a container, bags opened (three deep), as records: an item in
-- a bag carries `parent` (the bag's id) and `from` (the bag's inventory), so
-- the run can take it out of the bag where it sits (vanilla moves items out of
-- bags in a trunk or on a seat; the loot window shows them)
function S.allItems(container)
    local out = {}
    local function walk(inv, depth, parent)
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local r = S.itemRecord(it)
            if r then
                r.from = inv
                r.parent = parent
                out[#out + 1] = r
            end
            if depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then
                walk(it:getInventory(), depth + 1, r and r.id or nil)
            end
        end
    end
    pcall(function() walk(container, 0, nil) end)
    return out
end

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
    local row = S.row(obj, container, sq, zone)
    if not row then return nil end
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
    local part = nil
    if src.vpart then pcall(function() part = src.vpart:getId() end) end   -- a glove box or seat resumes as itself, not the trunk
    return { kind = src.kind, id = src.id, key = src.key, x = src.x, y = src.y, z = src.z, label = src.label, part = part }
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
        local vehicle = S.findVehicle(saved.id, saved.x, saved.y, saved.z)
        if not vehicle then return nil end
        local vpart = nil
        if saved.part then pcall(function() vpart = vehicle:getPartById(saved.part) end) end
        return S.vehicleSource(vehicle, vpart)
    end
    return nil
end

-- the vehicle with this id, looked for on the squares round where it was
-- parked (a few tiles either way: it may have rolled)
function S.findVehicle(id, x, y, z)
    if not x or not y then return nil end
    local cell = getCell()
    local found
    for r = 0, 6 do
        for dx = -r, r do
            for dy = -r, r do
                if not found and (math.abs(dx) == r or math.abs(dy) == r) then
                    pcall(function()
                        local sq = cell:getGridSquare(x + dx, y + dy, z or 0)
                        local v = sq and sq:getVehicleContainer() or nil
                        if v and (id == nil or v:getId() == id) then found = v end
                    end)
                end
            end
        end
        if found then return found end
    end
    return nil
end

-- the square to measure the zone from
function S.sourceSquare(src)
    if src.kind == "vehicle" then return S.squareOf(src.vehicle) end
    if src.kind == "object" then return src.object:getSquare() end
    return nil
end
