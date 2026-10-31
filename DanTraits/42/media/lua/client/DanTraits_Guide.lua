-- Project Zomboid Vitality Project: the Guide tab of the character window.
--
-- An in-game overview of every system and how they fit together, for everyone
-- (the Notes tab beside it is per character and per condition). Left, the list
-- of pages; right, the page as rich text, with its picture above the text when
-- media/ui/Guide/<id>.png exists. The pages are DanTraits_GuideData.pages
-- (DanTraits_GuideData.lua, plain lines: "## heading", "- bullet", a paragraph);
-- the last page is What's New (DanTraits_GuideData.whatsNew), which
-- DanTraits_WhatsNew.lua also shows once after an update.
--
-- The tab is added when the window is built (createChildren), like the Notes
-- tab. DanTraits_OpenGuide(playerNum, pageId) opens the window on the tab and
-- that page (the What's New dialog's button). Neat Rocco's icon bar gets a book.
require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISRichTextPanel"
require "XpSystem/ISUI/ISCharacterInfoWindow"

local GD_LIST_MIN = 120     -- px, the page list: as wide as its longest title, within these
local GD_LIST_MAX = 220
local GD_TEXT_MIN = 260     -- px, the text column at least (the window widens for it;
                            -- vanilla's tabs only ever widen the window, so keep it modest)
local GD_GAP      = 6       -- px between the list and the text
local GD_H        = 340     -- the window's height on this tab (exact, as vanilla's info
                            -- and health tabs set theirs; the text scrolls). All of these
                            -- are vanilla pixels: Neat Rocco multiplies them by its font
                            -- factor, so a size that looks modest in vanilla stays in
                            -- proportion with the other tabs there.
local GD_IMAGE_W  = 460     -- px, a page's picture at most (narrower in a narrow column)
local GD_ICON     = "Item_Book"   -- the tab's icon on Neat Rocco's bar
local GD_HEAD_RGB = "<RGB:0.95,0.78,0.45>"

local function t(key) return getText("UI_DanTraits_guide_" .. key) end

-- a page's picture, looked up once (none ships yet; a miss is remembered, so
-- the texture loader is not asked again on every redraw)
local textures = {}
local function pictureOf(id)
    local tex = textures[id]
    if tex == nil then
        tex = getTexture("media/ui/Guide/" .. id .. ".png") or false
        textures[id] = tex
    end
    return tex or nil
end
function DanTraits_GuideForgetPictures() textures = {} end   -- tests

