-- Project Zomboid Vitality Project: the Notes tab of the character window.
--
-- What the character has worked out about themselves, kept out of the health
-- panel (which is about the body right now). Each section is a header and
-- its lines:
--   Migraine triggers (Migraines): the strong triggers worked out
--     (DanTraits_Migraine.lua), how many are still to find, and before the
--     first, how one gives itself away.
--   Food (Sensory Issues): the two safe and two can't-stand food groups and
--     how many foods became safe by eating them calmly (DanTraits_Sensory.lua).
-- A new condition adds its section to NOTES_SECTIONS.
--
-- The tab is added to the window when it is built (createChildren, the way
-- vanilla adds its own five), and only for a character with a trait that has
-- something to note, so everyone else's window is as it was. Neat Rocco's icon
-- tab bar gives every mod's tab the same spanner; ours gets a notebook, set a
-- frame later (Neat Rocco sets its icons after the window's own build).
require "ISUI/ISPanelJoypad"
require "XpSystem/ISUI/ISCharacterInfoWindow"

local NT_BORDER  = 10      -- px around the text
local NT_INDENT  = 8       -- px a section's lines sit in from its header
local NT_GAP     = 6       -- px under each section
local NT_ICON    = "Item_Notebook"   -- the tab's icon on Neat Rocco's bar

local RED, GREEN, ORANGE = { 0.89, 0.28, 0.28 }, { 0.28, 0.89, 0.28 }, { 1, 0.58, 0 }
local GREY, WHITE = { 0.7, 0.7, 0.7 }, { 1, 1, 1 }

local function t(key) return getText("UI_DanTraits_notes_" .. key) end

-- Migraines: the strong triggers worked out, and how many are left to find
local function migraineLines(player)
    if not DanTraits_MigraineTriggerSummary then return {} end
    local s = DanTraits_MigraineTriggerSummary(player)
    if not s then return {} end
    local out = {}
    if #s.known == 0 then
        out[#out + 1] = { getText("UI_DanTraits_notes_MigraineNone", tostring(s.left)), GREY }
        out[#out + 1] = { t("MigraineHow"), GREY }
        return out
    end
    for _, key in ipairs(s.known) do out[#out + 1] = { t("Migraine_" .. key), ORANGE } end
    if s.left > 0 then out[#out + 1] = { getText("UI_DanTraits_notes_MigraineLeft", tostring(s.left)), GREY } end
    return out
end
DanTraits_NotesMigraineLines = migraineLines

-- Sensory Issues: the safe and can't-stand food groups, and the foods learned
local function foodLines(player)
    if not DanTraits_SensoryFoodSummary then return {} end
    local s = DanTraits_SensoryFoodSummary(player)
    if not s then return {} end
    local out = {
        { getText("UI_DanTraits_SensorySafe", s.safe[1], s.safe[2]), GREEN },
        { getText("UI_DanTraits_SensoryHate", s.hate[1], s.hate[2]), RED },
    }
    if s.learned > 0 then out[#out + 1] = { getText("UI_DanTraits_notes_FoodLearned", tostring(s.learned)), GREY } end
    return out
end
DanTraits_NotesFoodLines = foodLines

-- { header key, lines(player) }, in the tab's order
local NOTES_SECTIONS = {
    { "MigraineHeader", migraineLines },
    { "FoodHeader", foodLines },
}

-- the sections with something to say: { header, lines }
local function notesFor(player)
    local out = {}
    for _, section in ipairs(NOTES_SECTIONS) do
        local lines = {}
        DanTraits_Guard("notes " .. section[1], function() lines = section[2](player) end)
        if #lines > 0 then out[#out + 1] = { t(section[1]), lines } end
    end
    return out
end
DanTraits_NotesFor = notesFor

-- the tab ---------------------------------------------------------------------

DanTraitsNotesView = ISPanelJoypad:derive("DanTraitsNotesView")

function DanTraitsNotesView:new(x, y, width, height, playerNum)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    return o
end

function DanTraitsNotesView:render()
    ISPanelJoypad.render(self)
    local player = getSpecificPlayer(self.playerNum)
    local sections = player and notesFor(player) or {}
    local tm = getTextManager()
    local fontHgt = tm:getFontHeight(UIFont.Small)
    local y, widest = NT_BORDER, 0
    local function draw(str, dx, c)
        self:drawText(str, NT_BORDER + dx, y, c[1], c[2], c[3], 1, UIFont.Small)
        widest = math.max(widest, dx + tm:MeasureStringX(UIFont.Small, str))
        y = y + fontHgt
    end
    if #sections == 0 then draw(t("Empty"), 0, GREY) end
    for _, section in ipairs(sections) do
        draw(section[1], 0, WHITE)
        for _, l in ipairs(section[2]) do draw(l[1], NT_INDENT, l[2]) end
        y = y + NT_GAP
    end
    -- the window fits the tab, as vanilla's protection tab does
    self:setWidthAndParentWidth(math.max(self.width, widest + NT_BORDER * 2))
    self:setHeightAndParentHeight(math.max(self.height, y + NT_BORDER))
end

-- the shoulder buttons switch tabs, B lets go (as vanilla's tabs)
function DanTraitsNotesView:onJoypadDown(button)
    if button == Joypad.BButton then
        getPlayerInfoPanel(self.playerNum):toggleView(t("Tab"))
        setJoypadFocus(self.playerNum, nil)
    end
    if button == Joypad.LBumper or button == Joypad.RBumper then
        getPlayerInfoPanel(self.playerNum):onJoypadDown(button)
    end
end

-- a character with a trait that has something to note (an unreadable player gets the tab)
local function wanted(playerNum)
    local yes = true
    pcall(function()
        local player = getSpecificPlayer(playerNum)
        yes = DanTraits_HasTrait(player, "migraine") or DanTraits_HasTrait(player, "sensory")
    end)
    return yes
end

-- Neat Rocco's icon bar: our tab's button, found by the view it shows
local function setIcon(window, view)
    if not window.tabButtons or not window.subPanels then return end
    local tex = getTexture(NT_ICON)
    if not tex then return end
    for n, panel in pairs(window.subPanels) do
        local btn = window.tabButtons[n]
        if panel == view and btn and btn.setIcon then btn:setIcon(tex) end
    end
end

local function addTab()
    DanTraits_Wrap(ISCharacterInfoWindow, "createChildren", "notes-tab", function(original, self, ...)
        local result = original(self, ...)
        DanTraits_Guard("notes tab", function()
            if not self.panel or not wanted(self.playerNum) then return end
            local view = DanTraitsNotesView:new(0, 8, self.width, self.height - 8, self.playerNum)
            view:initialise()
            view.infoText = getTextOrNull("UI_DanTraits_notes_Info")
            self.panel:addView(t("Tab"), view)
            self.danTraitsNotesView = view
            DanTraits_Later(1, function() setIcon(self, view) end, "notes icon")
        end)
        return result
    end)
end

addTab()
Events.OnGameStart.Add(addTab)
