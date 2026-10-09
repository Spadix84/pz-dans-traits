-- Offline test for the collection checklist in Dan's Vanilla Fixes
-- (DansVanillaFixes/42/media/lua/shared/DansVanillaFixes_Collection.lua,
-- client/DansVanillaFixes_CollectionUI.lua and
-- client/DansVanillaFixes_CollectionClient.lua): the lists built from the
-- item scripts (skill books by skill and volume, magazines without seed
-- packets, key rings, mementos without reversed caps, tools without the
-- debug and half-made items, a tab per recorded media kind), ticking and Unwanted (set on tick, cleared on untick only if
-- the checklist set it), tapes and CDs kept by title with no Unwanted, the
-- item lookup, the right-click options, the tooltip line, the window's search
-- and Hide collected, and the sidebar icon sizes.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/../DansVanillaFixes/42/media/lua/"

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

-- the game -----------------------------------------------------------------------

ItemType = { LITERATURE = "literature" }
SkillBook = { Carpentry = { perk = "Carpentry" }, Cooking = { perk = "Cooking" } }
PerkFactory = { getPerk = function(perk) return { getName = function() return perk .. " skill" end } end }

-- a script item: o = { name, display, category, lit, skill, level, recipes, media, obsolete, hidden }
local function script(o)
  local s = {}
  function s:getName() return o.name end
  function s:getFullName() return "Base." .. o.name end
  function s:getDisplayName() return o.display or o.name end
  function s:getDisplayCategory() return o.category end
  function s:isItemType(t) return o.lit == true and t == ItemType.LITERATURE end
  function s:getSkillTrained() return o.skill end
  function s:getLevelSkillTrained() return o.level or 1 end
  function s:getLearnedRecipes() return o.recipes and list(o.recipes) or nil end
  function s:getRecordedMediaCat() return o.media end
  function s:getObsolete() return o.obsolete == true end
  function s:isHidden() return o.hidden == true end
  function s:getNormalTexture() return "TEX:" .. o.name end
  return s
end

local SCRIPTS = {
  script({ name = "BookCarpentry2", display = "Carpentry Vol. 2", category = "SkillBook", lit = true, skill = "Carpentry", level = 3 }),
  script({ name = "BookCarpentry1", display = "Carpentry Vol. 1", category = "SkillBook", lit = true, skill = "Carpentry", level = 1 }),
  script({ name = "BookCarpentry3", display = "Carpentry Vol. 3", category = "SkillBook", lit = true, skill = "Carpentry", level = 5 }),
  script({ name = "BookCooking1", display = "Cooking Vol. 1", category = "SkillBook", lit = true, skill = "Cooking", level = 1 }),
  script({ name = "BookCarpentrySet", display = "Carpentry Set", category = "SkillBook", lit = true }),
  script({ name = "BookOldSkill", category = "SkillBook", lit = true, skill = "Gone" }),          -- no SkillBook entry
  script({ name = "ElectronicsMag1", display = "Electronics Mag", category = "RecipeResource", lit = true, recipes = { "MakeRemote" } }),
  script({ name = "RadioMag1", display = "Amateur Radio", category = "RecipeResource", lit = true, recipes = { "MakeRadio" } }),
  script({ name = "CarrotBagSeed2", category = "Gardening", lit = true, recipes = { "CarrotGrowing" } }),
  script({ name = "CarrotBagSeed2_Empty", category = "RecipeResource", lit = true, recipes = { "CarrotGrowing" } }),
  script({ name = "OldMag", category = "RecipeResource", lit = true, recipes = { "Old" }, obsolete = true }),
  script({ name = "Novel", category = "Literature", lit = true }),
  script({ name = "KeyRing_Spiffos", display = "Spiffo's Key Ring", category = "Memento" }),
  script({ name = "Medal_Gold", display = "Gold Medal", category = "Memento" }),
  script({ name = "Hat_BaseballCap_Spiffos", display = "Spiffo's Cap", category = "Memento" }),
  script({ name = "Hat_BaseballCap_Spiffos_Reverse", display = "Spiffo's Cap", category = "Memento" }),
  script({ name = "Hammer", display = "Hammer", category = "ToolWeapon" }),
  script({ name = "Saw", display = "Saw", category = "Tool" }),
  script({ name = "Shovel", display = "Shovel", category = "GardeningWeapon" }),
  script({ name = "DebugFluid", category = "Tool" }),
  script({ name = "TobaccoDried", category = "Tool" }),
  script({ name = "ClayToolUnfired", category = "Tool" }),
  script({ name = "OldDrill", display = "Old Drill", category = "Tool", obsolete = true }),
  script({ name = "Pot", category = "Cooking" }),
  script({ name = "VHS_Retail", category = "Entertainment", media = "Retail-VHS" }),
  script({ name = "Disc_Retail", category = "Entertainment", media = "CDs" }),
}
getScriptManager = function() return { getAllItems = function() return list(SCRIPTS) end } end

