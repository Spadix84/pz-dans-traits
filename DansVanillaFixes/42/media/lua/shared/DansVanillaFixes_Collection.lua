-- Dan's Vanilla Fixes: the collection checklist, the rules and the lists
-- (client/DansVanillaFixes_CollectionUI.lua is the window,
-- client/DansVanillaFixes_CollectionClient.lua the sidebar button, the
-- right-click options and the tooltip line;
-- shared/DansVanillaFixes_CollectionTitles.lua is the generated list of the
-- game's book, magazine, comic and newspaper titles).
--
-- Each character keeps a checklist of the skill books, recipe magazines,
-- books, magazines, comics, newspapers, fliers, tapes, CDs, key rings,
-- mementos and tools they own. Nothing is ticked for them: the player ticks
-- what they have.
--
-- Items are kept by type ("Base.BookCarpentry2"). Ticking one sets the
-- game's own Unwanted on that type for this character, so every copy goes
-- grey and Take All passes it by; unticking clears Unwanted again, but only
-- if the checklist was what set it.
--
-- Tapes and CDs are one item type per kind (every film is a Base.VHS_Retail),
-- the title is in the item's media data, so they are kept by media id. The
-- game keeps Unwanted for a tape by that same id (InventoryItem.isUnwanted
-- asks the player about the media id, not the type), so ticking a title sets
-- it Unwanted and only that title's copies go grey.
--
-- The rest of the game's reading is the same: every novel is one of a few item
-- types (Base.Book_Fantasy, Base.Paperback_Horror) and the game writes the
-- title on each copy as it spawns (item mod data literatureTitle, or
-- collectibleKey on an old newspaper). So books, magazines, comics,
-- newspapers, fliers, brochures, catalogues and RPG manuals are kept by title.
-- The game keeps Unwanted for these by the string on the copy, so a ticked
-- title is set Unwanted by that string where the list knows it (entry.exact:
-- a book, a flier, a newspaper).
--
-- A magazine or a comic is kept by its name, not by the issue: any issue of
-- Bassline ticks Bassline. The string on a copy has the issue in it, so the
-- list cannot set Unwanted for the name; Add to collection on a copy sets it
-- for that copy's issue, and a tick in the window sets none.
--
-- With Vitality, some novels are real books ("Jurassic Park", by Michael
-- Crichton): its reading swaps them in as loot spawns and writes its own key
-- on the copy, IGUI_DVF_BookTitle_<key>, which has no translation. The titles
-- and authors are in Vitality's table (DanTraits_ReadingData.real), read here
-- if it is loaded, so they are rows in Books like any other.
--
-- Player mod data DVF_Collection:
--   { v = 2, items = { [fullType] = WE_SET | WAS_SET }, media = { [id] = WE_SET | WAS_SET },
--     titles = { [title key] = true | the name, for a title the lists did not know },
--     marks = { [the string Unwanted was set by] = title key } }   only what the checklist set
-- v 1 kept a tape as media[id] = true and set no Unwanted for tapes or titles.

require "DansVanillaFixes_CollectionTitles"

DVF_Collection = DVF_Collection or {}
local C = DVF_Collection

C.KEY = "DVF_Collection"
C.VERSION = 2
C.WE_SET = 1    -- the checklist set Unwanted, so unticking clears it
C.WAS_SET = 2   -- it was Unwanted already, so unticking leaves it

-- the game's tool categories: hand tools, tools that double as weapons
-- (hammers, axes, wrenches) and garden tools (shovels, hoes, rakes)
C.TOOL_CATEGORIES = { Tool = true, ToolWeapon = true, GardeningWeapon = true }
-- in the Tool category but not tools: debug items, raw tobacco, seed paste,
-- unfired clay parts
C.NOT_TOOLS = { "Debug", "^Test", "^Tobacco", "^SeedPaste", "Unfired" }

-- The titled reading, a group per registry of the game's. list: the ids in
-- DVF_CollectionTitles; prefix .. id .. suffix: the title's translation key,
-- which is also what the list keeps it by; icon: the item a row is drawn with.
-- What the game writes on a copy (and keeps Unwanted by) is that key, unless:
-- onCopy: written in front of it; dated: an issue date behind it, so no one
-- string stands for the title; named: the whole translated name instead.
C.TITLE_GROUPS = {
    { list = "Book",         tab = "Books",       icon = "Base.Book",          prefix = "IGUI_BookTitle_" },
    { list = "RpgManual",    tab = "Books",       icon = "Base.RPGmanual",     prefix = "IGUI_RPG_", onCopy = "RPGmanual_" },
    { list = "Magazine",     tab = "Periodicals", icon = "Base.Magazine",      prefix = "IGUI_MagazineTitle_", dated = true },
    { list = "Catalogue",    tab = "Periodicals", icon = "Base.Catalog",       prefix = "IGUI_", onCopy = "Catalog_" },
    -- a comic with no issue numbers carries the bare key; one with them, key#issue
    { list = "ComicBook",    tab = "Comics",      icon = "Base.ComicBook",     prefix = "IGUI_ComicTitle_" },
    -- an old newspaper carries its whole name, "Newspaper: Knox Knews", not a key
    { list = "OldNewspaper", tab = "Newspapers",  icon = "Base.Newspaper",     prefix = "IGUI_NewspaperTitle_",
      named = "IGUI_Newspaper_Name" },
    -- the dated papers of the outbreak, one row an issue
    { list = "Newspaper",    tab = "Newspapers",  icon = "Base.Newspaper_New", prefix = "Print_Media_", suffix = "_title" },
    { list = "Flier",        tab = "Fliers",      icon = "Base.Flier",         prefix = "Print_Media_", suffix = "_title" },
    { list = "Brochure",     tab = "Fliers",      icon = "Base.Brochure",      prefix = "Print_Media_", suffix = "_title" },
}
-- magazines the game names in code: the key is what it writes in front of the
-- issue's date. The names are the mastheads (the items read "Magazine: TV
-- Monthly"); with no name a row is called after its item.
C.TITLE_EXTRA = {
    { key = "TVMagazine", tab = "Periodicals", icon = "Base.TVMagazine", name = "TV Monthly" },
    { key = "HottieZ",    tab = "Periodicals", icon = "Base.HottieZ",    name = "HottieZ" },
    { key = "HunkZ",      tab = "Periodicals", icon = "Base.HottieZ",    name = "HunkZ" },
}
-- a title on none of the lists (a mod's, or a game update's) joins the tab its
-- key belongs to the first time a copy is seen
C.REAL_PREFIX = "IGUI_DVF_BookTitle_"   -- Vitality's real books
C.TITLE_ADOPT = {
    { prefix = "IGUI_BookTitle_",     tab = "Books",       icon = "Base.Book" },
    { prefix = C.REAL_PREFIX,         tab = "Books",       icon = "Base.Book" },
    { prefix = "IGUI_MagazineTitle_", tab = "Periodicals", icon = "Base.Magazine", dated = true },
    { prefix = "IGUI_ComicTitle_",    tab = "Comics",      icon = "Base.ComicBook" },
    { prefix = "Print_Media_",        tab = "Fliers",      icon = "Base.Flier" },
}
C.TITLE_TABS = { "Books", "Periodicals", "Comics", "Newspapers", "Fliers" }

-- the store ---------------------------------------------------------------------

local function transmit(player)
    pcall(function() player:transmitModData() end)
end

-- Unwanted for a title the checklist ticked, by the string the game keys it
-- with; marks remembers the ones set here, and the title each is for
local function markUnwanted(player, d, unwantedKey, titleKey)
    if d.marks[unwantedKey] or player:isUnwanted(unwantedKey) == true then return end
    player:setUnwanted(unwantedKey, true)
    d.marks[unwantedKey] = titleKey
end

-- a character from before tapes and titles set Unwanted: what is ticked gets it now
local function migrate(player, d)
    d.v = C.VERSION
    for id, mark in pairs(d.media) do
        if mark == true then
            local already = player:isUnwanted(id) == true
            d.media[id] = already and C.WAS_SET or C.WE_SET
            if not already then player:setUnwanted(id, true) end
        end
    end
    C.lists()
    for key in pairs(d.titles) do
        local entry = C.byTitle[key]
        if entry and entry.exact then markUnwanted(player, d, entry.exact, key) end
    end
    transmit(player)
end

function C.data(player)
    local md = player:getModData()
    local d = md[C.KEY]
    if type(d) ~= "table" then
        d = { v = C.VERSION, items = {}, media = {}, titles = {}, marks = {} }
        md[C.KEY] = d
    end
    d.items = d.items or {}
    d.media = d.media or {}
    d.titles = d.titles or {}
    d.marks = d.marks or {}
    if d.v ~= C.VERSION then migrate(player, d) end
    return d
end

-- tick or untick key in store (items by type, media by id), Unwanted with it:
-- set on a tick, cleared on an untick only if the tick was what set it
local function setMarked(player, store, key, on)
    local mark = store[key]
    if on then
        if mark then return end
        local already = player:isUnwanted(key) == true
        store[key] = already and C.WAS_SET or C.WE_SET
        if not already then player:setUnwanted(key, true) end
    else
        if not mark then return end
        store[key] = nil
        if mark == C.WE_SET then player:setUnwanted(key, false) end
    end
    transmit(player)
end

function C.hasType(player, fullType)
    return C.data(player).items[fullType] ~= nil
end

function C.hasMedia(player, id)
    return C.data(player).media[id] ~= nil
end

function C.setType(player, fullType, on)
    setMarked(player, C.data(player).items, fullType, on)
end

function C.setMedia(player, id, on)
    setMarked(player, C.data(player).media, id, on)
end

function C.hasTitle(player, key)
    return C.data(player).titles[key] ~= nil
end

-- the string the game wrote on a titled copy, which it keeps Unwanted by, or nil
function C.titleKeyOf(item)
    if not item or not item.hasModData or not item:hasModData() then return nil end
    local md = item:getModData()
    local key = md.literatureTitle or md.collectibleKey
    if type(key) ~= "string" or key == "" then return nil end
    return key
end

-- copies: the items Add to collection was chosen on, each set Unwanted by its
-- own string (the issue in hand of a magazine); a tick in the window has none.
-- An adopted title keeps its name, so its row can be made again in a later
-- session before a copy is seen.
function C.setTitle(player, entry, on, copies)
    local d = C.data(player)
    if on then
        if d.titles[entry.key] == nil then d.titles[entry.key] = entry.adopted and entry.name or true end
        if entry.exact then markUnwanted(player, d, entry.exact, entry.key) end
        for _, item in ipairs(copies or {}) do
            local key = C.titleKeyOf(item)
            if key then markUnwanted(player, d, key, entry.key) end
        end
    else
        d.titles[entry.key] = nil
        local ours = {}
        for unwantedKey, titleKey in pairs(d.marks) do
            if titleKey == entry.key then ours[#ours + 1] = unwantedKey end
        end
        for _, unwantedKey in ipairs(ours) do
            player:setUnwanted(unwantedKey, false)
            d.marks[unwantedKey] = nil
        end
    end
    transmit(player)
end

-- an entry from the lists: { kind = "type" | "media" | "title", key = fullType | id | title key }
function C.has(player, entry)
    if entry.kind == "media" then return C.hasMedia(player, entry.key) end
    if entry.kind == "title" then return C.hasTitle(player, entry.key) end
    return C.hasType(player, entry.key)
end

-- copies: see C.setTitle
function C.set(player, entry, on, copies)
    if entry.kind == "media" then
        C.setMedia(player, entry.key, on)
    elseif entry.kind == "title" then
        C.setTitle(player, entry, on, copies)
    else
        C.setType(player, entry.key, on)
    end
end

-- whether a copy still has something for Add to collection to do: its entry
-- is not ticked, or it is a title whose copy in hand (this issue) is not
-- Unwanted yet
function C.needsAdding(player, entry, item)
    if not C.has(player, entry) then return true end
    if entry.kind ~= "title" then return false end
    local key = C.titleKeyOf(item)
    return key ~= nil and player:isUnwanted(key) ~= true
end

-- the lists ---------------------------------------------------------------------

-- C.tabs: { { id, title, rows = { entry | skill row } , total } } in order
-- C.byType[fullType] / C.byMedia[id] / C.byTitle[key]: the entry, for the
-- tooltip and the menu.
-- A skill row is { skill = name, label = perk name, books = { [volume] = entry } }.

local function perkName(skill)
    local name
    pcall(function() name = PerkFactory.getPerk(SkillBook[skill].perk):getName() end)
    return name or skill
end

local function isLiterature(script)
    local ok, yes = pcall(function() return script:isItemType(ItemType.LITERATURE) end)
    return ok and yes
end

local function skip(script)
    local ok, hidden = pcall(function() return script:getObsolete() or script:isHidden() end)
    return ok and hidden
end

-- what a script item is on the list as, or nil
function C.typeTab(script)
    if skip(script) then return nil end
    local name = script:getName() or ""
    if isLiterature(script) then
        local skill = script:getSkillTrained()
        if skill and SkillBook and SkillBook[skill] then return "SkillBooks" end
        local recipes = script:getLearnedRecipes()
        if recipes and recipes:size() > 0 and script:getDisplayCategory() ~= "Gardening"
            and not name:find("BagSeed", 1, true) then
            return "Magazines"
        end
    end
    if script:getDisplayCategory() == "Memento" then
        if name:find("^KeyRing") then return "KeyRings" end
        -- a reversed cap is the same cap worn the other way round
        if name:find("_Reverse$") then return nil end
        return "Mementos"
    end
    if C.TOOL_CATEGORIES[script:getDisplayCategory()] then
        for _, pattern in ipairs(C.NOT_TOOLS) do
            if name:find(pattern) then return nil end
        end
        return "Tools"
    end
    return nil
end

local function byName(a, b) return a.name:lower() < b.name:lower() end

-- the title vanilla's Literature window shows for a tape or CD
function C.mediaTitle(media)
    local title
    if media:hasTitle() then
        title = media:getTranslatedTitle()
        if media:hasSubTitle() and media:getSubtitleEN() ~= "Home VHS" then
            title = title .. " " .. media:getTranslatedSubTitle()
        end
    elseif media:hasSubTitle() then
        title = media:getTranslatedSubTitle()
    else
        title = media:getTranslatedItemDisplayName()
    end
    return title or media:getId()
end

local function buildTypeLists()
    local found = { SkillBooks = {}, Magazines = {}, KeyRings = {}, Mementos = {}, Tools = {} }
    local mediaScript = {}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local script = all:get(i)
        C.scripts[script:getFullName()] = script
        local tab = C.typeTab(script)
        if tab then
            local entry = { kind = "type", key = script:getFullName(), name = script:getDisplayName(),
                            script = script, tab = tab }
            if tab == "SkillBooks" then
                entry.skill = script:getSkillTrained()
                entry.volume = math.floor((script:getLevelSkillTrained() + 1) / 2)
            end
            table.insert(found[tab], entry)
            C.byType[entry.key] = entry
        end
        local cat = script:getRecordedMediaCat()
        if cat and not mediaScript[cat] then mediaScript[cat] = script end
    end
    return found, mediaScript
end

-- skill books become one row per skill, volumes in order (a mod's sixth
-- volume, or two books at one level, just take the next free box)
local function skillRows(books)
    local rows, bySkill = {}, {}
    for _, e in ipairs(books) do
        local row = bySkill[e.skill]
        if not row then
            row = { skill = e.skill, label = perkName(e.skill), books = {} }
            bySkill[e.skill] = row
            rows[#rows + 1] = row
        end
        row.books[#row.books + 1] = e
    end
    for _, row in ipairs(rows) do
        table.sort(row.books, function(a, b)
            if a.volume ~= b.volume then return a.volume < b.volume end
            return a.key < b.key
        end)
        for v, e in ipairs(row.books) do e.volume = v end
        row.name = row.label
    end
    table.sort(rows, byName)
    return rows
end

local function mediaTabs(mediaScript)
    local tabs = {}
    local rm = getZomboidRadio():getRecordedMedia()
    local cats = rm:getCategories()
    for i = 0, cats:size() - 1 do
        local cat = cats:get(i)
        local rows = {}
        local list = rm:getAllMediaForType(RecordedMedia.getMediaTypeForCategory(cat))
        for j = 0, list:size() - 1 do
            local media = list:get(j)
            if media:getCategory() == cat then
                local entry = { kind = "media", key = media:getId(), name = C.mediaTitle(media),
                                script = mediaScript[cat], tab = cat }
                rows[#rows + 1] = entry
                C.byMedia[entry.key] = entry
            end
        end
        table.sort(rows, byName)
        local title = getText("IGUI_LiteratureUI_RecordedMedia_" .. cat)
        tabs[#tabs + 1] = { id = cat, title = title, rows = rows, total = #rows }
    end
    return tabs
end

-- titled reading ----------------------------------------------------------------

-- exact: the one string the game writes on every copy of the title and keeps
-- Unwanted by; nil for a dated magazine
local function titleEntry(key, name, tab, icon, exact)
    local entry = { kind = "title", key = key, name = name, script = C.scripts[icon], tab = tab, exact = exact }
    C.byTitle[key] = entry
    return entry
end

local function scriptName(fullType)
    local script = C.scripts[fullType]
    return script and script:getDisplayName() or nil
end

-- Vitality's table of real books, { [key] = { title, author, ... } }, or nil
-- without Vitality
local function realBooks()
    local D = DanTraits_ReadingData
    local real = type(D) == "table" and D.real or nil
    return type(real) == "table" and real or nil
end

-- whether Vitality is putting them in the loot: its reading on and the chance
-- above 0. With it off they are not listed, and a copy from before is adopted.
local function realBooksSpawn()
    local R = DanTraits_Reading
    if type(R) ~= "table" or not realBooks() then return false end
    local ok, yes = pcall(function()
        return R.on() and (tonumber(R.opt("ReadingRealBookChance", 8)) or 0) > 0
    end)
    return ok and yes == true
end

-- "Jurassic Park, by Michael Crichton" for a real book's key, or nil
local function realName(key)
    local real = realBooks()
    if not real or string.sub(key, 1, #C.REAL_PREFIX) ~= C.REAL_PREFIX then return nil end
    local row = real[string.sub(key, #C.REAL_PREFIX + 1)]
    if type(row) ~= "table" or not row.title then return nil end
    if not row.author then return row.title end
    return getText("IGUI_DVF_Collection_BookBy", row.title, row.author)
end

-- rows per tab from the generated lists; a title two registries share (a
-- brochure that is also a flier) is one row
local function buildTitleLists()
    local found = {}
    for _, id in ipairs(C.TITLE_TABS) do found[id] = {} end
    local lists = DVF_CollectionTitles or {}
    for _, g in ipairs(C.TITLE_GROUPS) do
        local itemName = g.named and scriptName(g.icon)
        for _, id in ipairs(lists[g.list] or {}) do
            local key = g.prefix .. id .. (g.suffix or "")
            if not C.byTitle[key] then
                local entry = titleEntry(key, getText(key), g.tab, g.icon, not g.dated and (g.onCopy or "") .. key or nil)
                table.insert(found[g.tab], entry)
                if itemName then
                    entry.exact = getText(g.named, itemName, entry.name)
                    C.titleNamed[entry.exact] = entry
                end
            end
        end
    end
    for _, x in ipairs(C.TITLE_EXTRA) do
        table.insert(found[x.tab], titleEntry(x.key, x.name or scriptName(x.icon) or x.key, x.tab, x.icon))
    end
    if realBooksSpawn() then
        for id in pairs(realBooks()) do
            local key = C.REAL_PREFIX .. id
            if not C.byTitle[key] then
                table.insert(found.Books, titleEntry(key, realName(key) or id, "Books", "Base.Book", key))
            end
        end
    end
    for _, id in ipairs(C.TITLE_TABS) do table.sort(found[id], byName) end
    return found
end

-- "Bassline" from an issue of it: a comic's key ends "#12", a magazine's
-- "_3_1989" (month, year)
function C.seriesKey(key)
    local series = string.gsub(key, "#%d+$", "")
    series = string.gsub(series, "_%d+_%d+$", "")
    return series
end

-- a row for a title on none of the lists, or nil when its key is no kind we
-- know. name: what to call it when the key has no translation.
function C.adopt(key, name)
    C.lists()
    if C.byTitle[key] then return C.byTitle[key] end
    for _, a in ipairs(C.TITLE_ADOPT) do
        if string.sub(key, 1, #a.prefix) == a.prefix then
            local text = getText(key)
            if text == key then text = realName(key) or name or key end
            local entry = titleEntry(key, text, a.tab, a.icon, not a.dated and key or nil)
            entry.adopted = true
            local tab = C.tabById[a.tab]
            table.insert(tab.rows, entry)
            table.sort(tab.rows, byName)
            tab.total = tab.total + 1
            C.revision = C.revision + 1
            return entry
        end
    end
    return nil
end

-- the rows a character collected in an earlier session that the lists do not have
function C.adoptStored(player)
    C.lists()
    for key, name in pairs(C.data(player).titles) do
        if not C.byTitle[key] and type(name) == "string" then C.adopt(key, name) end
    end
end

-- the entry a titled copy is on the list as, or nil
function C.titleEntryFor(item)
    local key = C.titleKeyOf(item)
    if not key then return nil end
    local entry = C.byTitle[key] or C.titleNamed[key]
    if entry then return entry end
    entry = C.titleSeen[key]
    if entry ~= nil then return entry or nil end
    -- a catalogue's and an RPG manual's key has the item's type in front
    local itemType = item:getType()
    if itemType and string.sub(key, 1, #itemType + 1) == itemType .. "_" then
        entry = C.byTitle[string.sub(key, #itemType + 2)]
    end
    local series = C.seriesKey(key)
    entry = entry or C.byTitle[series] or C.adopt(series, item:getName())
    C.titleSeen[key] = entry or false
    return entry
end

local function tabOf(id, rows, total)
    return { id = id, title = getText("IGUI_DVF_Collection_" .. id), rows = rows, total = total or #rows }
end

function C.build()
    C.byType, C.byMedia, C.byTitle = {}, {}, {}
    C.scripts, C.titleNamed, C.titleSeen = {}, {}, {}
    C.revision = (C.revision or 0) + 1
    local found, mediaScript = buildTypeLists()
    for _, k in ipairs({ "Magazines", "KeyRings", "Mementos", "Tools" }) do table.sort(found[k], byName) end
    local titled = buildTitleLists()
    local tabs = {}
    tabs[#tabs + 1] = tabOf("SkillBooks", skillRows(found.SkillBooks), #found.SkillBooks)
    tabs[#tabs + 1] = tabOf("Magazines", found.Magazines)
    for _, id in ipairs(C.TITLE_TABS) do tabs[#tabs + 1] = tabOf(id, titled[id]) end
    local ok, media = pcall(mediaTabs, mediaScript)
    if ok then
        for _, t in ipairs(media) do tabs[#tabs + 1] = t end
    end
    tabs[#tabs + 1] = tabOf("KeyRings", found.KeyRings)
    tabs[#tabs + 1] = tabOf("Mementos", found.Mementos)
    tabs[#tabs + 1] = tabOf("Tools", found.Tools)
    C.tabById = {}
    for _, t in ipairs(tabs) do C.tabById[t.id] = t end
    C.tabs = tabs
    return tabs
end

function C.lists()
    if not C.tabs then C.build() end
    return C.tabs
end

-- how many of a tab the character has
function C.count(player, tab)
    local n = 0
    for _, row in ipairs(tab.rows) do
        if row.books then
            for _, e in ipairs(row.books) do if C.has(player, e) then n = n + 1 end end
        elseif C.has(player, row) then
            n = n + 1
        end
    end
    return n
end

-- the entry an inventory item is on the list as, or nil
function C.entryFor(item)
    if not item then return nil end
    C.lists()
    local media
    pcall(function() if item:isRecordedMedia() then media = item:getMediaData() end end)
    if media then return C.byMedia[media:getId()] end
    return C.titleEntryFor(item) or C.byType[item:getFullType()]
end
