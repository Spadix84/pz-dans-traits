-- Offline test for Vitality's reading overhaul
-- (DanTraits/42/media/lua/shared/DanTraits_Reading*.lua,
-- client/DanTraits_ReadingClient.lua, client/DanTraits_ReadingTIYL.lua
-- and Vitality's DanTraits_ReadingHooks.lua): the generated table (counts,
-- families, page ranges, quality), the title key parsing (prefixes, a
-- magazine's date, a comic's issue), the taste roll (two different families,
-- stable, kids never), the relief per page against vanilla's totals and the
-- taste and quality multipliers, the long read through the action wraps
-- (duration from vanilla's own answer, Fast Reader, the drip while reading,
-- the lump at the end cancelled, the bookmark on an interrupted read and the
-- resume, a chapter that is not marked read, the finish that is), finding a
-- taste out at 30 pages, the disliked tick, re-read comfort in the liked
-- family only, the Good Read moodle (level, hours, Classics longer, replace
-- or refresh, the minute's easing and the genre buff, expiry), the real-book
-- swap, the fallback for another mod's book, the tooltip lines, the chapter
-- context option, the journal lines for This Is Your Life, and the Vitality
-- hooks.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/../DanTraits/42/media/lua/"

-- the game -----------------------------------------------------------------------

local TEXT = {
  IGUI_DanTraits_Reading_Genre = "Genre: %1", IGUI_DanTraits_Reading_Pages = "Pages: %1 of %2", IGUI_DanTraits_Reading_Verdict = "Your verdict: %1",
  IGUI_DanTraits_Reading_liked = " (you love these)", IGUI_DanTraits_Reading_disliked = " (not your thing)", IGUI_DanTraits_Reading_neutral = " (fine by you)",
  IGUI_DanTraits_Genre_horror = "Horror", IGUI_DanTraits_Genre_westerns = "Westerns", IGUI_DanTraits_Genre_thrillers = "Thrillers & Crime",
  IGUI_DanTraits_Genre_popular = "Popular Fiction", IGUI_DanTraits_Genre_classics = "Classics", IGUI_DanTraits_Genre_scifi = "Sci-Fi & Fantasy",
  IGUI_DanTraits_BookBy = "\"%1\", by %2", IGUI_MagazineNameNoIssue = "%1: %2",
  IGUI_DanTraits_Journal_Finished = "Finished \"%1\". %2", IGUI_DanTraits_JournalVerdict_loved = "Loved it.", IGUI_DanTraits_JournalVerdict_great = "Great.",
  IGUI_DanTraits_JournalVerdict_fine = "It was fine.", IGUI_DanTraits_JournalVerdict_again = "Again.", IGUI_DanTraits_JournalTaste_liked = "Turns out I love %1.",
  IGUI_DanTraits_JournalTaste_disliked = "Turns out I can't stand %1.", IGUI_DanTraits_Month7 = "July",
  IGUI_BookTitle_ADameaDozen = "\"A Dame a Dozen\", by Someone",
  ContextMenu_DanTraits_ReadChapter = "Read a chapter (~%1 min)",
}
TEXT.IGUI_DanTraits_Reading_MoodleDesc = "%1: %2. About %3 h left."
TEXT.IGUI_DanTraits_ReadingBuff_popular = "boredom eases"
getText = function(k, a, b, c)
  local t = TEXT[k] or k
  if a ~= nil then t = t:gsub("%%1", tostring(a)) end
  if b ~= nil then t = t:gsub("%%2", tostring(b)) end
  if c ~= nil then t = t:gsub("%%3", tostring(c)) end
  return t
end
HaloTextHelper.addText = function(_, t) H.halo[#H.halo + 1] = "=" .. t end
-- one player: the minute loop asks for four
function getSpecificPlayer(i) if i == nil or i == 0 then return H.current end return nil end
SandboxVars = { DanTraits = {} }
local hours = 100
getGameTime = function() return { getWorldAgeHours = function() return hours end, getMinutesPerDay = function() return 1440 end,
  getMonth = function() return 6 end, getDay = function() return 11 end, getYear = function() return 1993 end, getMultiplier = function() return 1 end } end
local minutesPerPage = 2.0
getSandboxOptions = function() return { getOptionByName = function() return { getValue = function() return minutesPerPage end } end } end
ItemTag = { FAST_READ = "fastread", NEWSPAPER = "newspaper", MAGAZINE = "magazine", PICTUREBOOK = "picturebook", PICTURE = "picture",
  UNINTERESTING = "uninteresting", SOFTCOVER = "softcover", HARDCOVER = "hardcover", FANCY_BOOK = "fancybook" }
SkillBook = { Carpentry = { perk = "Carpentry" } }
CharacterTrait.ILLITERATE = "illiterate"
CharacterTrait.FAST_READER = "fastreader"
local xpCalls = {}
addXpMultiplier = function(player, perk, mult, lo, hi) xpCalls[#xpCalls + 1] = { perk = perk, mult = mult }; player._xp[perk] = mult end
function isClient() return false end
UIFont = { Small = "small" }
function getCore() return {
  getGoodHighlitedColor = function() return { getR = function() return 0 end, getG = function() return 1 end, getB = function() return 0 end } end,
  getBadHighlitedColor = function() return { getR = function() return 1 end, getG = function() return 0 end, getB = function() return 0 end } end,
} end
function getTextManager() return { MeasureStringX = function(_, _, s) return #s * 6 end, getFontHeight = function() return 12 end } end
ISToolTipInv = { render = function() end }
ISContextMenu = {}
ISInventoryPane = { getActualItems = function(items) return items end }
ISInventoryPaneContextMenu = { transferIfNeeded = function() end, addToolTip = function() return {} end }
local queued = {}
ISTimedActionQueue = { add = function(a) queued[#queued + 1] = a end }

-- a literature item: o = { type, title (literatureTitle), tags, skill, recipes, write, boredom, stress, unhappy, display }
local function list(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local function item(o)
  local it = { _o = o, _md = {}, _name = nil }
  if o.title then it._md.literatureTitle = o.title end
  local tags = {}
  for _, t in ipairs(o.tags or {}) do tags[t] = true end
  function it:getFullType() return "Base." .. (o.type or "Book_Fiction") end
  function it:getType() return o.type or "Book_Fiction" end
  function it:hasModData() return true end
  function it:getModData() return self._md end
  function it:hasTag(t) return tags[t] == true end
  function it:getSkillTrained() return o.skill end
  function it:getLearnedRecipes() return o.recipes and list(o.recipes) or nil end
  function it:canBeWrite() return o.write == true end
  function it:getBoredomChange() return o.boredom or -50 end
  function it:getStressChange() return o.stress or -40 end
  function it:getUnhappyChange() return o.unhappy or -40 end
  function it:getScriptItem() return { getDisplayName = function() return o.display or "Book" end } end
  function it:setName(n) self._name = n end
  function it:getName() return self._name or (o.display or "Book") end
  function it:getContainer() return {} end
  function it:getNumberOfPages() return -1 end
  function it:setJobDelta() end
  function it:setJobType() end
  function it:setAlreadyReadPages() end
  function it:getAlreadyReadPages() return 0 end
  return it
end
local function literature(o) o.lit = true; return item(o) end
local realInstanceof = instanceof
function instanceof(obj, cls)
  if cls == "Literature" then return type(obj) == "table" and obj._o ~= nil and obj._o.lit == true end
  return realInstanceof(obj, cls)
end

-- the player: vanilla read-tracking and the XP table on top of the harness's
local function player(o)
  local p = H.player(o)
  p._read, p._xp, p._hours = {}, {}, o and o.hours or 100
  p.isLiteratureRead = function(_, t) return p._read[t] == true end
  p.addReadLiterature = function(_, t) p._read[t] = true end
  p.getXp = function() return { getMultiplier = function(_, perk) return p._xp[perk] or 1 end } end
  p.transmitModData = function() end
  p.getHoursSurvived = function() return p._hours end
  return p
end
H.current = player()

-- vanilla's read action, as much of it as the wraps touch
ISReadABook = {}
ISReadABook.__index = ISReadABook
local vanillaCalls = {}
function ISReadABook:getDuration()
  local t = 5 * self.minutesPerPage / (1 / 1440 / 2)   -- five pages at the server's minutes per page
  if self.item:hasTag(ItemTag.FAST_READ) then t = 50 end
  if self.character:hasTrait(CharacterTrait.FAST_READER) then t = t * 0.7 end
  return t
end
function ISReadABook:start() vanillaCalls.start = (vanillaCalls.start or 0) + 1 end
function ISReadABook:update() end
function ISReadABook:stop() vanillaCalls.stop = (vanillaCalls.stop or 0) + 1 end
function ISReadABook:perform()
  local md = self.item:getModData()
  if md.literatureTitle then self.character:addReadLiterature(md.literatureTitle) end
end
function ISReadABook:complete()
  -- the lump at the end: ReadLiterature
  local stats = self.character:getStats()
  stats:set(CharacterStat.BOREDOM, stats:get(CharacterStat.BOREDOM) + self.item:getBoredomChange())
  stats:set(CharacterStat.STRESS, stats:get(CharacterStat.STRESS) + self.item:getStressChange() / 100)
  stats:set(CharacterStat.UNHAPPINESS, stats:get(CharacterStat.UNHAPPINESS) + self.item:getUnhappyChange())
  local md = self.item:getModData()
  if md.literatureTitle then self.character:addReadLiterature(md.literatureTitle) end
  return true
end
function ISReadABook:getJobDelta() return self._delta or 0 end
function ISReadABook:new(character, it)
  local o = setmetatable({}, self)
  o.character, o.item, o.minutesPerPage = character, it, minutesPerPage
  o.maxTime = o:getDuration()
  return o
end

local function load(path)
  local chunk, err = loadfile(ROOT .. path)
  assert(chunk, err)
  chunk()
end
load("shared/DanTraits_ReadingData.lua")
load("shared/DanTraits_ReadingBooks.lua")
load("shared/DanTraits_Reading.lua")
load("shared/DanTraits_ReadingAction.lua")
load("client/DanShared_Tooltip.lua")
load("client/DanTraits_ReadingClient.lua")
load("client/DanTraits_ReadingTIYL.lua")
local R, D = DanTraits_Reading, DanTraits_ReadingData
H.expectHooks("OnFillContainer", "EveryOneMinute", "OnCreatePlayer", "OnFillInventoryObjectContextMenu", "OnGameStart")

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function near(a, b, msg) H.near(a, b, 1e-6, msg) end

-- the table ---------------------------------------------------------------------------

local FAMILY = {}
for _, f in ipairs(R.FAMILIES) do FAMILY[f] = true end
assert(count(D.books) == D.counts.books and D.counts.books > 1100, "books in the table")
assert(count(D.comics) == D.counts.comics and D.counts.comics > 200, "comics in the table")
assert(count(D.magazines) == D.counts.magazines and D.counts.magazines > 150, "magazines in the table")
for key, row in pairs(D.books) do
  assert(FAMILY[row[1]], "book family " .. key .. ": " .. tostring(row[1]))
  assert(row[2] >= 24 and row[2] <= 650, "book pages " .. key)
  assert(row[3] >= 1 and row[3] <= 5, "book quality " .. key)
  assert(row[4] == "S" or row[4] == "H" or row[4] == "B", "book cover " .. key)
end
for key, row in pairs(D.comics) do
  assert(FAMILY[row[1]] and row[2] >= 24 and row[2] <= 48 and row[3] >= 1 and row[3] <= 5, "comic row " .. key)
end
for key, row in pairs(D.magazines) do
  assert(FAMILY[row[1]] and row[2] >= 60 and row[2] <= 140 and row[3] >= 1 and row[3] <= 5, "magazine row " .. key)
end
assert(D.books.ADameaDozen[1] == "thrillers", "A Dame a Dozen is crime fiction")
assert(D.books.AFarewelltoArms[1] == "classics", "two subjects: the first names the family")
assert(D.comics.AtomLizardAwakes[1] == "scifi", "comics: Atom Lizard")
assert(D.comics.DraculaHunters[1] == "horror", "comics: Dracula Hunters")
assert(D.magazines.AirandSpaceNews[1] == "history", "magazines: military subject")
local qs = { 0, 0, 0, 0, 0 }
for _, row in pairs(D.books) do qs[row[3]] = qs[row[3]] + 1 end
assert(qs[2] + qs[3] > qs[1] + qs[4] + qs[5], "most books are two or three stars")
assert(count(D.real) >= 80, "real books drafted: " .. count(D.real))
for key, row in pairs(D.real) do
  assert(FAMILY[row.family] and row.pages > 50 and row.quality >= 1 and row.quality <= 5 and row.title and row.author, "real book " .. key)
end
assert(D.real.JurassicPark.pages == 399 and D.real.It.pages == 1138, "real page counts")

-- keys and lookups --------------------------------------------------------------------

local kind, key = R.parseKey("IGUI_BookTitle_ADameaDozen")
assert(kind == "book" and key == "ADameaDozen", "book key")
kind, key = R.parseKey("IGUI_MagazineTitle_AirandSpaceNews_3_1993")
assert(kind == "magazine" and key == "AirandSpaceNews", "magazine key loses its date: " .. tostring(key))
kind, key = R.parseKey("IGUI_ComicTitle_AtomLizardAwakes12")
assert(kind == "comic" and key == "AtomLizardAwakes", "comic key loses its issue: " .. tostring(key))
kind, key = R.parseKey("IGUI_ComicTitle_AtomLizardAwakes_3")
assert(kind == "comic" and key == "AtomLizardAwakes", "comic key loses an underscored issue")
kind, key = R.parseKey("IGUI_DVF_BookTitle_JurassicPark")
assert(kind == "real" and key == "JurassicPark", "real key")
kind, key = R.parseKey("SomeMod_Title")
assert(kind == nil and key == "SomeMod_Title", "unknown prefix")
local row = R.lookup("book", "AFarewelltoArms")
assert(row.quality == 5, "override: quality")
assert(R.lookup("comic", "TeenSurgeons").family == "humor", "override: comic family")
assert(R.lookup("book", "NoSuchBook") == nil, "unknown title")

-- what is ours
local dame = literature({ title = "IGUI_BookTitle_ADameaDozen", tags = { "softcover" } })
local info = R.info(dame)
assert(info and info.known and info.family == "thrillers" and info.medium == "novel" and info.pages == D.books.ADameaDozen[2], "info for a novel")
assert(info.moodle, "a novel gives a moodle")
assert(R.info(literature({ title = "x", skill = "Carpentry" })) == nil, "skill books are vanilla")
assert(R.info(literature({ title = "x", recipes = { "MakeRemote" } })) == nil, "recipe magazines are vanilla")
assert(R.info(literature({ write = true })) == nil, "journals are vanilla")
assert(R.info(literature({ tags = { "fastread", "picture" } })) == nil, "fliers are vanilla")
assert(R.info(literature({ tags = { "newspaper", "uninteresting" } })) == nil, "old newspapers are vanilla")
assert(R.info(item({ title = "x" })) == nil, "not literature")
local paper = R.info(literature({ type = "Newspaper_New", title = "KnoxKnews_July2", tags = { "newspaper", "fastread" }, boredom = 0, stress = 0, unhappy = 0 }))
assert(paper and paper.medium == "newspaper" and paper.pages >= 12 and paper.pages <= 40 and not paper.moodle, "a recent newspaper: short, no moodle")
assert(paper.boredom == -10 and paper.stress == -5, "a newspaper's small payoff")
local modbook = R.info(literature({ type = "Mod_Novel", title = "IGUI_Mod_Title" }))
assert(modbook and not modbook.known and modbook.family == "popular" and modbook.pages == 120 and modbook.quality == 3 and not modbook.moodle, "another mod's book: the fallback")
local kids = R.info(literature({ title = "IGUI_BookTitle_StandingUptoBullies", tags = { "hardcover" } }))
assert(kids.family == "kids" and kids.medium == "picture", "a kids' book reads at picture speed")
local comic = R.info(literature({ type = "ComicBook", title = "IGUI_ComicTitle_DraculaHunters", tags = { "picturebook" }, boredom = -30, stress = -20, unhappy = -20 }))
assert(comic.medium == "comic" and comic.family == "horror", "a comic")
SandboxVars.DanTraits.ReadingEnabled = false
assert(R.info(dame) == nil and not R.on(), "the master switch")
SandboxVars.DanTraits.ReadingEnabled = true

-- taste ---------------------------------------------------------------------------------

local p = player()
H.current = p
H.rng = { 0, 0 }   -- first family, then the first of the rest: the second
local liked, disliked = R.tastes(p)
assert(liked == R.TASTE_POOL[1] and disliked == R.TASTE_POOL[2], "two different families: " .. tostring(liked) .. " " .. tostring(disliked))
H.rng = { 5, 5 }
local l2, d2 = R.tastes(p)
assert(l2 == liked and d2 == disliked, "the roll is kept")
assert(R.tasteOf(p, liked) == "liked" and R.tasteOf(p, disliked) == "disliked" and R.tasteOf(p, "westerns") == "neutral", "tasteOf")
assert(R.tasteOf(p, "kids") == "neutral" and R.tasteOf(p, "humor") == "neutral", "kids and humor are never a taste")
H.rng = { 3, 2 }
local q = player()
local l3, d3 = R.tastes(q)
assert(l3 == R.TASTE_POOL[4] and d3 == R.TASTE_POOL[3], "a roll below the first stays put")
near(R.tasteMult(p, liked), 1.25, "liked x1.25")
near(R.tasteMult(p, disliked), 0.5, "disliked x0.5")
near(R.tasteMult(p, "westerns"), 1, "neutral x1")
SandboxVars.DanTraits.ReadingTasteStrength = 0
near(R.tasteMult(p, liked), 1, "taste strength 0: no difference")
SandboxVars.DanTraits.ReadingTasteStrength = 2
near(R.tasteMult(p, liked), 1.5, "taste strength 2: double")
SandboxVars.DanTraits.ReadingTasteStrength = nil
near(R.qualityMult(1), 0.8, "one star"); near(R.qualityMult(5), 1.2, "five stars")
-- the creation roll
local fresh = player()
H.rng = { 2, 2 }
H.fire("OnCreatePlayer", 0, fresh)
assert(R.data(fresh).liked == R.TASTE_POOL[3], "tastes rolled on creation")

-- relief per page ----------------------------------------------------------------------

-- horror is liked (pool[1]), thrillers disliked (pool[2]) for p
assert(liked == "horror" and disliked == "thrillers", "the pool's first two")
local neutralBook = literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } })   -- a western
local ni = R.info(neutralBook)
assert(ni.family == "westerns", "Aim West Boys is a western")
local b, s, u = R.perPage(p, ni, false)
local qm = R.qualityMult(ni.quality)
near(b * 300, -50 * qm, "a novel's boredom over 300 pages is vanilla's -50 at its quality")
near(s * 300, -0.40 * qm, "stress -0.40 (hundredths)")
near(u * 300, -40 * qm, "unhappiness -40")
local hb = R.perPage(p, info, false)   -- A Dame a Dozen: thrillers, disliked
near(hb * 300, -50 * R.qualityMult(info.quality) * 0.5, "a disliked book: half")
local horror = R.info(literature({ title = "IGUI_BookTitle_AnUnexpectedLetter", tags = { "softcover" } }))
assert(horror.family == "horror", "An Unexpected Letter is horror")
local lb = R.perPage(p, horror, false)
near(lb * 300, -50 * R.qualityMult(horror.quality) * 1.25, "a liked book: x1.25")
local cb = R.perPage(p, comic, false)
near(cb * comic.pages, -30 * R.qualityMult(comic.quality) * 1.25, "a comic's total stays vanilla's (horror, liked)")
-- re-reads
local rb = R.perPage(p, horror, true)
near(rb, lb * 0.2, "a re-read in the liked family: a fifth")
assert(select(1, R.perPage(p, ni, true)) == 0, "a re-read elsewhere: nothing")
SandboxVars.DanTraits.ReadingRereadComfort = false
assert(select(1, R.perPage(p, horror, true)) == 0, "re-read comfort off")
SandboxVars.DanTraits.ReadingRereadComfort = nil
-- applied
p._st.boredom, p._st.stress, p._st.unhappy = 60, 0.5, 30
R.applyPages(p, ni, 30, false)
near(p._st.boredom, 60 + b * 30, "boredom after 30 pages")
near(p._st.stress, 0.5 + s * 30, "stress after 30 pages")
near(p._st.unhappy, 30 + u * 30, "unhappiness after 30 pages")
p._st.boredom = 1
R.applyPages(p, ni, 300, false)
assert(p._st.boredom == 0, "stats stop at 0")
-- a hook
R.addReliefHook("test", function(player, i) return 2 end)
near(select(1, R.perPage(p, ni, false)), b * 2, "a relief hook multiplies")
R.reliefHooks.test = nil

-- immersion: the stress and unhappiness drip climbs over the first hour of a sitting
near(R.immersion(ni, 0), 0.4, "a sitting's first page: 0.4 of the drip")
near(R.immersion(ni, 30), 0.85, "half an hour in: 0.85")
near(R.immersion(ni, 60), 1.3, "an hour in: 1.3")
near(R.immersion(ni, 600), 1.3, "and no further")
near(R.immersion(comic, 10), 0.85, "a comic: the ramp over 20 minutes")
p._st.boredom, p._st.stress, p._st.unhappy = 60, 0.5, 30
R.applyPages(p, ni, 10, false, 60)
near(p._st.boredom, 60 + b * 10, "immersed: boredom is flat, a page is a page")
near(p._st.stress, 0.5 + s * 10 * 1.3, "immersed: stress by the ramp")
near(p._st.unhappy, 30 + u * 10 * 1.3, "immersed: unhappiness by the ramp")
assert(R.sittingStart(p, ni) == 0, "no sitting yet")
R.sittingNote(p, ni, 45)
assert(R.sittingStart(p, ni) == 45, "the same title picked straight back up: 45 minutes in")
assert(R.sittingStart(p, horror) == 0, "another title: from the start")
hours = 100.2
assert(R.sittingStart(p, ni) == 45, "12 minutes later: still in it")
hours = 100.3
assert(R.sittingStart(p, ni) == 0, "18 minutes later: the spell is broken")
hours = 100
R.data(p).sitting = nil

-- time -----------------------------------------------------------------------------------

near(R.minutesPerPage(p, ni), 1.5, "a novel: 1.5 minutes a page")
near(R.minutesPerPage(p, comic), 0.5, "a comic: half a minute")
near(R.minutesPerPage(p, kids), 0.5, "a kids' book: half a minute")
minutesPerPage = 4.0
near(R.minutesPerPage(p, ni), 3, "the server's MinutesPerPage scales ours")
minutesPerPage = 2.0
SandboxVars.DanTraits.ReadingPageScale = 0.5
near(R.minutesPerPage(p, ni), 0.75, "the sandbox scale")
SandboxVars.DanTraits.ReadingPageScale = nil
assert(R.chapterPages(p, ni) == 20, "a chapter of a novel is 20 pages (30 minutes)")
assert(R.chapterPages(p, comic) == 60, "a chapter of a comic")

-- the long read --------------------------------------------------------------------------

local function stats(pl) return pl._st.boredom, pl._st.stress, pl._st.unhappy end
local pages = ni.pages
local f = 1 / 1440 / 2
local a = ISReadABook:new(p, neutralBook)
near(a.maxTime, pages * 1.5 / f, "duration: the whole book at 1.5 minutes a page")
assert(a.readPlan.from == 0 and a.readPlan.span == pages, "the plan: from the start, the lot")
local fast = player({ vanilla = { "fastreader" } })
local af = ISReadABook:new(fast, neutralBook)
near(af.maxTime, pages * 1.5 / f * 0.7, "Fast Reader: vanilla's x0.7 carries over")
R.addDurationHook("test", function() return 2 end)
near(ISReadABook:new(p, neutralBook).maxTime, pages * 1.5 / f * 2, "a duration hook multiplies")
R.durationHooks.test = nil
-- vanilla items go through untouched
local skill = literature({ title = "x", skill = "Carpentry" })
local as = ISReadABook:new(p, skill)
near(as.maxTime, 5 * 2.0 / f, "a skill book: vanilla's duration")
assert(as.readInfo == false, "no plan for a skill book")

-- reading: the drip, then interrupted
p._st.boredom, p._st.stress, p._st.unhappy = 80, 0.8, 80
a:start()
assert(vanillaCalls.start == 1 and a.readSession and a.readSession.pages == 0 and not a.readSession.reread, "the session")
a._delta = 0.25
a:update()
local b0, s0, u0 = stats(p)
local read1 = math.floor(pages * 0.25)
assert(a.readSession.pages == read1, "pages turned at a quarter")
near(b0, 80 + b * read1, "the drip: boredom at a quarter")
near(a.readSession.minutes, read1 * 1.5, "minutes into the sitting")
near(s0, 0.8 + s * read1 * R.immersion(ni, read1 * 1.5 / 2), "the drip: stress at a quarter, at the ramp's midpoint")
assert(R.mark(p, neutralBook, ni) == read1 and neutralBook._md[R.ITEM_KEY] == read1, "the bookmark, on the character and the copy")
a:update()
assert(p._st.boredom == b0, "the same tick again turns nothing")
a:stop()
assert(vanillaCalls.stop == 1 and a.readSession == nil, "stopped")
assert(R.mark(p, neutralBook, ni) == read1, "the bookmark stays")
assert(not p:isLiteratureRead("IGUI_BookTitle_AimWestBoys"), "not marked read")
-- another copy of the same title resumes from the character's bookmark
local copy = literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "hardcover" } })
local a2 = ISReadABook:new(p, copy)
assert(a2.readPlan.from == read1 and a2.readPlan.span == pages - read1, "resume from the bookmark on another copy")
near(a2.maxTime, (pages - read1) * 1.5 / f, "the rest of the book's time")
-- the copy's own bookmark counts too
local far = literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "hardcover" } })
far._md[R.ITEM_KEY] = read1 + 40
assert(R.mark(p, far, ni) == read1 + 40, "a copy read further: its bookmark")

