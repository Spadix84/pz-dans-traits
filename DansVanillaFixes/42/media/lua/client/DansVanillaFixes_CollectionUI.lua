-- Dan's Vanilla Fixes: the Collection window (the lists and the rules are in
-- shared/DansVanillaFixes_Collection.lua; the sidebar button that opens it is
-- in client/DansVanillaFixes_CollectionClient.lua).
--
-- One tab per kind: Skill Books (a row per skill, a box per volume),
-- Magazines, one per recorded media kind (VHS, Home VHS, CD), Key Rings,
-- Mementos and Tools. Click a row (or a volume's box) to tick it. A search
-- box and a Hide collected tick sit above the tabs, with the active tab's
-- count.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTabPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"
require "DansVanillaFixes_Collection"

local C = DVF_Collection

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local ROW_HGT = math.max(FONT_HGT_SMALL + 8, 26)
local BOX = FONT_HGT_SMALL + 2
local PAD = 6
local ICON = 20
local VOLUMES = 5
local VOL_GAP = 10

DVF_CollectionList = ISScrollingListBox:derive("DVF_CollectionList")
DVF_CollectionWindow = ISCollapsableWindow:derive("DVF_CollectionWindow")
DVF_CollectionWindow.instances = {}
DVF_CollectionWindow.last = {}   -- where each player last closed it, for this session

-- the list ----------------------------------------------------------------------

local function tickTexture()
    return getTexture("media/ui/inventoryPanes/Tickbox_Tick.png")
end

function DVF_CollectionList:drawBox(x, y, ticked)
    self:drawRect(x, y, BOX, BOX, 1.0, 0.3, 0.3, 0.3)
    self:drawRectBorder(x, y, BOX, BOX, 1.0, 0.6, 0.6, 0.6)
    if ticked then
        local c = getCore():getGoodHighlitedColor()
        self:drawTextureScaled(tickTexture(), x + 2, y + 2, BOX - 4, BOX - 4, 1, c:getR(), c:getG(), c:getB())
    end
end

-- where volume v's box starts on a skill row: right-aligned, each box with
-- its number in front, clear of the scrollbar
function DVF_CollectionList:volumeX(v)
    local numW = getTextManager():MeasureStringX(UIFont.Small, "5")
    local slot = numW + 3 + BOX + VOL_GAP
    return self.width - 20 - (VOLUMES - v + 1) * slot + numW + 3 + VOL_GAP
end

function DVF_CollectionList:drawIcon(script, x, y)
    local tex
    pcall(function() tex = script and script:getNormalTexture() end)
    if tex then self:drawTextureScaledAspect(tex, x, y + (ROW_HGT - ICON) / 2, ICON, ICON, 1, 1, 1, 1) end
end

function DVF_CollectionList:doDrawItem(y, item, alt)
    if y + self:getYScroll() >= self.height then return y + item.height end
    if y + item.height + self:getYScroll() <= 0 then return y + item.height end
    local row = item.item
    local player = self.character
    local boxY = y + (ROW_HGT - BOX) / 2
    local textY = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self:isMouseOver() and self.mouseoverselected == item.index then
        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 2, 0.08, 1, 1, 1)
    end
    if row.books then
        local owned = 0
        for _, e in ipairs(row.books) do if C.has(player, e) then owned = owned + 1 end end
        self:drawIcon(row.books[1] and row.books[1].script, PAD, y)
        local done = owned == #row.books
        local shade = done and 1.0 or 0.75
        self:drawText(row.label, PAD + ICON + PAD, textY, shade, shade, shade, 1, UIFont.Small)
        for v, e in ipairs(row.books) do
            if v > VOLUMES then break end
            local x = self:volumeX(v)
            local numW = getTextManager():MeasureStringX(UIFont.Small, tostring(v))
            self:drawText(tostring(v), x - numW - 3, textY, 0.7, 0.7, 0.7, 1, UIFont.Small)
            self:drawBox(x, boxY, C.has(player, e))
        end
    else
        local have = C.has(player, row)
        self:drawBox(PAD, boxY, have)
        self:drawIcon(row.script, PAD + BOX + PAD, y)
        local shade = have and 1.0 or 0.75
        self:drawText(row.name, PAD + BOX + PAD + ICON + PAD, textY, shade, shade, shade, 1, UIFont.Small)
    end
    return y + item.height
end

function DVF_CollectionList:onMouseDown(x, y)
    if #self.items == 0 then return end
    local index = self:rowAt(x, y)
    if index < 1 or index > #self.items then return end
    local row = self.items[index].item
    local player = self.character
    local entry
    if row.books then
        for v, e in ipairs(row.books) do
            local bx = self:volumeX(v)
            if v <= VOLUMES and x >= bx - 14 and x <= bx + BOX + 2 then entry = e end
        end
    else
        entry = row
    end
    if not entry then return end
    getSoundManager():playUISound("UISelectListItem")
    C.set(player, entry, not C.has(player, entry))
    if self.window then self.window:changed() end
end

function DVF_CollectionList:new(x, y, width, height, character, window)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.character = character
    o.window = window
    o.itemheight = ROW_HGT
    o.drawBorder = true
    return o
