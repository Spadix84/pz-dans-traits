-- Base Unloader: the base inventory. Everything stored in the base zones
-- (containers, bags in them, the floor), one row per type per container:
-- name, category, how many, zone, container. Search in every field or in one,
-- sort by any column, Refresh to count again. A zone out of range keeps its
-- last count, marked with how old it is. Hover a row to light its container
-- up; double-click to walk to it.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "BaseUnloader_Scan"

local BU = BaseUnloader
local S = BU_Scan

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local PAD = 6
local ROW_HGT = math.max(FONT_HGT_SMALL + 6, 22)
local ICON = ROW_HGT - 4
local BAR_HGT = FONT_HGT_SMALL + 8

-- the columns: field, header key, share of the width (the count is fixed)
local COLUMNS = {
    { field = "name", label = "IGUI_BU_StockName", share = 0.34 },
    { field = "category", label = "IGUI_BU_StockCategory", share = 0.18 },
    { field = "count", label = "IGUI_BU_StockCount", fixed = 50 },
    { field = "zone", label = "IGUI_BU_StockZone", share = 0.18 },
    { field = "container", label = "IGUI_BU_StockContainer", share = 0.30 },
}
local SEARCH_FIELDS = { "all", "name", "category", "zone", "container" }

BU_StockList = ISScrollingListBox:derive("BU_StockList")
BU_StockWindow = ISCollapsableWindow:derive("BU_StockWindow")
BU_StockWindow.instances = {}

local iconCache = {}
local function iconOf(fullType)
    if iconCache[fullType] == nil then
        local tex = false
        pcall(function()
            local script = getScriptManager():FindItem(fullType)
            tex = script and script:getNormalTexture() or false
        end)
        iconCache[fullType] = tex
    end
    return iconCache[fullType] or nil
end

local function truncate(text, width)
    local tm = getTextManager()
    if tm:MeasureStringX(UIFont.Small, text) <= width then return text end
    while #text > 1 and tm:MeasureStringX(UIFont.Small, text .. "...") > width do text = text:sub(1, -2) end
    return text .. "..."
end

-- how old a count is, in words: hours under two days, else days
function BU_StockWindow.ageLabel(age)
    if not age or age < 1 then return nil end
    if age < 48 then return getText("IGUI_BU_StockAgeHours", math.floor(age)) end
    return getText("IGUI_BU_StockAgeDays", math.floor(age / 24))
end

-- the list ----------------------------------------------------------------------------------------

function BU_StockList:doDrawItem(y, item, alt)
    if y + self:getYScroll() >= self.height then return y + item.height end
    if y + item.height + self:getYScroll() <= 0 then return y + item.height end
    local row = item.item
    local win = self.window
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height, 0.3, 0.7, 0.35, 0.15)
    elseif self:isMouseOver() and self.mouseoverselected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height, 0.1, 1, 1, 1)
    elseif alt then
        self:drawRect(0, y, self:getWidth(), item.height, 0.06, 1, 1, 1)
    end
    local ty = y + (item.height - FONT_HGT_SMALL) / 2
    local shade = row.age and 0.6 or 0.95
    for _, col in ipairs(win.cols) do
        local text
        if col.field == "name" then
            local tex = iconOf(row.fullType)
            if tex then self:drawTextureScaledAspect(tex, col.x, y + 2, ICON, ICON, 1, 1, 1, 1) end
            text = truncate(row.name, col.w - ICON - 4)
            self:drawText(text, col.x + ICON + 4, ty, shade, shade, shade, 1, UIFont.Small)
        elseif col.field == "count" then
            text = "x" .. tostring(row.count)
            self:drawText(text, col.x, ty, shade, shade, shade, 1, UIFont.Small)
        elseif col.field == "category" then
            self:drawText(truncate(S.categoryLabel(row.category or ""), col.w - 4), col.x, ty, shade * 0.8, shade * 0.8, shade * 0.8, 1, UIFont.Small)
        elseif col.field == "container" then
            local age = BU_StockWindow.ageLabel(row.age)
            text = row.container or ""
            if age then text = text .. "  (" .. age .. ")" end
            self:drawText(truncate(text, col.w - 4), col.x, ty, shade, shade, shade, 1, UIFont.Small)
        else
            self:drawText(truncate(tostring(row[col.field] or ""), col.w - 4), col.x, ty, shade, shade, shade, 1, UIFont.Small)
        end
    end
    return y + item.height
end

function BU_StockList:rowUnderMouse()
    if not self:isMouseOver() then return nil end
    local index = self:rowAt(self:getMouseX(), self:getMouseY())
    if index < 1 or index > #self.items then return nil end
    return self.items[index].item
