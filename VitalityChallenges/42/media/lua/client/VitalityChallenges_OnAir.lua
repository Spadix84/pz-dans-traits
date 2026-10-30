-- The Last Broadcast: the desk. Right-click in the studio for tonight's show:
-- a small window with the listeners, the segments to put in the running order
-- (the ones that cannot go in tonight say why), and Go on air when the hour,
-- the room and the power allow it. The show is a timed action: each line goes
-- out on LBMW and over the character's head in turn, every few real seconds
-- by its length (time paused does not count). Walking off, or losing the
-- power, cuts it: the show does not count, and while it is still before seven
-- it can be started again.

require "ISUI/ISPanel"
require "TimedActions/ISBaseTimedAction"
require "VitalityChallenges_LastBroadcast"
local VC = VitalityChallenges
local B = VC.broadcast
local LB = VC.lastBroadcast

local W, PAD, GAP = 400, 14, 6
local REFRESH_MS = 500
local MAX_STEP_MS = 100   -- one update's share of the clock at most, so a pause does not count as air time

-- the action ------------------------------------------------------------------------------

VCOnAirAction = ISBaseTimedAction:derive("VCOnAirAction")

function VCOnAirAction:isValid()
    if self.started then return LB.canCarryOn(self.character) end
    return LB.blocked(self.character) == nil
end

function VCOnAirAction:start()
    self.started = true
    self.lines = LB.beginShow(self.character, self.order)
    self.index = 0
    self.wait = 0
    self.last = getTimestampMs()
end

function VCOnAirAction:update()
    local now = getTimestampMs()
    self.wait = self.wait - math.min(MAX_STEP_MS, now - self.last)
    self.last = now
    if self.wait > 0 then return end
    self.index = self.index + 1
    local line = self.lines[self.index]
    if not line then
        self:forceComplete()
        return
    end
    LB.airLine(self.character, line)
    self.wait = B.lineGap(line.text)
end

function VCOnAirAction:stop()
    if not self.ended then
        self.ended = true
        LB.endShow(self.character, self.order, false)
    end
    ISBaseTimedAction.stop(self)
end

function VCOnAirAction:perform()
    if not self.ended then
        self.ended = true
        LB.endShow(self.character, self.order, true)
    end
    ISBaseTimedAction.perform(self)
end

function VCOnAirAction:new(character, order)
    local o = ISBaseTimedAction.new(self, character)
    o.order = order
    o.maxTime = -1
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

-- the window ------------------------------------------------------------------------------

VCOnAirWindow = ISPanel:derive("VCOnAirWindow")

-- top to bottom: the title; the audience and the count; the segments to put in
-- tonight (with why one cannot go in); how every show opens and ends; whether
-- you can go on air now, and why not; the buttons
function VCOnAirWindow:createChildren()
    ISPanel.createChildren(self)
    local FONT_SMALL = getTextManager():getFontHeight(UIFont.Small)
    local FONT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
    local BOX = math.max(16, FONT_SMALL)      -- ISTickBox's height argument is the size of one box
    local BUTTON_H = math.max(25, FONT_SMALL + 8)
    local y = PAD
    local function label(font, r, g, b)
        local l = ISLabel:new(PAD, y, font == UIFont.Medium and FONT_MEDIUM or FONT_SMALL, "", r, g, b, 1, font, true)
        self:addChild(l)
        y = y + l.height + GAP
        return l
    end
    label(UIFont.Medium, 1, 1, 1):setName(getText("IGUI_VC_LB_WindowTitle"))
    y = y + GAP
    self.listenersLabel = label(UIFont.Small, 0.95, 0.85, 0.55)
    self.showsLabel = label(UIFont.Small, 0.95, 0.85, 0.55)
    y = y + GAP * 2
    label(UIFont.Small, 1, 1, 1):setName(getText("IGUI_VC_LB_Segments"))
    self.ticks = ISTickBox:new(PAD, y, W - PAD * 2, BOX, "", nil, nil)
    self.ticks:initialise()
    self:addChild(self.ticks)
    self.names = {}
    for i, id in ipairs(B.SEGMENTS) do
        self.names[i] = getText("IGUI_VC_LB_Seg_" .. id)
        self.ticks:addOption(self.names[i], id)
    end
    y = y + self.ticks:getHeight() + GAP
    self.whyLabel = label(UIFont.Small, 0.7, 0.7, 0.7)
    label(UIFont.Small, 0.6, 0.6, 0.6):setName(getText("IGUI_VC_LB_Frame"))
    y = y + GAP * 2
    self.statusLabel = label(UIFont.Small, 1, 1, 1)
    y = y + GAP
    self.goButton = ISButton:new(PAD, y, 140, BUTTON_H, getText("IGUI_VC_LB_GoOnAir"), self, VCOnAirWindow.onGo)
    self.goButton:initialise()
    self:addChild(self.goButton)
    self.closeButton = ISButton:new(W - PAD - 90, y, 90, BUTTON_H, getText("UI_Close"), self, VCOnAirWindow.close)
    self.closeButton:initialise()
    self:addChild(self.closeButton)
    self:setHeight(y + BUTTON_H + PAD)
    self.nextRefresh = 0
    self:refresh()
