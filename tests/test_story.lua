-- Offline test for the story events in DanTraits.lua: notices are published
-- as OnStoryEvent with source, kind, text and tone; the event is registered
-- once; a broken listener or a missing event system never stops the halo.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- OnStoryEvent is absent until the core registers it, as in the game
H.events({ absent = { OnStoryEvent = true } })
H.stubs()
local registered = 0
LuaEventManager = { AddEvent = function(name)
  registered = registered + 1
  local list = {}
  Events[name] = { Add = function(f) list[#list + 1] = f end, _list = list }
end }
function triggerEvent(name, ...)
  for _, f in ipairs(Events[name]._list) do f(...) end
end
local halo = H.halo
function getText(k) return "text:" .. k end
H.load("DanTraits")

-- 1. registered once, and a second mod registering it too would find it there
assert(registered == 1 and rawget(Events, "OnStoryEvent"), "event registered")

local seen = {}
Events.OnStoryEvent.Add(function(p, ev) seen[#seen + 1] = { p = p, ev = ev } end)
local player = {}

-- 2. a bad notice
DanTraits_Notify(player, "UI_DanTraits_SmokerCraving")
assert(halo[1] == "text:UI_DanTraits_SmokerCraving", "halo still shown")
local ev = seen[1].ev
assert(seen[1].p == player and ev.source == "DanTraits" and ev.kind == "SmokerCraving" and ev.text == "text:UI_DanTraits_SmokerCraving" and ev.tone == "bad", "bad event")

-- 3. a good notice
DanTraits_NotifyGood(player, "UI_DanTraits_MddEnd")
assert(halo[2] == "+text:UI_DanTraits_MddEnd" and seen[2].ev.kind == "MddEnd" and seen[2].ev.tone == "good", "good event")

-- 4. a direct story line (the glucose meter)
DanTraits_Story(player, "DiaReading", "Blood sugar 62", "bad")
assert(seen[3].ev.kind == "DiaReading" and seen[3].ev.text == "Blood sugar 62", "direct story")

-- 5. a listener that throws does not take the notice down with it
Events.OnStoryEvent.Add(function() error("boom") end)
DanTraits_Notify(player, "UI_DanTraits_BrittleSnap")
assert(halo[3] == "text:UI_DanTraits_BrittleSnap" and seen[4].ev.kind == "BrittleSnap", "survives a broken listener")

-- 6. no event system (older build, tests elsewhere): notices still work, nothing published
triggerEvent = nil
DanTraits_Notify(player, "UI_DanTraits_Anemia1")
assert(halo[4] == "text:UI_DanTraits_Anemia1" and #seen == 4, "quiet without triggerEvent")
DanTraits_Story(nil, "x", "y")
H.pass()
