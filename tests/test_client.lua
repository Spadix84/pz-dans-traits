-- Offline test for client/DanTraits_Client.lua: the inventory context menus and the character
-- creation wrap. A stub menu (addOption, getOptionFromName, removeOptionByName, addSubMenu, getNew)
-- records what was offered: the inhaler option greys when empty and the vanilla pill option is
-- removed; the insulin submenu greys doses above what is left (and the whole option for a
-- non-diabetic or an empty pen); the glucose meter needs strips; Vegetarian greys Eat (and the
-- item's custom option) on meat; iron pills, nicotine gum, anticonvulsants and sun block;
-- the moodles DanTraits_Moodles.lua lists are created; isTraitEnabled hides Wakeful (and
-- Deep Sleeper on a no-sleep server) from character creation.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("DanTraits")   -- the core: DanTraits_Wrap, which the client file wraps with

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
CharacterCreationProfession = { isTraitEnabled = function() return true end, setVisible = function(self, v) self._shown = v end,
  repopulateTraitLists = function(self) self._repopulated = (self._repopulated or 0) + 1 end }
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
  function it:getCurrentUsesFloat() return self._uses end
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

-- 2. insulin: a submenu of 1, 2, 4, 8 doses; doses above what is left are greyed
local pen = item("insulin", 3)
m = open({ pen })
o = m.options[1]
assert(o.name == "ContextMenu_DanTraits_Inject" and not o.notAvailable and o.sub, "inject has a submenu")
local doses = o.sub.options
assert(#doses == 4, "four dose options")
assert(not doses[1].notAvailable and not doses[2].notAvailable, "1 and 2 doses are fine with 3 left")
assert(doses[3].notAvailable and doses[4].notAvailable and tip(doses[3]) == "Tooltip_DanTraits_InsulinShort", "4 and 8 greyed")
assert(doses[1].name == "ContextMenu_DanTraits_InjectDoses:1" and doses[3].name == "ContextMenu_DanTraits_InjectDoses:4", "labelled by dose count")
choose(doses[2])
assert(queued[#queued].kind == "inject" and queued[#queued].doses == 2 and queued[#queued].item == pen, "click queues an injection of 2")
m = open({ item("insulin", 8) }); assert(not m.options[1].sub.options[4].notAvailable, "8 left: all four offered")
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
-- the Age traits are hidden when the sandbox switches Age off
multiplayer = false
assert(list.isTraitEnabled(list, trait("age40s")) == true and list.isTraitEnabled(list, trait("age20s")) == true, "Age on: both offered")
-- at creation the live sandbox options decide (SandboxVars is still the previous game's copy)
local ageOption = true
function getSandboxOptions() return { getOptionByName = function(_, name) if name == "DanTraits.AgeEnabled" then return { getValue = function() return ageOption end } end end } end
SandboxVars = { DanTraits = { AgeEnabled = true } }
ageOption = false
assert(list.isTraitEnabled(list, trait("age40s")) == false and list.isTraitEnabled(list, trait("age20s")) == false, "Age off in the new game's options: both hidden, whatever SandboxVars says")
assert(list.isTraitEnabled(list, trait("base:brave")) == true, "others unaffected by Age off")
ageOption = true
assert(list.isTraitEnabled(list, trait("age40s")) == true, "Age on in the options: offered")
getSandboxOptions = nil; SandboxVars = { DanTraits = { AgeEnabled = false } }
assert(list.isTraitEnabled(list, trait("age40s")) == false, "no options object: SandboxVars decides")
SandboxVars = nil
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
