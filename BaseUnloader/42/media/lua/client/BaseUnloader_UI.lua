-- Base Unloader: the window. Left, what is in the source grouped by type, with
-- where each type goes; right, every container in the base with its name,
-- kind, room, floor, distance and how full it is. Drag a type onto a
-- container (or drag items straight out of the vanilla inventory windows)
-- to say that type lives there; Ctrl while dropping sends just those items,
-- this run only. Suggest guesses homes from what the base already holds;
-- Start hands the plan to BaseUnloader_Run. Hover a container row to light
-- it up in the world, double-click to rename it, right-click for more.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTextBox"
require "ISUI/ISTickBox"
require "ISUI/ISContextMenu"
require "ISUI/ISInventoryPane"
require "BaseUnloader_Scan"
require "BaseUnloader_Run"

local BU = BaseUnloader
local S = BU_Scan

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local ROW_HGT = FONT_HGT_SMALL * 2 + 10
local HEADER_HGT = FONT_HGT_SMALL + 8
local PAD = 6
local DRAG_START = 5     -- pixels the mouse moves before a press becomes a drag
local MAX_NAME = 40
local ICON = ROW_HGT - 10
local BOX = FONT_HGT_SMALL + 2

-- the picture the loot window gives a container of this kind, else its shelf
local function containerIcon(row)
    local tex
    pcall(function()
        local kind = row.container:getType()
        if ContainerButtonIcons and ContainerButtonIcons[kind] then tex = ContainerButtonIcons[kind] end
        if not tex then tex = getTexture("media/ui/Container_Shelf.png") end
    end)
    return tex
end

local function itemIcon(g)
    local tex
    pcall(function()
        local first = g.items[1] and g.items[1].item
        if first then tex = first:getTex() end
    end)
    return tex
end

local function drawIcon(list, tex, x, y)
    if tex then list:drawTextureScaledAspect(tex, x, y + 5, ICON, ICON, 1, 1, 1, 1) end
end

BU_ItemList = ISScrollingListBox:derive("BU_ItemList")
BU_ContainerList = ISScrollingListBox:derive("BU_ContainerList")
BU_Window = ISCollapsableWindow:derive("BU_Window")
BU_Window.instances = {}
BU_Window.last = {}

local function dim(list, x, y, w, h)
    list:drawRect(x, y, w, h, 0.08, 1, 1, 1)
end

-- the item list ------------------------------------------------------------------------------------

function BU_ItemList:doDrawItem(y, item, alt)
    if y + self:getYScroll() >= self.height then return y + item.height end
    if y + item.height + self:getYScroll() <= 0 then return y + item.height end
    local g = item.item
    local win = self.window
    if alt then self:drawRect(0, y, self:getWidth(), item.height, 0.06, 1, 1, 1) end
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.3, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.sel[g.fullType] then self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 2, 0.25, 0.35, 0.55, 0.85) end
    if self:isMouseOver() and self.mouseoverselected == item.index then dim(self, 1, y + 1, self:getWidth() - 2, item.height - 2) end
    local line1 = y + 4
    local line2 = y + 6 + FONT_HGT_SMALL
    local count = getText("IGUI_BU_Count", g.count, BU.fmtWeight(g.weight))
    local cw = getTextManager():MeasureStringX(UIFont.Small, count)
    drawIcon(self, itemIcon(g), PAD, y)
    local tx = PAD + ICON + PAD
    self:drawText(g.name, tx, line1, 1, 1, 1, 1, UIFont.Small)
    self:drawText(count, self.width - cw - PAD - 14, line1, 0.7, 0.7, 0.7, 1, UIFont.Small)
    local dest, how = win:destinationLabel(g)
    if dest then
        local r, gg, b = 0.6, 0.85, 0.6
        if how == "oneoff" then r, gg, b = 0.6, 0.75, 0.95 end
        if how == "mixed" then r, gg, b = 0.85, 0.8, 0.5 end
        self:drawText(getText("IGUI_BU_GoesTo", dest), tx, line2, r, gg, b, 1, UIFont.Small)
    else
        self:drawText(getText("IGUI_BU_Unassigned"), tx, line2, 0.95, 0.55, 0.5, 1, UIFont.Small)
    end
    return y + item.height
