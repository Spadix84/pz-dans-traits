-- Base Unloader: the base zones. The player draws them (the game's own
-- click-and-drag zone tool, borrowed: what it draws is kept in our saved data
-- and never becomes an animal zone), names them, renames and removes them in
-- a small window that lights every zone up on the ground with its name.
-- Pieces given the same name are one zone, so an L-shaped house is two
-- rectangles called "House". The unloader lists and uses only what is inside
-- the zones near the source; the base inventory counts what is in all of them.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"
require "ISUI/Animal/ISAddDesignationAnimalZoneUI"
require "TimedActions/WalkToTimedAction"
require "BaseUnloader_Scan"

local BU = BaseUnloader
local S = BU_Scan

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PAD = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ROW_HGT = FONT_HGT_SMALL * 2 + 8
local ZONE_COLOR = { r = 0.3, g = 0.8, b = 0.45, a = 0.35 }
local PICKED_COLOR = { r = 0.95, g = 0.85, b = 0.3, a = 0.55 }
local BAD_COLOR = { r = 0.9, g = 0.15, b = 0.15 }

BU_ZoneDraw = ISAddDesignationAnimalZoneUI:derive("BU_ZoneDraw")
BU_ZoneWindow = ISCollapsableWindow:derive("BU_ZoneWindow")
BU_ZoneWindow.instances = {}

-- drawing a piece -------------------------------------------------------------------------------

-- The vanilla tool, minus what makes it an animal zone: its own instance and
-- the animal-zone overlay are put back as they were, and the piece drawn is
-- named and saved by us.
function BU_ZoneDraw:new(x, y, player, parentUI)
    local seeing = player:isSeeDesignationZone()
    local vanillaInstance = ISAddDesignationAnimalZoneUI.instance
    local o = ISAddDesignationAnimalZoneUI.new(self, x, y, 340, 0, player)
    ISAddDesignationAnimalZoneUI.instance = vanillaInstance
    player:setSeeDesignationZone(seeing)
    o.parentUI = parentUI
    o.zoneColor = { r = ZONE_COLOR.r, g = ZONE_COLOR.g, b = ZONE_COLOR.b, a = 0.5 }
    return o
end

function BU_ZoneDraw:initialise()
    ISAddDesignationAnimalZoneUI.initialise(self)
    self.titleEntry:setName(BU.nextZoneName(BU.store(), getText("IGUI_BU_ZoneDefault")))
end

-- the drawn corners in order, and the floor
function BU_ZoneDraw:corners()
    local x1, y1, x2, y2 = self.startingX, self.startingY, self.endX, self.endY
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    local z = 0
    pcall(function() z = self.player:getCurrentSquare():getZ() end)
    return x1, y1, x2, y2, z
end

