-- Map Legend: the editor, opened from the legend's Edit button.
--
-- At the top, whose legend is being edited: the profile (every character
-- without its own) or, with "This character keeps its own legend" ticked,
-- the character's own, which can be copied over the profile. Then the
-- entries, which can be reordered and removed, and the form for one entry:
-- the symbol (the vanilla symbols, in the vanilla tabs), the pen colour, and
-- what it means, typed or picked from the presets. Clicking an entry loads it
-- into the form to change it.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISModalDialog"
require "MapLegend_Core"

local ML = MapLegend

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local PAD = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local BOX = FONT_HGT_SMALL + 2
local ICON = math.max(BUTTON_HGT, 20)
local ROW_HGT = ICON + 6
local CELL = ICON + 6
local LIST_ROWS = 6
local WIDTH = 460

MapLegendEntryList = ISScrollingListBox:derive("MapLegendEntryList")
MapLegendSymbolGrid = ISPanel:derive("MapLegendSymbolGrid")
MapLegendEditor = ISCollapsableWindow:derive("MapLegendEditor")
MapLegendEditor.instances = {}

-- the symbols, by tab, in MapSymbolDefinitions order ---------------------------------------

local function symbolTabs()
    local tabs, byTab = {}, {}
    pcall(function()
        local defs = MapSymbolDefinitions.getInstance()
        for i = 0, defs:getSymbolCount() - 1 do
            local def = defs:getSymbolByIndex(i)
            local tab = def:getTab()
            if not byTab[tab] then
                byTab[tab] = {}
                tabs[#tabs + 1] = tab
            end
            local list = byTab[tab]
            list[#list + 1] = def:getId()
        end
    end)
    return tabs, byTab
end

local function tabTitle(tab)
    local text = getTextOrNull("IGUI_Map_Tab" .. tostring(tab))
    return text or tostring(tab)
end

-- the entry list --------------------------------------------------------------------------

function MapLegendEntryList:doDrawItem(y, item, alt)
    if y + self:getYScroll() >= self.height then return y + item.height end
    if y + item.height + self:getYScroll() <= 0 then return y + item.height end
    local e = item.item
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height, 0.3, 0.7, 0.35, 0.15)
    elseif self:isMouseOver() and self.mouseoverselected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height, 0.1, 1, 1, 1)
    end
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawRect(PAD / 2, y + 3, ICON, ICON, 1, 0.5, 0.5, 0.5)
    local tex = ML.texture(e.sym)
    if tex then self:drawTextureScaledAspect(tex, PAD / 2 + 1, y + 4, ICON - 2, ICON - 2, 1, e.r, e.g, e.b) end
    self:drawText(e.text, PAD / 2 + ICON + PAD, y + (item.height - FONT_HGT_SMALL) / 2, 1, 1, 1, 1, UIFont.Small)
    return y + item.height
end

-- the symbol grid -------------------------------------------------------------------------

function MapLegendSymbolGrid:columns()
    return math.max(1, math.floor((self.width - 2) / CELL))
end

function MapLegendSymbolGrid:render()
    ISPanel.render(self)
    local win = self.window
    local list = win.byTab[win.tab] or {}
    local cols = self:columns()
    local c = win.color
    for i, sym in ipairs(list) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = 1 + col * CELL + 2, 1 + row * CELL + 2
        local hover = self:isMouseOver() and self.hoverIndex == i
        local shade = hover and 0.65 or 0.5
        self:drawRect(x, y, ICON, ICON, 1, shade, shade, shade)
        local tex = ML.texture(sym)
        if tex then self:drawTextureScaledAspect(tex, x + 1, y + 1, ICON - 2, ICON - 2, 1, c.r, c.g, c.b) end
        if sym == win.sym then
            self:drawRectBorder(x - 2, y - 2, ICON + 4, ICON + 4, 1, 1, 1, 1)
        end
    end
end

function MapLegendSymbolGrid:indexAt(x, y)
    local cols = self:columns()
    local col, row = math.floor((x - 1) / CELL), math.floor((y - 1) / CELL)
    if col < 0 or col >= cols or row < 0 then return nil end
    local i = row * cols + col + 1
    local list = self.window.byTab[self.window.tab] or {}
    if list[i] then return i end
    return nil
end

function MapLegendSymbolGrid:prerender()
    ISPanel.prerender(self)
    self.hoverIndex = self:isMouseOver() and self:indexAt(self:getMouseX(), self:getMouseY()) or nil