end

-- Selection: click picks one type, Ctrl-click adds or removes one, Shift-click
-- takes the range from the last click. A drag carries the whole selection when
-- it starts on a selected row, else just that row.
function BU_ItemList:selectedGroups(pressed)
    local out = {}
    if pressed and self.sel[pressed.fullType] then
        for _, it in ipairs(self.items) do
            if self.sel[it.item.fullType] then out[#out + 1] = it.item end
        end
    else
        out[1] = pressed
    end
    return out
end

function BU_ItemList:selectOnly(index)
    self.sel = {}
    local it = self.items[index]
    if it then self.sel[it.item.fullType] = true end
    self.lastClick = index
end

function BU_ItemList:onMouseDown(x, y)
    ISScrollingListBox.onMouseDown(self, x, y)
    local index = self:rowAt(x, y)
    if index < 1 or index > #self.items then return end
    self.pressRow = index
    self.pressX, self.pressY = x, y
    local g = self.items[index].item
    if isCtrlKeyDown() then
        if self.sel[g.fullType] then self.sel[g.fullType] = nil else self.sel[g.fullType] = true end
        self.lastClick = index
    elseif isShiftKeyDown() and self.lastClick then
        local a, b = math.min(self.lastClick, index), math.max(self.lastClick, index)
        for i = a, b do
            local it = self.items[i]
            if it then self.sel[it.item.fullType] = true end
        end
    elseif not self.sel[g.fullType] then
        self:selectOnly(index)
    end
end

function BU_ItemList:startDrag()
    local row = self.items[self.pressRow]
    if not row then return end
    self.window.drag = { groups = self:selectedGroups(row.item) }
end

function BU_ItemList:onMouseMove(dx, dy)
    ISScrollingListBox.onMouseMove(self, dx, dy)
    if self.pressRow and isMouseButtonDown(0) and not self.window.drag then
        local x, y = self:getMouseX(), self:getMouseY()
        if math.abs(x - (self.pressX or x)) + math.abs(y - (self.pressY or y)) >= DRAG_START then self:startDrag() end
    end
end

function BU_ItemList:onMouseMoveOutside(dx, dy)
    ISScrollingListBox.onMouseMoveOutside(self, dx, dy)
    if self.pressRow and isMouseButtonDown(0) and not self.window.drag then self:startDrag() end
end

function BU_ItemList:onMouseUp(x, y)
    ISScrollingListBox.onMouseUp(self, x, y)
    -- a plain click on an already selected row, without a drag, narrows the selection to it
    if self.pressRow and not self.window.drag and not isCtrlKeyDown() and not isShiftKeyDown() then
        local index = self:rowAt(x, y)
        if index == self.pressRow then self:selectOnly(index) end
    end
    self.pressRow = nil
end

function BU_ItemList:onMouseUpOutside(x, y)
    ISScrollingListBox.onMouseUpOutside(self, x, y)
    self.pressRow = nil
end

function BU_ItemList:onRightMouseUp(x, y)
    local index = self:rowAt(x, y)
    if index < 1 or index > #self.items then return end
    local g = self.items[index].item
    local win = self.window
    if not self.sel[g.fullType] then self:selectOnly(index) end
    local menu = ISContextMenu.get(win.playerNum, self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    menu:addOption(getText("IGUI_BU_Unassign"), win, BU_Window.unassignGroups, self:selectedGroups(g))
    if g.category then
        menu:addOption(getText("IGUI_BU_UnassignCategory", g.category), win, BU_Window.unassignCategory, g)
    end
end

function BU_ItemList:new(x, y, width, height, window)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.window = window
    o.sel = {}
    o.itemheight = ROW_HGT
    o.drawBorder = true
    return o
end

-- the container list ----------------------------------------------------------------------------------

function BU_ContainerList:doDrawItem(y, item, alt)
    if y + self:getYScroll() >= self.height then return y + item.height end
    if y + item.height + self:getYScroll() <= 0 then return y + item.height end
    local row = item.item
    local win = self.window
    if row.header then
        self:drawRect(0, y, self:getWidth(), item.height, 0.35, 0.25, 0.3, 0.4)
        self:drawText(row.text, PAD, y + 4, 0.9, 0.9, 0.95, 1, UIFont.Small)
        return y + item.height
    end
    if alt then self:drawRect(0, y, self:getWidth(), item.height, 0.06, 1, 1, 1) end
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.3, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local over = self:isMouseOver() and self.mouseoverselected == item.index
    if over then dim(self, 1, y + 1, self:getWidth() - 2, item.height - 2) end
    if over and (win.drag or ISMouseDrag.dragging) then
        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 2, 0.25, 0.4, 0.8, 0.4)
    end
    local line1 = y + 4
    local line2 = y + 6 + FONT_HGT_SMALL
    local nameW = getTextManager():MeasureStringX(UIFont.Small, row.name)
    local hidden = win:isHidden(row)
    local shade = (row.pinned or hidden) and 0.7 or 1
    drawIcon(self, containerIcon(row), PAD, y)
    local tx = PAD + ICON + PAD
    self:drawText(row.name, tx, line1, shade, shade, shade, 1, UIFont.Small)
    local after = tx + nameW + 8
    if row.named then
        self:drawText(row.kindLabel, after, line1, 0.6, 0.6, 0.6, 1, UIFont.Small)
        after = after + getTextManager():MeasureStringX(UIFont.Small, row.kindLabel) + 8
    end
    if hidden then self:drawText(getText("IGUI_BU_HiddenTag"), after, line1, 0.6, 0.5, 0.5, 1, UIFont.Small) end
    local n = win.ruleCounts[row.key] or 0
    local right = row.pinned and getText("IGUI_BU_Source") or getText("IGUI_BU_Fill", BU.fmtWeight(row.used), BU.fmtWeight(row.capacity))
    local rw = getTextManager():MeasureStringX(UIFont.Small, right)
    self:drawText(right, self.width - rw - PAD - 14, line1, 0.7, 0.7, 0.7, 1, UIFont.Small)
    -- second line: how far, and outdoors which way (the room is the header)
    local place = win:distanceLabel(row) or ""
    if not row.room and row.offset then place = row.offset .. ", " .. place end
    if row.tagged and row.room then place = row.room .. ", " .. place end
    self:drawText(place, tx, line2, 0.6, 0.6, 0.6, 1, UIFont.Small)
    local tagText = win:tagLabel(row)
    if tagText then
        local px = tx + getTextManager():MeasureStringX(UIFont.Small, place) + 10
        self:drawText(tagText, px, line2, 0.55, 0.8, 0.9, 1, UIFont.Small)
    end
    if n > 0 and not row.pinned then
        local t = getText("IGUI_BU_Rules", n)
        local tw = getTextManager():MeasureStringX(UIFont.Small, t)
        self:drawText(t, self.width - tw - PAD - 14, line2, 0.6, 0.85, 0.6, 1, UIFont.Small)
    end
    return y + item.height
end

function BU_ContainerList:rowUnderMouse()
    if not self:isMouseOver() then return nil end
    local index = self:rowAt(self:getMouseX(), self:getMouseY())
    if index < 1 or index > #self.items then return nil end
    local row = self.items[index].item
    if row.header then return nil end
    return row
end

-- a drop from the vanilla inventory windows lands here; the window's own drag
-- is settled in BU_Window:prerender, which sees the button go up wherever it does
function BU_ContainerList:onMouseUp(x, y)
    ISScrollingListBox.onMouseUp(self, x, y)
    if ISMouseDrag.dragging ~= nil and ISMouseDrag.draggingFocus ~= nil and ISMouseDrag.draggingFocus ~= self then
        local row = self:rowUnderMouse()
        if row then
            local items = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
            self.window:dropItems(items, row, isCtrlKeyDown())
        end
        if ISMouseDrag.draggingFocus then ISMouseDrag.draggingFocus:onMouseUp(0, 0) end
        ISMouseDrag.draggingFocus = nil
        ISMouseDrag.dragging = nil
    end
end

function BU_ContainerList:onMouseDoubleClick(x, y)
    local index = self:rowAt(x, y)
    if index < 1 or index > #self.items or self.items[index].item.header then return end
    self.window:rename(self.items[index].item)
end

function BU_ContainerList:onRightMouseUp(x, y)
    local index = self:rowAt(x, y)
    if index < 1 or index > #self.items then return end
    local row = self.items[index].item
    if row.header then return end
    local win = self.window
    local menu = ISContextMenu.get(win.playerNum, self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    menu:addOption(getText("IGUI_BU_Rename"), win, BU_Window.rename, row)
    if not row.pinned then
        if win:isHidden(row) then
            menu:addOption(getText("IGUI_BU_Unhide"), win, BU_Window.setHidden, row, false)
        else
            menu:addOption(getText("IGUI_BU_Hide"), win, BU_Window.setHidden, row, true)
        end
        menu:addOption(getText("IGUI_BU_SendUnassigned"), win, BU_Window.sendUnassigned, row)
        local catOption = menu:addOption(getText("IGUI_BU_Categories"), nil, nil)
        local sub = ISContextMenu:getNew(menu)
        menu:addSubMenu(catOption, sub)
        local tags = BU.store().tags
        for _, cat in ipairs(win:categories()) do
            local on = BU.hasTag(tags, row.key, cat)
            sub:addOption((on and "[x] " or "[  ] ") .. win:categoryLabel(cat), win, BU_Window.toggleTag, row, cat)
        end
        if #BU.tagsOf(tags, row.key) > 0 then
            menu:addOption(getText("IGUI_BU_ClearTags"), win, BU_Window.clearTags, row)
        end
        local n = win.ruleCounts[row.key] or 0
        if n > 0 then
            menu:addOption(getText("IGUI_BU_ClearRules", n), win, BU_Window.clearRulesTo, row)
        end
    end
end

-- light up the container under the mouse, and only that one
function BU_ContainerList:prerender()
    ISScrollingListBox.prerender(self)
    local row = self:rowUnderMouse()
    local obj = row and row.object or nil
    if obj ~= self.lit then
        self.window:highlight(self.lit, false)
        self.window:highlight(obj, true)
        self.lit = obj
    end
end

function BU_ContainerList:new(x, y, width, height, window)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.window = window
    o.itemheight = ROW_HGT
    o.drawBorder = true
    return o
end

-- the window --------------------------------------------------------------------------------------------

function BU_Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local barH = FONT_HGT_SMALL + 8
    local btnW = math.max(70, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_BU_Suggest")) + 20)

    self.filterBox = ISTextEntryBox:new("", PAD, th + PAD, math.floor(self.width * 0.3), barH)
    self.filterBox:initialise()
    self.filterBox:instantiate()
    self.filterBox.font = UIFont.Small
    self.filterBox:setPlaceholderText(getText("IGUI_FilterSearch"))
    self.filterBox.onTextChangeFunction = BU_Window.fill
    self.filterBox.target = self
    self:addChild(self.filterBox)

    local startW = math.max(90, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_BU_Start")) + 24)
    self.startBtn = ISButton:new(self.width - startW - PAD, th + PAD, startW, barH, getText("IGUI_BU_Start"), self, BU_Window.onStart)
    self.startBtn:initialise()
    self.startBtn:instantiate()
    self.startBtn:setAnchorLeft(false)
    self.startBtn:setAnchorRight(true)
    self.startBtn.borderColor = { r = 0.4, g = 0.7, b = 0.4, a = 0.9 }
    self:addChild(self.startBtn)

    self.suggestBtn = ISButton:new(self.startBtn:getX() - btnW - PAD, th + PAD, btnW, barH, getText("IGUI_BU_Suggest"), self, BU_Window.onSuggest)
    self.suggestBtn:initialise()
    self.suggestBtn:instantiate()
    self.suggestBtn:setAnchorLeft(false)
    self.suggestBtn:setAnchorRight(true)
    self:addChild(self.suggestBtn)

    local rescanW = math.max(70, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_BU_Rescan")) + 20)
    self.rescanBtn = ISButton:new(self.suggestBtn:getX() - rescanW - PAD, th + PAD, rescanW, barH, getText("IGUI_BU_Rescan"), self, BU_Window.onRescan)
    self.rescanBtn:initialise()
    self.rescanBtn:instantiate()
    self.rescanBtn:setAnchorLeft(false)
    self.rescanBtn:setAnchorRight(true)
    self:addChild(self.rescanBtn)

    self.hiddenBox = ISTickBox:new(self.filterBox:getRight() + PAD * 2, th + PAD, BOX, barH, "", self, BU_Window.onShowHidden)
    self.hiddenBox:initialise()
    self.hiddenBox:instantiate()
    self.hiddenBox:addOption(getText("IGUI_BU_ShowHidden"))
    self.hiddenBox:setWidthToFit()
    self:addChild(self.hiddenBox)

    local top = self.filterBox:getBottom() + PAD + FONT_HGT_SMALL + PAD
    local leftW = math.floor((self.width - PAD * 3) * 0.42)
    self.itemList = BU_ItemList:new(PAD, top, leftW, self.height - top - rh - PAD, self)
    self.itemList:initialise()
    self.itemList:instantiate()
    self.itemList:setAnchorBottom(true)
    self.itemList:setFont(UIFont.Small, 3)
    self.itemList.itemheight = ROW_HGT
    self:addChild(self.itemList)

    self.containerList = BU_ContainerList:new(self.itemList:getRight() + PAD, top, self.width - leftW - PAD * 3, self.height - top - rh - PAD, self)
    self.containerList:initialise()
    self.containerList:instantiate()
    self.containerList:setAnchorRight(true)
    self.containerList:setAnchorBottom(true)
    self.containerList:setFont(UIFont.Small, 3)
    self.containerList.itemheight = ROW_HGT
    self:addChild(self.containerList)

    self.resizeWidget2:bringToTop()
    self.resizeWidget:bringToTop()
    self:scan()
end

-- the world, read again
function BU_Window:scan()
    local src = self.source
    self.zone = S.zone(self.character, S.sourceSquare(src))
    self.rows = S.containers(self.zone, src.container, self.character)
    if src.kind == "object" and src.row then
        src.row = S.row(src.object, src.container, BU.parseKey(src.key).index, src.object:getSquare(), self.zone, self.character)
        src.row.pinned = true
        table.insert(self.rows, 1, src.row)
    end
    self.byKey = {}
    for _, row in ipairs(self.rows) do self.byKey[row.key] = row end
    local items
    if src.kind == "self" then
        items = {}
        local function walk(inv, depth)
            local list = inv:getItems()
            for i = 0, list:size() - 1 do
                local it = list:get(i)
                local r = S.itemRecord(it)
                if r then items[#items + 1] = r end
                if depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then walk(it:getInventory(), depth + 1) end
            end
        end
        pcall(function() walk(src.container, 0) end)
    else
        items = S.items(src.container)
    end
    self.items = items
    self.groups = BU.groups(items)
    self:fill()
end

function BU_Window:destinationLabel(g)
    local rules = BU.store().rules
    local probe = { fullType = g.fullType, category = g.category }
    local ruleKey = BU.destinationOf(probe, rules, nil)
    local oneKey, mixed = nil, false
    for _, r in ipairs(g.items) do
        local k = self.oneOffs[r.id]
        if k then
            if oneKey and oneKey ~= k then mixed = true end
            oneKey = oneKey or k
        elseif oneKey then
            mixed = true
        end
    end
    local key = oneKey or ruleKey
    local how = "rule"
    if not key then
        key = BU.tagDestination(probe, BU.store().tags, self:visibleRows())
        how = "tag"
    end
    if not key then return nil end
    local row = self.byKey[key]
    local name = row and row.name or getText("IGUI_BU_Missing")
    if mixed then return name, "mixed" end
    if oneKey then return name, "oneoff" end
    return name, how
end

-- tags ---------------------------------------------------------------------------------------------------------

function BU_Window:categoryLabel(cat)
    return S.categoryLabel(cat)
end

function BU_Window:categories()
    return S.categories(self.groups, self.rows)
end

function BU_Window:tagLabel(row)
    local list = BU.tagsOf(BU.store().tags, row.key)
    if #list == 0 then return nil end
    local names = {}
    for i, cat in ipairs(list) do names[i] = self:categoryLabel(cat) end
    return table.concat(names, ", ")
end

function BU_Window:toggleTag(row, cat)
    local tags = BU.store().tags
    BU.setTag(tags, row.key, cat, not BU.hasTag(tags, row.key, cat))
    self:fill()
end

function BU_Window:clearTags(row)
    BU.store().tags[row.key] = nil
    self:fill()
end

function BU_Window:distanceLabel(row)
    local sq = S.squareOf(self.character)
    if not sq then return nil end
    local d = BU.dist({ x = sq:getX(), y = sq:getY(), z = sq:getZ() }, row)
    return getText("IGUI_BU_Away", math.floor(d + 0.5))
end

function BU_Window:fill()
    local filter = string.lower(self.filterBox:getInternalText() or "")
    self.ruleCounts = BU.ruleCounts(BU.store().rules)
    local scroll = self.itemList:getYScroll()
    self.itemList:clear()
    self.unassigned = 0
    for _, g in ipairs(self.groups) do
        if not self:destinationLabel(g) then self.unassigned = self.unassigned + 1 end
        if filter == "" or string.find(string.lower(g.name), filter, 1, true) then
            self.itemList:addItem(g.name, g)
        end
    end
    self.itemList:setYScroll(scroll)
    scroll = self.containerList:getYScroll()
    local list = self.containerList
    list:clear()
    local lastHeader = nil
    self.hiddenCount = 0
    local tags = BU.store().tags
    local function header(text)
        if text == lastHeader then return end
        local h = list:addItem(text, { header = true, text = text })
        list:setScrollHeight(list:getScrollHeight() - h.height + HEADER_HGT)
        h.height = HEADER_HGT
        lastHeader = text
    end
    local function shown(row, hidden)
        local text = string.lower(row.name .. " " .. (row.place or "") .. " " .. row.kindLabel .. " " .. (self:tagLabel(row) or ""))
        return (row.pinned or filter == "" or string.find(text, filter, 1, true)) and (self.showHidden or not hidden)
    end
    -- the source, then the tagged containers, then everything else by room
    for _, row in ipairs(self.rows) do
        local hidden = not row.pinned and self:isHidden(row)
        if hidden then self.hiddenCount = self.hiddenCount + 1 end
        row.tagged = not row.pinned and tags[row.key] ~= nil
        if row.pinned and shown(row, hidden) then
            header(getText("IGUI_BU_Source"))
            list:addItem(row.name, row)
        end
    end
    for _, row in ipairs(self.rows) do
        if row.tagged and shown(row, self:isHidden(row)) then
            header(getText("IGUI_BU_Tagged"))
            list:addItem(row.name, row)
        end
    end
    for _, row in ipairs(self.rows) do
        if not row.pinned and not row.tagged and shown(row, self:isHidden(row)) then
            header((row.room or getText("IGUI_BU_Outside")) .. ", " .. S.floorLabel(row.z))
            list:addItem(row.name, row)
        end
    end
    list:setYScroll(scroll)
end

-- hiding ---------------------------------------------------------------------------------------------------

function BU_Window:isHidden(row)
    return BU.store().hidden[row.key] == true
end

function BU_Window:setHidden(row, hidden)
    BU.store().hidden[row.key] = hidden and true or nil
    self:fill()
end

function BU_Window:onShowHidden(index, selected)
    self.showHidden = selected
    self:fill()
end

-- the containers Suggest may pick: not the hidden ones
function BU_Window:visibleRows()
    local out = {}
    for _, row in ipairs(self.rows) do
        if not row.pinned and not self:isHidden(row) then out[#out + 1] = row end
    end
    return out
end

-- assignments ----------------------------------------------------------------------------------------------

function BU_Window:assignGroup(g, row, oneOff)
    if row.pinned and self.source.key == row.key then
        -- dropped back on the source: leave it there
        BU.setRule(BU.store().rules, g.fullType, nil)
        for _, r in ipairs(g.items) do self.oneOffs[r.id] = nil end
        self:fill()
        return
    end
    if oneOff then
        for _, r in ipairs(g.items) do self.oneOffs[r.id] = row.key end
    else
        BU.setRule(BU.store().rules, g.fullType, row.key)
        for _, r in ipairs(g.items) do self.oneOffs[r.id] = nil end
    end
    getSoundManager():playUISound("UISelectListItem")
    self:fill()
end

-- items dragged from a vanilla inventory window
function BU_Window:dropItems(items, row, oneOff)
    if row.pinned then return end
    local rules = BU.store().rules
    for _, it in ipairs(items) do
        local r = S.itemRecord(it)
        if r then
            if oneOff then
                self.oneOffs[r.id] = row.key
            else
                BU.setRule(rules, r.fullType, row.key)
                self.oneOffs[r.id] = nil
            end
        end
    end
    getSoundManager():playUISound("UISelectListItem")
    self:fill()
end

function BU_Window:assignGroups(groups, row, oneOff)
    for _, g in ipairs(groups) do self:assignGroup(g, row, oneOff) end
end

function BU_Window:unassignGroups(groups)
    for _, g in ipairs(groups) do self:unassign(g) end
end

function BU_Window:unassign(g)
    local rules = BU.store().rules
    BU.setRule(rules, g.fullType, nil)
    for _, r in ipairs(g.items) do self.oneOffs[r.id] = nil end
    self:fill()
end

function BU_Window:unassignCategory(g)
    BU.setRule(BU.store().rules, BU.catKey(g.category), nil)
    self:unassign(g)
end

function BU_Window:sendUnassigned(row)
    local rules = BU.store().rules
    for _, g in ipairs(self.groups) do
        if not self:destinationLabel(g) then BU.setRule(rules, g.fullType, row.key) end
    end
    self:fill()
end

function BU_Window:clearRulesTo(row)
    BU.clearRulesTo(BU.store().rules, row.key)
    for id, key in pairs(self.oneOffs) do
        if key == row.key then self.oneOffs[id] = nil end
    end
    self:fill()
end

function BU_Window:onSuggest()
    local rules = BU.store().rules
    local picks = BU.suggest(self.groups, self:visibleRows(), rules)
    local n = 0
    for fullType, key in pairs(picks) do
        if not (self.source.key and key == self.source.key) then
            BU.setRule(rules, fullType, key)
            n = n + 1
        end
    end
    if n == 0 then
        pcall(function() HaloTextHelper.addBadText(self.character, getText("IGUI_BU_NoSuggestion")) end)
    end
    self:fill()
end

function BU_Window:onRescan()
    self:scan()
end

function BU_Window:onStart()
    local oneOffs = {}
    for id, key in pairs(self.oneOffs) do oneOffs[tostring(id)] = key end
    BU_Run.start(self.character, self.source, oneOffs)
    self:close()
end

-- renaming ----------------------------------------------------------------------------------------------------

function BU_Window:rename(row)
    local modal = ISTextBox:new(0, 0, 280, 180, getText("IGUI_BU_NameThis"), row.name, self, BU_Window.onRenamed, self.playerNum, self.playerNum, row)
    modal:initialise()
    modal:addToUIManager()
    modal.entry:setMaxTextLength(MAX_NAME)
end

function BU_Window:onRenamed(button, playerNum, row)
    if button.internal ~= "OK" then return end
    local text = button.parent.entry:getText() or ""
    if text == row.kindLabel then text = "" end
    S.rename(row.container, row.key, text)
    pcall(function()
        local pdata = getPlayerData(playerNum)
        pdata.playerInventory:refreshBackpacks()
        pdata.lootInventory:refreshBackpacks()
    end)
    self:scan()
end

-- highlight -----------------------------------------------------------------------------------------------------

function BU_Window:highlight(obj, on)
    if not obj then return end
    pcall(function()
        obj:setHighlighted(self.playerNum, on, false)
        if on then obj:setHighlightColor(self.playerNum, getCore():getObjectHighlitedColor()) end
    end)
end

-- the frame --------------------------------------------------------------------------------------------------------

function BU_Window:prerender()
    ISCollapsableWindow.prerender(self)
    if self.character:isDead() then self:close(); return end
    -- the window's own drag: settled when the button comes up, wherever that is
    if self.drag and not isMouseButtonDown(0) then
        local row = self.containerList:rowUnderMouse()
        if row then self:assignGroups(self.drag.groups, row, isCtrlKeyDown()) end
        self.drag = nil
    end
end

function BU_Window:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local y = self.filterBox:getBottom() + PAD
    local text = getText("IGUI_BU_Status", #self.groups, self.unassigned or 0, #self.rows - (self.source.row and 1 or 0))
    if (self.hiddenCount or 0) > 0 then text = text .. " " .. getText("IGUI_BU_HiddenCount", self.hiddenCount) end
    self:drawText(text, PAD, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
    local hint = getText("IGUI_BU_Hint")
    local hw = getTextManager():MeasureStringX(UIFont.Small, hint)
    self:drawText(hint, self.width - hw - PAD, y, 0.55, 0.55, 0.55, 1, UIFont.Small)
    if self.drag then
        local label = self.drag.groups[1].name
        if #self.drag.groups > 1 then label = label .. " " .. getText("IGUI_BU_More", #self.drag.groups - 1) end
        local mx, my = self:getMouseX(), self:getMouseY()
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 12
        self:drawRect(mx + 10, my + 6, w, FONT_HGT_SMALL + 6, 0.85, 0.1, 0.1, 0.1)
        self:drawRectBorder(mx + 10, my + 6, w, FONT_HGT_SMALL + 6, 0.8, 0.6, 0.8, 0.6)
        self:drawText(label, mx + 16, my + 9, 1, 1, 1, 1, UIFont.Small)
    end
end

function BU_Window:close()
    self:highlight(self.containerList and self.containerList.lit, false)
    BU_Window.last[self.playerNum] = { x = self:getX(), y = self:getY(), w = self:getWidth(), h = self:getHeight() }
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    BU_Window.instances[self.playerNum] = nil
end

function BU_Window:new(x, y, width, height, character, source)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("IGUI_BU_Title", source.label or ""))
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.source = source
    o.oneOffs = {}
    o.rows = {}
    o.byKey = {}
    o.groups = {}
    o.ruleCounts = {}
    o.minimumWidth = 560
    o.minimumHeight = 320
    return o
end

-- something outside the window changed the saved data: redraw
function BU_Window.refresh(playerNum)
    local win = BU_Window.instances[playerNum]
    if win then win:fill() end
end

-- open for a source (closing any window already open for this player)
function BU_Window.open(character, source)
    local playerNum = character:getPlayerNum()
    local old = BU_Window.instances[playerNum]
    if old then old:close() end
    local at = BU_Window.last[playerNum] or {
        x = getPlayerScreenLeft(playerNum) + 80, y = getPlayerScreenTop(playerNum) + 60,
        w = math.min(820, getPlayerScreenWidth(playerNum) - 160), h = math.min(560, getPlayerScreenHeight(playerNum) - 120) }
    local win = BU_Window:new(at.x, at.y, at.w, at.h, character, source)
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    BU_Window.instances[playerNum] = win
    return win
end