function BU_ZoneDraw:prerender()
    local x, y = PAD + 1, PAD + 1
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local title = getText("IGUI_BU_ZoneDrawTitle")
    self:drawText(title, (self.width - getTextManager():MeasureStringX(UIFont.Medium, title)) / 2, y, 1, 1, 1, 1, UIFont.Medium)
    y = y + FONT_HGT_MEDIUM + PAD
    local label = getText("IGUI_PvpZone_ZoneName")
    self:drawText(label, x, y + 2, 1, 1, 1, 1, UIFont.Small)
    self.titleEntry:setX(x + getTextManager():MeasureStringX(UIFont.Small, label) + PAD)
    self.titleEntry:setY(y)
    y = y + FONT_HGT_SMALL
    local howTo = getText("IGUI_DesignationZone_HowTo")
    if getJoypadData(self.playerNum) then
        howTo = getText(self.startingX == nil and "IGUI_DesignationZone_HowToJoypadStart" or "IGUI_DesignationZone_HowToJoypadEnd")
    end
    self:drawText(howTo, x, y + 2, 1, 1, 1, 1, UIFont.Small)
    self:setWidth(math.max(self.width, PAD * 2 + 2 + getTextManager():MeasureStringX(UIFont.Small, howTo)))
    self.cancel:setX(self.width - self.cancel.width - PAD - 1)
    y = y + FONT_HGT_SMALL + PAD
    if not self.startingX or not self.startRenderTile then
        self:highlightSquareAtMousePointer()
        self:highlightSquareAtStartPosition()
        self:updateButtons()
        return
    end
    local x1, y1, x2, y2, z = self:corners()
    local w, h = x2 - x1 + 1, y2 - y1 + 1
    local ok = BU.zoneSizeOk(w, h)
    -- the vanilla buttons and confirmation read these two
    self.widthCorrect, self.heightCorrect = ok, ok
    local wc = (w >= 1 and w <= BU.ZONE_MAX) and { r = 1, g = 1, b = 1 } or BAD_COLOR
    local hc = (h >= 1 and h <= BU.ZONE_MAX) and { r = 1, g = 1, b = 1 } or BAD_COLOR
    self:drawText(getText("IGUI_DesignationZone_Type_Width") .. ": " .. w, x, y + 2, wc.r, wc.g, wc.b, 1, UIFont.Small)
    y = y + FONT_HGT_SMALL
    self:drawText(getText("IGUI_DesignationZone_Type_Height") .. ": " .. h, x, y + 2, hc.r, hc.g, hc.b, 1, UIFont.Small)
    y = y + FONT_HGT_SMALL
    self:drawText(getText("IGUI_BU_ZoneMax", BU.ZONE_MAX), x, y + 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    local c = ok and self.zoneColor or { r = BAD_COLOR.r, g = BAD_COLOR.g, b = BAD_COLOR.b, a = self.zoneColor.a }
    addAreaHighlightForPlayer(self.playerNum, x1, y1, x2 + 1, y2 + 1, z, c.r, c.g, c.b, c.a)
    self:highlightSquareAtMousePointer()
    self:updateButtons()
end

-- the mouse came up (or the joypad said done): name the piece, then keep it
function BU_ZoneDraw:askCreateZone()
    if not self.drawTileMouse or not self.startingX or not self.widthCorrect or not self.heightCorrect then
        self:undisplay()
        return
    end
    self.drawTileMouse = false
    self.waitingConfirm = true
    local modal = ISTextBox:new(0, 0, 300, 180, getText("IGUI_BU_ZoneNameAsk"), self.titleEntry.name, self, BU_ZoneDraw.onNamed, self.playerNum)
    modal:initialise()
    modal:addToUIManager()
    modal.maxChars = 30
    if getJoypadData(self.playerNum) then
        modal:centerOnScreen(self.playerNum)
        modal.prevFocus = self
        setJoypadFocus(self.playerNum, modal)
    end
end

function BU_ZoneDraw:onNamed(button)
    self.waitingConfirm = false
    self.cancel.enable = true
    local name = button.internal == "OK" and (button.parent.entry:getText() or "") or ""
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then
        self:undisplay()
        return
    end
    local x1, y1, x2, y2, z = self:corners()
    BU.addZone(BU.store(), name, x1, y1, x2, y2, z)
    ISWorldObjectContextMenu.disableWorldMenu = false
    self:undisplay()
    self.parentUI:populateList()
end

-- the zone window -------------------------------------------------------------------------------

local function pieceSize(z) return (z.x2 - z.x1 + 1), (z.y2 - z.y1 + 1) end

function BU_ZoneWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local btnW = 0
    for _, key in ipairs({ "IGUI_BU_ZoneDraw", "IGUI_BU_Rename", "IGUI_BU_ZoneRemove", "IGUI_BU_ZoneWalk" }) do
        btnW = math.max(btnW, getTextManager():MeasureStringX(UIFont.Small, getText(key)) + 20)
    end
    local top = th + PAD + FONT_HGT_SMALL * 2 + PAD
    self.list = ISScrollingListBox:new(PAD, top, self.width - PAD * 2, self.height - top - BUTTON_HGT - PAD * 2 - rh)
    self.list:initialise()
    self.list:instantiate()
    self.list:setAnchorRight(true)
    self.list:setAnchorBottom(true)
    self.list:setFont(UIFont.Small, 3)
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.doDrawItem = BU_ZoneWindow.drawPiece
    self.list.window = self
    self.list:setOnMouseDoubleClick(self, BU_ZoneWindow.walkTo)
    self:addChild(self.list)

    local y = self.list:getBottom() + PAD
    local x = PAD
    local function button(key, fn, internal)
        local b = ISButton:new(x, y, btnW, BUTTON_HGT, getText(key), self, fn)
        b.internal = internal
        b:initialise()
        b:instantiate()
        b:setAnchorTop(false)
        b:setAnchorBottom(true)
        self:addChild(b)
        x = x + btnW + PAD
        return b
    end
    self.drawBtn = button("IGUI_BU_ZoneDraw", BU_ZoneWindow.onDraw)
    self.drawBtn.borderColor = { r = 0.4, g = 0.7, b = 0.4, a = 0.9 }
    self.renameBtn = button("IGUI_BU_Rename", BU_ZoneWindow.onRename)
    self.walkBtn = button("IGUI_BU_ZoneWalk", BU_ZoneWindow.onWalk)
    self.removeBtn = button("IGUI_BU_ZoneRemove", BU_ZoneWindow.onRemove)
    self.removeBtn:enableCancelColor()
    self:populateList()
end

-- every piece, by name then nearest first
function BU_ZoneWindow:populateList()
    if not self.list then return end
    local keep = self:selectedPiece()
    self.list:clear()
    local sq = S.squareOf(self.character)
    local pieces = {}
    for _, z in ipairs(BU.store().zones) do
        local d = sq and BU.areaDistance({ rects = { z } }, sq:getX(), sq:getY()) or 0
        pieces[#pieces + 1] = { zone = z, distance = d }
    end
    table.sort(pieces, function(a, b)
        if a.zone.name ~= b.zone.name then return a.zone.name < b.zone.name end
        return a.distance < b.distance
    end)
    for i, p in ipairs(pieces) do
        self.list:addItem(p.zone.name, p)
        if p.zone == keep then self.list.selected = i end
    end
    if self.list.selected > #self.list.items then self.list.selected = #self.list.items end
    -- an unloader window open on this base lists the new zones at once
    if BU_Window and BU_Window.rescanAll then BU_Window.rescanAll() end
end

function BU_ZoneWindow:selectedPiece()
    local item = self.list and self.list.items[self.list.selected]
    return item and item.item.zone or nil
end

function BU_ZoneWindow.drawPiece(list, y, item, alt)
    local p = item.item
    local z = p.zone
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), item.height, 0.3, 0.7, 0.35, 0.15)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), item.height, 0.06, 1, 1, 1)
    end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, list.borderColor.r, list.borderColor.g, list.borderColor.b)
    list:drawText(z.name, PAD, y + 4, 1, 1, 1, 1, UIFont.Small)
    local w, h = pieceSize(z)
    local line = getText("IGUI_BU_ZonePiece", w, h) .. ", " .. S.floorLabel(z.z) .. ", " .. getText("IGUI_BU_Away", math.floor(p.distance + 0.5))
    list:drawText(line, PAD, y + 6 + FONT_HGT_SMALL, 0.65, 0.65, 0.65, 1, UIFont.Small)
    return y + item.height