end

function VCOnAirWindow:refresh()
    local state = LB.state()
    if not state then return end
    self.listenersLabel:setName(getText("IGUI_VC_LB_Listeners", tostring(state.listeners or 0)))
    self.showsLabel:setName(getText("IGUI_VC_LB_Shows", tostring(state.shows or 0), tostring(B.SHOWS_TO_WIN)))
    local avail = B.available(state)
    local why = ""
    for i, id in ipairs(B.SEGMENTS) do
        local ok = avail[id] == true
        self.ticks:disableOption(self.names[i], not ok)
        if not ok then
            self.ticks:setSelected(i, false)
            if why == "" then why = getText(avail[id]) end
        end
    end
    self.whyLabel:setName(why)
    local blocked = LB.blocked(self.player)
    if blocked then
        self.statusLabel:setName(getText(blocked))
        self.statusLabel:setColor(1, 0.55, 0.45)
    else
        self.statusLabel:setName(getText("IGUI_VC_LB_Ready"))
        self.statusLabel:setColor(0.55, 0.9, 0.55)
    end
    self.goButton:setEnable(blocked == nil)
    self:fit()
end

-- wide enough for the longest line (labels do not wrap); the close button stays right
function VCOnAirWindow:fit()
    local need = W
    for _, child in pairs(self:getChildren()) do
        if child.Type == "ISLabel" then need = math.max(need, child:getX() + child:getWidth() + PAD) end
    end
    if need ~= self.width then
        self:setWidth(need)
        self.closeButton:setX(need - PAD - self.closeButton:getWidth())
    end
end

function VCOnAirWindow:update()
    ISPanel.update(self)
    local now = getTimestampMs()
    if now < self.nextRefresh then return end
    self.nextRefresh = now + REFRESH_MS
    self:refresh()
end

function VCOnAirWindow:onGo()
    if LB.blocked(self.player) then return end
    local avail = B.available(LB.state())
    local order = {}
    for i, id in ipairs(B.SEGMENTS) do
        if avail[id] == true and self.ticks:isSelected(i) then order[id] = true end
    end
    ISTimedActionQueue.add(VCOnAirAction:new(self.player, order))
    self:close()
end

function VCOnAirWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    VCOnAirWindow.instance = nil
end

function VCOnAirWindow:new(x, y, player)
    local o = ISPanel.new(self, x, y, W, 200)
    o.player = player
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    return o
end

function VCOnAirWindow.open(player)
    if VCOnAirWindow.instance then VCOnAirWindow.instance:close() end
    local x = (getCore():getScreenWidth() - W) / 2
    local y = getCore():getScreenHeight() / 3
    local w = VCOnAirWindow:new(x, y, player)
    w:initialise()
    w:addToUIManager()
    VCOnAirWindow.instance = w
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if player and LB.inStudio(player) then
        context:addOption(getText("IGUI_VC_LB_Menu"), player, VCOnAirWindow.open)
    end
end)