-- a page's lines as the rich text panel wants them; the picture no wider than imageW
local function richText(page, imageW)
    local out = {}
    local tex = pictureOf(page.id)
    if tex then
        local w = math.max(120, math.min(GD_IMAGE_W, imageW or GD_IMAGE_W))
        local h = w * 9 / 16
        pcall(function()
            local tw, th = tex:getWidth(), tex:getHeight()
            if tw and th and tw > 0 then h = math.floor(w * th / tw + 0.5) end
        end)
        out[#out + 1] = "<IMAGECENTRE:media/ui/Guide/" .. page.id .. ".png," .. w .. "," .. h .. "> <LINE> <LINE> "
    end
    out[#out + 1] = "<SIZE:medium>" .. page.title .. " <SIZE:small> <LINE> <LINE> "
    for _, line in ipairs(page.body or {}) do
        if line == "" then
            out[#out + 1] = "<LINE> "
        elseif string.sub(line, 1, 3) == "## " then
            out[#out + 1] = GD_HEAD_RGB .. string.sub(line, 4) .. " <RGB:1,1,1> <LINE> "
        elseif string.sub(line, 1, 2) == "- " then
            out[#out + 1] = "  - " .. string.sub(line, 3) .. " <LINE> "
        else
            out[#out + 1] = line .. " <LINE> "
        end
    end
    return table.concat(out)
end
DanTraits_GuideRichText = richText

-- every page, What's New last
local function pages()
    local list = {}
    for _, p in ipairs(DanTraits_GuideData and DanTraits_GuideData.pages or {}) do list[#list + 1] = p end
    local wn = DanTraits_GuideData and DanTraits_GuideData.whatsNew
    if wn and wn.lines then
        list[#list + 1] = { id = "whatsnew", title = getText("UI_DanTraits_whatsnew_Page", tostring(wn.version or "")), body = wn.lines }
    end
    return list
end
DanTraits_GuidePages = pages

-- the tab ---------------------------------------------------------------------

DanTraitsGuideView = ISPanelJoypad:derive("DanTraitsGuideView")

function DanTraitsGuideView:new(x, y, width, height, playerNum)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.pages = pages()
    return o
end

function DanTraitsGuideView:createChildren()
    ISPanelJoypad.createChildren(self)
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local widest = 0
    for _, page in ipairs(self.pages) do
        widest = math.max(widest, getTextManager():MeasureStringX(UIFont.Small, page.title or ""))
    end
    self.listW = math.max(GD_LIST_MIN, math.min(GD_LIST_MAX, widest + 16))
    self.list = ISScrollingListBox:new(0, 0, self.listW, self.height)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = fontHgt + 8
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list:setOnMouseDownFunction(self, self.onPagePicked)
    for _, page in ipairs(self.pages) do self.list:addItem(page.title, page) end
    self:addChild(self.list)
    self.text = ISRichTextPanel:new(self.listW + GD_GAP, 0, self.width - self.listW - GD_GAP, self.height)
    self.text:initialise()
    self.text:instantiate()
    self.text.marginLeft, self.text.marginRight = 12, 12
    self.text.background = true
    self.text.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    self.text.clip = true
    self.text.autosetheight = false
    self.text:addScrollBars()
    self:addChild(self.text)
    self:showPage(self.pages[1] and self.pages[1].id)
end

-- the picked page: the list row selected, the text set and laid out again
function DanTraitsGuideView:showPage(id)
    local page
    for i, p in ipairs(self.pages) do
        if p.id == id then
            page = p
            if self.list then self.list.selected = i end
        end
    end
    if not page or not self.text then return end
    self.shown = page.id
    -- the picture fits the text column (margins and the scroll bar off)
    local imageW = (self.text.width or 0) - (self.text.marginLeft or 0) - (self.text.marginRight or 0) - 16
    DanTraits_Guard("guide page", function()
        self.text:setText(richText(page, imageW))
        self.text:paginate()
        if self.text.setYScroll then self.text:setYScroll(0) end
    end)
end

function DanTraitsGuideView:onPagePicked(item)
    if item then self:showPage(item.id) end
end

-- the window stays on the screen (it sits at the right edge for most players,
-- and a wider tab would push its far side, and Neat Rocco's close button with
-- it, off the edge). The window is the top of the parent chain: vanilla puts
-- the view in a tab panel in the window, Neat Rocco straight in the window.
local function keepOnScreen(view)
    local win = view.parent
    while win and win.parent do win = win.parent end
    if not (win and win.getX and win.setX and getCore) then return end
    pcall(function()
        local core = getCore()
        local sw, sh = core:getScreenWidth(), core:getScreenHeight()
        local x, y = win:getX(), win:getY()
        local nx = math.max(0, math.min(x, sw - win:getWidth()))
        local ny = math.max(0, math.min(y, sh - win:getHeight()))
        if nx ~= x then win:setX(nx) end
        if ny ~= y then win:setY(ny) end
    end)
end

-- the children follow the tab's size (the window can grow for another tab)
function DanTraitsGuideView:prerender()
    ISPanelJoypad.prerender(self)
    -- the window fits the tab, as vanilla's tabs do: wide enough for the list
    -- and a GD_TEXT_MIN column (vanilla widens, never narrows), exactly GD_H
    -- tall (first, so the children are laid out for that size in the same frame)
    local listW = self.listW or GD_LIST_MIN
    self:setWidthAndParentWidth(math.max(self.width, listW + GD_GAP + GD_TEXT_MIN))
    self:setHeightAndParentHeight(GD_H)
    if self.list and (self.laidW ~= self.width or self.laidH ~= self.height) then
        self.laidW, self.laidH = self.width, self.height
        self.list:setHeight(self.height)
        self.text:setX(listW + GD_GAP)
        self.text:setWidth(self.width - listW - GD_GAP)
        self.text:setHeight(self.height)
        self:showPage(self.shown)       -- set again: the picture width follows the column
        keepOnScreen(self)
    end
end

-- the shoulder buttons switch tabs, B lets go (as vanilla's tabs)
function DanTraitsGuideView:onJoypadDown(button)
    if button == Joypad.BButton then
        getPlayerInfoPanel(self.playerNum):toggleView(t("Tab"))
        setJoypadFocus(self.playerNum, nil)
    end
    if button == Joypad.LBumper or button == Joypad.RBumper then
        getPlayerInfoPanel(self.playerNum):onJoypadDown(button)
    end
end

-- Neat Rocco's icon bar: our tab's button, found by the view it shows
local function setIcon(window, view)
    if not window.tabButtons or not window.subPanels then return end
    local tex = getTexture(GD_ICON)
    if not tex then return end
    for n, panel in pairs(window.subPanels) do
        local btn = window.tabButtons[n]
        if panel == view and btn and btn.setIcon then btn:setIcon(tex) end
    end
end

local function addTab()
    DanTraits_Wrap(ISCharacterInfoWindow, "createChildren", "guide-tab", function(original, self, ...)
        local result = original(self, ...)
        DanTraits_Guard("guide tab", function()
            if not self.panel then return end
            local view = DanTraitsGuideView:new(0, 8, self.width, self.height - 8, self.playerNum)
            view:initialise()
            view.infoText = getTextOrNull("UI_DanTraits_guide_Info")
            self.panel:addView(t("Tab"), view)
            self.danTraitsGuideView = view
            DanTraits_Later(1, function() setIcon(self, view) end, "guide icon")
        end)
        return result
    end)
end

-- the character window, on the Guide tab, on that page (the What's New dialog's button)
function DanTraits_OpenGuide(playerNum, pageId)
    return DanTraits_Guard("open guide", function()
        local window = getPlayerInfoPanel(playerNum or 0)
        if not window or not window.panel then return end
        -- as vanilla's toggle: closing takes the window out of the UI manager
        if not (window.getIsVisible and window:getIsVisible()) then
            window:setVisible(true)
            if window.addToUIManager then window:addToUIManager() end
        end
        window.panel:activateView(t("Tab"))
        local view = window.danTraitsGuideView
        if view and pageId then view:showPage(pageId) end
    end)
end

addTab()
Events.OnGameStart.Add(addTab)
