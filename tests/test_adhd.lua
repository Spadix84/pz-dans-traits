-- Offline test for DanTraits_ADHD.lua: boredom rises x1.5 through the delta
-- pipeline (falls untouched), a skill book bores (a novel does not), a running
-- action drifts off and stops, never while panicked, never for walking, not
-- twice within the gap; hyperfocus builds, locks in (no drifting, no boredom
-- rise, quicker actions, more experience, the moodle) and breaks on idling,
-- panic and sleep; coffee softens it all; a new building lifts boredom and
-- home's relief is halved; the console; nothing without the trait.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
ISBaseTimedAction = { adjustMaxTime = function(_, t) return t end }
H.load("ADHD")
H.expectEvery("minute", "ADHD")
H.expectEvery("minute", "Delta:boredomRise")

local near, minute = H.near, H.minute
local A = DanTraits_AdhdC

SkillBook = { Carpentry = { perk = "Woodwork" } }
local stopped = 0
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = { H.action } } end }
local function action(type, item)
  return { Type = type, item = item, isStarted = function() return true end,
           forceStop = function() stopped = stopped + 1; H.action = nil end }
end
local function book(skill, id)
  return { getSkillTrained = function() return skill end, getID = function() return id end }
end
-- Home's placeOf, stood in: H.place
DanTraits_HomePlaceOf = function() return H.place end

local p = H.player({ traits = { "adhd" }, boredom = 10 }); H.current = p
local d = DanTraits_Data(p)
-- a clean slate between sections: no focus, no gap, boredom where asked
local function fresh(boredom)
  d.adhdFocus, d.adhdHyper, d.adhdIdle, d.adhdNext, d.adhdCaf = 0, nil, 0, nil, nil
  p._st.boredom = boredom or 0
  d.deltaLast = d.deltaLast or {}
  d.deltaLast.boredomRise = p._st.boredom
  stopped = 0
end

-- 1. boredom: a rise is x1.5, a fall is left alone
H.rollf = 0.99
minute()                                        -- first look: adopts 10
near(p._st.boredom, 10, 1e-9, "first minute adopts")
p._st.boredom = 12; minute()                    -- the game gave +2
near(p._st.boredom, 13, 1e-9, "a rise of 2 counts as 3")
p._st.boredom = 5; minute()                     -- something cheered them up
near(p._st.boredom, 5, 1e-9, "a fall is untouched")
-- a floor another system raised (DanTraits_FloorUp flags it) is not the game's rise
p._st.boredom = 7; d.floorsThisMinute = { boredomRise = true }; minute()
near(p._st.boredom, 7, 1e-9, "a mod floor's rise of 2 stays 2")
assert(d.floorsThisMinute.boredomRise == nil, "the flag is spent")
p._st.boredom = 9; minute()
near(p._st.boredom, 10, 1e-9, "the game's next rise of 2 is 3 again")

-- without the trait, the same rise is the same rise
local q = H.player({ boredom = 10 }); H.current = q
minute(); q._st.boredom = 12; minute()
near(q._st.boredom, 12, 1e-9, "no trait: no scaling")
H.current = p

-- 2. a skill book bores (and says so once); a novel does not
fresh(0); H.clearHalo()
H.action = action("ISReadABook", book("Carpentry", 7))
minute()
near(p._st.boredom, A.BOOK_BOREDOM, 1e-9, "a minute of a skill book")
minute()
near(p._st.boredom, A.BOOK_BOREDOM * A.BOREDOM_MULT + A.BOOK_BOREDOM, 1e-9, "the book's boredom counts x1.5 next minute")
local said = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_AdhdBook" then said = said + 1 end end
assert(said == 1, "the dull notice once per book, got " .. said)
assert(d.adhdBookSaid == "7", "mod data keeps the id, not the item")
assert((d.adhdFocus or 0) == 0, "a skill book builds no focus")

H.action = action("ISReadABook", book(nil, 8))
fresh(0); minute()
near(p._st.boredom, 0, 1e-9, "a novel is not a slog")

