-- Offline test for client/DanTraits_Client.lua: the inventory context menus and the character
-- creation wrap. A stub menu (addOption, getOptionFromName, removeOptionByName, addSubMenu, getNew)
-- records what was offered: the inhaler option greys when empty and the vanilla pill option is
-- removed; the insulin submenu greys doses above what is left (and the whole option for a
-- non-diabetic or an empty pen); the glucose meter needs strips; Vegetarian greys Eat (and the
-- item's custom option) on meat; iron pills, nicotine gum, anticonvulsants and sun block;
-- the moodles DanTraits_Moodles.lua lists are created; isTraitEnabled hides Wakeful (and
-- Deep Sleeper on a no-sleep server) from character creation; In Their 30s is never offered
-- and age's levels are added to the Major Skills list (checkXPBoost); the body traits'
-- extra cost with age comes off the points to spend and is drawn on their rows; the traits
-- only one age can take are offered to that age alone and dropped when the age changes
-- (not while a saved build loads); a chosen trait's exclusions hide the other trait too.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("DanTraits", "Age", "AgeTraits")   -- the core: DanTraits_Wrap, which the client file wraps with; Age: the levels

-- the game's UI classes the file reaches for
local queued, transfers = {}, {}
ISInventoryPaneContextMenu = {
  addToolTip = function() return { description = nil } end,
  transferIfNeeded = function(player, item) transfers[#transfers + 1] = item end,
}
ISTimedActionQueue = { add = function(action) queued[#queued + 1] = action end }
ISUseInhalerAction = { new = function(_, player, item) return { kind = "inhaler", item = item } end }
ISDiabetesAction = { new = function(_, player, item, kind, doses, strips)
  return { kind = kind, item = item, doses = doses, strips = strips } end }
ISVitalityPillAction = { new = function(_, player, item, label, anim, time)
  return { kind = "vitality", item = item, label = label, anim = anim, time = time } end }
SandboxOptionsScreen = { setSandboxVars = function() end }
MainScreen = { instance = {} }
local drawn = {}
CharacterCreationProfession = { isTraitEnabled = function() return true end, setVisible = function(self, v) self._shown = v end,
  repopulateTraitLists = function(self) self._repopulated = (self._repopulated or 0) + 1 end,
  -- vanilla's list: the profession's and the chosen traits' boosts, Fitness and Strength at 5
  checkXPBoost = function(self)
    local list = self.listboxXpBoost
    list.items = {}
    for perk, level in pairs(self._vanilla) do list:addItem("name:" .. perk, { perk = perk, level = level }) end
  end,
  drawXpBoostMap = function(self, y, item) drawn[#drawn + 1] = { text = item.text, perk = item.item.perk, level = item.item.level }; return y + 20 end,
  PointToSpend = function(self) return self._points or 0 end,
  prerender = function(self) self._prerendered = (self._prerendered or 0) + 1 end,
  removeTrait = function(self, i) self._removed = (self._removed or 0) + 1; table.remove(self.listboxTraitSelected.items, i) end,
  -- a saved build: its traits are looked up in the lists (isTraitEnabled) and added one by one
  loadBuild = function(self, box)
    self._offeredWhileLoading = {}
    for _, kind in ipairs(box.build) do
      self._offeredWhileLoading[kind] = self:isTraitEnabled({ getType = function() return kind end })
      self.listboxTraitSelected.items[#self.listboxTraitSelected.items + 1] = { item = { getType = function() return kind end } }
      self:checkXPBoost()
    end
    return "loaded"
  end,
  drawTraitMap = function(self, y, item) self._rows = (self._rows or 0) + 1; return y + 24 end,
  -- vanilla's render decides Next from the points each frame; the lists are cleared and filled
  render = function(self) self.playButton:setEnable(true); self.playButton:setTooltip(nil) end,
  populateTraitList = function(self, list) list:clear() end,
  isTraitExcluded = function(self, def) return false end,
  resetBuild = function(self) self._reset = (self._reset or 0) + 1; self.listboxTraitSelected.items = {} end,
  -- vanilla's random: reset, roll, and (here) its balancing has taken everything back off again
  randomizeTraits = function(self) self:resetBuild(); self._randomized = true; self.listboxTraitSelected.items = {} end,
  instance = { whiteBar = "BAR" } }
function getCore() return { getBadHighlitedColor = function() return { getR = function() return 1 end, getG = function() return 0 end, getB = function() return 0 end } end } end
PerkFactory = { getPerkName = function(perk) return "name:" .. perk end }
UIFont = { Small = "small", Medium = "medium" }
function getTextManager() return { getFontHeight = function() return 20 end, MeasureStringX = function() return 40 end } end
function transformIntoKahluaTable(t) return t end
local multiplayer, serverAllows = false, true
function isMultiplayer() return multiplayer end
function getServerOptions() return { getBoolean = function() return serverAllows end } end

-- what the trait files provide, by the items' _kind
local function isKind(kind) return function(item) return item._kind == kind end end
DanTraits_IsInhaler, DanTraits_IsInsulin, DanTraits_IsMeter = isKind("inhaler"), isKind("insulin"), isKind("meter")
DanTraits_IsStrips, DanTraits_IsMetformin = isKind("strips"), isKind("metformin")
DanTraits_IsIronPills, DanTraits_IsNicotineGum = isKind("iron"), isKind("gum")
DanTraits_IsAnticonvulsants, DanTraits_IsSunblock = isKind("anticonvulsants"), isKind("sunblock")
DanTraits_IsMSMed = isKind("msmed")
-- Moodle Framework, and the list of moodles the shared file hands the client
local created = {}
MF = { createMoodle = function(name) created[#created + 1] = name end }
DanTraits_MoodleNames = { "ChestPain", "Sunburn" }
local diabetic = true
DanTraits_IsDiabetic = function() return diabetic end
DanTraits_RefuseReason = function(_, item)
  if item._kind == "meat" then return "UI_DanTraits_VegetarianRefuse" end
  if item._kind == "cigs" then return "UI_DanTraits_StraightEdgeRefuse" end
end

H.load("client/DanTraits_Client.lua")
H.expectHooks("OnFillInventoryObjectContextMenu", "OnGameBoot", "OnMainMenuEnter")
assert(#created == 11 and created[1] == "AirwayIrritation" and created[9] == "BloodSugar" and created[10] == "ChestPain" and created[11] == "Sunburn",
  "the eight older moodles and Blood Sugar, then the listed ones")
MF = nil

-- an item: kind and uses left
local function item(kind, uses, extra)
  local it = { _kind = kind, _uses = uses }
  -- as the game: a count of uses, and separately how full it is (0 to 1)
  function it:getCurrentUses() return math.floor(self._uses) end
  function it:getCurrentUsesFloat() return self._uses > 0 and math.min(1, self._uses / 40) or 0 end
  for k, v in pairs(extra or {}) do it[k] = v end
  return it
end

-- a context menu that records its options; `preset` names options already on it (vanilla's)
local function menu(preset)
  local m = { options = {}, removed = {} }
  for _, name in ipairs(preset or {}) do m.options[#m.options + 1] = { name = name } end
  function m:addOption(name, target, fn, ...)
    local o = { name = name, target = target, fn = fn, params = { ... } }
    self.options[#self.options + 1] = o
    return o
  end
  function m:getOptionFromName(name)
    for _, o in ipairs(self.options) do if o.name == name then return o end end
  end
  function m:removeOptionByName(name)
    self.removed[#self.removed + 1] = name
    for i, o in ipairs(self.options) do if o.name == name then table.remove(self.options, i); return end end
  end
  function m:getNew() return menu() end
  function m:addSubMenu(option, sub) option.sub = sub end
  return m
end
local function choose(option) option.fn(option.target, table.unpack(option.params)) end   -- the click

local player = H.player({ traits = {} })
H.current = player
local function open(items, preset)
  local m = menu(preset)
  H.fire("OnFillInventoryObjectContextMenu", 0, m, items)
  return m
end
local function tip(option) return option.toolTip and option.toolTip.description end

-- 0. no character: nothing offered
H.current = nil
assert(#open({ item("inhaler", 3) }).options == 0, "no player: no options")
H.current = player

-- 1. an inhaler: the vanilla pill option goes, ours is offered; empty greys it with the reason
local m = open({ item("inhaler", 3) }, { "ContextMenu_Take_pills" })
assert(m.removed[1] == "ContextMenu_Take_pills" and #m.options == 1, "vanilla pill option removed")
local o = m.options[1]
assert(o.name == "ContextMenu_DanTraits_UseInhaler" and not o.notAvailable, "inhaler offered")
choose(o)
assert(queued[#queued].kind == "inhaler" and transfers[#transfers] == o.target, "click queues the action after moving it to the bag")
m = open({ item("inhaler", 0) })
o = m.options[1]
assert(o.notAvailable and tip(o) == "Tooltip_DanTraits_InhalerEmpty", "empty inhaler greyed with its reason")
assert(#open({ item("bandage", 1) }).options == 0, "an ordinary item: nothing added")

-- 2. insulin: a submenu of 1, 2, 3, 4, 8 doses (3 since 2026-10-08); doses above what is left are greyed
local pen = item("insulin", 3)
m = open({ pen })
o = m.options[1]
assert(o.name == "ContextMenu_DanTraits_Inject" and not o.notAvailable and o.sub, "inject has a submenu")
local doses = o.sub.options
assert(#doses == 5, "five dose options")
assert(not doses[1].notAvailable and not doses[2].notAvailable and not doses[3].notAvailable, "1, 2 and 3 doses are fine with 3 left")
assert(doses[4].notAvailable and doses[5].notAvailable and tip(doses[4]) == "Tooltip_DanTraits_InsulinShort", "4 and 8 greyed")
assert(doses[1].name == "ContextMenu_DanTraits_InjectDoses:1" and doses[3].name == "ContextMenu_DanTraits_InjectDoses:3", "labelled by dose count")
choose(doses[2])
assert(queued[#queued].kind == "inject" and queued[#queued].doses == 2 and queued[#queued].item == pen, "click queues an injection of 2")
m = open({ item("insulin", 8) }); assert(not m.options[1].sub.options[5].notAvailable, "8 left: all five offered")
m = open({ item("insulin", 0) }); o = m.options[1]
assert(o.notAvailable and tip(o) == "Tooltip_DanTraits_InsulinEmpty" and not o.sub, "empty pen greyed, no submenu")
diabetic = false
m = open({ item("insulin", 5) }); o = m.options[1]
assert(o.notAvailable and tip(o) == "Tooltip_DanTraits_NotDiabetic" and not o.sub, "not diabetic: greyed with the reason")
diabetic = true

-- 3. the meter needs strips: found in the inventory, else greyed
local strips = item("strips", 4)
player.getInventory = function()
  return { getAllEvalRecurse = function(_, test)
    local hit = test(strips) and { strips } or {}
    return { size = function() return #hit end, get = function(_, i) return hit[i + 1] end }
  end }
end
local meter = item("meter", 1)
m = open({ meter }); o = m.options[1]
assert(o.name == "ContextMenu_DanTraits_CheckSugar" and not o.notAvailable, "meter with strips in the pack")
choose(o); assert(queued[#queued].kind == "test" and queued[#queued].strips == strips and transfers[#transfers] == strips, "strips ride along")
strips._uses = 0
m = open({ meter }); o = m.options[1]
assert(o.notAvailable and tip(o) == "Tooltip_DanTraits_NoStrips", "no usable strips: greyed")
strips._uses = 4

-- 4. metformin: greyed for a non-diabetic and when empty
m = open({ item("metformin", 2) }); o = m.options[1]
assert(o.name == "ContextMenu_DanTraits_TakeMetformin" and not o.notAvailable, "metformin offered")
choose(o); assert(queued[#queued].kind == "pill", "click queues the pill action")
diabetic = false
m = open({ item("metformin", 2) }); assert(tip(m.options[1]) == "Tooltip_DanTraits_NotDiabetic", "not diabetic: greyed")
diabetic = true
m = open({ item("metformin", 0) }); assert(tip(m.options[1]) == "Tooltip_DanTraits_MetforminEmpty", "empty: greyed")

-- 5. Vegetarian: Eat is greyed on meat, and so is the item's own custom option; other food is left alone
local eat = menu({ "ContextMenu_Eat", "Gnaw" })
local meat = item("meat", 1, { getCustomMenuOption = function() return "Gnaw" end })
H.fire("OnFillInventoryObjectContextMenu", 0, eat, { meat })
assert(eat.options[1].notAvailable and tip(eat.options[1]) == "Tooltip_DanTraits_VegetarianRefuse", "Eat greyed on meat")
assert(eat.options[2].notAvailable, "the custom eat option too")
local bread = menu({ "ContextMenu_Eat" })
H.fire("OnFillInventoryObjectContextMenu", 0, bread, { item("bread", 1) })
assert(not bread.options[1].notAvailable, "bread: left alone")
local smoke = menu({ "ContextMenu_Eat", "Smoke" })
H.fire("OnFillInventoryObjectContextMenu", 0, smoke, { item("cigs", 1, { getCustomMenuOption = function() return "Smoke" end }) })
assert(smoke.options[2].notAvailable and tip(smoke.options[2]) == "Tooltip_DanTraits_StraightEdgeRefuse", "Straight Edge: Smoke greyed with its own reason")
local noEat = menu({})
H.fire("OnFillInventoryObjectContextMenu", 0, noEat, { meat })   -- no Eat option on the menu: no error
assert(#noEat.options == 0, "no Eat option: nothing to grey")

-- 6. iron pills and nicotine gum: the vanilla pill option goes; empty greys
m = open({ item("iron", 3) }, { "ContextMenu_Take_pills" })
assert(m.removed[1] == "ContextMenu_Take_pills" and m.options[1].name == "ContextMenu_DanTraits_TakeIronPill", "iron pills offered")
choose(m.options[1]); assert(queued[#queued].kind == "vitality" and queued[#queued].label == nil, "iron pill action")
m = open({ item("iron", 0) }); assert(tip(m.options[1]) == "Tooltip_DanTraits_IronPillsEmpty", "empty iron pills greyed")
m = open({ item("gum", 2) }, { "ContextMenu_Take_pills" })
assert(m.options[1].name == "ContextMenu_DanTraits_ChewGum", "gum offered")
choose(m.options[1]); assert(queued[#queued].label == "ContextMenu_DanTraits_ChewGum", "gum action carries its label")
m = open({ item("gum", 0) }); assert(tip(m.options[1]) == "Tooltip_DanTraits_NicotineGumEmpty", "empty gum greyed")

-- 6b. anticonvulsants and sun block: their own options; sun block is rubbed in, not swallowed
m = open({ item("anticonvulsants", 5) }, { "ContextMenu_Take_pills" })
assert(m.removed[1] == "ContextMenu_Take_pills" and m.options[1].name == "ContextMenu_DanTraits_TakeAnticonvulsant", "anticonvulsants offered")
m = open({ item("sunblock", 8) }, { "ContextMenu_Take_pills" })
assert(m.removed[1] == "ContextMenu_Take_pills" and #m.options == 1, "no pill option on sun block")
o = m.options[1]
assert(o.name == "ContextMenu_DanTraits_ApplySunblock" and not o.notAvailable, "sun block offered")
choose(o)
assert(queued[#queued].kind == "vitality" and queued[#queued].label == "ContextMenu_DanTraits_ApplySunblock", "the action carries its label")
assert(queued[#queued].anim == "WashFace" and queued[#queued].time == 150, "rubbed in, and it takes a little longer")
m = open({ item("sunblock", 0) }); assert(tip(m.options[1]) == "Tooltip_DanTraits_SunblockEmpty", "empty sun block greyed")

-- 6c. the MS pills: one option each, its label named after the item
--     (ContextMenu_DanTraits_Take<Type> in Translate/EN/ContextMenu.json)
for _, name in ipairs({ "Prednisone", "Baclofen", "Amantadine" }) do
  local function pill(uses) return item("msmed", uses, { getType = function() return name end }) end
  m = open({ pill(4) }, { "ContextMenu_Take_pills" })
  o = m.options[1]
  assert(m.removed[1] == "ContextMenu_Take_pills" and #m.options == 1, name .. ": no vanilla pill option")
  assert(o.name == "ContextMenu_DanTraits_Take" .. name, name .. " offered")
  choose(o)
  assert(queued[#queued].kind == "vitality" and queued[#queued].label == o.name, name .. ": the action carries its label")
  m = open({ pill(0) }); assert(tip(m.options[1]) == "Tooltip_DanTraits_MSMedEmpty", name .. ": empty bottle greyed")
end

-- 7. character creation: Wakeful (needs-less-sleep) is hidden, Deep Sleeper follows the server's sleep rule
local function trait(kind) return { getType = function() return kind end } end
local list = CharacterCreationProfession
assert(list.isTraitEnabled(list, trait("base:needslesssleep")) == false, "Wakeful hidden")
assert(list.isTraitEnabled(list, trait("base:brave")) == true, "an ordinary trait shown")
assert(list.isTraitEnabled(list, trait("deepsleeper")) == true, "Deep Sleeper shown in single player")
multiplayer, serverAllows = true, true
assert(list.isTraitEnabled(list, trait("deepsleeper")) == true, "and on a server with sleep on")
serverAllows = false
assert(list.isTraitEnabled(list, trait("deepsleeper")) == false, "hidden on a server where sleep is off")
assert(list.isTraitEnabled(list, trait("base:brave")) == true, "others unaffected by the server")
-- the Age traits are hidden when the sandbox switches Age off; In Their 30s is never offered
multiplayer = false
assert(list.isTraitEnabled(list, trait("age40s")) == true and list.isTraitEnabled(list, trait("age20s")) == true
  and list.isTraitEnabled(list, trait("age50s")) == true, "Age on: the 20s, 40s and 50s offered")
assert(list.isTraitEnabled(list, trait("age30s")) == true, "In Their 30s offered too (0 points, put in the list by hand)")
-- at creation the live sandbox options decide (SandboxVars is still the previous game's copy)
local ageOption = true
function getSandboxOptions() return { getOptionByName = function(_, name) if name == "DanTraits.AgeEnabled" then return { getValue = function() return ageOption end } end end } end
SandboxVars = { DanTraits = { AgeEnabled = true } }
ageOption = false
assert(list.isTraitEnabled(list, trait("age40s")) == false and list.isTraitEnabled(list, trait("age20s")) == false
  and list.isTraitEnabled(list, trait("age50s")) == false, "Age off in the new game's options: all hidden, whatever SandboxVars says")
assert(list.isTraitEnabled(list, trait("base:brave")) == true, "others unaffected by Age off")
ageOption = true
assert(list.isTraitEnabled(list, trait("age40s")) == true, "Age on in the options: offered")
getSandboxOptions = nil; SandboxVars = { DanTraits = { AgeEnabled = false } }
assert(list.isTraitEnabled(list, trait("age40s")) == false, "no options object: SandboxVars decides")
SandboxVars = nil
-- 7b. the Major Skills list: age's levels are added after vanilla builds it
local function skills(profBoosts, traits, vanilla)
  local sc = setmetatable({ _vanilla = vanilla, listboxTraitSelected = { items = {} } }, { __index = CharacterCreationProfession })
  for _, kind in ipairs(traits) do sc.listboxTraitSelected.items[#sc.listboxTraitSelected.items + 1] = { item = trait(kind) } end
  sc.profession = profBoosts and { getXpBoosts = function() return profBoosts end } or nil
  sc.listboxXpBoost = { items = {}, width = 400, itemheight = 24, fontHgt = 20, _bars = {},
    addItem = function(self, text, item) local row = { text = text, item = item }; self.items[#self.items + 1] = row; return row end,
    sort = function(self) self._sorted = true end,
    drawTextureScaled = function(self, tex, x, y, w, h, a, r, g, b) self._bars[#self._bars + 1] = { tex = tex, x = x, b = b } end }
  sc:checkXPBoost()
  local byPerk = {}
  for _, row in ipairs(sc.listboxXpBoost.items) do byPerk[row.item.perk] = row end
  return byPerk, sc.listboxXpBoost
end
local carpenter = { Woodwork = 4, Carving = 1 }
local rows, box = skills(carpenter, {}, { Woodwork = 4, Carving = 1, Fitness = 5, Strength = 5 })
assert(rows.Woodwork.item.level == 4 and rows.Woodwork.item.ageLevels == nil, "no age picked: nothing added until one is (the default no longer stands in)")
rows, box = skills(carpenter, { "age30s" }, { Woodwork = 4, Carving = 1, Fitness = 5, Strength = 5 })
assert(rows.Woodwork.item.level == 5 and rows.Woodwork.item.ageLevels == 1, "the 30s picked: +1 on the main skill")
assert(rows.Woodwork.text == "name:Woodwork UI_DanTraits_AgeLevels:1", "the row says how many are age's")
assert(rows.Carving.item.level == 1 and rows.Carving.item.ageLevels == nil and rows.Fitness.item.level == 5, "other rows untouched")
assert(box._sorted and box.doDrawItem ~= nil, "sorted again, and the age draw is in place")
rows = skills(carpenter, { "age20s" }, { Woodwork = 4, Fitness = 5, Strength = 5 })
assert(rows.Woodwork.item.level == 4 and rows.Woodwork.item.ageLevels == nil, "20s: nothing added")
rows = skills(carpenter, { "age50s", "base:handy" }, { Woodwork = 5, Fitness = 5, Strength = 5 })
assert(rows.Woodwork.item.level == 9 and rows.Woodwork.item.ageLevels == 4, "50s Handy carpenter: 5 from the game, +3 +1 from age")
assert(rows.Carving and rows.Carving.item.level == 2 and rows.Carving.item.ageLevels == 2, "and a row for a side skill the game's list did not have")
rows = skills(carpenter, { "age40s" }, { Woodwork = 4, Carving = 1 })
assert(rows.Woodwork.item.ageLevels == 2 and rows.Carving.item.level == 2 and rows.Carving.item.ageLevels == 1, "40s: +2 main, +1 side")
rows = skills({ Woodwork = 9 }, { "age50s" }, { Woodwork = 9 })
assert(rows.Woodwork.item.level == 10 and rows.Woodwork.item.ageLevels == 1, "capped at 10")
rows, box = skills(nil, { "age40s" }, { Fitness = 5, Strength = 5 })
assert(rows.Maintenance and rows.Maintenance.item.level == 2 and rows.Maintenance.item.ageLevels == 2, "Unemployed 40s: a Maintenance row is added")
-- the draw: vanilla draws the game's levels, age's bars follow in their own colour
drawn = {}
box.doDrawItem(box, 0, rows.Maintenance)
assert(#drawn == 1 and drawn[1].level == 0 and drawn[1].perk == Perks.Fitness, "an age-only skill: vanilla draws no bars and no XP rate")
assert(#box._bars == 2 and box._bars[1].tex == "BAR" and box._bars[2].x > box._bars[1].x and box._bars[1].b == 1.0, "two age bars")
rows, box = skills(carpenter, { "age40s" }, { Woodwork = 4, Fitness = 5, Strength = 5 })
drawn = {}
box.doDrawItem(box, 0, rows.Woodwork); box.doDrawItem(box, 0, rows.Fitness)
assert(drawn[1].level == 4 and drawn[1].perk == "Woodwork" and #box._bars == 2, "the game's 4 by vanilla (its XP rate too), then 2 age bars")
assert(drawn[2].level == 5 and #box._bars == 2, "a row without age levels is vanilla's own draw")
-- the new game's sandbox options decide, not SandboxVars
local live = { ["DanTraits.AgeEnabled"] = true, ["DanTraits.AgeDefault"] = 52, ["DanTraits.AgeBonus50s"] = 2, ["DanTraits.AgeBonus40s"] = 5 }
function getSandboxOptions() return { getOptionByName = function(_, name) if live[name] ~= nil then return { getValue = function() return live[name] end } end end } end
rows = skills(carpenter, {}, { Woodwork = 4 })
assert(rows.Woodwork.item.ageLevels == nil, "default age 52 does not stand in at creation: no age picked, nothing added")
rows = skills(carpenter, { "age40s" }, { Woodwork = 4 })
assert(rows.Woodwork.item.ageLevels == 5, "a picked band reads its own option")
live["DanTraits.AgeEnabled"] = false
rows, box = skills(carpenter, { "age40s" }, { Woodwork = 4 })
assert(rows.Woodwork.item.level == 4 and rows.Woodwork.item.ageLevels == nil, "Age off: the list is vanilla's")
getSandboxOptions = nil
-- 7c. the body traits cost more with age: off the points to spend, and drawn on the row
local function points(traits, live)
  local sc = setmetatable({ _points = 20, listboxTraitSelected = { items = {} }, listboxTrait = {} }, { __index = CharacterCreationProfession })
  for _, kind in ipairs(traits) do sc.listboxTraitSelected.items[#sc.listboxTraitSelected.items + 1] = { item = trait(kind) } end
  if live then getSandboxOptions = function() return { getOptionByName = function(_, name) if live[name] ~= nil then return { getValue = function() return live[name] end } end end } end end
  local n = sc:PointToSpend()
  getSandboxOptions = nil
  return n, sc
end
assert(points({ "base:strong", "base:fit" }) == 20, "no age picked: vanilla's total")
assert(points({ "age20s", "base:strong", "base:athletic" }) == 20, "20s: nothing extra")
assert(points({ "age40s", "base:strong" }) == 18, "40s Strong: 2 more")
assert(points({ "age40s", "base:stout", "base:fit" }) == 18, "40s Stout and Fit: 1 each")
assert(points({ "base:athletic", "age50s", "base:stout" }) == 14, "50s Athletic and Stout: 4 + 2, whatever the order")
assert(points({ "age50s", "base:brave" }) == 20, "other traits cost what they cost")
assert(points({ "base:strong" }, { ["DanTraits.AgeEnabled"] = true, ["DanTraits.AgeDefault"] = 55 }) == 20, "no age picked, default 55: no surcharge (the default no longer stands in; the gate makes you pick)")
assert(points({ "age50s", "base:strong" }, { ["DanTraits.AgeEnabled"] = false }) == 20, "Age off: vanilla's total")
-- the rows: checkXPBoost puts the age draw on the lists; it adds the surcharge beside the cost
local _, sc = points({ "age50s", "base:strong" })
sc._vanilla = {}; sc.listboxXpBoost = { items = {}, addItem = function(self, text, item) local row = { text = text, item = item }; self.items[#self.items + 1] = row; return row end, sort = function() end }
sc:checkXPBoost()
assert(sc.listboxTrait.doDrawItem ~= nil and sc.listboxTrait.doDrawItem == sc.listboxTraitSelected.doDrawItem, "both trait lists draw through the age row")
CharacterCreationProfession.instance.listboxTraitSelected = sc.listboxTraitSelected
local texts = {}
local listbox = { itemheight = 24, fontHgt = 20, getWidth = function() return 300 end,
  drawTextRight = function(self, text, x) texts[#texts + 1] = { text = text, x = x } end }
local function row(kind) local t = trait(kind); t.getRightLabel = function() return "+10" end; return { item = t } end
assert(sc.listboxTrait.doDrawItem(listbox, 0, row("base:strong")) == 24 and listbox._rows == 1, "vanilla's row is drawn and its height returned")
assert(#texts == 1 and texts[1].text == "UI_DanTraits_AgeSurcharge:4" and texts[1].x == 300 - 30 - 40, "50s Strong: '+4 at this age' left of the cost")
sc.listboxTrait.doDrawItem(listbox, 0, row("base:fit")); assert(texts[2].text == "UI_DanTraits_AgeSurcharge:2", "50s Fit: 2")
sc.listboxTrait.doDrawItem(listbox, 0, row("base:brave")); assert(#texts == 2 and listbox._rows == 3, "other rows: vanilla's only")
CharacterCreationProfession.instance.listboxTraitSelected = { items = {} }
sc.listboxTrait.doDrawItem(listbox, 0, row("base:strong")); assert(#texts == 2, "no age picked: no surcharge drawn")
CharacterCreationProfession.instance.listboxTraitSelected = nil
-- 7d. the traits only one age can take
local function creation(traits)
  local sc = setmetatable({ _vanilla = {}, listboxTraitSelected = { items = {} }, listboxTrait = {} }, { __index = CharacterCreationProfession })
  for _, kind in ipairs(traits) do sc.listboxTraitSelected.items[#sc.listboxTraitSelected.items + 1] = { item = trait(kind) } end
  sc.listboxXpBoost = { items = {}, addItem = function(self, text, item) local row = { text = text, item = item }; self.items[#self.items + 1] = row; return row end, sort = function() end }
  return sc
end
local function offered(traits, kind) local sc = creation(traits); return sc:isTraitEnabled(trait(kind)) end
local function chosen(sc) local t = {}; for _, row in ipairs(sc.listboxTraitSelected.items) do t[#t + 1] = row.item:getType() end return table.concat(t, ",") end
assert(offered({ "age20s" }, "green") and offered({ "age20s" }, "quickstudy"), "20s: Green and Quick Study offered")
assert(not offered({}, "green") and not offered({ "age40s" }, "quickstudy"), "not to the 30s or 40s")
for _, key in ipairs({ "readingglasses", "badback", "badknees", "oldhand" }) do
  assert(offered({ "age40s" }, key) and offered({ "age50s" }, key), key .. ": the 40s and 50s")
  assert(not offered({}, key) and not offered({ "age20s" }, key), key .. ": not the 20s or 30s")
end
assert(offered({ "age50s" }, "oldinjury") and offered({ "age50s" }, "setinways"), "50s: Old Injury and Set in Their Ways")
assert(not offered({ "age40s" }, "oldinjury") and not offered({}, "setinways"), "not the 40s or 30s")
assert(not offered({}, "base:brave") and offered({ "age50s" }, "base:brave") and offered({ "age30s" }, "base:brave"), "every other trait: any age, once one is chosen (the gate)")
-- the default age counts as the age picked; Age off hides them all
function getSandboxOptions() return { getOptionByName = function(_, name)
  if name == "DanTraits.AgeDefault" then return { getValue = function() return 52 end } end
  if name == "DanTraits.AgeEnabled" then return { getValue = function() return true end } end
end } end
assert(not offered({}, "oldinjury") and not offered({}, "green"), "no age picked: the default does not stand in; nothing but the ages")
function getSandboxOptions() return { getOptionByName = function(_, name) if name == "DanTraits.AgeEnabled" then return { getValue = function() return false end } end end } end
assert(not offered({ "age50s" }, "oldinjury") and not offered({ "age20s" }, "green"), "Age off: none of them")
getSandboxOptions = nil
-- the age changes under a chosen trait: it comes back off when the lists are next worked out
local sc = creation({ "base:brave", "oldhand", "age20s", "green" })
sc:checkXPBoost()
assert(chosen(sc) == "base:brave,age20s,green" and sc._removed == 1, "Old Hand dropped under a 20s age; the rest kept")
sc = creation({ "oldinjury", "badback", "age40s" }); sc:checkXPBoost()
assert(chosen(sc) == "badback,age40s", "the 50s trait dropped in the 40s")
sc = creation({ "oldinjury", "badback" }); sc:checkXPBoost()
assert(chosen(sc) == "", "no age: both dropped")
-- a saved build adds its traits in list order: nothing is hidden or dropped until it has loaded
sc = creation({})
sc.listboxTrait = {}; sc.listboxBadTrait = {}
local result = sc:loadBuild({ build = { "oldhand", "green", "age50s" } })
assert(result == "loaded" and sc._offeredWhileLoading.oldhand == true, "while loading: offered before the age is in")
assert(chosen(sc) == "oldhand,age50s" and sc._removed == 1, "after loading: what the build's age cannot have is dropped, the rest kept")
assert(sc.danTraitsLoadingBuild == nil and sc._repopulated == 1, "the flag is cleared and the lists refilled")
-- the preset box is pointed at the wrapped loader
sc = creation({}); sc.savedBuilds = { onChange = function() end }; sc:checkXPBoost()
assert(sc.savedBuilds.onChange == CharacterCreationProfession.loadBuild, "the preset box loads through the wrap")
-- Green on the Major Skills list: a level off each skill the occupation boosts, greyed
rows, box = skills({ Woodwork = 4, Carving = 1 }, { "age20s", "green" }, { Woodwork = 4, Carving = 1, Fitness = 5 })
assert(rows.Woodwork.item.level == 3 and rows.Woodwork.item.ageLevels == -1 and rows.Woodwork.text == "name:Woodwork UI_DanTraits_AgeLevelsLost:1", "Green: Woodwork 4 -> 3, and the row says so")
assert(rows.Carving.item.level == 0 and rows.Fitness.item.level == 5, "Carving 1 -> 0; Fitness untouched")
drawn = {}
box.doDrawItem(box, 0, rows.Woodwork)
assert(drawn[1].level == 4 and drawn[1].perk == "Woodwork", "vanilla draws the game's 4 (and its XP rate)")
assert(#box._bars == 1 and box._bars[1].b == 0.3, "the lost fourth bar greyed out")
-- 7f. the screen watches the new game's Age settings each frame it is drawn
local opts = { ["DanTraits.AgeEnabled"] = true, ["DanTraits.AgeDefault"] = 30 }
function getSandboxOptions() return { getOptionByName = function(_, name) if opts[name] ~= nil then return { getValue = function() return opts[name] end } end end } end
sc = creation({ "age50s", "oldhand", "base:brave" }); sc.listboxBadTrait = {}
sc:prerender()
assert(sc._prerendered == 1 and sc._repopulated == 1, "first frame: vanilla's prerender runs, and the lists are worked out once")
assert(chosen(sc) == "age50s,oldhand,base:brave", "Age on: the chosen traits stand")
sc:prerender(); sc:prerender()
assert(sc._repopulated == 1 and sc._prerendered == 3, "nothing changed: nothing redone")
opts["DanTraits.AgeEnabled"] = false
sc:prerender()
assert(sc._repopulated == 2, "Age switched off: the lists are worked out again")
assert(chosen(sc) == "base:brave", "and the chosen Age trait and age-only trait come back off")
assert(sc:isTraitEnabled(trait("age20s")) == false and sc:isTraitEnabled(trait("age40s")) == false and sc:isTraitEnabled(trait("age50s")) == false, "no Age trait on offer")
opts["DanTraits.AgeEnabled"] = true
sc:prerender(); assert(sc._repopulated == 3 and sc:isTraitEnabled(trait("age40s")) == true, "switched back on: offered again")
opts["DanTraits.AgeDefault"] = 55
sc:prerender(); assert(sc._repopulated == 4, "a new default age: worked out again (the levels shown depend on it)")
opts["DanTraits.AgeDefault"] = 30
-- 7g. the age gate: with Age on, nothing but the four ages is offered until one is chosen
sc = creation({})
assert(not sc:isTraitEnabled(trait("base:brave")) and not sc:isTraitEnabled(trait("base:strong")), "no age chosen: the ordinary traits are not offered")
assert(sc:isTraitEnabled(trait("age20s")) and sc:isTraitEnabled(trait("age30s")) and sc:isTraitEnabled(trait("age40s")) and sc:isTraitEnabled(trait("age50s")), "the four ages are")
sc = creation({ "age30s" })
assert(sc:isTraitEnabled(trait("base:brave")), "an age chosen: the rest unlocks")
assert(list.isTraitEnabled(list, trait("base:brave")) == true, "no screen state (vanilla's own call): not gated")
opts["DanTraits.AgeEnabled"] = false
sc = creation({})
assert(sc:isTraitEnabled(trait("base:brave")) and not sc:isTraitEnabled(trait("age30s")), "Age off: everything but the ages, and no gate")
opts["DanTraits.AgeEnabled"] = true
sc = creation({}); sc.listboxTrait = {}; sc.listboxBadTrait = {}
sc:loadBuild({ build = { "base:brave", "age40s" } })
assert(sc._offeredWhileLoading["base:brave"] == true, "a preset's traits load before its age: not gated while loading")
-- In Their 30s (0 points) goes into the positive list by hand, once, and not with Age off
local defs = { age30s = { getLabel = function() return "In Their 30s" end, getDescription = function() return "d" end, getType = function() return "age30s" end, isFree = function() return false end, getCost = function() return 0 end } }
CharacterTraitDefinition = { getCharacterTraitDefinition = function(kind) return defs[kind] end }
local function box()
  local b = { items = {} }
  function b:clear() self.items = {} end
  function b:contains(label) for _, it in ipairs(self.items) do if it.label == label then return true end end return false end
  function b:addItem(label, item) self.items[#self.items + 1] = { label = label, item = item } end
  return b
end
local function withContains(sc)
  sc.listboxTraitSelected.contains = function(self, label) for _, row in ipairs(self.items) do if row.item.getLabel and row.item:getLabel() == label then return true end end return false end
  return sc
end
sc = withContains(creation({}))
local good = box()
sc:populateTraitList(good)
assert(#good.items == 1 and good.items[1].label == "In Their 30s" and good.items[1].item == defs.age30s, "the 30s offered in the positive list")
sc:populateTraitList(good)
assert(#good.items == 1, "vanilla clears the list first; the 30s is added once")
sc = withContains(creation({})); sc.listboxTraitSelected.items[1] = { item = defs.age30s }
good = box(); sc:populateTraitList(good)
assert(#good.items == 0, "already chosen: not offered again")
opts["DanTraits.AgeEnabled"] = false
sc = withContains(creation({})); good = box(); sc:populateTraitList(good)
assert(#good.items == 0, "Age off: not offered")
opts["DanTraits.AgeEnabled"] = true
-- Next is greyed until an age is chosen, with the reason as its tooltip and on the screen
local function screenWithButton(traits)
  local s = creation(traits)
  s.playButton = { _enabled = true, setEnable = function(self, v) self._enabled = v end, setTooltip = function(self, t) self._tip = t end, getY = function() return 500 end }
  s.listboxTrait = { getX = function() return 300 end }
  s._texts = {}
  s.drawText = function(self, text, x, y) self._texts[#self._texts + 1] = { text = text, x = x, y = y } end
  return s
end
sc = screenWithButton({})
sc:render()
assert(sc.playButton._enabled == false and sc.playButton._tip == "UI_DanTraits_PickAgeFirst", "no age chosen: Next greyed, the reason as its tooltip")
assert(#sc._texts == 1 and sc._texts[1].text == "UI_DanTraits_PickAgeHint" and sc._texts[1].x == 300 and sc._texts[1].y == 500 - 20 - 15, "and written on the screen, on the points line")
sc = screenWithButton({ "age40s" })
sc:render()
assert(sc.playButton._enabled == true and sc.playButton._tip == nil and #sc._texts == 0, "an age chosen: vanilla decides, nothing drawn")
opts["DanTraits.AgeEnabled"] = false
sc = screenWithButton({}); sc:render()
assert(sc.playButton._enabled == true and #sc._texts == 0, "Age off: no gate")
opts["DanTraits.AgeEnabled"] = true
-- Random picks an age first, right after vanilla's reset; if the balancing takes it off, one is added at the end
defs.age50s = { getType = function() return "age50s" end, getLabel = function() return "In Their 50s" end }
local added = {}
sc = creation({})
sc.addTrait = function(self, def) added[#added + 1] = def:getType(); self.listboxTraitSelected.items[#self.listboxTraitSelected.items + 1] = { item = def } end
H.rng = { 3, 3 }
sc:randomizeTraits()
assert(sc._reset == 1 and sc._randomized == true, "vanilla's random ran, with its reset")
assert(#added == 2 and added[1] == "age50s" and added[2] == "age50s", "an age added right after the reset, and again when vanilla's balancing had taken it off")
assert(rawget(sc, "resetBuild") == nil and chosen(sc) == "age50s", "the screen's reset is the class's again; the build has its age")
H.rng = {}
opts["DanTraits.AgeEnabled"] = false
added = {}; sc = creation({}); sc.addTrait = function(self, def) added[#added + 1] = def:getType() end
sc:randomizeTraits()
assert(#added == 0 and sc._randomized == true, "Age off: random is vanilla's alone")
opts["DanTraits.AgeEnabled"] = true
getSandboxOptions = nil
-- 7e. exclusions work both ways: a chosen trait that excludes another hides it, whichever declares it
local function excl(kind, excludes)
  local t = trait(kind)
  t.isMutuallyExclusive = function(_, other) for _, k in ipairs(excludes or {}) do if other:getType() == k then return true end end return false end
  return t
end
sc = creation({})
sc.listboxTraitSelected.items = { { item = excl("age20s", { "arthritis", "base:handy" }) } }
assert(sc:isTraitEnabled(excl("arthritis")) == false and sc:isTraitEnabled(excl("base:handy")) == false, "In Their 20s chosen: Arthritis and Handy hidden though only the 20s declare it")
assert(sc:isTraitEnabled(excl("base:brave")) == true, "others still offered")
local twenties = sc.listboxTraitSelected.items[1].item
assert(sc:isTraitEnabled(twenties) == true, "a trait is not hidden by itself")
-- vanilla fills the lists once at boot; showing the screen fills them again (with the new game's options)
local screen = setmetatable({ listboxTrait = {}, listboxBadTrait = {} }, { __index = CharacterCreationProfession })
screen:setVisible(true); assert(screen._shown == true and screen._repopulated == 1, "shown: lists refilled")
screen:setVisible(false); assert(screen._repopulated == 1, "hidden: not refilled")
-- the sandbox screen applies the new settings after showing it: fill again then
if SandboxOptionsScreen and MainScreen then
  MainScreen.instance = { charCreationProfession = screen }
  SandboxOptionsScreen.setSandboxVars({}); assert(screen._repopulated == 2, "settings applied: lists refilled")
end
multiplayer = false
-- the wrap is applied once, however many times the boot events re-run it
local wrapped = list.isTraitEnabled
H.fire("OnGameBoot"); H.fire("OnMainMenuEnter")
assert(list.isTraitEnabled == wrapped, "not wrapped twice")

H.pass()
