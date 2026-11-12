-- Dan's Storage: shelves made for one thing.
--
-- Each shelf is two tiles long (art/storage) and each tile is its own container that
-- takes only the items its row in KINDS names, up to perTile:
--   water jug rack   storage_waterjugrack_01   water dispenser jugs           9 a tile
--   gas can shelf    storage_gascanshelf_01    petrol cans and jerry cans     9 a tile
--   propane shelf    storage_propaneshelf_01   propane tanks                  6 a tile
-- Every tileset has the same layout: 0-7 the shelf (two tiles for each facing), 8-15 the
-- same half full, 16-23 full.
--
-- Only those items: the game asks a container's accept-item function before anything
-- goes in (ItemContainer.isItemAllowed). The function's name lives on the container in
-- memory only and is not saved, so every shelf tile gets it again as it loads, as it is
-- built or put down, and as its loot window opens (that last one covers whatever slipped
-- past the others: nothing can be put in without that window).
--
-- How full it looks is an overlay tile drawn over the shelf tile: none when it is empty,
-- 8-15 (half) while it holds some, 16-23 (full) only when every place is taken. The
-- game's own container overlays (zombie.iso.ContainerOverlays, which stock shop fridges)
-- would say full at 7 items, so the shelves are not registered with them; they clear a
-- shelf's overlay after every transfer instead (ItemPicker.updateOverlaySprite sets none
-- for a sprite they don't know), and the client file puts the right one back straight
-- after (ISInventoryTransferAction transferItem). Every shelf seen is also looked at once
-- a game minute (the server file), for whatever else changes one: loading, another mod
-- moving items.
DansStorage = DansStorage or {}

local Shelves = {}
DansStorage.Shelves = Shelves

Shelves.TILES = 8           -- 0-7: the shelf, two tiles for each facing
Shelves.HALF = 8            -- the overlay tiles' offsets from the shelf tile
Shelves.FULL = 16

-- accept: what the game looks up with LuaManager.getFunctionObject, a global and one key.
-- capacity: the weight a tile takes, enough for a full tile (the same number is in the
-- tile definitions, tools/build_pack.py; set here too so shelves built before a change
-- take the new one, since a container keeps the capacity it was made with).
Shelves.KINDS = {
    { key = "WaterJugRack", tileset = "storage_waterjugrack_01", container = "waterjugrack",
      items = { ["Base.WaterDispenserBottle"] = true }, perTile = 9, capacity = 200,
      accept = "DansStorage.acceptWaterJug" },
    { key = "GasCanShelf", tileset = "storage_gascanshelf_01", container = "gascanshelf",
      items = { ["Base.PetrolCan"] = true, ["Base.JerryCan"] = true }, perTile = 9, capacity = 220,
      accept = "DansStorage.acceptGasCan" },
    { key = "PropaneShelf", tileset = "storage_propaneshelf_01", container = "propaneshelf",
      items = { ["Base.PropaneTank"] = true }, perTile = 6, capacity = 70,
      accept = "DansStorage.acceptPropane" },
}

local byTileset, byContainer = {}, {}
for _, kind in ipairs(Shelves.KINDS) do
    byTileset[kind.tileset] = kind
    byContainer[kind.container] = kind
end

function Shelves.kindByContainer(containerType) return byContainer[containerType] end

-- A shelf tile's kind and its place 0-7 in the tileset, or nil for anything else
function Shelves.kindOf(obj)
    local sprite = obj and obj.getSprite and obj:getSprite()
    local name = sprite and sprite:getName()
    if not name then return nil end
    local tileset, n = name:match("^(.*)_(%d+)$")
    local kind = tileset and byTileset[tileset]
    n = tonumber(n)
    if not kind or not n or n < 0 or n >= Shelves.TILES then return nil end
    return kind, n
end

function Shelves.isShelf(obj) return Shelves.kindOf(obj) ~= nil end

