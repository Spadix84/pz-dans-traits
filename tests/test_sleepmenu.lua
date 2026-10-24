-- Offline test for DanTraits_SleepUndressList (DanTraits_Sleep.lua) and
-- DanTraits/42/media/lua/client/DanTraits_SleepMenu.lua: what comes off
-- (every worn thing that costs sleep, warm clothes only while warm enough to
-- matter, sleepwear never), which bags go down (worn or in the hands, a
-- two-handed one once), the option under the game's Sleep (found in a
-- submenu too, left out while Sleep is greyed or the sandbox option is off,
-- greyed when nothing needs to come off), and the queue: a walk to the bed,
-- an unequip per garment, a drop per bag, then the bed's own sleep; and
-- the morning: what came off goes back on once you wake (or once a refused
-- sleep leaves you idle), if still carried and not worn; bags stay down.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local ROOT = (arg[0]:match("^(.*)[/\\]") or ".") .. "/../DanTraits/42/media/lua/"

instanceof = function(o, cls) return type(o) == "table" and o.kind == cls end
MoodleType = { HYPOTHERMIA = "HYPOTHERMIA" }
local nextId = 0
local function item(loc, kind)
  nextId = nextId + 1
  local id = nextId
  return { kind = kind or "Clothing", getBodyLocation = function() return "base:" .. loc end,
           getDisplayName = function() return loc end, getID = function() return id end }
end
local function newPlayer(worn, hands)
  hands = hands or {}
  local p = { _worn = worn, _md = {}, _carried = {}, _busy = false, _asleep = false }
  p.getWornItems = function() return { size = function() return #p._worn end, getItemByIndex = function(_, i) return p._worn[i + 1] end,
    contains = function(_, it) for _, w in ipairs(p._worn) do if w == it then return true end end return false end } end
  p.getInventory = function() return { getItemWithIDRecursiv = function(_, id)
    for _, it in ipairs(p._carried) do if it.getID() == id then return it end end end } end
  p.getModData = function() return p._md end
  p.hasTimedActions = function() return p._busy end
  p.isAsleep = function() return p._asleep end
  p.getPrimaryHandItem = function() return hands[1] end
  p.getSecondaryHandItem = function() return hands[2] end
  p.getMoodles = function() return { getMoodleLevel = function() return 0 end } end
  p.getPlayerNum = function() return 0 end
  p.isSittingOnFurniture = function() return false end
  return p
end
getClimateManager = function() return { getAirTemperatureForCharacter = function() return H.climate.temp end } end

ISBaseTimedAction = { derive = function(self, name) local c = { Type = name }; c.__index = c; return setmetatable(c, { __index = self }) end,
                      new = function(self, character) return setmetatable({ character = character }, self) end,
                      perform = function() end }
