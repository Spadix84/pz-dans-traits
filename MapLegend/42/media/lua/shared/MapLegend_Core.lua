-- Map Legend: the part with no UI in it. The entries (a vanilla map symbol in
-- one pen colour, and what it means), finding the entry for a symbol on the
-- map, the colour the symbol picker should switch to, counting what is
-- placed, and where the legend is kept:
--
--   the profile    Zomboid/Lua/MapLegend.txt, shared by every save and
--                  every character that has no legend of its own
--   a character    player mod data (MapLegend), saved with that character,
--                  once its own legend is switched on
--
-- An entry is { sym = "Skull", r = 0.65, g = 0.054, b = 0.054, text = "Horde" }:
-- the symbol id from MapSymbolDefinitions and the colour of the pen it is
-- drawn in. The same symbol in another colour is another entry, so a red X
-- can mean Horde and a green X Cleared.
--
-- The client files (MapLegend_Panel, MapLegend_Editor) draw it; everything
-- here can be tested offline.

MapLegend = MapLegend or {}
local ML = MapLegend

ML.VERSION = "0.1.0"
ML.FILE = "MapLegend.txt"          -- under Zomboid/Lua, written by getFileWriter
ML.HEADER = "MapLegend 1"
ML.MOD_DATA = "MapLegend"
-- How close two colours must be to count as the same pen. The game keeps a
-- symbol's colour as a float, so 0.65 comes back as 0.6499999; the closest
-- two vanilla pens (black 0.129 and pencil 0.2) are 0.07 apart.
ML.COLOR_TOLERANCE = 0.03
ML.MAX_TEXT = 60
ML.revision = 0                    -- bumped on every change; the UI redraws on it