-- the eight shelf tiles of every kind, for loading
function Shelves.spriteNames()
    local names = {}
    for _, kind in ipairs(Shelves.KINDS) do
        for i = 0, Shelves.TILES - 1 do names[#names + 1] = kind.tileset .. "_" .. i end
    end
    return names
end

-- Its items, and room for one more. One already on the shelf (the game asks about those
-- too, for moving them about) is always fine.
function Shelves.accepts(kind, container, item)
    if not item or not kind.items[item:getFullType()] then return false end
    if not container then return true end
    if container:contains(item) then return true end
    return container:getItems():size() < kind.perTile
end

for _, kind in ipairs(Shelves.KINDS) do
    local fn = kind.accept:match("^DansStorage%.(.+)$")
    DansStorage[fn] = function(container, item) return Shelves.accepts(kind, container, item) end
end

-- The overlay tile a shelf tile should show for what it holds, or nil (empty)
function Shelves.overlayFor(obj)
    local kind, n = Shelves.kindOf(obj)
    local container = kind and obj:getContainer()
    if not container then return nil end
    local count = container:getItems():size()
    if count <= 0 then return nil end
    return kind.tileset .. "_" .. (n + (count >= kind.perTile and Shelves.FULL or Shelves.HALF))
end

-- Draw the overlay the shelf tile should have, if it hasn't got it already. The server
-- sends it to the clients; a client sets its own copy only.
function Shelves.sync(obj)
    if not Shelves.isShelf(obj) then return end
    local want = Shelves.overlayFor(obj)
    local current = obj:getOverlaySprite()
    local have = current and current:getName() or nil
    if have ~= want then obj:setOverlaySprite(want, isServer()) end
end

-- Every shelf tile seen, for the minute's look (a plain table: no weak keys in the game's
-- Lua, so the minute drops the ones picked up or unloaded).
Shelves.seen = Shelves.seen or {}

local function ensureContainer(container, kind)
    if not container then return end
    if container:getAcceptItemFunction() ~= kind.accept then container:setAcceptItemFunction(kind.accept) end
    if container:getCapacity() ~= kind.capacity then container:setCapacity(kind.capacity) end
end

-- Give a shelf tile's container(s) its accept-item function and capacity, note it, and
-- draw its overlay.
function Shelves.ensure(obj)
    local kind = Shelves.kindOf(obj)
    if not kind then return end
    ensureContainer(obj:getContainer(), kind)
    local n = obj.getContainerCount and obj:getContainerCount() or 0
    for i = 0, n - 1 do ensureContainer(obj:getContainerByIndex(i), kind) end
    Shelves.seen[obj] = true
    Shelves.sync(obj)
end

-- A shelf tile whose chunk has just unloaded is still an object for a moment, with no
-- chunk under its square: it is dropped, not touched.
local function gone(obj)
    if obj:getObjectIndex() == -1 or not Shelves.isShelf(obj) then return true end
    local sq = obj:getSquare()
    return sq == nil or (sq.getChunk ~= nil and sq:getChunk() == nil)
end

function Shelves.syncAll()
    for obj in pairs(Shelves.seen) do
        if gone(obj) then Shelves.seen[obj] = nil else Shelves.sync(obj) end
    end
end

-- After an item moves: the shelf tile(s) it moved between, by their containers.
function Shelves.afterTransfer(...)
    for i = 1, select("#", ...) do
        local container = select(i, ...)
        local parent = container and container:getParent()
        if parent and Shelves.isShelf(parent) then Shelves.ensure(parent) end
    end
end

-- Every shelf tile on a square and the ones around it: a shelf is two tiles, and the
-- build hook is given one of them.
function Shelves.ensureAround(square)
    if not square then return end
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            local objects = sq and sq:getObjects()
            if objects then
                for i = 0, objects:size() - 1 do Shelves.ensure(objects:get(i)) end
            end
        end
    end
end

-- SpriteConfig OnCreate (scripts/DansStorage_entities.txt): a shelf has just been built.
-- The game doesn't fire OnObjectAdded for that in singleplayer.
function Shelves.onBuilt(params)
    local obj = params and params.thumpable
    if obj then Shelves.ensureAround(obj:getSquare()) end
end

Events.OnObjectAdded.Add(Shelves.ensure)

return Shelves