-- recorded media: id, category, title, subtitle
local function mediaData(id, cat, title, sub)
  return {
    getId = function() return id end, getCategory = function() return cat end,
    hasTitle = function() return title ~= nil end, getTranslatedTitle = function() return title end,
    hasSubTitle = function() return sub ~= nil end, getSubtitleEN = function() return sub end,
    getTranslatedSubTitle = function() return sub end, getTranslatedItemDisplayName = function() return "Tape " .. id end,
  }
end
local MEDIA = {
  ["Retail-VHS"] = { mediaData("v2", "Retail-VHS", "Zombie Night", "Part 2"), mediaData("v1", "Retail-VHS", "Aerobics") },
  ["Home-VHS"] = { mediaData("h1", "Home-VHS", "Birthday", "Home VHS") },
  CDs = { mediaData("c1", "CDs", nil, "Greatest Hits"), mediaData("c2", "CDs") },
}
local MEDIA_CATS = { "CDs", "Home-VHS", "Retail-VHS" }
RecordedMedia = { getMediaTypeForCategory = function(cat) return cat end }
getZomboidRadio = function()
  return { getRecordedMedia = function()
    return { getCategories = function() return list(MEDIA_CATS) end,
             getAllMediaForType = function(_, cat) return list(MEDIA[cat]) end }
  end }
end

-- a player with the vanilla Unwanted store
local function player(num)
  local md, unwanted, sent = {}, {}, 0
  local p = { _unwanted = unwanted }
  function p:getModData() return md end
  function p:isUnwanted(t) return unwanted[t] == true end
  function p:setUnwanted(t, on) unwanted[t] = on and true or nil end
  function p:transmitModData() sent = sent + 1 end
  function p:getPlayerNum() return num or 0 end
  function p:isDead() return false end
  function p.sent() return sent end
  return p
end

-- an inventory item: a type, or a tape with media data (blank: no media data)
local function item(fullType, media, recorded)
  return {
    getFullType = function() return fullType end,
    isRecordedMedia = function() return recorded or media ~= nil end,
    getMediaData = function() return media end,
  }
end

-- the UI the client files build on, as small as they need
local function class(name)
  local c = { Type = name }
  c.__index = c
  function c.derive(base, n)
    local d = setmetatable({ Type = n }, { __index = base })
    d.__index = d
    return d
  end
  function c.new(self) return setmetatable({}, self) end
  return c