-- The vanilla pens (ISWorldMapSymbols:createChildren's colorButtonInfo), for
-- when no symbols panel is open to read them from; the live panel's list
-- wins, so pens other mods add show up too.
ML.DEFAULT_COLORS = {
    { item = "Pen", r = 0.129, g = 0.129, b = 0.129 },
    { item = "Pencil", r = 0.2, g = 0.2, b = 0.2 },
    { item = "RedPen", r = 0.65, g = 0.054, b = 0.054 },
    { item = "BluePen", r = 0.156, g = 0.188, b = 0.49 },
    { item = "GreenPen", r = 0.06, g = 0.39, b = 0.17 },
}

-- the meanings offered in the editor's preset list (IGUI_ML_Preset_<name>)
ML.PRESETS = {
    "Safehouse", "Loot", "Looted", "Food", "Water", "Medical", "Weapons", "Ammo",
    "Tools", "Fuel", "Generator", "Vehicle", "Farm", "Animals", "Fishing", "Danger",
    "Horde", "Cleared", "Locked", "Blocked", "Trap", "Survivors", "Meet", "ToCheck",
}

-- entries ---------------------------------------------------------------------------------

local function round(v)
    return math.floor((tonumber(v) or 0) * 1000 + 0.5) / 1000
end
ML.round = round

function ML.sameColor(r1, g1, b1, r2, g2, b2)
    local t = ML.COLOR_TOLERANCE
    return math.abs(r1 - r2) <= t and math.abs(g1 - g2) <= t and math.abs(b1 - b2) <= t
end

-- what is typed: one line, no tabs (the file is tab separated), trimmed, capped
function ML.sanitize(text)
    text = tostring(text or "")
    text = string.gsub(text, "[%c]", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if #text > ML.MAX_TEXT then text = string.sub(text, 1, ML.MAX_TEXT) end
    return text
end

function ML.newEntry(sym, r, g, b, text)
    return { sym = sym, r = round(r), g = round(g), b = round(b), text = ML.sanitize(text) }
end

function ML.copyEntries(entries)
    local out = {}
    for i, e in ipairs(entries or {}) do
        out[i] = { sym = e.sym, r = e.r, g = e.g, b = e.b, text = e.text }
    end
    return out
end

-- the entry for a symbol drawn in a colour, or nil
function ML.find(entries, sym, r, g, b)
    for i, e in ipairs(entries) do
        if e.sym == sym and ML.sameColor(e.r, e.g, e.b, r, g, b) then return i end
    end
    return nil
end

-- Add an entry, or change one. With `at` (the entry being edited) that one is
-- changed; a symbol and colour that another entry already has takes that
-- entry's place, so there is never two rows for one mark. Returns where the
-- entry ended up.
function ML.put(entries, sym, r, g, b, text, at)
    local e = ML.newEntry(sym, r, g, b, text)
    local same = ML.find(entries, sym, r, g, b)
    if at and entries[at] then
        entries[at] = e
        if same and same ~= at then
            table.remove(entries, same)
            if same < at then at = at - 1 end
        end
        return at
    end
    if same then
        entries[same] = e
        return same
    end
    entries[#entries + 1] = e
    return #entries
end

function ML.remove(entries, i)
    if entries[i] then table.remove(entries, i) end
end

-- move entry i up (-1) or down (+1); returns where it is now
function ML.move(entries, i, delta)
    local j = i + delta
    if not entries[i] or not entries[j] then return i end
    entries[i], entries[j] = entries[j], entries[i]
    return j
end

function ML.forSymbol(entries, sym)
    local out = {}
    for _, e in ipairs(entries) do
        if e.sym == sym then out[#out + 1] = e end
    end
    return out
end

-- The colour the symbol picker should switch to when `sym` is picked: the
-- current one if the legend has `sym` in it, else the first legend colour for
-- `sym` whose pen the character has. `colors` is the panel's pens in order,
-- { r, g, b, enabled }. Returns an index into `colors`, or nil to leave it.
function ML.pickColor(entries, sym, current, colors)
    local mine = ML.forSymbol(entries, sym)
    if #mine == 0 then return nil end
    if current then
        for _, e in ipairs(mine) do
            if ML.sameColor(e.r, e.g, e.b, current.r, current.g, current.b) then return nil end
        end
    end
    for _, e in ipairs(mine) do
        for i, c in ipairs(colors) do
            if c.enabled and ML.sameColor(e.r, e.g, e.b, c.r, c.g, c.b) then return i end
        end
    end
    return nil
end

-- how many of each entry are on the map; `symbols` is { sym, r, g, b } per
-- placed symbol. Returns counts by entry index, and how many placed symbols
-- the legend says nothing about.
function ML.count(entries, symbols)
    local counts = {}
    for i = 1, #entries do counts[i] = 0 end
    local unlisted = 0
    for _, s in ipairs(symbols) do
        local i = ML.find(entries, s.sym, s.r, s.g, s.b)
        if i then counts[i] = counts[i] + 1 else unlisted = unlisted + 1 end
    end
    return counts, unlisted
end

-- the pen an entry is drawn with, from `colors` ({ item, r, g, b }), or nil
function ML.colorOf(entry, colors)
    for i, c in ipairs(colors or ML.DEFAULT_COLORS) do
        if ML.sameColor(entry.r, entry.g, entry.b, c.r, c.g, c.b) then return i, c end
    end
    return nil
end

-- the profile file ------------------------------------------------------------------------

local function newProfile()
    return { entries = {}, collapsed = false }
end

function ML.serialize(profile)
    local lines = { ML.HEADER, "collapsed=" .. (profile.collapsed and "1" or "0") }
    for _, e in ipairs(profile.entries) do
        lines[#lines + 1] = table.concat({ "entry", e.sym, tostring(e.r), tostring(e.g), tostring(e.b), e.text }, "\t")
    end
    return lines
end

local function split(line)
    local out, start = {}, 1
    while true do
        local tab = string.find(line, "\t", start, true)
        if not tab then
            out[#out + 1] = string.sub(line, start)
            return out
        end
        out[#out + 1] = string.sub(line, start, tab - 1)
        start = tab + 1
    end
end

-- A file that is not ours, or a line that does not read, is skipped rather
-- than failing: the worst a bad file does is an empty legend.
function ML.parse(lines)
    local profile = newProfile()
    if not lines or lines[1] ~= ML.HEADER then return profile end
    for n = 2, #lines do
        local line = lines[n]
        if line == "collapsed=1" then
            profile.collapsed = true
        elseif string.sub(line, 1, 6) == "entry\t" then
            local f = split(line)
            local r, g, b = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
            local text = f[6] and ML.sanitize(f[6]) or ""
            if f[2] and f[2] ~= "" and r and g and b and text ~= "" then
                ML.put(profile.entries, f[2], r, g, b, text)
            end
        end
    end
    return profile
end

function ML.readProfile()
    local lines = {}
    pcall(function()
        local reader = getFileReader(ML.FILE, false)
        if not reader then return end
        local line = reader:readLine()
        while line ~= nil do
            lines[#lines + 1] = line
            line = reader:readLine()
        end
        reader:close()
    end)
    return ML.parse(lines)
end

function ML.writeProfile()
    local profile = ML.profile()
    local ok, err = pcall(function()
        local writer = getFileWriter(ML.FILE, true, false)
        writer:write(table.concat(ML.serialize(profile), "\n") .. "\n")
        writer:close()
    end)
    if not ok then print("[MapLegend] could not save " .. ML.FILE .. ": " .. tostring(err)) end
end

function ML.profile()
    if not ML.loaded then ML.loaded = ML.readProfile() end
    return ML.loaded
end

-- per character ---------------------------------------------------------------------------

local function charData(player)
    if not player then return nil end
    local md = player:getModData()
    return md and md[ML.MOD_DATA] or nil
end

function ML.isOwn(player)
    local d = charData(player)
    return d ~= nil and d.own == true
end

-- the legend the character goes by: its own when switched on, else the profile
function ML.entriesFor(player)
    local d = charData(player)
    if d and d.own then
        d.entries = d.entries or {}
        return d.entries, true
    end
    return ML.profile().entries, false
end

-- Switching a character's own legend on starts it from the profile the first
-- time; after that, switching off and on again brings back what it had.
function ML.setOwn(player, own)
    if not player then return end
    local md = player:getModData()
    local d = md[ML.MOD_DATA]
    if own then
        if not d then
            d = { entries = ML.copyEntries(ML.profile().entries) }
            md[ML.MOD_DATA] = d
        end
        d.own = true
    elseif d then
        d.own = false
    end
    ML.changed(player)
end

-- the character's own legend becomes the profile, for every other character
function ML.copyToProfile(player)
    local d = charData(player)
    if not d or not d.own then return end
    ML.profile().entries = ML.copyEntries(d.entries)
    ML.writeProfile()
    ML.changed(nil)
end

-- After any edit: the profile is written out at once (a character's mod data
-- saves with the character), and the UI is told to redraw.
function ML.changed(player)
    if not ML.isOwn(player) then ML.writeProfile() end
    ML.revision = ML.revision + 1
    if ML.onChanged then pcall(ML.onChanged) end
end

function ML.setCollapsed(collapsed)
    local p = ML.profile()
    if p.collapsed == collapsed then return end
    p.collapsed = collapsed
    ML.writeProfile()
end

-- translations ----------------------------------------------------------------------------

function ML.presetText(name)
    return getText("IGUI_ML_Preset_" .. name)
end

-- "Red Pen", from the pen's item, for tooltips; "" when there is no pen for it
function ML.colorName(entry, colors)
    local _, c = ML.colorOf(entry, colors)
    if not c or not c.item then return "" end
    local name
    pcall(function() name = getItemNameFromFullType("Base." .. c.item) end)
    return name or c.item
end