local queued = {}
ISTimedActionQueue = { add = function(a) queued[#queued + 1] = a end, clear = function() queued = {} end }
local walked = 0
luautils = { walkAdj = function() walked = walked + 1; return true end }
ISInventoryPaneContextMenu = { unequipItem = function(it) queued[#queued + 1] = { off = it } end,
                               dropItem = function(it) queued[#queued + 1] = { drop = it } end,
                               wearItem = function(it) queued[#queued + 1] = { on = it } end }
local slept = nil
ISWorldObjectContextMenu = { onSleep = function() end,
                             onConfirmSleep = function(_, button, playerNum, bed) slept = { button.internal, playerNum, bed } end }
ISToolTip = { new = function() return { initialise = function() end, setVisible = function() end } end }

H.load("Sleep")
dofile(ROOT .. "client/DanTraits_SleepMenu.lua")
local M = DanTraits_SleepMenu

-- 1. what comes off: costly clothes and gear, not sleepwear; bags apart
local jeans, shirt, boots, tee, socks = item("pants"), item("shirt"), item("shoes"), item("tshirt"), item("socks")
local pack, bagInHand = item("back", "InventoryContainer"), { kind = "InventoryContainer", getDisplayName = function() return "duffel" end }
local p = newPlayer({ jeans, shirt, boots, tee, socks, pack }, { bagInHand, bagInHand })
local clothes, bags = DanTraits_SleepUndressList(p)
assert(#clothes == 3 and clothes[1] == jeans and clothes[2] == shirt and clothes[3] == boots, "jeans, shirt, boots; the tee and socks stay")
assert(#bags == 2 and bags[1] == pack and bags[2] == bagInHand, "the backpack and the duffel held in both hands, once")
-- the cold: warm clothes stay on below 15C, gear still comes off
H.climate.temp = 14
clothes = DanTraits_SleepUndressList(p)
assert(#clothes == 1 and clothes[1] == boots, "14C: only the boots")
H.climate.temp = 15
assert(#DanTraits_SleepUndressList(p) == 3, "15C: all three")
H.climate.temp = 20
SandboxVars = { DanTraits = { SleepClothesEnabled = false } }
clothes, bags = DanTraits_SleepUndressList(p)
assert(#clothes == 0 and #bags == 0, "off: nothing")
SandboxVars = nil

-- 2. the menu: under the game's Sleep, in a submenu too
local function newMenu(opts, subs)
  local m = { options = opts }
  function m:getSubMenu(n) return subs and subs[n] end
  function m:insertOptionAfter(prev, name, target, fn, a)
    for i, o in ipairs(self.options) do
      if o.name == prev then
        local opt = { name = name, run = function() return fn(target, a) end }
        table.insert(self.options, i + 1, opt)
        return opt
      end
    end
  end
  return m
end
local bed = { getSquare = function() return "sq" end }
getSpecificPlayer = function() return p end
local fill = H.only("OnFillWorldObjectContextMenu")
local top = newMenu({ { name = "Walk to" }, { name = "ContextMenu_Sleep", onSelect = ISWorldObjectContextMenu.onSleep, target = bed } })
fill(0, top, {}, false)
local mine = top.options[3]
assert(mine and mine.name == "ContextMenu_DanTraits_UndressSleep" and not mine.notAvailable, "right under Sleep, live")
assert(mine.toolTip.description == "ContextMenu_DanTraits_UndressSleepOff:pants, shirt, shoes <LINE> ContextMenu_DanTraits_UndressSleepDrop:back, duffel",
  "the tooltip names what comes off and what goes down")
local sub = newMenu({ { name = "ContextMenu_Rest" }, { name = "ContextMenu_Sleep", onSelect = function() end, target = bed } })
top = newMenu({ { name = "Bed", subOption = 7 } }, { [7] = sub })
fill(0, top, {}, false)
assert(#top.options == 1 and sub.options[3].name == "ContextMenu_DanTraits_UndressSleep", "found by name in the bed's submenu")
top = newMenu({ { name = "ContextMenu_Sleep", onSelect = ISWorldObjectContextMenu.onSleep, target = bed, notAvailable = true } })
fill(0, top, {}, false); assert(#top.options == 1, "Sleep greyed (not tired, too early): no option")
top = newMenu({ { name = "Walk to" } })
fill(0, top, {}, false); assert(#top.options == 1, "no Sleep: no option")
SandboxVars = { DanTraits = { SleepClothesEnabled = false } }
top = newMenu({ { name = "ContextMenu_Sleep", onSelect = ISWorldObjectContextMenu.onSleep, target = bed } })
fill(0, top, {}, false); assert(#top.options == 1, "sandbox off: no option")
SandboxVars = nil
local pj = newPlayer({ tee, socks })
getSpecificPlayer = function() return pj end
top = newMenu({ { name = "ContextMenu_Sleep", onSelect = ISWorldObjectContextMenu.onSleep, target = bed } })
fill(0, top, {}, false)
assert(top.options[2].notAvailable and top.options[2].toolTip.description == "ContextMenu_DanTraits_UndressSleepNone", "in sleepwear: greyed")
getSpecificPlayer = function() return p end

-- 3. the queue: walk, unequip each, drop each, then the bed's own sleep
top = newMenu({ { name = "ContextMenu_Sleep", onSelect = ISWorldObjectContextMenu.onSleep, target = bed } })
fill(0, top, {}, false)
queued = { "stale" }
top.options[2].run()
assert(walked == 1, "walked to the bed")
assert(#queued == 6 and queued[1].off == jeans and queued[3].off == boots and queued[4].drop == pack and queued[5].drop == bagInHand,
  "the old queue cleared, three off, two down")
local last = queued[6]
assert(last.Type == "ISDanTraitsBedtimeAction" and last.bed == bed and last.maxTime == 1, "then bedtime")
-- the unequips ran: jeans and boots came off into the bag of carried things; the shirt was put back on by hand
p._worn = { shirt, tee, socks }; p._carried = { jeans, boots, shirt }
last:perform()
assert(slept[1] == "YES" and slept[2] == 0 and slept[3] == bed, "the bed's own sleep, as if the dialog said yes")
local d = p._md.DanTraits
assert(#d.slUndressed == 2 and d.slUndressed[1] == jeans.getID() and d.slUndressed[2] == boots.getID(), "remembers what came off, not what is worn")

-- 4. the morning
local onMinute = DanTraits_SleepMenu.onMinute
queued = {}
p._asleep = true; onMinute(p, d); H.hours = H.hours + 8
assert(#queued == 0 and d.slUndressSlept, "asleep: noted, nothing yet")
p._carried = { boots }   -- the jeans went missing in the night
p._asleep = false; onMinute(p, d)
assert(#queued == 1 and queued[1].on == boots, "awake: the boots go back on; the missing jeans are skipped")
assert(d.slUndressed == nil, "done with")
onMinute(p, d); assert(#queued == 1, "once")
-- refused (zombies in sight): never asleep; waits while busy and for two minutes, then dresses
queued = {}
p._worn = { tee }; p._carried = { jeans, boots }
last.clothes = { jeans, boots }; last:perform()
onMinute(p, d); assert(#queued == 0, "just now: wait")
H.hours = H.hours + 5 / 60; p._busy = true
onMinute(p, d); assert(#queued == 0, "still walking to the bed: wait")
p._busy = false; onMinute(p, d)
assert(#queued == 2 and queued[1].on == jeans and queued[2].on == boots, "the sleep never came: dressed again")
-- put back on by hand already: nothing to do
queued = {}
last:perform(); p._worn = { tee, jeans, boots }
p._asleep = true; onMinute(p, d); p._asleep = false; onMinute(p, d)
assert(#queued == 0 and d.slUndressed == nil, "already dressed: nothing queued")
-- sleeping on the ground: no bed, no walk
walked = 0
top = newMenu({ { name = "ContextMenu_Sleep", onSelect = ISWorldObjectContextMenu.onSleep, target = nil } })
fill(0, top, {}, false)
top.options[2].run()
assert(walked == 0 and queued[#queued].bed == nil, "the ground: no walk, sleep where you stand")

H.pass("sleepmenu")