end
ISScrollingListBox = class("ISScrollingListBox")
ISCollapsableWindow = class("ISCollapsableWindow")
UIFont = { Small = "small" }
getTextManager = function()
  return { getFontHeight = function() return 15 end, MeasureStringX = function(_, _, s) return #s * 7 end }
end
local GOOD = { getR = function() return 0.2 end, getG = function() return 0.9 end, getB = function() return 0.3 end }
local sidebarSize, fontSize = 1, 3
getCore = function()
  return { getGoodHighlitedColor = function() return GOOD end,
           getOptionSidebarSize = function() return sidebarSize end,
           getOptionFontSizeReal = function() return fontSize end }
end
local vanillaInits, vanillaRenders = 0, 0
ISEquippedItem = { initialise = function() vanillaInits = vanillaInits + 1 end, prerender = function() end }
ISToolTipInv = { render = function() vanillaRenders = vanillaRenders + 1 end }
ISInventoryPane = { getActualItems = function(items) return items end }
ISContextMenu = {}

dofile(ROOT .. "shared/DansVanillaFixes_Collection.lua")
dofile(ROOT .. "client/DansVanillaFixes_CollectionUI.lua")
dofile(ROOT .. "client/DansVanillaFixes_CollectionClient.lua")
local C = DVF_Collection

local function tab(id)
  for _, t in ipairs(C.lists()) do if t.id == id then return t end end
end
local function names(t)
  local out = {}
  for _, r in ipairs(t.rows) do out[#out + 1] = r.name end
  return table.concat(out, ",")
end

-- 1. the lists
do
  local ids = {}
  for _, t in ipairs(C.lists()) do ids[#ids + 1] = t.id end
  assert(table.concat(ids, ",") == "SkillBooks,Magazines,CDs,Home-VHS,Retail-VHS,KeyRings,Mementos,Tools",
    "tabs in order, a media tab per category: " .. table.concat(ids, ","))
  local books = tab("SkillBooks")
  assert(#books.rows == 2 and books.total == 4, "two skills, four books (the set and an unknown skill left out)")
  assert(books.rows[1].label == "Carpentry skill", "a row is named after its perk")
  local carp = books.rows[1].books
  assert(#carp == 3 and carp[1].key == "Base.BookCarpentry1" and carp[2].key == "Base.BookCarpentry2"
    and carp[3].key == "Base.BookCarpentry3", "volumes in order of the level they train")
  assert(carp[3].volume == 3, "volume number from the order")
  assert(books.title == "IGUI_DVF_Collection_SkillBooks", "own tab title")
  assert(names(tab("Magazines")) == "Amateur Radio,Electronics Mag", "magazines sorted; no seed packets, no obsolete one")
  assert(names(tab("KeyRings")) == "Spiffo's Key Ring", "key rings on their own")
  assert(names(tab("Mementos")) == "Gold Medal,Spiffo's Cap", "mementos without key rings or reversed caps")
  assert(names(tab("Tools")) == "Hammer,Saw,Shovel", "tools from all three categories; no debug, tobacco, unfired or obsolete ones")
  assert(tab("Tools").title == "IGUI_DVF_Collection_Tools", "own tab title")
  assert(names(tab("Retail-VHS")) == "Aerobics,Zombie Night Part 2", "tapes by title with the subtitle, sorted")
  assert(names(tab("Home-VHS")) == "Birthday", "a home tape's 'Home VHS' subtitle is left off")
  assert(names(tab("CDs")) == "Greatest Hits,Tape c2", "no title: subtitle, then the item name")
  assert(tab("CDs").title == "IGUI_LiteratureUI_RecordedMedia_CDs", "media tabs use vanilla's names")
  assert(tab("Retail-VHS").rows[1].script.getName() == "VHS_Retail", "a tape row shows the tape's icon")
  assert(C.typeTab(SCRIPTS[12]) == nil, "novels are not on the list")
  assert(C.typeTab(SCRIPTS[24]) == nil, "nor pots and pans")
end

-- 2. ticking an item type sets Unwanted; unticking clears it
do
  local p = player()
  local book = C.byType["Base.BookCarpentry2"]
  assert(not C.has(p, book), "starts unticked")
  C.set(p, book, true)
  assert(C.has(p, book), "ticked")
  assert(p._unwanted["Base.BookCarpentry2"], "ticking set Unwanted")
  assert(p:getModData()[C.KEY].items["Base.BookCarpentry2"] == C.WE_SET, "remembers it set Unwanted")
  assert(p.sent() == 1, "mod data sent")
  C.set(p, book, true)
  assert(p:getModData()[C.KEY].items["Base.BookCarpentry2"] == C.WE_SET, "ticking again changes nothing")
  C.set(p, book, false)
  assert(not C.has(p, book) and not p._unwanted["Base.BookCarpentry2"], "unticking clears both")
  C.set(p, book, false)
  assert(not p._unwanted["Base.BookCarpentry2"], "unticking an unticked one is harmless")
end

-- 3. something already Unwanted stays Unwanted when unticked
do
  local p = player()
  p:setUnwanted("Base.Medal_Gold", true)
  local medal = C.byType["Base.Medal_Gold"]
  C.set(p, medal, true)
  assert(p:getModData()[C.KEY].items["Base.Medal_Gold"] == C.WAS_SET, "it was Unwanted already")
  C.set(p, medal, false)
  assert(not C.has(p, medal), "unticked")
  assert(p._unwanted["Base.Medal_Gold"], "the player's own Unwanted is kept")
  -- vanilla Unwanted alone does not tick anything
  p:setUnwanted("Base.KeyRing_Spiffos", true)
  assert(not C.has(p, C.byType["Base.KeyRing_Spiffos"]), "vanilla Unwanted is not a tick")
end

-- 4. tapes and CDs by title, never Unwanted
do
  local p = player()
  local tape = C.byMedia.v1
  C.set(p, tape, true)
  assert(C.has(p, tape) and not C.has(p, C.byMedia.v2), "one title ticked, the other not")
  assert(next(p._unwanted) == nil, "no Unwanted for tapes")
  C.set(p, tape, false)
  assert(not C.has(p, tape), "unticked")
  assert(C.count(p, tab("Retail-VHS")) == 0, "count follows")
end

-- 5. counts: skill rows count each volume
do
  local p = player()
  C.set(p, C.byType["Base.BookCarpentry1"], true)
  C.set(p, C.byType["Base.BookCooking1"], true)
  C.set(p, C.byType["Base.ElectronicsMag1"], true)
  assert(C.count(p, tab("SkillBooks")) == 2, "two volumes")
  assert(C.count(p, tab("Magazines")) == 1, "one magazine")
  assert(C.count(p, tab("Mementos")) == 0, "none")
end

-- 6. the entry an inventory item is
do
  assert(C.entryFor(item("Base.BookCarpentry3")) == C.byType["Base.BookCarpentry3"], "a book by its type")
  assert(C.entryFor(item("Base.VHS_Retail", MEDIA["Retail-VHS"][1])) == C.byMedia.v2, "a tape by its title")
  assert(C.entryFor(item("Base.VHS_Home", nil, true)) == nil, "a blank tape is nothing")
  assert(C.entryFor(item("Base.Hammer")) == C.byType["Base.Hammer"], "a hammer is a tool")
  assert(C.entryFor(item("Base.Pot")) == nil, "a pot is nothing")
  assert(C.entryFor(nil) == nil, "no item")
end

-- 7. right-click
do
  local p = player(0)
  getSpecificPlayer = function() return p end
  local function menu(items)
    local opts = {}
    local context = { addOption = function(_, text, target, fn, a, b)
      opts[#opts + 1] = { text = text, run = function() fn(target, a, b) end }
    end }
    H.only("OnFillInventoryObjectContextMenu")(0, context, items)
    return opts
  end
  assert(#menu({ item("Base.Pot") }) == 0, "nothing on the list: no option")
  local two = { item("Base.BookCarpentry1"), item("Base.BookCarpentry1"), item("Base.Medal_Gold") }
  local opts = menu(two)
  assert(#opts == 1 and opts[1].text == "ContextMenu_DVF_CollectionAdd", "add when any is missing")
  C.set(p, C.byType["Base.BookCarpentry1"], true)
  opts = menu(two)
  assert(opts[1].text == "ContextMenu_DVF_CollectionAdd", "still add while one is missing")
  opts[1].run()
  assert(C.hasType(p, "Base.Medal_Gold") and C.hasType(p, "Base.BookCarpentry1"), "adds the missing, keeps the rest")
  opts = menu(two)
  assert(opts[1].text == "ContextMenu_DVF_CollectionRemove", "remove when all are in")
  opts[1].run()
  assert(not C.hasType(p, "Base.Medal_Gold") and not C.hasType(p, "Base.BookCarpentry1"), "removes them all")
  assert(not p._unwanted["Base.Medal_Gold"], "and their Unwanted")
  local tape = menu({ item("Base.VHS_Retail", MEDIA["Retail-VHS"][2]) })
  tape[1].run()
  assert(C.hasMedia(p, "v1"), "a tape from the menu")
end

-- 8. the tooltip line
do
  local p = player()
  local text, r = C.tooltipLine(p, item("Base.BookCooking1"))
  assert(text == "IGUI_DVF_Collection_Missing" and r == 0.6, "grey when not collected")
  C.set(p, C.byType["Base.BookCooking1"], true)
  text, r = C.tooltipLine(p, item("Base.BookCooking1"))
  assert(text == "IGUI_DVF_Collection_Have" and r == 0.2, "green (vanilla's good colour) when collected")
  assert(C.tooltipLine(p, item("Base.Pot")) == nil, "nothing for other items")
  -- the strip is drawn under vanilla's tooltip
  local drawn
  local tip = { item = item("Base.BookCooking1"), width = 100, height = 50,
    tooltip = { getCharacter = function() return p end },
    backgroundColor = { r = 0, g = 0, b = 0, a = 1 }, borderColor = { r = 1, g = 1, b = 1, a = 1 },
    drawRect = function() end, drawRectBorder = function() end,
    drawText = function(_, t, x, y) drawn = { t, y } end }
  ISToolTipInv.render(tip)
  assert(vanillaRenders == 1, "vanilla's tooltip first")
  assert(drawn and drawn[1] == "IGUI_DVF_Collection_Have" and drawn[2] > 50, "line drawn below it")
end

-- 9. the window's search and Hide collected
do
  local p = player()
  local win = setmetatable({ character = p, hideOwned = false }, { __index = DVF_CollectionWindow })
  local carpRow = tab("SkillBooks").rows[1]
  local medal = C.byType["Base.Medal_Gold"]
  assert(win:shows(medal, ""), "no search: shown")
  assert(win:shows(medal, "gold") and not win:shows(medal, "cap"), "search by name")
  assert(win:shows(carpRow, "vol. 2"), "a skill row matches its books' names too")
  win.hideOwned = true
  C.set(p, medal, true)
  assert(not win:shows(medal, ""), "collected is hidden")
  C.set(p, C.byType["Base.BookCarpentry1"], true)
  C.set(p, C.byType["Base.BookCarpentry2"], true)
  assert(win:shows(carpRow, ""), "a skill row stays while a volume is missing")
  C.set(p, C.byType["Base.BookCarpentry3"], true)
  assert(not win:shows(carpRow, ""), "and goes once all are in")
end

-- 10. the volume boxes sit inside the row and in order
do
  local l = setmetatable({ width = 400 }, { __index = DVF_CollectionList })
  local last = 0
  for v = 1, 5 do
    local x = l:volumeX(v)
    assert(x > last, "volume " .. v .. " right of the one before")
    last = x
  end
  assert(last + 17 <= 400 - 20, "the last box clears the scrollbar")
end

-- 11. the sidebar: icon size as vanilla picks it, the button added under the others
do
  local sizes = { [1] = 48, [2] = 64, [3] = 80, [4] = 96, [5] = 128 }
  for opt, w in pairs(sizes) do
    sidebarSize = opt
    local width, height = C.sidebarSize()
    assert(width == w and height == w * 0.75, "sidebar option " .. opt)
  end
  sidebarSize, fontSize = 6, 3
  assert(C.sidebarSize() == 64, "option 6 follows the font size")
  sidebarSize = 1
  local added, wrapped = {}, 0
  ISButton = class("ISButton")
  function ISButton.new(self, x, y, w, h, title, target, fn)
    local b = setmetatable({ x = x, y = y, w = w, h = h, target = target, fn = fn }, self)
    return b
  end
  for _, m in ipairs({ "initialise", "instantiate", "setDisplayBackground", "ignoreWidthChange", "ignoreHeightChange" }) do
    ISButton[m] = function() end
  end
  function ISButton:setImage(t) self.image = t end
  getTexture = function(path) return path end
  local bar = setmetatable({ invBtn = {}, chr = player(0) }, { __index = ISEquippedItem })
  function bar:getHeight() return 300 end
  function bar:addChild(c) added[#added + 1] = c end
  function bar:addMouseOverToolTipItem() end
  function bar:shrinkWrap() wrapped = wrapped + 1 end
  ISEquippedItem.initialise(bar)
  assert(vanillaInits == 1, "vanilla's buttons first")
  assert(#added == 1 and added[1].y == 315, "one button under the last one")
  assert(added[1].image == "media/ui/DVF/Collection_Off_48.png", "the closed icon at this size")
  assert(wrapped == 1, "sidebar resized to fit")
  local opened
  DVF_CollectionWindow.toggle = function(chr) opened = chr end
  added[1].fn(added[1].target, added[1])
  assert(opened == bar.chr, "the button opens this player's window")
  local split = setmetatable({ chr = player(1) }, { __index = ISEquippedItem })
  function split:addChild() error("no button for split-screen players") end
  ISEquippedItem.initialise(split)
end

H.pass()
