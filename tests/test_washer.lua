-- Offline test for DansVanillaFixes/42/media/lua/client/DansVanillaFixes_WasherClient.lua:
-- the washer among the clicked objects (a washing machine, a combo set to wash,
-- a stacked pair's washer; not a dryer or a combo set to dry), the dirty or
-- bloody garments carried (bags included, the worn ones left out, everything
-- else ignored), the menu option with its count, greyed with the reason when
-- there is nothing to load or the machine runs, and the load: a walk up, then
-- one transfer per garment into the washer's container.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local ROOT = (arg[0]:match("^(.*)[/\\]") or ".") .. "/../DansVanillaFixes/42/media/lua/"

instanceof = function(o, cls) return type(o) == "table" and o.kind == cls end
local function obj(kind, o) o = o or {}; o.kind = kind; o.getSquare = function() return "sq" end; return o end
local function garment(name, dirty, bloody, container)
  return { kind = "Clothing", name = name, isDirty = function() return dirty end, isBloody = function() return bloody end,
           getContainer = function() return container or "main" end }
end
local list = function(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
ArrayList = { new = function() return {} end }
local queued = {}
ISTimedActionQueue = { add = function(a) queued[#queued + 1] = a end }
ISInventoryTransferAction = { new = function(_, player, item, src, dst) return { item = item, src = src, dst = dst } end }
local walked = 0
luautils = { walkAdj = function() walked = walked + 1; return true end }
ISToolTip = { new = function() return { initialise = function() end, setVisible = function() end } end }
local texts = {}
getText = function(key, n) texts[#texts + 1] = key; return key .. (n and (":" .. tostring(n)) or "") end

dofile(ROOT .. "client/DansVanillaFixes_WasherClient.lua")
local M = DVF_Washer

-- 1. which object is a washer
local washer = obj("IsoClothingWasher", { getContainer = function() return "wc" end, isActivated = function() return false end })
local dryer = obj("IsoClothingDryer", { getContainer = function() return "dc" end })
local comboWash = obj("IsoCombinationWasherDryer", { getContainer = function() return "cc" end, isModeWasher = function() return true end })
local comboDry = obj("IsoCombinationWasherDryer", { getContainer = function() return "cc" end, isModeWasher = function() return false end })
local stacked = obj("IsoStackedWasherDryer", { getContainerByType = function(_, t) return t == "clothingwasher" and "sw" or nil end })
local w, c = M.washerOf({ dryer, washer }); assert(w == washer and c == "wc", "the washing machine, its container")
w, c = M.washerOf({ comboWash }); assert(w == comboWash and c == "cc", "a combo set to wash")
assert(M.washerOf({ comboDry }) == nil, "a combo set to dry is not a washer")
w, c = M.washerOf({ stacked }); assert(w == stacked and c == "sw", "a stacked pair: its washer container")
assert(M.washerOf({ dryer, obj("IsoObject") }) == nil, "a dryer or a table: nothing")

-- 2. the garments: dirty or bloody, carried anywhere, not worn, not other items
local shirt, jeans, clean, inBag = garment("shirt", true, false), garment("jeans", false, true), garment("tee", false, false), garment("socks", true, true, "bag")
local wornCoat = garment("coat", true, false)
local pot = { kind = "InventoryItem", isDirty = function() return true end }
local all = { shirt, jeans, clean, inBag, wornCoat, pot }
local p = { getInventory = function() return { getAllEvalRecurse = function() return list(all) end } end,
            isEquipped = function(_, item) return item == wornCoat end }
local items = M.dirtyClothes(p)
assert(#items == 3 and items[1] == shirt and items[2] == jeans and items[3] == inBag, "shirt, jeans and the socks in the bag; not the clean tee, the worn coat or the pot")
-- a game without the recursive search: the main inventory only
local p2 = { getInventory = function() return { getItems = function() return list({ shirt, clean }) end } end, isEquipped = function() return false end }
assert(#M.dirtyClothes(p2) == 1, "fallback: the main inventory")

-- 3. the menu: the option with its count, greyed when nothing or running
getSpecificPlayer = function() return p end
local function menu(objects)
  local opts = {}
  local context = { addOption = function(_, text, target, fn, a, b, c3)
    local o = { text = text, run = function() return fn(target, a, b, c3) end }
    opts[#opts + 1] = o
    return o
  end }
  H.only("OnFillWorldObjectContextMenu")(0, context, objects, false)
  return opts
end
assert(#menu({ dryer }) == 0, "no washer: no option")
local opts = menu({ washer })
assert(#opts == 1 and opts[1].text == "ContextMenu_DVF_WasherLoad:3" and not opts[1].notAvailable, "one option, three garments, live")
queued = {}
assert(opts[1].run() == 3, "loads three")
assert(walked == 1 and #queued == 3 and queued[1].item == shirt and queued[1].src == "main" and queued[1].dst == "wc", "a walk, then a transfer each into the washer")
assert(queued[3].src == "bag", "the socks come out of the bag")
getSpecificPlayer = function() return p2 end
local p3 = { getInventory = function() return { getItems = function() return list({ clean }) end } end, isEquipped = function() return false end }
getSpecificPlayer = function() return p3 end
opts = menu({ washer })
assert(opts[1].notAvailable and opts[1].toolTip.description == "ContextMenu_DVF_WasherNone", "nothing to load: greyed, says why")
getSpecificPlayer = function() return p end
washer.isActivated = function() return true end
opts = menu({ washer })
assert(opts[1].notAvailable and opts[1].toolTip.description == "ContextMenu_DVF_WasherRunning", "running: greyed, says why")
washer.isActivated = function() return false end
-- the game's test pass (building the menu to see if anything would show) adds nothing
local before = #queued
local ctx = { addOption = function() error("should not be called") end }
H.only("OnFillWorldObjectContextMenu")(0, ctx, { washer }, true)
assert(#queued == before, "test pass: nothing")
-- the walk refused: nothing queued
luautils.walkAdj = function() return false end
queued = {}
assert(M.load(p, washer, "wc", { shirt }) == 0 and #queued == 0, "cannot get there: nothing moves")

H.pass("washer")