-- 3. drifting off: the roll stops a running action and starts the gap
fresh(0); H.action = action("ISCraftAction"); H.clearHalo()
H.rollf = 0.99; minute()
assert(stopped == 0 and H.action, "a high roll: carries on")
H.rollf = 0.0; minute()
assert(stopped == 1 and H.action == nil, "a low roll: the action stops")
assert(H.halo[#H.halo]:find("^UI_DanTraits_AdhdDrift_"), "a drift notice")
assert(d.adhdFocus == 0, "drifting off loses the focus")
H.action = action("ISCraftAction"); minute()
assert(stopped == 1, "not again within the gap")
H.hours = H.hours + (A.GAP_MIN + 1) / 60; minute()
assert(stopped == 2, "again after the gap")
-- a quick action (a transfer, an equip) is never the one: the loot queue behind it would go too
fresh(0); H.rollf = 0.0
local quick = action("ISInventoryTransferAction"); quick.maxTime = A.DRIFT_MIN_TIME - 1; H.action = quick; minute()
assert(stopped == 0 and H.action == quick, "a quick action is not drifted off from")
local long = action("ISCraftAction"); long.maxTime = A.DRIFT_MIN_TIME; H.action = long; minute()
assert(stopped == 1, "a long one is")

-- boredom makes it likelier: the chance doubles fully bored
fresh(0); H.rollf = A.DRIFT * 1.5; H.action = action("ISCraftAction")
minute()
assert(stopped == 0, "calm: a roll above the base chance carries on")
fresh(100); H.rollf = A.DRIFT * 1.5; H.action = action("ISCraftAction")
minute()
assert(stopped == 1, "fully bored: the same roll drifts off")

-- 4. never while panicked, never walking or resting, never a stopped queue
fresh(0); H.rollf = 0.0
p._st.panic = 50; H.action = action("ISCraftAction"); minute()
assert(stopped == 0, "panicked: never")
p._st.panic = 0
for _, t in ipairs({ "ISWalkToTimedAction", "ISPathFindAction", "ISEnterVehicle", "ISRestAction", "ISSensoryStimAction" }) do
  H.action = action(t); minute()
  assert(stopped == 0, t .. " is never interrupted")
end
H.action = nil; minute()
assert(stopped == 0, "nothing to stop")

-- 5. hyperfocus: twenty working minutes lock in
fresh(0); H.rollf = 0.99; H.clearHalo()
H.action = action("ISCraftAction")
for _ = 1, A.FOCUS_AT / 2 do minute() end
assert(DanTraits_AdhdMoodle(p, d) == -1, "half way: getting into it")
H.action = action("ISWalkToTimedAction"); minute()
assert(d.adhdFocus == A.FOCUS_AT / 2, "walking neither builds nor breaks it")
H.action = action("ISCraftAction")
for _ = 1, A.FOCUS_AT / 2 - 1 do minute() end
assert(not d.adhdHyper, "not yet")
minute()
assert(d.adhdHyper, "locked in")
assert(DanTraits_AdhdMoodle(p, d) == -2, "the moodle: hyperfocused")
assert(H.halo[#H.halo] == "+UI_DanTraits_AdhdHyper", "a good notice")

-- locked in: no drifting, boredom eases and does not rise, a skill book is no slog
H.rollf = 0.0; stopped = 0
minute()
assert(stopped == 0, "hyperfocused: never drifts off")
p._st.boredom = 20; d.deltaLast.boredomRise = 20; minute()
near(p._st.boredom, 20 - A.HYPER_BOREDOM, 1e-9, "boredom eases")
p._st.boredom = 25; minute()
near(p._st.boredom, 20 - A.HYPER_BOREDOM * 2, 1e-9, "a rise is wiped out")
local b0 = p._st.boredom; d.deltaLast.boredomRise = b0
p._st.boredom = b0 + 3; d.floorsThisMinute = { boredomRise = true }; minute()
near(p._st.boredom, b0 + 3 - A.HYPER_BOREDOM, 1e-9, "another system's floor is not wiped out")
H.action = action("ISReadABook", book("Carpentry", 9))
local b = p._st.boredom; minute()
near(p._st.boredom, b - A.HYPER_BOREDOM, 1e-9, "hyperfocus carries you through a skill book")
assert(d.adhdHyper, "and it holds")

-- quicker actions started now (adjustMaxTime), more experience (AddXP)
local base = action("ISCraftAction"); base.character = p
near(ISBaseTimedAction.adjustMaxTime(base, 100), 100 * A.HYPER_TIME, 1e-9, "actions go quicker")
near(ISBaseTimedAction.adjustMaxTime(base, 1), 1, 1e-9, "an instant action is left alone")
local added = {}
function DanTraits_AgeXpAdjust(_, perk, extra) added[#added + 1] = { perk = perk, extra = extra } end
H.fire("AddXP", p, "Woodwork", 10)
assert(#added == 1 and added[1].perk == "Woodwork", "one adjustment")
near(added[1].extra, 10 * (A.HYPER_XP - 1), 1e-9, "a tenth more experience")

-- it breaks: three idle minutes, panic, sleep
H.action = nil; minute(); minute()
assert(d.adhdHyper, "two idle minutes: still locked in")
minute()
assert(not d.adhdHyper and d.adhdFocus == 0, "three idle minutes: snapped out")
assert(H.halo[#H.halo] == "UI_DanTraits_AdhdHyperEnd", "the snap-out notice")
near(ISBaseTimedAction.adjustMaxTime(base, 100), 100, 1e-9, "normal speed again")
added = {}; H.fire("AddXP", p, "Woodwork", 10)
assert(#added == 0, "normal experience again")

fresh(0); d.adhdHyper = true; H.action = action("ISCraftAction")
p._st.panic = 50; minute(); p._st.panic = 0
assert(not d.adhdHyper, "panic breaks it")
fresh(0); d.adhdHyper = true
p._asleep = true; minute(); p._asleep = false
assert(not d.adhdHyper, "sleep ends it")

-- 6. coffee: a mug softens the boredom, the drifting, and locks in sooner
fresh(0); H.clearHalo()
DanTraits_AdhdOnCaffeine(p, A.CAF_FULL)
assert(H.halo[#H.halo] == "+UI_DanTraits_AdhdCoffee", "a clearer head")
H.action = nil
p._st.boredom = 2; minute()
near(p._st.boredom, 2 * A.CAF_BOREDOM_MULT, 0.01, "a rise of 2 counts as 2.5 on coffee")
fresh(0); d.adhdCaf = A.CAF_FULL
H.rollf = A.DRIFT * 0.75; H.action = action("ISCraftAction"); minute()
assert(stopped == 0, "coffee: a roll under the base chance carries on")
fresh(0); d.adhdCaf = A.CAF_FULL; H.rollf = 0.99
for _ = 1, A.FOCUS_AT - A.CAF_FOCUS_CUT + 1 do minute() end   -- +1: the mug wears off a little meanwhile
assert(d.adhdHyper, "coffee: locked in about five minutes sooner")
fresh(0); d.adhdCaf = A.CAF_FULL
for _ = 1, 300 do minute() end
assert(d.adhdCaf > A.CAF_FULL * 0.49 and d.adhdCaf < A.CAF_FULL * 0.51, "half gone in five hours")
H.action = nil; minute(); minute(); minute()

-- 7. novelty: a new building lifts boredom and mood once; home is dull
fresh(50); p._st.unhappy = 20; H.clearHalo(); H.action = nil
H.place = { x = 5, y = 5, z = 0, b = { 0, 0, 10, 10 } }
minute()
assert(p._st.boredom == 50, "where they start is not new")
H.place = { x = 25, y = 5, z = 0, b = { 20, 0, 30, 10 } }
minute()
near(p._st.boredom, 50 - A.NEW_BOREDOM, 1e-9, "somewhere new: boredom off")
near(p._st.unhappy, 20 - A.NEW_UNHAPPY, 1e-9, "and a little lift")
assert(H.halo[#H.halo] == "+UI_DanTraits_AdhdNew", "the notice")
local after = p._st.boredom
minute()
near(p._st.boredom, after, 1e-9, "the same building twice: nothing")
H.place = { x = 45, y = 5, z = 0, b = { 40, 0, 50, 10 } }
minute()
near(p._st.boredom, after, 1e-9, "inside the gap: nothing yet")
H.hours = H.hours + (A.NEW_GAP_MIN + 1) / 60; minute()
near(p._st.boredom, after - A.NEW_BOREDOM, 1e-9, "a building found in the gap is still new after it")
H.place = { x = 60, y = 60, z = 0 }; minute()
assert(d.adhdSeenN == 3, "outdoors counts nothing")
H.place = nil

near(DanTraits_RunHooks("homeBoredom", 0.3, p), 0.3 * A.HOME_BOREDOM, 1e-9, "home eases boredom half as much")
near(DanTraits_RunHooks("homeBoredom", 0.3, q), 0.3, 1e-9, "no trait: home as ever")

-- 8. the console: distract and focus
fresh(0); H.hours = H.hours + 2
DanTraits_ExtraCommands.adhd(p, { "distract" })
H.rollf = 0.99; H.action = action("ISCraftAction")
minute()
assert(stopped == 1, "distract forces it")
DanTraits_ExtraCommands.adhd(p, { "focus" })
H.action = action("ISCraftAction"); minute()
assert(d.adhdHyper, "focus locks in at the next working minute")
assert(DanTraits_ExtraCommands.adhd(p, {}):find("hyperfocused"), "the status line")

-- 9. without the trait nothing happens
H.current = q; H.rollf = 0.0; stopped = 0
q._st.boredom = 0; minute()
H.action = action("ISReadABook", book("Carpentry", 9)); minute()
assert(stopped == 0, "no trait: no drifting")
near(q._st.boredom, 0, 1e-9, "no trait: books are fine")
for _ = 1, 30 do H.action = action("ISCraftAction"); minute() end
assert(DanTraits_AdhdMoodle(q, DanTraits_Data(q)) == 0, "no trait: no moodle")
DanTraits_AdhdOnCaffeine(q, 100)
assert(DanTraits_Data(q).adhdCaf == nil, "no trait: coffee is just coffee")

H.pass("adhd")
