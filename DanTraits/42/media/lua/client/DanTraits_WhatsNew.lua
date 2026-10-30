-- Project Zomboid Vitality Project: What's New, once per update.
--
-- The first time a game loads after the mod's version changed, a small window
-- shows the headline changes (DanTraits_GuideData.whatsNew, the same page the
-- Guide tab keeps last) with Open the guide and Close. Closing it, either way,
-- remembers the version in the Lua folder (~/Zomboid/Lua/DanTraits_whatsnew.txt),
-- so it is once per install, not per character or save. "Don't show these
-- again" writes "never". The version compared is the one the game reports from
-- mod.info (getModInfoByID), the notes' own when that is not available.
-- Nothing in multiplayer clients' way: it shows for the local player 0 only,
-- a few seconds after the game starts.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"

local WN_FILE   = "DanTraits_whatsnew.txt"
local WN_W, WN_H = 560, 460
local WN_PAD    = 10
local WN_DELAY  = 180      -- ticks after the game starts (the HUD is up by then)

local function t(key) return getText("UI_DanTraits_whatsnew_" .. key) end

-- the installed version: mod.info's, else the notes' own
function DanTraits_WhatsNewVersion()
    local v
    pcall(function()
        local info = getModInfoByID and getModInfoByID("DanTraits")
        if info and info.getModVersion then v = info:getModVersion() end
    end)
    if type(v) ~= "string" or v == "" then
        v = DanTraits_GuideData and DanTraits_GuideData.whatsNew and DanTraits_GuideData.whatsNew.version
    end
    return v
end

-- the version last shown, or "never", or nil
local function readSeen()
    local seen
    pcall(function()
        local reader = getFileReader(WN_FILE, true)
        if not reader then return end
        local line = reader:readLine()
        reader:close()
        if line then seen = string.match(line, "^%s*(.-)%s*$") end
    end)
    if seen == "" then seen = nil end
    return seen
end

local function writeSeen(value)
    pcall(function()
        local writer = getFileWriter(WN_FILE, true, false)
        writer:write(tostring(value) .. "\n")
        writer:close()
    end)
end

-- does the dialog show for this version, given what was last seen?
function DanTraits_WhatsNewDue(seen, version)
    if not version or version == "" then return false end
    if seen == "never" then return false end
    return seen ~= version
end

-- the window -------------------------------------------------------------------

DanTraitsWhatsNew = ISCollapsableWindow:derive("DanTraitsWhatsNew")
DanTraitsWhatsNew.instance = nil

function DanTraitsWhatsNew:new(playerNum, version)
    local w, h = WN_W, WN_H
    local x, y = 100, 100
    pcall(function()
        x = math.floor((getCore():getScreenWidth() - w) / 2)
        y = math.floor((getCore():getScreenHeight() - h) / 2)
    end)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o:setTitle(getText("UI_DanTraits_whatsnew_Title", tostring(version or "")))
    o.playerNum = playerNum
    o.version = version
    o.resizable = false
    o.pin = true
    return o
end

function DanTraitsWhatsNew:createChildren()
    ISCollapsableWindow.createChildren(self)
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local btnHgt = math.max(25, fontHgt + 6)
    local top = self:titleBarHeight() + WN_PAD
    local bottom = self.height - WN_PAD - btnHgt
    self.text = ISRichTextPanel:new(WN_PAD, top, self.width - WN_PAD * 2, bottom - WN_PAD - fontHgt - 6 - top)
    self.text:initialise()
    self.text:instantiate()
    self.text.marginLeft, self.text.marginRight = 12, 12
    self.text.background = true
    self.text.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    self.text.clip = true
    self.text.autosetheight = false
    self.text:addScrollBars()
    self:addChild(self.text)
    local wn = DanTraits_GuideData and DanTraits_GuideData.whatsNew or { lines = {} }
    local page = { id = "whatsnew", title = getText("UI_DanTraits_whatsnew_Page", tostring(self.version or "")), body = wn.lines }
    DanTraits_Guard("whats new text", function()
        self.text:setText(DanTraits_GuideRichText and DanTraits_GuideRichText(page) or table.concat(wn.lines or {}, " <LINE> "))
        self.text:paginate()
    end)
    self.never = ISTickBox:new(WN_PAD, bottom - fontHgt - 6, self.width - WN_PAD * 2, fontHgt + 4, "", nil, nil)
    self.never:initialise()
    self.never:instantiate()
    self.never:addOption(t("Never"))
    self:addChild(self.never)
    local openW = getTextManager():MeasureStringX(UIFont.Small, t("Open")) + 24
    self.openBtn = ISButton:new(WN_PAD, bottom, openW, btnHgt, t("Open"), self, DanTraitsWhatsNew.onOpen)
    self.openBtn:initialise()
    self.openBtn:instantiate()
    self:addChild(self.openBtn)
    local closeW = math.max(90, getTextManager():MeasureStringX(UIFont.Small, t("Close")) + 24)
    self.closeBtn = ISButton:new(self.width - WN_PAD - closeW, bottom, closeW, btnHgt, t("Close"), self, DanTraitsWhatsNew.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)
end

function DanTraitsWhatsNew:remember()
    local never = false
    pcall(function() never = self.never and self.never:isSelected(1) == true end)
    writeSeen(never and "never" or (self.version or ""))
end

function DanTraitsWhatsNew:onOpen()
    self:close()
    if DanTraits_OpenGuide then DanTraits_OpenGuide(self.playerNum, "whatsnew") end
end

function DanTraitsWhatsNew:onClose() self:close() end

-- the X too: every way out remembers the version
function DanTraitsWhatsNew:close()
    self:remember()
    DanTraitsWhatsNew.instance = nil
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

function DanTraitsWhatsNew.show(playerNum, version)
    if DanTraitsWhatsNew.instance then return DanTraitsWhatsNew.instance end
    local win = DanTraitsWhatsNew:new(playerNum, version)
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    DanTraitsWhatsNew.instance = win
    return win
end

-- after the game starts: due or not
local function onGameStart()
    local version = DanTraits_WhatsNewVersion()
    if not DanTraits_WhatsNewDue(readSeen(), version) then return end
    local wn = DanTraits_GuideData and DanTraits_GuideData.whatsNew
    if not wn or not wn.lines or #wn.lines == 0 then return end
    DanTraits_Later(WN_DELAY, function()
        local player = getSpecificPlayer(0)
        if player and not player:isDead() then DanTraitsWhatsNew.show(0, version) end
    end, "whats new")
end
Events.OnGameStart.Add(function() DanTraits_Guard("whats new", onGameStart) end)
