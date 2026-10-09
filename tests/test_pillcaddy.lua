-- Offline test for the Pill Caddy: what it accepts (shared/DanTraits_PillCaddy.lua
-- and its AcceptItemFunction in server/Items), the 1% start for a new
-- character with a medical trait, and its tab in the inventory window
-- (client/DanTraits_PillCaddyTab.lua).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end }
AcceptItemFunction = {}   -- vanilla's table, which the server file adds to
H.load("Faint", "Meds", "PillCaddy", "server/Items/DanTraits_PillCaddyAccept.lua", "client/DanTraits_PillCaddyTab.lua")
H.expectHooks("OnCreatePlayer", "OnRefreshInventoryWindowContainers")

local function item(fullType)
  return { getType = function() return (fullType:gsub("^.*%.", "")) end, getFullType = function() return fullType end }
end

-- 1. medication only: the shared drug list plus antibiotics
for _, t in ipairs({ "Base.PillsBeta", "Base.Pills", "Base.PillsVitamins", "Base.Antibiotics", "Base.AntibioticsBox",
                     "DanTraits.Baclofen", "DanTraits.Inhaler", "DanTraits.InsulinPen", "DanTraits.Diazepam" }) do
  assert(DanTraits_IsCaddyMed(item(t)), t .. " fits")
  assert(AcceptItemFunction.DanPillCaddy(nil, item(t)), t .. " accepted")
end
for _, t in ipairs({ "Base.Bandage", "Base.Splint", "Base.FirstAidKit", "DanTraits.GlucoseMeter",
                     "DanTraits.Sunblock", "DanTraits.PillCaddy", "Base.Apple" }) do
  assert(not DanTraits_IsCaddyMed(item(t)), t .. " does not fit")
  assert(not AcceptItemFunction.DanPillCaddy(nil, item(t)), t .. " refused")
end
assert(not DanTraits_IsCaddyMed(nil), "nothing is not medication")
assert(DanTraits_IsPillCaddy(item("DanTraits.PillCaddy")) and not DanTraits_IsPillCaddy(item("Base.KeyRing")), "the caddy is recognised")

-- 2. the start: 1% (ZombRand(100) == 0) for a new character with a medical trait, rolled once
local function create(n, p) H.fire("OnCreatePlayer", n, p) end   -- core's one handler runs every registered kit
local function caddies(p)
  local n = 0
  local items = p:getInventory():getItems()
  for i = 0, items:size() - 1 do if items:get(i):getFullType() == "DanTraits.PillCaddy" then n = n + 1 end end
  return n
end
local p = H.player({ traits = { "heart" }, hours = 0 })
H.rng = { 0 }
create(0, p)
assert(caddies(p) == 1, "the 1% roll hits: one caddy")
H.rng = { 0 }
create(0, p)
assert(caddies(p) == 1, "rolled once per character, not on every load")
p = H.player({ traits = { "ms" }, hours = 0 })
H.rng = { 1 }
create(0, p)
assert(caddies(p) == 0, "any other roll: none")
p = H.player({ traits = { "vegetarian" }, hours = 0 })
H.rng = { 0 }
H.rolls = 0
create(0, p)
assert(caddies(p) == 0 and H.rolls == 0, "no medical trait: no roll at all")
p = H.player({ traits = { "epilepsy" }, hours = 50 })
H.rng = { 0 }
create(0, p)
assert(caddies(p) == 0, "an existing character (an old save) is left alone")
H.rng = {}

-- 3. the tab: every caddy loose in the main inventory, after vanilla's buttons
local refresh = H.only("OnRefreshInventoryWindowContainers")
p = H.player({ hours = 10 }); H.current = p
local function decorate(it, name, parent)
  local inv = { name = name, _parent = parent }
  function inv:getParent() return self._parent end
  function inv:setParent(who) self._parent = who end
  it.getInventory = function() return inv end
  it.getTex = function() return "tex" end
  it.getName = function() return name end
  return it
end
local caddy = decorate(p:getInventory():AddItem("DanTraits.PillCaddy"), "Pill Caddy", p)   -- on the belt: the game parented it to the character
local pack = decorate(p:getInventory():AddItem("Base.Bag_FannyPackFront"), "Fanny Pack", p)
local function page(onCharacter, existing)
  local pg = { player = 0, onCharacter = onCharacter, backpacks = {}, added = {} }
  for _, inv in ipairs(existing or {}) do pg.backpacks[#pg.backpacks + 1] = { inventory = inv } end
  function pg:addContainerButton(container, tex, name, tooltip)
    self.added[#self.added + 1] = name
    self.backpacks[#self.backpacks + 1] = { inventory = container }
  end
  return pg
end
local pg = page(true)
refresh(pg, "begin")
assert(#pg.added == 0, "nothing before vanilla's buttons")
refresh(pg, "buttonsAdded")
assert(#pg.added == 1 and pg.added[1] == "Pill Caddy", "the caddy gets a tab, the unworn fanny pack does not")
assert(caddy:getInventory():getParent() == nil, "the belt's parenting is undone before the tab is made (it was reading the whole carried weight)")
assert(pack:getInventory():getParent() == p, "other containers are left alone")
caddy:getInventory():setParent(p)
refresh(page(true, { caddy:getInventory() }), "buttonsAdded")
assert(caddy:getInventory():getParent() == nil, "undone again on every refresh, tab or no tab")
caddy:getInventory():setParent("a shelf")
refresh(page(true), "buttonsAdded")
assert(caddy:getInventory():getParent() == "a shelf", "only the character as parent is cleared")
caddy:getInventory():setParent(nil)
pg = page(true, { caddy:getInventory() })
refresh(pg, "buttonsAdded")
assert(#pg.added == 0, "held in the hands it already has one: no second tab")
pg = page(false)
refresh(pg, "buttonsAdded")
assert(#pg.added == 0, "the loot window is left alone")

H.pass("pillcaddy")