end

-- every piece on the character's floor lit on the ground, the picked one
-- brighter, each zone's name over its first piece there
function BU_ZoneWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.character:isDead() then self:close(); return end
    local floor = 0
    pcall(function() floor = self.character:getCurrentSquare():getZ() end)
    local picked = self:selectedPiece()
    for _, z in ipairs(BU.store().zones) do
        if z.z == floor and z ~= picked then
            addAreaHighlightForPlayer(self.playerNum, z.x1, z.y1, z.x2 + 1, z.y2 + 1, z.z, ZONE_COLOR.r, ZONE_COLOR.g, ZONE_COLOR.b, ZONE_COLOR.a)
        end
    end
    if picked and picked.z == floor then
        addAreaHighlightForPlayer(self.playerNum, picked.x1, picked.y1, picked.x2 + 1, picked.y2 + 1, picked.z, PICKED_COLOR.r, PICKED_COLOR.g, PICKED_COLOR.b, PICKED_COLOR.a)
    end
    local any = picked ~= nil
    self.renameBtn.enable, self.removeBtn.enable, self.walkBtn.enable = any, any, any
end

function BU_ZoneWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local y = self:titleBarHeight() + PAD
    self:drawText(getText("IGUI_BU_ZoneHelp1"), PAD, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
    self:drawText(getText("IGUI_BU_ZoneHelp2", S.floors()), PAD, y + FONT_HGT_SMALL, 0.6, 0.6, 0.6, 1, UIFont.Small)
    self:drawGroundNames()
end

function BU_ZoneWindow:drawGroundNames()
    if self.playerNum ~= 0 then return end
    pcall(function()
        local floor = self.character:getCurrentSquare():getZ()
        local zoom = getCore():getZoom(self.playerNum)
        local camX, camY = IsoCamera.getOffX(), IsoCamera.getOffY()
        local tm = getTextManager()
        local done = {}
        for _, z in ipairs(BU.store().zones) do
            if z.z == floor and not done[z.name] then
                done[z.name] = true
                local cx, cy = (z.x1 + z.x2 + 1) / 2, (z.y1 + z.y2 + 1) / 2
                local sx = (IsoUtils.XToScreen(cx, cy, floor, 0) - camX) / zoom
                local sy = (IsoUtils.YToScreen(cx, cy, floor, 0) - camY) / zoom
                local w = tm:MeasureStringX(UIFont.Medium, z.name)
                tm:DrawString(UIFont.Medium, sx - w / 2, sy, z.name, 1, 1, 1, 1)
            end
        end
    end)
end

function BU_ZoneWindow:onDraw()
    local ui = BU_ZoneDraw:new(getPlayerScreenLeft(self.playerNum) + 10, getPlayerScreenTop(self.playerNum) + 10, self.character, self)
    ui:initialise()
    ui:addToUIManager()
    self:setVisible(false)
    if getJoypadData(self.playerNum) then setJoypadFocus(self.playerNum, ui) end
end

function BU_ZoneWindow:onRename()
    local z = self:selectedPiece()
    if not z then return end
    local modal = ISTextBox:new(0, 0, 300, 180, getText("IGUI_BU_ZoneRenameAsk"), z.name, self, BU_ZoneWindow.onRenamed, self.playerNum, z)
    modal:initialise()
    modal:addToUIManager()
    modal.maxChars = 30
end

function BU_ZoneWindow:onRenamed(button, z)
    if button.internal ~= "OK" then return end
    local name = string.gsub(button.parent.entry:getText() or "", "^%s*(.-)%s*$", "%1")
    BU.renameZone(BU.store(), z, name)
    self:populateList()
end

function BU_ZoneWindow:onRemove()
    local z = self:selectedPiece()
    if not z then return end
    local w, h = pieceSize(z)
    local modal = ISModalDialog:new(0, 0, 320, 150, getText("IGUI_BU_ZoneRemoveAsk", z.name, w .. "x" .. h), true, self, BU_ZoneWindow.onRemoved, self.playerNum, z)
    modal:initialise()
    modal:addToUIManager()
end

function BU_ZoneWindow:onRemoved(button, z)
    if button.internal ~= "YES" then return end
    BU.removeZone(BU.store(), z)
    self:populateList()
end

-- the walkable square nearest the middle of a piece, on its floor
local function standingSquare(z)
    local cx, cy = math.floor((z.x1 + z.x2) / 2), math.floor((z.y1 + z.y2) / 2)
    local cell = getCell()
    local best, bestD
    for y = z.y1, z.y2 do
        for x = z.x1, z.x2 do
            local sq = cell:getGridSquare(x, y, z.z)
            if sq and not sq:isSolid() and not sq:isSolidTrans() and sq:TreatAsSolidFloor() then
                local d = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                if not bestD or d < bestD then best, bestD = sq, d end
            end
        end
    end
    return best
end

function BU_ZoneWindow:onWalk()
    self:walkTo(self.list.items[self.list.selected] and self.list.items[self.list.selected].item)
end

function BU_ZoneWindow:walkTo(p)
    if not p then return end
    local sq = standingSquare(p.zone)
    if not sq then
        pcall(function() HaloTextHelper.addBadText(self.character, getText("IGUI_BU_ZoneTooFar")) end)
        return
    end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(self.character, sq))
end

function BU_ZoneWindow:close()
    BU_ZoneWindow.instances[self.playerNum] = nil
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

function BU_ZoneWindow:new(x, y, width, height, character)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("IGUI_BU_ZoneTitle"))
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.minimumWidth = 420
    o.minimumHeight = 260
    o:setResizable(true)
    return o
end

function BU_ZoneWindow.open(character)
    local playerNum = character:getPlayerNum()
    local old = BU_ZoneWindow.instances[playerNum]
    if old then
        old:setVisible(true)
        old:bringToTop()
        return old
    end
    local x = getPlayerScreenLeft(playerNum) + 120
    local y = getPlayerScreenTop(playerNum) + 100
    local win = BU_ZoneWindow:new(x, y, 460, 380, character)
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    BU_ZoneWindow.instances[playerNum] = win
    return win
end