-- a chapter: stops short, not marked read
local ac = ISReadABook:new(p, copy)
ac.readChapter = true
ac.maxTime = ac:getDuration()
assert(ac.readPlan.from == read1 and ac.readPlan.span == 20, "a chapter's plan")
near(ac.maxTime, 20 * 1.5 / f, "a chapter's time")
ac:start()
near(ac.readSession.minutes, read1 * 1.5, "the sitting carries over: the same title, put down just now")
ac._delta = 0.5
ac:update()
assert(ac.readSession.pages == read1 + 10, "half a chapter")
local bb, ss, uu = stats(p)
ac._delta = 1
assert(ac:complete() == true, "complete returns vanilla's answer")
ac:perform()
assert(ac.readSession.pages == read1 + 20, "the chapter's last pages were turned at the end")
near(p._st.boredom, bb + b * 10, "the lump at the end is cancelled: only ten pages' drip")
near(p._st.stress, ss + s * 10 * R.immersion(ni, read1 * 1.5 + 15 + 7.5), "stress likewise, deep in the sitting")
assert(not p:isLiteratureRead("IGUI_BookTitle_AimWestBoys"), "a chapter does not mark the title read")
assert(copy._md.literatureTitle == "IGUI_BookTitle_AimWestBoys", "the title is back on the item")
assert(R.mark(p, copy, ni) == read1 + 20, "the bookmark after a chapter")
assert(not R.finished(p, ni.key), "not finished")

