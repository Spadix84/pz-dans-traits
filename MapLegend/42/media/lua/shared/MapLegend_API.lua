-- Map Legend API for other mods. Everything here is safe to call from a shared
-- or client Lua file; see API.md beside the mod for examples.
--
--   local ok = pcall(require, "MapLegend_API")
--   if ok and MapLegend and MapLegend.API_VERSION then
--       MapLegend.addPreset("Beehive", "Beehive")
--   end
--
-- The legend is a list of entries { sym, r, g, b, text }: a vanilla map symbol
-- id (MapSymbolDefinitions: "Skull", "X", "House", ...) in one pen colour, and
-- what it means. The same symbol in another colour is another entry. A
-- character reads the profile's legend (Zomboid/Lua/MapLegend.txt) unless it
-- keeps its own; every function here takes the player and works on whichever
-- that character uses, and an edit is saved at once.
--
-- API_VERSION goes up only when something here changes meaning or goes away.
require "MapLegend_Core"

local ML = MapLegend
ML.API_VERSION = 1

-- presets -------------------------------------------------------------------------------

-- a meaning offered in the editor's preset list. name is a key: the text shown is
-- the translation IGUI_ML_Preset_<name> if your mod ships one, else text, else
-- the name. Returns true when added (false when a preset of that name exists).
function ML.addPreset(name, text)
    if type(name) ~= "string" or name == "" then return false end
    for _, n in ipairs(ML.PRESETS) do
        if n == name then return false end
    end
    ML.PRESETS[#ML.PRESETS + 1] = name
    if type(text) == "string" and text ~= "" then ML.PRESET_TEXT[name] = text end
    return true
end

-- reading -------------------------------------------------------------------------------

-- the entries this character uses, in legend order. The live list: read it,
-- do not edit it (use set and unset, which save and tell the UI).
function ML.entries(player) return ML.entriesFor(player) end

-- the entry for a symbol in a pen colour, or nil (colours within the pen tolerance)
function ML.meaning(player, sym, r, g, b)
    local entries = ML.entriesFor(player)
    local i = ML.find(entries, sym, r, g, b)
    return i and entries[i] or nil
end

-- every entry for a symbol, whatever the pen
function ML.meaningsFor(player, sym) return ML.forSymbol(ML.entriesFor(player), sym) end

-- writing -------------------------------------------------------------------------------

-- give a symbol in a pen colour a meaning (text up to ML.MAX_TEXT characters); a
-- symbol and colour already in the legend is replaced, so one mark never has
-- two meanings. Saved at once. Returns the entry.
function ML.set(player, sym, r, g, b, text)
    if type(sym) ~= "string" or sym == "" then return nil end
    local entries = ML.entriesFor(player)
    ML.put(entries, sym, tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, text or "")
    ML.changed(player)
    return entries[ML.find(entries, sym, r, g, b)]
end

-- take a symbol in a pen colour out of the legend; true when there was one
function ML.unset(player, sym, r, g, b)
    local entries = ML.entriesFor(player)
    local i = ML.find(entries, sym, r, g, b)
    if not i then return false end
    ML.remove(entries, i)
    ML.changed(player)
    return true
end

-- ML.isOwn(player) and ML.setOwn(player, own) are in the core: whether this
-- character keeps a legend of its own, and switching that on (starts as a copy
-- of the profile's) or off.

-- events --------------------------------------------------------------------------------

-- fn(player) after any change to a legend (an edit in the editor, set, unset,
-- setOwn; player is nil when the profile changed from outside a character). An
-- error in one listener is logged and does not stop the others.
function ML.on(event, fn)
    local list = ML.listeners[event]
    if not list or type(fn) ~= "function" then return false end
    list[#list + 1] = fn
    return true
end

function ML.off(event, fn)
    local list = ML.listeners[event]
    if not list then return false end
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) return true end
    end
    return false
end