end

-- light up the container under the mouse, when it is in range
function BU_StockList:prerender()
    ISScrollingListBox.prerender(self)
    local row = self:rowUnderMouse()
    local key = row and not row.age and row.key or nil
    if key ~= self.litKey then
        self.window:highlight(self.lit, false)
        self.lit = nil
        if key then
            local found = S.resolve(key)
            self.lit = found and found.object or nil
            self.window:highlight(self.lit, true)
        end
        self.litKey = key
    end
end

function BU_StockList:onMouseDoubleClick(x, y)
    local index = self:rowAt(x, y)
    if index < 1 or index > #self.items then return end
    self.window:walkTo(self.items[index].item)
end

function BU_StockList:new(x, y, width, height, window)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.window = window
    o.itemheight = ROW_HGT
    o.drawBorder = true
    return o
end

-- the window ----------------------------------------------------------------------------------------

function BU_StockWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()

    self.fieldBox = ISComboBox:new(PAD, th + PAD, 110, BAR_HGT, self, BU_StockWindow.onField)
    self.fieldBox:initialise()
    for _, f in ipairs(SEARCH_FIELDS) do self.fieldBox:addOptionWithData(getText("IGUI_BU_StockIn_" .. f), f) end
    self:addChild(self.fieldBox)

    local refreshW = math.max(80, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_BU_Rescan")) + 20)
    self.refreshBtn = ISButton:new(self.width - refreshW - PAD, th + PAD, refreshW, BAR_HGT, getText("IGUI_BU_Rescan"), self, BU_StockWindow.onRefresh)
    self.refreshBtn:initialise()
    self.refreshBtn:instantiate()
    self.refreshBtn:setAnchorLeft(false)
    self.refreshBtn:setAnchorRight(true)
    self:addChild(self.refreshBtn)

    local zonesW = math.max(70, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_BU_Zones")) + 20)
    self.zonesBtn = ISButton:new(self.refreshBtn:getX() - zonesW - PAD, th + PAD, zonesW, BAR_HGT, getText("IGUI_BU_Zones"), self, BU_StockWindow.onZones)
    self.zonesBtn:initialise()
    self.zonesBtn:instantiate()
    self.zonesBtn:setAnchorLeft(false)
    self.zonesBtn:setAnchorRight(true)
    self:addChild(self.zonesBtn)

    local sx = self.fieldBox:getRight() + PAD
    self.searchBox = ISTextEntryBox:new(self.search or "", sx, th + PAD, self.zonesBtn:getX() - sx - PAD, BAR_HGT)
    self.searchBox:initialise()
    self.searchBox:instantiate()
    self.searchBox.font = UIFont.Small
    self.searchBox:setAnchorRight(true)
    self.searchBox:setPlaceholderText(getText("IGUI_FilterSearch"))
    self.searchBox:setClearButton(true)
    self.searchBox.onTextChangeFunction = BU_StockWindow.filter
    self.searchBox.target = self
    self:addChild(self.searchBox)

    -- the column headers: click to sort, again to turn the order round
    self.headerY = self.searchBox:getBottom() + PAD + FONT_HGT_SMALL + PAD
    self.headers = {}
    for _, col in ipairs(COLUMNS) do
        local b = ISButton:new(0, self.headerY, 10, BAR_HGT, getText(col.label), self, BU_StockWindow.onSort)
        b.internal = col.field
        b:initialise()
        b:instantiate()
        b.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
        b.backgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 }
        self:addChild(b)
        self.headers[col.field] = b
    end

    local top = self.headerY + BAR_HGT
    self.list = BU_StockList:new(PAD, top, self.width - PAD * 2, self.height - top - rh - PAD, self)
    self.list:initialise()
    self.list:instantiate()
    self.list:setAnchorRight(true)
    self.list:setAnchorBottom(true)
    self.list:setFont(UIFont.Small, 2)
    self.list.itemheight = ROW_HGT
    self:addChild(self.list)

    self:layoutColumns()
    self:refresh()
end

function BU_StockWindow:layoutColumns()
    local inner = self.list:getWidth() - 14
    local fixed = 0
    for _, col in ipairs(COLUMNS) do fixed = fixed + (col.fixed or 0) end
    local x = 4
    self.cols = {}
    for _, col in ipairs(COLUMNS) do
        local w = col.fixed or math.floor((inner - fixed) * col.share)
        self.cols[#self.cols + 1] = { field = col.field, x = x, w = w }
        local b = self.headers[col.field]
        b:setX(self.list:getX() + x)
        b:setWidth(w)
        local arrow = self.sortField == col.field and (self.sortDesc and " v" or " ^") or ""
        b:setTitle(getText(col.label) .. arrow)
        x = x + w
    end
end

function BU_StockWindow:onResize()
    ISCollapsableWindow.onResize(self)
    if self.list then self:layoutColumns() end
end

-- count the zones in range again, then list
function BU_StockWindow:refresh()
    local store = BU.store()
    self.fresh = S.refreshStock(store)
    self:reload()
end

-- list from the saved counts as they stand
function BU_StockWindow:reload()
    local store = BU.store()
    self.rows = BU.stockRows(store.stock, S.worldHours(), self.fresh)
    self.zoneCount = #BU.zoneAreas(store.zones)
    self:sort()
end

function BU_StockWindow:sort()
    BU.sortStock(self.rows, self.sortField, self.sortDesc)
    self:filter()
end

function BU_StockWindow:filter()
    if not self.list then return end
    local text = self.searchBox and self.searchBox:getInternalText() or ""
    local field = self.fieldBox and self.fieldBox:getOptionData(self.fieldBox.selected) or "all"
    local scroll = self.list:getYScroll()
    self.list:clear()
    self.shown, self.shownTotal, self.stale = 0, 0, false
    for _, row in ipairs(self.rows or {}) do
        local probe = { name = row.name, category = S.categoryLabel(row.category or ""), zone = row.zone, container = row.container }
        if BU.stockMatch(probe, text, field) then
            self.list:addItem(row.name, row)
            self.shown = self.shown + 1
            self.shownTotal = self.shownTotal + row.count
            if row.age then self.stale = true end
        end
    end
    self.list:setYScroll(scroll)
end

function BU_StockWindow:onField()
    self:filter()
end

function BU_StockWindow:onSort(button)
    if self.sortField == button.internal then
        self.sortDesc = not self.sortDesc
    else
        self.sortField = button.internal
        self.sortDesc = button.internal == "count"
    end
    self:layoutColumns()
    self:sort()
end

function BU_StockWindow:onRefresh()
    self:refresh()
end

function BU_StockWindow:onZones()
    BU_ZoneWindow.open(self.character)
end

function BU_StockWindow:setSearch(text)
    self.searchBox:setText(text or "")
    self:filter()
end

function BU_StockWindow:highlight(obj, on)
    if not obj then return end
    pcall(function()
        obj:setHighlighted(self.playerNum, on, false)
        if on then obj:setHighlightColor(self.playerNum, getCore():getObjectHighlitedColor()) end
    end)
end

function BU_StockWindow:walkTo(row)
    local found = row and row.key and S.resolve(row.key) or nil
    if not found then
        pcall(function() HaloTextHelper.addBadText(self.character, getText("IGUI_BU_ZoneTooFar")) end)
        return
    end
    luautils.walkToContainer(found.container, self.playerNum)
end

function BU_StockWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local y = self.searchBox:getBottom() + PAD
    local text
    if (self.zoneCount or 0) == 0 then
        text = getText("IGUI_BU_StockNoZones")
    else
        text = getText("IGUI_BU_StockStatus", self.shownTotal or 0, self.shown or 0, self.zoneCount)
        if self.stale then text = text .. " " .. getText("IGUI_BU_StockStale") end
    end
    self:drawText(text, PAD, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function BU_StockWindow:close()
    if self.list then self:highlight(self.list.lit, false) end
    BU_StockWindow.instances[self.playerNum] = nil
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

function BU_StockWindow:new(x, y, width, height, character, search)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("IGUI_BU_StockTitle"))
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.search = search
    o.sortField = "name"
    o.sortDesc = false
    o.rows = {}
    o.minimumWidth = 520
    o.minimumHeight = 260
    o:setResizable(true)
    return o
end

-- open (or bring forward) the window for a player, searched for `search` if given
function BU_StockWindow.open(character, search)
    local playerNum = character:getPlayerNum()
    local win = BU_StockWindow.instances[playerNum]
    if win then
        win:setVisible(true)
        win:bringToTop()
        win:refresh()
    else
        local x = getPlayerScreenLeft(playerNum) + 100
        local y = getPlayerScreenTop(playerNum) + 80
        win = BU_StockWindow:new(x, y, math.min(720, getPlayerScreenWidth(playerNum) - 200), math.min(520, getPlayerScreenHeight(playerNum) - 160), character, search)
        win:initialise()
        win:instantiate()
        win:addToUIManager()
        BU_StockWindow.instances[playerNum] = win
    end
    if search then win:setSearch(search) end
    return win
end