-- the finish
local a3 = ISReadABook:new(p, copy)
a3:start()
H.clearHalo()
a3._delta = 1
a3:complete()
a3:perform()
assert(p:isLiteratureRead("IGUI_BookTitle_AimWestBoys"), "finished: vanilla marks it read")
assert(R.finished(p, ni.key) and R.mark(p, copy, ni) == 0 and copy._md[R.ITEM_KEY] == nil, "finished: the record, no bookmark")
assert(R.verdict(p, ni) ~= nil, "a verdict")
local m = R.moodle(p)
assert(m and m.family == "westerns" and m.key == ni.key, "the Good Read moodle")
assert(#H.halo == 1 and H.halo[1]:find("^%+IGUI_DanTraits_Finished_"), "the finish notice: " .. tostring(H.halo[1]))
assert(p._md.DVF_Reading.read[ni.key].when == 100, "the record's time")
-- the whole book from the start, by a reader whose stats were high: the total drip
local p2 = player()
H.rng = { 0, 0 }
R.tastes(p2)
p2._st.boredom, p2._st.stress, p2._st.unhappy = 100, 1, 100
local whole = literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } })
local aw = ISReadABook:new(p2, whole)
aw:start()
aw._delta = 1
aw:complete()
aw:perform()
near(p2._st.boredom, 100 + b * pages, "a whole book's drip: vanilla's total over 300 pages, scaled by its length")
near(p2._st.unhappy, 100 + u * pages * 1.3, "unhappiness likewise, a whole book in one sitting: fully immersed")