end

function MapLegendSymbolGrid:onMouseDown(x, y)
    local i = self:indexAt(x, y)
    if i then self.window:pickSymbol(self.window.byTab[self.window.tab][i]) end
    return true
end

function MapLegendSymbolGrid:new(x, y, w, h, window)
    local o = ISPanel.new(self, x, y, w, h)
    o.window = window
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.4 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end

-- the window ------------------------------------------------------------------------------

local function newButton(win, x, y, title, onClick, w)
    local btn = ISButton:new(x, y, w or 10, BUTTON_HGT, title, win, onClick)
    btn:initialise()
    btn:instantiate()
    if not w then btn:setWidthToTitle(60) end
    win:addChild(btn)
    return btn
end

function MapLegendEditor:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local inner = self.width - PAD * 2
    local y = th + PAD

    -- whose legend
    self.ownBox = ISTickBox:new(PAD, y, BOX, BUTTON_HGT, "", self, MapLegendEditor.onOwn)
    self.ownBox:initialise()
    self.ownBox:instantiate()
    self.ownBox:addOption(getText("IGUI_ML_OwnLegend"))
    self.ownBox:setWidthToFit()
    self:addChild(self.ownBox)
    self.toProfileBtn = newButton(self, 0, y, getText("IGUI_ML_CopyToProfile"), MapLegendEditor.onCopyToProfile)
    self.toProfileBtn:setX(self.width - PAD - self.toProfileBtn.width)
    self.toProfileBtn.tooltip = getText("IGUI_ML_CopyToProfile_tt")
    y = y + BUTTON_HGT + 4
    self.whoseY = y
    y = y + FONT_HGT_SMALL + PAD

    -- the entries
    self.list = MapLegendEntryList:new(PAD, y, inner, ROW_HGT * LIST_ROWS)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list:setFont(UIFont.Small, 3)
    self.list:setOnMouseDownFunction(self, MapLegendEditor.onPickRow)
    self:addChild(self.list)
    y = self.list:getBottom() + 4

    local x = PAD
    self.upBtn = newButton(self, x, y, getText("IGUI_ML_Up"), MapLegendEditor.onUp)
    x = self.upBtn:getRight() + 4
    self.downBtn = newButton(self, x, y, getText("IGUI_ML_Down"), MapLegendEditor.onDown)
    x = self.downBtn:getRight() + 4
    self.removeBtn = newButton(self, x, y, getText("IGUI_ML_Remove"), MapLegendEditor.onRemove)
    self.newBtn = newButton(self, 0, y, getText("IGUI_ML_New"), MapLegendEditor.onNew)
    self.newBtn:setX(self.width - PAD - self.newBtn.width)
    y = y + BUTTON_HGT + PAD * 2

    -- the form: symbol
    self.symbolLabelY = y
    y = y + FONT_HGT_SMALL + 4
    self.tabButtons = {}
    x = PAD
    for _, tab in ipairs(self.tabs) do
        local btn = newButton(self, x, y, tabTitle(tab), MapLegendEditor.onTab)
        if btn:getRight() > self.width - PAD and x > PAD then
            x = PAD
            y = y + BUTTON_HGT + 4
            btn:setX(x)
            btn:setY(y)
        end
        btn.tab = tab
        self.tabButtons[#self.tabButtons + 1] = btn
        x = btn:getRight() + 4
    end
    y = y + BUTTON_HGT + 4
    local cols = math.max(1, math.floor((inner - 2) / CELL))
    local most = 1
    for _, list in pairs(self.byTab) do most = math.max(most, #list) end
    local gridH = math.ceil(most / cols) * CELL + 4
    self.grid = MapLegendSymbolGrid:new(PAD, y, inner, gridH, self)
    self.grid:initialise()
    self:addChild(self.grid)
    y = self.grid:getBottom() + PAD

    -- colour
    self.colorLabelY = y
    y = y + FONT_HGT_SMALL + 4
    self.colorButtons = {}
    x = PAD
    for _, c in ipairs(self.colors) do
        local btn = ISButton:new(x, y, BUTTON_HGT * 2, BUTTON_HGT, "", self, MapLegendEditor.onColor)
        btn:initialise()
        btn:instantiate()
        btn.backgroundColor = { r = c.r, g = c.g, b = c.b, a = 1 }
        btn.backgroundColorMouseOver = { r = c.r, g = c.g, b = c.b, a = 1 }
        btn.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
        btn.color = c
        btn.tooltip = c.item and ML.colorName(c, self.colors) or nil
        self:addChild(btn)
        self.colorButtons[#self.colorButtons + 1] = btn
        x = btn:getRight() + 6
        if x + BUTTON_HGT * 2 > self.width - PAD then
            x = PAD
            y = y + BUTTON_HGT + 4
        end
    end
    if x > PAD then y = y + BUTTON_HGT end
    y = y + PAD

    -- meaning
    self.textLabelY = y
    y = y + FONT_HGT_SMALL + 4
    local comboW = math.floor(inner * 0.4)
    self.presets = ISComboBox:new(PAD, y, comboW, BUTTON_HGT, self, MapLegendEditor.onPreset)
    self.presets:initialise()
    self:addChild(self.presets)
    self.presets:addOption(getText("IGUI_ML_Presets"))
    for _, name in ipairs(ML.PRESETS) do self.presets:addOption(ML.presetText(name)) end
    self.presets.selected = 1
    self.textBox = ISTextEntryBox:new("", PAD + comboW + 6, y, inner - comboW - 6, BUTTON_HGT)
    self.textBox:initialise()
    self.textBox:instantiate()
    self.textBox.font = UIFont.Small
    self.textBox:setPlaceholderText(getText("IGUI_ML_TextHint"))
    self.textBox:setMaxTextLength(ML.MAX_TEXT)
    self:addChild(self.textBox)
    y = y + BUTTON_HGT + PAD

    self.saveBtn = newButton(self, PAD, y, getText("IGUI_ML_Add"), MapLegendEditor.onSave, math.floor(inner / 2) - 3)
    self.closeBtn = newButton(self, PAD + math.floor(inner / 2) + 3, y, getText("UI_btn_close"), MapLegendEditor.close, math.floor(inner / 2) - 3)
    y = y + BUTTON_HGT + 4
    self.statusY = y
    y = y + FONT_HGT_SMALL + PAD

    self:setHeight(y)
    self:refresh()
end

function MapLegendEditor:entries()
    return ML.entriesFor(self.character)
end

-- the list and the buttons that depend on the selection and the mode
function MapLegendEditor:refresh()
    local entries, own = self:entries()
    self.ownBox:setSelected(1, own)
    self.toProfileBtn:setVisible(own)
    self.list:clear()
    for _, e in ipairs(entries) do self.list:addItem(e.text, e) end
    if self.editing and not entries[self.editing] then self.editing = nil end
    self.list.selected = self.editing or 0
    local sel = self.editing
    self.upBtn.enable = sel ~= nil and sel > 1
    self.downBtn.enable = sel ~= nil and sel < #entries
    self.removeBtn.enable = sel ~= nil
    self.saveBtn:setTitle(getText(sel and "IGUI_ML_Save" or "IGUI_ML_Add"))
    for _, btn in ipairs(self.tabButtons) do
        btn.borderColor = { r = 1, g = 1, b = 1, a = btn.tab == self.tab and 1 or 0.4 }
    end
    for _, btn in ipairs(self.colorButtons) do
        local c = btn.color
        btn.borderColor = { r = 1, g = 1, b = 1, a = ML.sameColor(c.r, c.g, c.b, self.color.r, self.color.g, self.color.b) and 1 or 0.4 }
    end
end

-- another window or the panel changed the legend
function MapLegendEditor.refreshAll()
    for _, win in pairs(MapLegendEditor.instances) do
        if win and win:isVisible() then win:refresh() end
    end
end

function MapLegendEditor:status(key, ...)
    self.statusText = key and getText(key, ...) or nil
    self.statusTime = getTimestampMs()
end

function MapLegendEditor:onOwn(index, selected)
    ML.setOwn(self.character, selected)
    self.editing = nil
    self:status(selected and "IGUI_ML_NowOwn" or "IGUI_ML_NowProfile")
    self:refresh()
end

function MapLegendEditor:onCopyToProfile()
    local text = getText("IGUI_ML_CopyToProfile_Confirm")
    local w = 380
    local modal = ISModalDialog:new(self:getAbsoluteX() + (self.width - w) / 2, self:getAbsoluteY() + 60, w, 150, text, true, self,
        MapLegendEditor.onCopyConfirmed, self.playerNum)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
end

function MapLegendEditor:onCopyConfirmed(button)
    if button.internal ~= "YES" then return end
    ML.copyToProfile(self.character)
    self:status("IGUI_ML_Copied")
end

function MapLegendEditor:onPickRow(e)
    local entries = self:entries()
    for i, other in ipairs(entries) do
        if other == e then self.editing = i end
    end
    self.sym = e.sym
    self.color = { r = e.r, g = e.g, b = e.b }
    self.textBox:setText(e.text)
    for _, tab in ipairs(self.tabs) do
        for _, sym in ipairs(self.byTab[tab]) do
            if sym == e.sym then self.tab = tab end
        end
    end
    self:status(nil)
    self:refresh()
end

function MapLegendEditor:onUp()
    if not self.editing then return end
    self.editing = ML.move(self:entries(), self.editing, -1)
    ML.changed(self.character)
end

function MapLegendEditor:onDown()
    if not self.editing then return end
    self.editing = ML.move(self:entries(), self.editing, 1)
    ML.changed(self.character)
end

function MapLegendEditor:onRemove()
    if not self.editing then return end
    ML.remove(self:entries(), self.editing)
    self.editing = nil
    self:status("IGUI_ML_Removed")
    ML.changed(self.character)
end

-- a fresh entry: the symbol and colour stay picked, the text clears
function MapLegendEditor:onNew()
    self.editing = nil
    self.textBox:setText("")
    self:status(nil)
    self:refresh()
end

function MapLegendEditor:onTab(button)
    self.tab = button.tab
    self:refresh()
end

function MapLegendEditor:pickSymbol(sym)
    self.sym = sym
    self:refresh()
end

function MapLegendEditor:onColor(button)
    self.color = { r = button.color.r, g = button.color.g, b = button.color.b }
    self:refresh()
end

function MapLegendEditor:onPreset(combo)
    local i = combo.selected
    if i and i > 1 then self.textBox:setText(combo:getOptionText(i)) end
end

function MapLegendEditor:onSave()
    local text = ML.sanitize(self.textBox:getInternalText())
    if not self.sym then return self:status("IGUI_ML_NeedSymbol") end
    if text == "" then return self:status("IGUI_ML_NeedText") end
    local entries = self:entries()
    local had = #entries
    self.editing = ML.put(entries, self.sym, self.color.r, self.color.g, self.color.b, text, self.editing)
    self:status(#entries > had and "IGUI_ML_Added" or "IGUI_ML_Saved")
    ML.changed(self.character)
end

function MapLegendEditor:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local _, own = self:entries()
    local whose = own and getText("IGUI_ML_EditingOwn", self.character:getDisplayName() or "") or getText("IGUI_ML_EditingProfile")
    self:drawText(whose, PAD, self.whoseY, 0.75, 0.75, 0.75, 1, UIFont.Small)
    self:drawText(getText("IGUI_ML_Symbol"), PAD, self.symbolLabelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("IGUI_ML_Colour"), PAD, self.colorLabelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("IGUI_ML_Meaning"), PAD, self.textLabelY, 1, 1, 1, 1, UIFont.Small)
    if self.statusText and getTimestampMs() - (self.statusTime or 0) < 4000 then
        self:drawText(self.statusText, PAD, self.statusY, 0.8, 0.8, 0.5, 1, UIFont.Small)
    end
end

function MapLegendEditor:prerender()
    ISCollapsableWindow.prerender(self)
    if self.character:isDead() then self:close() end
end

function MapLegendEditor:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    MapLegendEditor.instances[self.playerNum] = nil
end

function MapLegendEditor:new(x, y, character)
    local o = ISCollapsableWindow.new(self, x, y, WIDTH, 400)
    o:setTitle(getText("IGUI_ML_EditorTitle"))
    o:setResizable(false)
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.tabs, o.byTab = symbolTabs()
    o.tab = o.tabs[1]
    o.colors = ML.colors()
    local first = o.colors[1] or ML.DEFAULT_COLORS[1]
    o.color = { r = first.r, g = first.g, b = first.b }
    return o
end

function MapLegendEditor.toggle(character)
    local playerNum = character:getPlayerNum()
    local open = MapLegendEditor.instances[playerNum]
    if open then
        open:close()
        return
    end
    local x = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - WIDTH) / 2
    local y = getPlayerScreenTop(playerNum) + 80
    local win = MapLegendEditor:new(x, y, character)
    win:initialise()
    win:addToUIManager()
    win:setAlwaysOnTop(true)
    MapLegendEditor.instances[playerNum] = win
end
