-- Map Legend: the legend in the bottom-left corner of the world map, and the
-- two places it reaches into the vanilla symbols panel.
--
-- The legend lists each entry with its symbol in its pen colour, what it
-- means and how many are on the map. Hovering a row outlines those symbols on
-- the map. Clicking it picks that symbol and pen in the symbols panel, ready
-- to draw (the cursor carries the symbol, as when it is picked in the panel),
-- and keeps those symbols outlined; clicking it again puts the pen down. With
-- no pen, or not the entry's pen, the row only outlines and a line under the
-- rows says which pen it needs. Edit opens the editor (MapLegend_Editor), the
-- small button folds the legend down to its title.
--
-- In the symbols panel: picking a symbol the legend has switches to the
-- legend's pen for it (when the character carries that pen), and each symbol
-- button's tooltip says what the symbol means in which colour.

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/Maps/ISWorldMap"
require "ISUI/Maps/ISWorldMapSymbols"
require "MapLegend_Core"

local ML = MapLegend

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local PAD = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ICON = math.max(BUTTON_HGT, 20)
local ROW_HGT = ICON + 4
local MIN_WIDTH = 180
local RECOUNT_FRAMES = 30
local HIGHLIGHT = { r = 1.0, g = 0.85, b = 0.2 }
local NOTE_MS = 4000

MapLegendPanel = ISPanel:derive("MapLegendPanel")

-- the map's symbols -----------------------------------------------------------------------

local function symbolDef(sym)
    local def
    pcall(function() def = MapSymbolDefinitions.getInstance():getSymbolById(sym) end)
    return def
end

-- a texture per symbol id, looked up once
local textures = {}
function ML.texture(sym)
    local tex = textures[sym]
    if tex == nil then
        local def = symbolDef(sym)
        tex = def and getTexture(def:getTexturePath()) or false
        textures[sym] = tex
    end
    return tex or nil
end

-- every symbol the players drew (the map's own default annotations are left
-- out), calling fn(symbol, sym, r, g, b) for each
local function eachPlaced(symbolsAPI, fn)
    local n = symbolsAPI:getSymbolCount()
    for i = 0, n - 1 do
        local s = symbolsAPI:getSymbolByIndex(i)
        if s and s:isTexture() and s:isUserDefined() then
            fn(s, s:getSymbolID(), s:getRed(), s:getGreen(), s:getBlue())
        end
    end
end

-- the pens of a symbols panel, as ML.pickColor and ML.colorName read them
local function panelColors(symbolsUI)
    local out = {}
    for i, btn in ipairs(symbolsUI and symbolsUI.colorButtons or {}) do
        local c = btn.buttonInfo.colorInfo
        out[i] = { item = btn.buttonInfo.item, r = c:getR(), g = c:getG(), b = c:getB(), enabled = btn.enable }
    end
    return out
end

function ML.colors()
    local symbolsUI = ISWorldMap_instance and ISWorldMap_instance.symbolsUI
    local live = panelColors(symbolsUI)
    if #live > 0 then return live end
    return ML.DEFAULT_COLORS
end

-- the panel -------------------------------------------------------------------------------

function MapLegendPanel:createChildren()
    self.editBtn = ISButton:new(0, PAD, 10, BUTTON_HGT, getText("IGUI_ML_Edit"), self, MapLegendPanel.onEdit)
    self.editBtn:initialise()
    self.editBtn:instantiate()
    self.editBtn.borderColor.a = 0.4
    self.editBtn:setWidthToTitle(40)
    self:addChild(self.editBtn)

    self.foldBtn = ISButton:new(0, PAD, BUTTON_HGT, BUTTON_HGT, "-", self, MapLegendPanel.onFold)
    self.foldBtn:initialise()
    self.foldBtn:instantiate()
    self.foldBtn.borderColor.a = 0.4
    self:addChild(self.foldBtn)
end

function MapLegendPanel:character()
    return self.mapUI.character
end

function MapLegendPanel:entries()
    return ML.entriesFor(self:character())
end

function MapLegendPanel:onEdit()
    local player = self:character()
    if player then MapLegendEditor.toggle(player) end
end

function MapLegendPanel:onFold()
    ML.setCollapsed(not ML.profile().collapsed)
end