-- a re-read: comfort in the liked family only, no moodle
local againH = literature({ title = "IGUI_BookTitle_AnUnexpectedLetter", tags = { "softcover" } })
p._read["IGUI_BookTitle_AnUnexpectedLetter"] = true   -- read before the mod
local ar = ISReadABook:new(p, againH)
ar:start()
assert(ar.readSession.reread, "vanilla's read-tracking makes it a re-read")
p._st.boredom = 50
ar._delta = 0.5
ar:update()
near(p._st.boredom, 50 + lb * 0.2 * math.floor(horror.pages * 0.5), "comfort re-read: a fifth")
local before = R.moodle(p)
ar._delta = 1
ar:complete()
ar:perform()
assert(R.moodle(p) == before, "a re-read gives no moodle")
assert(R.data(p).read[horror.key].verdict ~= nil, "but is recorded")

-- finding out -------------------------------------------------------------------------

local p3 = player()
H.rng = { 0, 0 }
R.tastes(p3)   -- horror liked, thrillers disliked
H.clearHalo()
assert(R.notePages(p3, "horror", 29) == nil and #H.halo == 0, "29 pages: nothing yet")
local a4 = ISReadABook:new(p3, literature({ title = "IGUI_BookTitle_AnUnexpectedLetter", tags = { "softcover" } }))
a4:start()
a4._delta = 1 / horror.pages
a4:update()
assert(#H.halo == 1 and H.halo[1] == "+IGUI_DanTraits_Taste_liked", "30 pages in: 'You're really into this.'")
assert(R.tasteKnown(p3, "horror") and not R.tasteKnown(p3, "thrillers"), "horror found out")
H.clearHalo()
a4._delta = 0.5
a4:update()
assert(#H.halo == 0, "told once")
assert(R.notePages(p3, "westerns", 30) == "neutral", "a neutral family is found out too")
assert(R.notePages(p3, "kids", 500) == nil and not R.tasteKnown(p3, "kids"), "kids never")
local found = {}
R.onTasteFound("test", function(pl, fam, v) found[#found + 1] = fam .. ":" .. v end)
R.notePages(p3, "thrillers", 30)
assert(found[1] == "thrillers:disliked", "the taste listener")
R.tasteListeners.test = nil

-- the disliked tick: every 20 minutes of a disliked book, DISLIKE_TICK boredom back
local p4 = player()
H.rng = { 0, 0 }
R.tastes(p4)
local dis = literature({ title = "IGUI_BookTitle_ADameaDozen", tags = { "softcover" } })
local ad = ISReadABook:new(p4, dis)
ad:start()
p4._st.boredom = 50
local hp = R.perPage(p4, info, false)
ad._delta = 12 / info.pages
ad:update()
near(p4._st.boredom, 50 + hp * 12, "12 pages (18 minutes): no tick yet")
ad._delta = 14 / info.pages
ad:update()
near(p4._st.boredom, 50 + hp * 14 + R.DISLIKE_TICK, "14 pages (21 minutes): the tick")

-- the moodle -----------------------------------------------------------------------------

local p5 = player()
H.rng = { 0, 0 }
R.tastes(p5)   -- horror liked
local function fakeInfo(family, quality, medium)
  return { key = family .. tostring(quality) .. tostring(medium or "novel"), family = family, quality = quality, medium = medium or "novel", pages = 300, moodle = true, known = true }
end
assert(R.moodleLevel(p5, fakeInfo("westerns", 3)) == 1, "Good Read")
assert(R.moodleLevel(p5, fakeInfo("westerns", 4)) == 2, "Great Read: quality")
assert(R.moodleLevel(p5, fakeInfo("horror", 2)) == 2, "Great Read: liked")
assert(R.moodleLevel(p5, fakeInfo("horror", 5)) == 3, "Loved It")
assert(R.moodleLevel(p5, fakeInfo("horror", 5, "comic")) == 1, "a comic never goes above Good Read")
assert(R.moodleLevel(p5, fakeInfo("thrillers", 5)) == 2, "disliked but excellent: Great Read")
local nomood = fakeInfo("westerns", 5); nomood.moodle = false
assert(R.moodleLevel(p5, nomood) == 0, "no moodle for a newspaper or a mod's book")
near(R.moodleHours(fakeInfo("westerns", 3), 1), 48, "two days for a novel")
near(R.moodleHours(fakeInfo("westerns", 1), 1), 48, "whatever its quality")
near(R.moodleHours(fakeInfo("classics", 5), 3), 48, "and whatever its genre or level")
near(R.moodleHours(fakeInfo("westerns", 5, "comic"), 1), 12, "a comic: 12 h")
SandboxVars.DanTraits.ReadingMoodleScale = 2
near(R.moodleHours(fakeInfo("westerns", 3), 1), 96, "the sandbox scale")
SandboxVars.DanTraits.ReadingMoodleScale = nil
near(R.strength(p5, fakeInfo("westerns", 3), 1), 1, "strength: neutral, three stars")
near(R.strength(p5, fakeInfo("horror", 5), 3), 1.25 * 1.2 + 0.25, "Loved It: liked x quality + the quarter")
near(R.strength(p5, fakeInfo("thrillers", 5), 2), 0.5 * 1.2, "disliked: half")
assert(R.verdictFor(fakeInfo("horror", 5), 3) == "loved" and R.verdictFor(fakeInfo("westerns", 4), 2) == "great"
  and R.verdictFor(fakeInfo("westerns", 3), 1) == "good" and R.verdictFor(fakeInfo("westerns", 1), 1) == "poor", "verdicts")

-- one buff at a time: the better one wins
hours = 200
local r1 = R.finish(p5, fakeInfo("westerns", 3), false)
assert(r1.level == 1 and r1.hours == 48 and R.moodle(p5).ends == 248, "a Good Read until 248")
hours = 210
R.finish(p5, fakeInfo("horror", 5), false)
assert(R.moodle(p5).level == 3 and R.moodle(p5).family == "horror" and R.moodle(p5).ends == 258, "a higher level replaces it")
hours = 220
local kept = R.finish(p5, fakeInfo("westerns", 2), false)
assert(kept.kept and R.moodle(p5).family == "horror" and R.moodle(p5).ends == 258, "a lower level leaves it, end and all")
hours = 250
R.finish(p5, fakeInfo("westerns", 3), false)
assert(R.moodle(p5).family == "horror" and R.moodle(p5).ends == 258, "still lower: no refresh either (one buff, not two)")
R.endMoodle(p5)
R.finish(p5, fakeInfo("westerns", 3), false)
hours = 260
R.finish(p5, fakeInfo("popular", 3, "comic"), false)
assert(R.moodle(p5).family == "westerns", "a comic's 12 h does not take over a novel's 38 h left")
hours = 290
R.finish(p5, fakeInfo("popular", 3), false)
assert(R.moodle(p5).family == "popular" and R.moodle(p5).ends == 338, "the same level with more time to run takes over, genre and all")
for _, f in ipairs(R.FAMILIES) do
  assert(R.BUFF[f], "every genre has a buff: " .. f)
end
assert(R.moodleText(p5) == "Popular Fiction: boredom eases. About 48 h left.", "the moodle says the genre, the buff and the time: " .. tostring(R.moodleText(p5)))
local finished = {}
R.onFinish("test", function(pl, i, res) finished[#finished + 1] = res.level end)
R.finish(p5, fakeInfo("westerns", 1), false)
assert(finished[1] == 1, "the finish listener")
R.finishListeners.test = nil

-- the minute: easing, the genre buff, expiry
local p6 = player()
H.current = p6
H.rng = { 0, 0 }
R.tastes(p6)
hours = 300
R.finish(p6, fakeInfo("horror", 3), false)   -- liked, level 2, strength 1.25
p6._st.boredom, p6._st.unhappy, p6._st.panic = 50, 50, 50
H.fire("EveryOneMinute")
near(p6._st.panic, 50 - 0.5 * 1.25, "Horror: panic eases")
assert(p6._st.boredom == 50 and p6._st.unhappy == 50, "and only that: the genre's buff is the whole buff")
p6._st.stress = 0.5
H.fire("EveryOneMinute")
assert(p6._st.stress == 0.5, "no stress buff for Horror")
-- a sports finish: the XP multipliers, cleared at expiry
xpCalls = {}
R.endMoodle(p6)
R.finish(p6, fakeInfo("sports", 3), false)
H.fire("EveryOneMinute")
assert(#xpCalls == 2 and xpCalls[1].perk == "Fitness" and math.abs(xpCalls[1].mult - 1.05) < 1e-9, "Sports: Fitness and Strength XP x1.05")
near(R.scaled(R.XP_MULT, 1.25), 1.0625, "stronger moodles scale the XP buff")
near(R.scaled(R.BUFF.serious.read, 1.25), 0.875, "and Serious Reading's page time")
H.fire("EveryOneMinute")
assert(#xpCalls == 2, "set once")
hours = 349   -- two days on
H.fire("EveryOneMinute")
assert(#xpCalls == 4 and xpCalls[3].mult == 1 and R.moodle(p6) == nil and p6._md.DVF_Reading.moodle == nil, "expired: the multipliers come off")
-- a skill book's multiplier is left alone
p6._xp.Fitness = 1.5
xpCalls = {}
R.finish(p6, fakeInfo("sports", 3), false)
H.fire("EveryOneMinute")
assert(#xpCalls == 1 and xpCalls[1].perk == "Strength", "a running skill-book multiplier is not touched")
hours = 450
H.fire("EveryOneMinute")
assert(#xpCalls == 2 and xpCalls[2].perk == "Strength", "and not cleared either")
H.current = p

-- real books ---------------------------------------------------------------------------

local shelf = {}
local container = { getItems = function() return list(shelf) end }
local vb = literature({ title = "IGUI_BookTitle_ADameaDozen", tags = { "softcover" }, display = "Paperback" })
local hb2 = literature({ title = "IGUI_BookTitle_ADameaDozen", tags = { "hardcover" }, display = "Book" })
local notBook = literature({ title = "IGUI_ComicTitle_DraculaHunters", tags = { "picturebook" } })
shelf = { vb, hb2, notBook }
H.rng = { 50 }   -- the first misses the 8% chance
H.fire("OnFillContainer", "kitchen", "shelves", container)
assert(vb._md.literatureTitle == "IGUI_BookTitle_ADameaDozen", "missed the roll: still vanilla")
H.rng = { 0, 0, 0, 0, 0, 0 }
H.fire("OnFillContainer", "kitchen", "shelves", container)
assert(vb._md.literatureTitle:find("^IGUI_DVF_BookTitle_"), "swapped for a real book: " .. tostring(vb._md.literatureTitle))
local rk = vb._md.literatureTitle:sub(#"IGUI_DVF_BookTitle_" + 1)
assert(D.real[rk] and D.real[rk].family == "thrillers", "a real thriller")
assert(D.real[rk].cover ~= "H", "a softcover copy never becomes a hardcover-only title")
assert(vb._name == "Paperback: \"" .. D.real[rk].title .. "\", by " .. D.real[rk].author, "named like a vanilla book: " .. tostring(vb._name))
assert(notBook._md.literatureTitle == "IGUI_ComicTitle_DraculaHunters", "comics are not swapped")
local ri = R.info(vb)
assert(ri.kind == "real" and ri.real.title == D.real[rk].title and ri.pages == D.real[rk].pages and ri.medium == "novel", "a real book's info")
assert(R.titleText(ri) == D.real[rk].title, "the journal title")
assert(R.titleText(info) == "\"A Dame a Dozen\", by Someone", "a vanilla title's text")
SandboxVars.DanTraits.ReadingRealBookChance = 0
local vb2 = literature({ title = "IGUI_BookTitle_ADameaDozen", tags = { "softcover" } })
shelf = { vb2 }
H.rng = { 0, 0 }
H.fire("OnFillContainer", "kitchen", "shelves", container)
assert(vb2._md.literatureTitle == "IGUI_BookTitle_ADameaDozen", "chance 0: never")
SandboxVars.DanTraits.ReadingRealBookChance = nil
assert(#R.realCandidates(hb2, "thrillers") > 0 and #R.realCandidates(hb2, "kids") == 0, "candidates by family")
for _, k in ipairs(R.realCandidates(hb2, "horror")) do assert(D.real[k].cover ~= "S", "a hardcover copy: no softcover-only titles") end

-- the tooltip and the chapter option ----------------------------------------------------

local lines = R.tooltipLines(p3, literature({ title = "IGUI_BookTitle_AnUnexpectedLetter", tags = { "softcover" } }))
assert(lines[1][1] == "Genre: Horror (you love these)" and lines[1][3] == 1, "the genre line, green: " .. lines[1][1])
assert(lines[2][1] == "Pages: " .. math.floor(horror.pages * 0.5) .. " of " .. horror.pages, "the pages line: " .. lines[2][1])
assert(#lines == 2, "no verdict yet")
lines = R.tooltipLines(p3, literature({ title = "IGUI_BookTitle_ADameaDozen", tags = { "softcover" } }))
assert(lines[1][1] == "Genre: Thrillers & Crime (not your thing)" and lines[1][2] == 1, "disliked, red")
lines = R.tooltipLines(p3, literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } }))
assert(lines[1][1] == "Genre: Westerns (fine by you)", "neutral, found out")
lines = R.tooltipLines(p, literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } }))
assert(lines[1][1] == "Genre: Westerns (fine by you)" and lines[3][1]:find("^Your verdict: IGUI_DanTraits_Verdict_"), "found out by reading it, a verdict after finishing")
assert(R.tooltipLines(p, skill) == nil, "no lines for a skill book")
local options = {}
local context = { addOption = function(_, name, target, fn, arg) options[#options + 1] = { name = name, fn = fn, target = target, arg = arg }; return {} end }
H.fire("OnFillInventoryObjectContextMenu", 0, context, { literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } }) })
assert(#options == 1 and options[1].name == "Read a chapter (~30 min)", "the chapter option")
options[1].fn(options[1].target, options[1].arg)
assert(#queued == 1 and queued[1].readChapter and queued[1].readPlan.span == 20, "the chapter action")
options = {}
H.fire("OnFillInventoryObjectContextMenu", 0, context, { comic })
assert(#options == 0, "no chapter option for a comic shorter than a chapter")
H.fire("OnFillInventoryObjectContextMenu", 0, context, { skill })
assert(#options == 0, "nor for a skill book")
isClient = function() return true end
H.fire("OnFillInventoryObjectContextMenu", 0, context, { literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } }) })
assert(#options == 0, "no chapter option on a multiplayer client (the server would read the whole book)")
isClient = function() return false end
local illit = player({ vanilla = { "illiterate" } })
H.current = illit
H.fire("OnFillInventoryObjectContextMenu", 0, context, { literature({ title = "IGUI_BookTitle_AimWestBoys", tags = { "softcover" } }) })
assert(#options == 0, "an Illiterate character gets no chapter of a novel")
H.current = p

-- This Is Your Life --------------------------------------------------------------------

local p7 = player()
H.rng = { 0, 0 }
R.tastes(p7)
R.finish(p7, fakeInfo("westerns", 3), false)
assert(p7._md.TIYL == nil, "without This Is Your Life: nothing written")
TIYL = {}
R.finish(p7, { key = "x", family = "horror", quality = 5, medium = "novel", pages = 300, moodle = true, known = true, real = { title = "The Shining" } }, false)
local tl = p7._md.TIYL.journal.timeline
assert(tl[1] == "July 12, 1993 - Finished \"The Shining\". Loved it.", "the journal line: " .. tostring(tl[1]))
R.notePages(p7, "thrillers", 30)
assert(tl[2] == "July 12, 1993 - Turns out I can't stand Thrillers & Crime.", "a taste line: " .. tostring(tl[2]))
R.notePages(p7, "westerns", 30)
assert(#tl == 2, "a neutral taste is not journaled")
R.finish(p7, { key = "y", family = "horror", quality = 5, medium = "novel", pages = 300, moodle = true, known = true, real = { title = "Misery" } }, true)
assert(tl[3] == "July 12, 1993 - Finished \"Misery\". Again.", "a re-read's line")
-- a re-read keeps the first reading's verdict (it was recomputed at level 0: "loved" became "great";
-- review 2026-10-16 A1.11)
assert(R.data(p7).read.x.verdict == "loved", "The Shining: loved first time")
local again = R.finish(p7, { key = "x", family = "horror", quality = 5, medium = "novel", pages = 300, moodle = true, known = true, real = { title = "The Shining" } }, true)
assert(again.reread and again.level == 0 and again.verdict == "loved" and R.data(p7).read.x.verdict == "loved", "re-read: still loved")
TIYL = nil

-- Vitality's hooks ---------------------------------------------------------------------

H.load("DanTraits", "ReadingHooks")
assert(R.reliefHooks.vitality and R.durationHooks.vitality, "the hooks are in")
local p8 = player({ hours = 100 })
near(DanTraits_ReadingRelief(p8, ni), 1, "nothing going on: x1")
near(DanTraits_ReadingTime(p8, ni), 1, "nothing going on: x1 time")
DanTraits_HomeStrength = function() return 1 end
DanTraits_Data(p8).hmAtHome = true
near(DanTraits_ReadingRelief(p8, ni), 1.15, "at home: x1.15")
local hbp = player({ traits = { "homebody" } })
DanTraits_Data(hbp).hmAtHome = true
near(DanTraits_ReadingRelief(hbp, ni), 1.3, "a Homebody at home: x1.3")
DanTraits_ConcussionStrength = function() return 1 end
near(DanTraits_ReadingRelief(p8, ni), 1.15 * 0.5, "concussed: half")
near(DanTraits_ReadingTime(p8, ni), 1.25, "concussed: a quarter longer")
DanTraits_ConcussionStrength = function() return 0 end
local bd = player({ traits = { "badday" }, hours = 10 })
near(DanTraits_ReadingRelief(bd, ni), 1.25, "a Bad Day's first day: comfort")
bd._hours = 30
near(DanTraits_ReadingRelief(bd, ni), 1, "the day after: none")
-- glasses: one rule, the Reading Glasses trait's (DanTraits_NeedsGlasses in DanTraits_AgeTraits.lua,
-- loaded here with Age as the game has them); a list of its own in the hooks disagreed with the
-- trait about prescription glasses (review 2026-10-16 A1.11). Without the trait file nothing is
-- slower; with it, the trait says who needs glasses and which pairs count, the hooks add the
-- small print's share by age band, and the trait's own x1.5 sits on top in the action
assert(DanTraits_NeedsGlasses == nil, "the trait file is not loaded yet")
near(DanTraits_ReadingTime(player({ traits = { "age40s", "readingglasses" } }), ni), 1, "without the trait file: nothing")
CharacterProfessionDefinition = { getCharacterProfessionDefinition = function() return { getXpBoosts = function() return nil end } end }
function transformIntoKahluaTable(t) return t end
MoodleType.HEAVY_LOAD = "heavy"
ClimbOverFenceState = { instance = function() return {} end }
ClimbThroughWindowState = { instance = function() return {} end }
BodyPartType.Torso_Lower = "Torso_Lower"
BodyPartType.getDisplayName = function(kind) return kind end
ISReadABook.isValid = function() return true end   -- the trait wraps it: no reading in the dark without glasses
H.load("Age", "AgeTraits")
assert(DanTraits_NeedsGlasses and ISReadABook.DanTraitsWraps["getDuration:glasses-read"] and ISReadABook.DanTraitsWraps["isValid:glasses-light"], "the trait's rule and its wraps are in")
near(DanTraits_ReadingTime(player({ traits = { "age40s" } }), ni), 1, "40s without the trait: no penalty of its own")
local rg = player({ traits = { "age40s", "readingglasses" } })
near(DanTraits_ReadingTime(rg, ni), 1.1, "Reading Glasses in the 40s, none on: a tenth longer a page")
for _, kind in ipairs({ "Base.Glasses_Reading", "Base.Glasses_Prescription_Sun", "Base.Glasses_Normal" }) do
  rg._worn = { { type = kind, name = "glasses" } }
  near(DanTraits_ReadingTime(rg, ni), 1, kind .. " on: the trait is satisfied, so is the page")
end
rg._worn = { { type = "Base.Glasses_Sun", name = "sunglasses" } }
near(DanTraits_ReadingTime(rg, ni), 1.1, "sunglasses are glasses to nobody")
near(DanTraits_ReadingTime(player({ traits = { "age50s", "readingglasses" } }), ni), 1.15, "50s: 15%")
near(DanTraits_ReadingTime(player({ traits = { "readingglasses" } }), ni), 1.1, "the trait on a 30s band (sandbox): the 40s share")
-- the action: the trait's x1.5 on the hooks' x1.1, and no reading in a dim room without a pair
rg._worn, rg._light = {}, 0.7
local plain40 = player({ traits = { "age40s" } }); plain40._light = 0.7
local function duration(who) return setmetatable({ character = who, item = neutralBook, minutesPerPage = minutesPerPage }, { __index = ISReadABook }):getDuration() end
near(duration(rg) / duration(plain40), 1.1 * 1.5, "no pair on: the small print's tenth and the trait's half again")
rg._worn = { { type = "Base.Glasses_Reading", name = "glasses" } }
near(duration(rg) / duration(plain40), 1, "a pair on: the same book takes the same time")
rg._worn, rg._light = {}, 0.3
assert(setmetatable({ character = rg, item = neutralBook }, { __index = ISReadABook }):isValid() == false, "dim, no pair: cannot read")
assert(setmetatable({ character = plain40, item = neutralBook }, { __index = ISReadABook }):isValid() == true, "dim without the trait: reads")

H.pass()
