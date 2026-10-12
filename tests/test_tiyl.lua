local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for client/DanTraits_TIYL.lua (This Is Your Life compatibility).
-- Without This Is Your Life it installs nothing. With it: after the folder's
-- populate, the rows DanTraits_Creation.hides turns down come out (a chosen one
-- stays), and In Their 30s (cost 0, never listed by the folder) goes in at the
-- top of the positive list when the screen offers it, never twice, and not
-- with Age off; Continue is greyed with the hint while the gate is up, and its
-- press (a controller's A) does nothing then; the rows draw the age surcharge.
H.events()
H.stubs()
UIFont = { Small = "small", Medium = "medium", NewSmall = "newsmall" }
function getCore() return {
  getBadHighlitedColor = function() return { getR = function() return 1 end, getG = function() return 0 end, getB = function() return 0 end } end,
  getGoodHighlitedColor = function() return { getR = function() return 0 end, getG = function() return 1 end, getB = function() return 0 end } end,
} end
function getTextManager() return { getFontHeight = function() return 20 end } end

local function def(kind, cost)
  return { _kind = kind, getType = function() return kind end, getCost = function() return cost end,
    isFree = function() return false end, getLabel = function() return "label:" .. kind end,
    getDescription = function() return "desc:" .. kind end }
end
local defs = { age30s = def("age30s", 0) }
CharacterTraitDefinition = { getCharacterTraitDefinition = function(kind) return defs[kind] end }

local function list()
  local l = { items = {}, width = 400 }
  function l:addItem(name, item) local r = { text = name, item = item }; table.insert(self.items, r); return r end
  function l:insertItem(i, name, item) local r = { text = name, item = item }; table.insert(self.items, i, r); return r end
  function l:removeItemByIndex(i) return table.remove(self.items, i) end
  return l
end

-- the hidden vanilla screen: the chosen traits and isTraitEnabled
local hidden, gate, ageOff, enabled30s, band = {}, false, false, true, nil
local vanilla = { listboxTraitSelected = { items = {} } }
function vanilla:isTraitEnabled(trait) if trait == defs.age30s then return enabled30s end return not hidden[trait._kind] end
MainScreen = { instance = { charCreationProfession = vanilla } }
DanTraits_Creation = {
  hides = function(_, trait) return hidden[trait._kind] == true end,
  gateOn = function() return gate end,
  band = function() return band end,
  ageOff = function() return ageOff end,
}
DanTraits_AgeSurcharge = function(b, kind) if b == 40 and kind == "strong" then return 2 end return 0 end

-- without This Is Your Life
H.load("DanTraits", "client/DanTraits_TIYL.lua")
H.expectHooks("OnGameBoot", "OnMainMenuEnter")

-- This Is Your Life's folder, as its file builds it
local brave, strong, age50, retired = def("brave", 4), def("strong", 10), def("age50s", -6), def("jinxed", -2)
local continued, drawnRows, button = 0, 0, {}
function button:setEnable(v) self.enabled = v end
function button:setTooltip(t) self.tooltip = t end
function button:getY() return 500 end
function button:getRight() return 700 end
TIYL = { TraitSelect = {} }
local P = TIYL.TraitSelect
local fill = function(self)
  self.goodList:addItem("brave", brave); self.goodList:addItem("strong", strong)
  self.badList:addItem("age50s", age50); self.badList:addItem("jinxed", retired)
end
function P:populate()
  self.goodList.items, self.badList.items = {}, {}
  fill(self)
end
function P:render() self.continueButton:setEnable(true); self.continueButton:setTooltip(nil) end
function P:onContinue() continued = continued + 1 end
function P:drawTextRight(text) self._hint = text end
local panel = setmetatable({ goodList = list(), badList = list(), continueButton = button }, { __index = P })
panel.goodList.doDrawItem = function(_, y) drawnRows = drawnRows + 1; return y + 54 end
panel.badList.doDrawItem = panel.goodList.doDrawItem

H.fire("OnGameBoot")

local function kinds(l) local out = {} for _, r in ipairs(l.items) do out[#out + 1] = r.item._kind end return table.concat(out, ",") end

-- nothing hidden: In Their 30s on top of the positive list
panel:populate()
assert(kinds(panel.goodList) == "age30s,brave,strong", "In Their 30s added at the top: " .. kinds(panel.goodList))
assert(kinds(panel.badList) == "age50s,jinxed", "the rest as the folder listed them")
assert(panel.goodList.items[1].tooltip == "desc:age30s", "with its description")

-- a retired trait and the gate's hidden traits come out; a chosen one stays
hidden = { jinxed = true, brave = true, strong = true }
vanilla.listboxTraitSelected.items = { { item = strong } }
panel:populate()
assert(kinds(panel.goodList) == "age30s,strong", "hidden rows out, the chosen one kept: " .. kinds(panel.goodList))
assert(kinds(panel.badList) == "age50s", "the retired trait out")

-- not twice (a folder that already lists it), not when the screen does not offer it, not with Age off
fill = function(self) self.goodList:addItem("age30s", defs.age30s) end
panel:populate()
assert(kinds(panel.goodList) == "age30s", "never twice")
hidden, vanilla.listboxTraitSelected.items = {}, {}
enabled30s = false
panel:populate()
assert(kinds(panel.goodList) == "age30s", "left alone when the folder had it")
fill = function() end
panel:populate()
assert(kinds(panel.goodList) == "", "not added when the screen does not offer it")
enabled30s, ageOff = true, true
panel:populate()
assert(kinds(panel.goodList) == "", "not added with Age off")
ageOff = false

-- the gate on Continue
gate = true
panel:render()
assert(button.enabled == false and button.tooltip == "UI_DanTraits_PickAgeFirst", "Continue greyed with the reason")
assert(panel._hint == "UI_DanTraits_PickAgeHint", "the hint drawn")
panel:onContinue()
assert(continued == 0, "a press does nothing while the gate is up")
gate = false
panel._hint = nil
panel:render()
assert(button.enabled == true and button.tooltip == nil and panel._hint == nil, "the folder's own state with an age chosen")
panel:onContinue()
assert(continued == 1, "and Continue goes on")

-- the surcharge under the cost
band = 40
local labels = {}
function panel.goodList:drawTextRight(text) labels[#labels + 1] = text end
local yy = panel.goodList.doDrawItem(panel.goodList, 10, { item = strong }, false)
assert(yy == 64 and drawnRows >= 1, "the folder's row drawn first")
assert(labels[1] == "UI_DanTraits_AgeSurcharge:2", "the surcharge written: " .. tostring(labels[1]))
panel.goodList.doDrawItem(panel.goodList, 10, { item = brave }, false)
assert(#labels == 1, "nothing for a trait without one")
H.pass()
