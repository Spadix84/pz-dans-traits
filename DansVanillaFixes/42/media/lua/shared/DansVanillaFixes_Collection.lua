-- Dan's Vanilla Fixes: the collection checklist, the rules and the lists
-- (client/DansVanillaFixes_CollectionUI.lua is the window,
-- client/DansVanillaFixes_CollectionClient.lua the sidebar button, the
-- right-click options and the tooltip line).
--
-- Each character keeps a checklist of the skill books, recipe magazines,
-- tapes, CDs, key rings, mementos and tools they own. Nothing is ticked for them:
-- the player ticks what they have.
--
-- Items are kept by type ("Base.BookCarpentry2"). Ticking one sets the
-- game's own Unwanted on that type for this character, so every copy goes
-- grey and Take All passes it by; unticking clears Unwanted again, but only
-- if the checklist was what set it.
--
-- Tapes and CDs are one item type per kind (every film is a Base.VHS_Retail),
-- the title is in the item's media data, so they are kept by media id and
-- never set Unwanted: that would grey out every tape.
--
-- Player mod data DVF_Collection:
--   { v = 1, items = { [fullType] = WE_SET | WAS_SET }, media = { [id] = true } }

DVF_Collection = DVF_Collection or {}
local C = DVF_Collection

C.KEY = "DVF_Collection"
C.WE_SET = 1    -- the checklist set Unwanted, so unticking clears it
C.WAS_SET = 2   -- it was Unwanted already, so unticking leaves it

-- the game's tool categories: hand tools, tools that double as weapons
-- (hammers, axes, wrenches) and garden tools (shovels, hoes, rakes)
C.TOOL_CATEGORIES = { Tool = true, ToolWeapon = true, GardeningWeapon = true }
-- in the Tool category but not tools: debug items, raw tobacco, seed paste,
-- unfired clay parts
C.NOT_TOOLS = { "Debug", "^Test", "^Tobacco", "^SeedPaste", "Unfired" }

-- the store ---------------------------------------------------------------------

function C.data(player)
    local md = player:getModData()
    local d = md[C.KEY]
    if type(d) ~= "table" then
        d = { v = 1, items = {}, media = {} }
        md[C.KEY] = d
    end
    d.items = d.items or {}
    d.media = d.media or {}
    return d
end

local function transmit(player)
    pcall(function() player:transmitModData() end)
end

function C.hasType(player, fullType)
    return C.data(player).items[fullType] ~= nil
end

function C.hasMedia(player, id)
    return C.data(player).media[id] == true
end

function C.setType(player, fullType, on)
    local d = C.data(player)
    local mark = d.items[fullType]
    if on then
        if mark then return end
        local already = player:isUnwanted(fullType) == true
        d.items[fullType] = already and C.WAS_SET or C.WE_SET
        if not already then player:setUnwanted(fullType, true) end
    else
        if not mark then return end
        d.items[fullType] = nil
        if mark == C.WE_SET then player:setUnwanted(fullType, false) end
    end
    transmit(player)
end

function C.setMedia(player, id, on)
    C.data(player).media[id] = on and true or nil
    transmit(player)
end

-- an entry from the lists: { kind = "type" | "media", key = fullType | id }
function C.has(player, entry)
    if entry.kind == "media" then return C.hasMedia(player, entry.key) end
    return C.hasType(player, entry.key)
end

function C.set(player, entry, on)
    if entry.kind == "media" then C.setMedia(player, entry.key, on) else C.setType(player, entry.key, on) end
end

-- the lists ---------------------------------------------------------------------

-- C.tabs: { { id, title, rows = { entry | skill row } , total } } in order
-- C.byType[fullType] / C.byMedia[id]: the entry, for the tooltip and the menu.
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

local function tabOf(id, rows, total)
    return { id = id, title = getText("IGUI_DVF_Collection_" .. id), rows = rows, total = total or #rows }
end

function C.build()
    C.byType, C.byMedia = {}, {}
    local found, mediaScript = buildTypeLists()
    for _, k in ipairs({ "Magazines", "KeyRings", "Mementos", "Tools" }) do table.sort(found[k], byName) end
    local tabs = {}
    tabs[#tabs + 1] = tabOf("SkillBooks", skillRows(found.SkillBooks), #found.SkillBooks)
    tabs[#tabs + 1] = tabOf("Magazines", found.Magazines)
    local ok, media = pcall(mediaTabs, mediaScript)
    if ok then
        for _, t in ipairs(media) do tabs[#tabs + 1] = t end
    end
    tabs[#tabs + 1] = tabOf("KeyRings", found.KeyRings)
    tabs[#tabs + 1] = tabOf("Mementos", found.Mementos)
    tabs[#tabs + 1] = tabOf("Tools", found.Tools)
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
    return C.byType[item:getFullType()]
end