end

-- the window --------------------------------------------------------------------

function DVF_CollectionWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local barH = FONT_HGT_SMALL + 6

    self.filterBox = ISTextEntryBox:new("", PAD, th + PAD, math.floor(self.width * 0.45), barH)
    self.filterBox:initialise()
    self.filterBox:instantiate()
    self.filterBox.font = UIFont.Small
    self.filterBox:setPlaceholderText(getText("IGUI_FilterSearch"))
    self.filterBox.onTextChangeFunction = DVF_CollectionWindow.fill
    self.filterBox.target = self
    self:addChild(self.filterBox)

    self.hideBox = ISTickBox:new(self.filterBox:getRight() + PAD * 2, th + PAD, BOX, barH, "", self,
        DVF_CollectionWindow.onHide)
    self.hideBox:initialise()
    self.hideBox:instantiate()
    self.hideBox:addOption(getText("IGUI_DVF_Collection_HideOwned"))
    self.hideBox:setWidthToFit()
    self:addChild(self.hideBox)

    local top = self.filterBox:getBottom() + PAD
    self.tabs = ISTabPanel:new(0, top, self.width, self.height - top - rh)
    self.tabs:setAnchorRight(true)
    self.tabs:setAnchorBottom(true)
    self.tabs:setEqualTabWidth(false)
    self:addChild(self.tabs)

    self.lists = {}
    for _, tab in ipairs(C.lists()) do
        local list = DVF_CollectionList:new(0, 0, self.tabs.width, self.tabs.height - self.tabs.tabHeight, self.character, self)
        list:setAnchorRight(true)
        list:setAnchorBottom(true)
        list:setFont(UIFont.Small, 3)
        list.tab = tab
        self.tabs:addView(tab.title, list)
        self.lists[#self.lists + 1] = list
    end

    self.resizeWidget2:bringToTop()
    self.resizeWidget:bringToTop()
    self:fill()
end

function DVF_CollectionWindow:onHide(index, selected)
    self.hideOwned = selected
    self:fill()
end

-- a row is shown when it matches the search and, with Hide collected on,
-- is not fully collected
function DVF_CollectionWindow:shows(row, filter)
    if filter ~= "" then
        local hit = string.find(row.name:lower(), filter, 1, true) ~= nil
        if row.books and not hit then
            for _, e in ipairs(row.books) do
                if string.find(e.name:lower(), filter, 1, true) then hit = true end
            end
        end
        if not hit then return false end
    end
    if self.hideOwned then
        if row.books then
            for _, e in ipairs(row.books) do if not C.has(self.character, e) then return true end end
            return false
        end
        return not C.has(self.character, row)
    end
    return true
end

function DVF_CollectionWindow:fill()
    local filter = string.lower(self.filterBox:getInternalText() or "")
    for _, list in ipairs(self.lists) do
        local scroll = list:getYScroll()
        list:clear()
        for _, row in ipairs(list.tab.rows) do
            if self:shows(row, filter) then list:addItem(row.name, row) end
        end
        list:setYScroll(scroll)
    end
end

-- a tick changed: only Hide collected makes the rows themselves change
function DVF_CollectionWindow:changed()
    if self.hideOwned then self:fill() end
end

function DVF_CollectionWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local list = self.tabs and self.tabs:getActiveView()
    if not list or not list.tab then return end
    local text = getText("IGUI_DVF_Collection_Count", C.count(self.character, list.tab), list.tab.total)
    local w = getTextManager():MeasureStringX(UIFont.Small, text)
    self:drawText(text, self.width - w - PAD * 2, self.filterBox:getY() + 3, 1, 1, 1, 1, UIFont.Small)
end

function DVF_CollectionWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.character:isDead() then self:close() end
end

function DVF_CollectionWindow:close()
    DVF_CollectionWindow.last[self.playerNum] = { x = self:getX(), y = self:getY(), w = self:getWidth(), h = self:getHeight() }
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    DVF_CollectionWindow.instances[self.playerNum] = nil
end

function DVF_CollectionWindow:new(x, y, width, height, character)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("IGUI_DVF_Collection_Title"))
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.minimumWidth = 360
    o.minimumHeight = 300
    o.hideOwned = false
    return o
end

function DVF_CollectionWindow.isOpen(playerNum)
    local w = DVF_CollectionWindow.instances[playerNum]
    return w ~= nil and w:isVisible()
end

function DVF_CollectionWindow.toggle(character)
    local playerNum = character:getPlayerNum()
    local open = DVF_CollectionWindow.instances[playerNum]
    if open then
        open:close()
        return
    end
    local at = DVF_CollectionWindow.last[playerNum] or {
        x = getPlayerScreenLeft(playerNum) + 120, y = getPlayerScreenTop(playerNum) + 50,
        w = 560, h = math.min(700, getPlayerScreenHeight(playerNum) - 100) }
    local win = DVF_CollectionWindow:new(at.x, at.y, at.w, at.h, character)
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    DVF_CollectionWindow.instances[playerNum] = win
end