function MapLegendPanel:recount(entries)
    local placed = {}
    pcall(function()
        eachPlaced(self.mapUI.mapAPI:getSymbolsAPIv2(), function(_, sym, r, g, b)
            placed[#placed + 1] = { sym = sym, r = r, g = g, b = b }
        end)
    end)
    self.counts, self.unlisted = ML.count(entries, placed)
    self.countedRevision = ML.revision
    self.countedFrames = 0
end

-- the key of the entry the map should outline: the row under the mouse, else
-- the one clicked
function MapLegendPanel:highlightEntry()
    local entries = self:entries()
    if self.hoverRow and entries[self.hoverRow] then return entries[self.hoverRow] end
    if self.pinned then
        local i = ML.find(entries, self.pinned.sym, self.pinned.r, self.pinned.g, self.pinned.b)
        if i then return entries[i] end
        self.pinned = nil
    end
    return nil
end

-- Called from the map's prerender, where the symbols panel draws its own
-- outlines, so these sit on the map the same way.
function MapLegendPanel:renderHighlights()
    if not self:isVisible() then return end
    local e = self:highlightEntry()
    if not e then return end
    local mapAPI = self.mapUI.mapAPI
    if not mapAPI:getBoolean("Symbols") then return end
    eachPlaced(mapAPI:getSymbolsAPIv2(), function(s, sym, r, g, b)
        if sym == e.sym and ML.sameColor(e.r, e.g, e.b, r, g, b) and s:isVisible() then
            s:renderOutline(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 1.0, 2.0)
        end
    end)
end

-- room left above the bottom edge: the joypad prompts sit in the bottom-left
function MapLegendPanel:bottomMargin()
    if self.mapUI.joyfocus then
        local prompt = math.max(32, FONT_HGT_LARGE)
        return 16 + (prompt + 8) * 3
    end
    return PAD
end

function MapLegendPanel:headerHeight()
    return PAD + math.max(FONT_HGT_MEDIUM, BUTTON_HGT) + PAD
end

-- how many rows fit in the top 60% of the map, under the header
function MapLegendPanel:maxRows()
    local room = self.mapUI.height * 0.6 - self:headerHeight() - PAD
    return math.max(1, math.floor(room / ROW_HGT))
end

function MapLegendPanel:layout(entries, collapsed)
    local tm = getTextManager()
    local title = getText("IGUI_ML_Title")
    local width = PAD + tm:MeasureStringX(UIFont.Medium, title) + PAD * 2 + self.editBtn.width + PAD / 2 + self.foldBtn.width + PAD
    local rows = 0
    if not collapsed then
        rows = math.min(#entries, self:maxRows())
        for i = 1, rows do
            local e = entries[i]
            local countText = self.counts and self.counts[i] and ("x" .. self.counts[i]) or ""
            local w = PAD + ICON + PAD + tm:MeasureStringX(UIFont.Small, e.text) + PAD + tm:MeasureStringX(UIFont.Small, countText) + PAD
            width = math.max(width, w)
        end
        local note = self:note()
        if note then width = math.max(width, PAD + tm:MeasureStringX(UIFont.Small, note) + PAD) end
    end
    width = math.max(MIN_WIDTH, math.min(width, self.mapUI.width * 0.4))
    local height = self:headerHeight()
    if not collapsed then
        local extra = 0
        if #entries == 0 or #entries > rows then extra = FONT_HGT_SMALL + 4 end
        if self.unlisted and self.unlisted > 0 then extra = extra + FONT_HGT_SMALL + 4 end
        if self:note() then extra = extra + FONT_HGT_SMALL + 4 end
        height = height + rows * ROW_HGT + extra + PAD / 2
    end
    self.rows = rows
    self:setWidth(width)
    self:setHeight(height)
    self:setX(PAD)
    self:setY(self.mapUI.height - height - self:bottomMargin())
    self.foldBtn:setX(width - PAD - self.foldBtn.width)
    self.editBtn:setX(self.foldBtn.x - PAD / 2 - self.editBtn.width)
end

function MapLegendPanel:rowAt(y)
    local top = self:headerHeight()
    if y < top then return nil end
    local i = math.floor((y - top) / ROW_HGT) + 1
    if i >= 1 and i <= (self.rows or 0) then return i end
    return nil
end

function MapLegendPanel:prerender()
    local entries = self:entries()
    local collapsed = ML.profile().collapsed
    self.countedFrames = (self.countedFrames or RECOUNT_FRAMES) + 1
    if self.countedRevision ~= ML.revision or self.countedFrames >= RECOUNT_FRAMES or not self.counts or #self.counts ~= #entries then
        self:recount(entries)
    end
    self:layout(entries, collapsed)
    self.foldBtn:setTitle(collapsed and "+" or "-")
    self.hoverRow = nil
    if not collapsed and self:isMouseOver() then self.hoverRow = self:rowAt(self:getMouseY()) end
    ISPanel.prerender(self)
    self:drawText(getText("IGUI_ML_Title"), PAD, PAD + (BUTTON_HGT - FONT_HGT_MEDIUM) / 2, 1, 1, 1, 1, UIFont.Medium)
end

function MapLegendPanel:render()
    ISPanel.render(self)
    if ML.profile().collapsed then return end
    local entries = self:entries()
    local tm = getTextManager()
    local pinned = self.pinned
    local y = self:headerHeight()
    for i = 1, self.rows or 0 do
        local e = entries[i]
        local isPinned = pinned and pinned.sym == e.sym and ML.sameColor(pinned.r, pinned.g, pinned.b, e.r, e.g, e.b)
        if i == self.hoverRow or isPinned then
            self:drawRect(PAD / 2, y, self.width - PAD, ROW_HGT, isPinned and 0.25 or 0.15, HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b)
        end
        -- a pale tile behind the icon, as the symbols panel's buttons have, so a black pen shows
        self:drawRect(PAD, y + 2, ICON, ICON, 1, 0.5, 0.5, 0.5)
        local tex = ML.texture(e.sym)
        if tex then self:drawTextureScaledAspect(tex, PAD + 1, y + 3, ICON - 2, ICON - 2, 1, e.r, e.g, e.b) end
        local textY = y + (ROW_HGT - FONT_HGT_SMALL) / 2
        local countText = "x" .. ((self.counts and self.counts[i]) or 0)
        local countW = tm:MeasureStringX(UIFont.Small, countText)
        local textX = PAD + ICON + PAD
        local room = self.width - textX - countW - PAD * 2
        local text = e.text
        if tm:MeasureStringX(UIFont.Small, text) > room then
            while #text > 1 and tm:MeasureStringX(UIFont.Small, text .. "...") > room do
                text = string.sub(text, 1, #text - 1)
            end
            text = text .. "..."
        end
        self:drawText(text, textX, textY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(countText, self.width - PAD - countW, textY, 0.6, 0.6, 0.6, 1, UIFont.Small)
        y = y + ROW_HGT
    end
    if #entries == 0 then
        self:drawText(getText("IGUI_ML_Empty"), PAD, y + 2, 0.6, 0.6, 0.6, 1, UIFont.Small)
        y = y + FONT_HGT_SMALL + 4
    elseif #entries > (self.rows or 0) then
        self:drawText(getText("IGUI_ML_More", #entries - self.rows), PAD, y + 2, 0.6, 0.6, 0.6, 1, UIFont.Small)
        y = y + FONT_HGT_SMALL + 4
    end
    if self.unlisted and self.unlisted > 0 then
        self:drawText(getText("IGUI_ML_Unlisted", self.unlisted), PAD, y + 2, 0.6, 0.6, 0.6, 1, UIFont.Small)
        y = y + FONT_HGT_SMALL + 4
    end
    local note = self:note()
    if note then
        self:drawText(note, PAD, y + 2, HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 1, UIFont.Small)
    end
end

-- a line for a few seconds under the rows: how to draw, or which pen is missing
function MapLegendPanel:say(key, arg)
    self.noteText = key and getText(key, arg) or nil
    self.noteTime = getTimestampMs()
end

function MapLegendPanel:note()
    if self.noteText and getTimestampMs() - (self.noteTime or 0) < NOTE_MS then return self.noteText end
    return nil
end

-- A click on a row picks its symbol and pen to draw with and pins its
-- outline. Again while that pen is still in hand puts it down and unpins; a
-- pinned row that cannot be drawn (no pen) unpins. The panel takes the click
-- either way, so the map underneath does not start a drag.
function MapLegendPanel:onMouseDown(x, y)
    local i = not ML.profile().collapsed and self:rowAt(y)
    if i then
        local e = self:entries()[i]
        local p = self.pinned
        local same = p and p.sym == e.sym and ML.sameColor(p.r, p.g, p.b, e.r, e.g, e.b)
        if same and self:isArmed(e) then
            self:disarm()
            self.pinned = nil
            self:say(nil)
            return true
        end
        local key, arg = self:arm(e)
        if key and same then
            self.pinned = nil
        else
            self.pinned = { sym = e.sym, r = e.r, g = e.g, b = e.b }
        end
        self:say(key or "IGUI_ML_Armed", arg)
    end
    return true
end

function MapLegendPanel:onMouseUp(x, y)
    return true
end

function MapLegendPanel:onMouseWheel(del)
    return false
end

function MapLegendPanel:new(mapUI)
    local o = ISPanel.new(self, PAD, 0, MIN_WIDTH, 50)
    o.mapUI = mapUI
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = false
    o.anchorBottom = false
    return o
end

-- the symbols panel -----------------------------------------------------------------------

-- picking a symbol the legend has: switch to the legend's pen for it
local function matchColor(symbolsUI, sym, click)
    local entries = ML.entriesFor(symbolsUI.character)
    local cur = symbolsUI.currentColor
    local current = cur and { r = cur:getR(), g = cur:getG(), b = cur:getB() } or nil
    local i = ML.pickColor(entries, sym, current, panelColors(symbolsUI))
    if i then click(symbolsUI, symbolsUI.colorButtons[i]) end
end

-- each symbol button says what it means, a line per colour
local function setTooltips(symbolsUI)
    local entries = ML.entriesFor(symbolsUI.character)
    local colors = panelColors(symbolsUI)
    for _, btn in ipairs(symbolsUI.buttonList or {}) do
        -- vanilla's checkInventory has just set every symbol button's
        -- tooltip: nil when the character can write, else why not, and
        -- that reason stays
        if btn.symbol and btn.tooltip == nil then
            local lines = {}
            for _, e in ipairs(ML.forSymbol(entries, btn.tex)) do
                local pen = ML.colorName(e, colors)
                lines[#lines + 1] = pen ~= "" and (pen .. ": " .. e.text) or e.text
            end
            if #lines > 0 then btn.tooltip = table.concat(lines, " <LINE> ") end
        end
    end
end

local vanillaClick = ISWorldMapSymbols.onButtonClick
function ISWorldMapSymbols:onButtonClick(button)
    vanillaClick(self, button)
    if button and button.symbol and self.selectedSymbol == button then
        local ok, err = pcall(matchColor, self, button.tex, vanillaClick)
        if not ok then print("[MapLegend] " .. tostring(err)) end
    end
end

-- The legend row clicked: the symbols panel's place tool with that symbol
-- and pen, as if both were clicked in the panel. Returns nothing when it is
-- ready to draw, else why not (a translation key and its argument).
function MapLegendPanel:arm(e)
    local ui = self.mapUI.symbolsUI
    if not ui or not ui.tools then return "IGUI_ML_NoSymbol" end
    local symBtn
    for _, b in ipairs(ui.buttonList or {}) do
        if b.symbol and b.tex == e.sym then symBtn = b end
    end
    -- a symbol from a mod that is no longer loaded
    if not symBtn then return "IGUI_ML_NoSymbol" end
    -- vanilla turns every symbol off when the character carries nothing to write with
    if not symBtn.enable then return "IGUI_ML_NeedPen" end
    local penBtn
    for _, b in ipairs(ui.colorButtons or {}) do
        local c = b.buttonInfo.colorInfo
        if ML.sameColor(e.r, e.g, e.b, c:getR(), c:getG(), c:getB()) then penBtn = b end
    end
    if not penBtn or not penBtn.enable then
        local pen = ML.colorName(e, panelColors(ui))
        if pen == "" then return "IGUI_ML_NeedPen" end
        return "IGUI_ML_NeedThisPen", pen
    end
    vanillaClick(ui, penBtn)
    -- a second click on the picked symbol would put it down
    if ui.selectedSymbol ~= symBtn then vanillaClick(ui, symBtn) end
    -- the panel shows the symbol's tab, so its picked border is in view
    pcall(function() ui.panel:activateView(getText("IGUI_Map_Tab" .. symBtn.tab)) end)
    return nil
end

-- the place tool is out with this entry's symbol and pen
function MapLegendPanel:isArmed(e)
    local ui = self.mapUI.symbolsUI
    if not ui or not ui.tools or ui.currentTool ~= ui.tools.AddSymbol then return false end
    local sel, c = ui.selectedSymbol, ui.currentColor
    return sel ~= nil and sel.tex == e.sym and c ~= nil and ML.sameColor(e.r, e.g, e.b, c:getR(), c:getG(), c:getB())
end

function MapLegendPanel:disarm()
    local ui = self.mapUI.symbolsUI
    ui:setCurrentTool(nil)
    ui.selectedSymbol = nil
end

local vanillaCheckInventory = ISWorldMapSymbols.checkInventory
function ISWorldMapSymbols:checkInventory()
    vanillaCheckInventory(self)
    local ok, err = pcall(setTooltips, self)
    if not ok then print("[MapLegend] " .. tostring(err)) end
end

-- the world map ---------------------------------------------------------------------------

local vanillaCreateChildren = ISWorldMap.createChildren
function ISWorldMap:createChildren()
    vanillaCreateChildren(self)
    local ok, err = pcall(function()
        self.legendUI = MapLegendPanel:new(self)
        self.legendUI:initialise()
        self:addChild(self.legendUI)
    end)
    if not ok then print("[MapLegend] " .. tostring(err)) end
end

local vanillaPrerender = ISWorldMap.prerender
function ISWorldMap:prerender()
    vanillaPrerender(self)
    if self.legendUI then
        local ok, err = pcall(self.legendUI.renderHighlights, self.legendUI)
        if not ok and not self.legendUI.reported then
            self.legendUI.reported = true
            print("[MapLegend] " .. tostring(err))
        end
    end
end

-- an edit in the editor: the tooltips in an open symbols panel follow
ML.onChanged = function()
    local map = ISWorldMap_instance
    if map and map.symbolsUI then map.symbolsUI:checkInventory() end
    if MapLegendEditor and MapLegendEditor.refreshAll then MapLegendEditor.refreshAll() end
end
