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

local GD_LIST_W   = 190     -- px, the page list
local GD_GAP      = 6       -- px between the list and the text
local GD_MIN_W    = 760     -- the window grows to at least this for the tab
local GD_MIN_H    = 540
local GD_IMAGE_W  = 460     -- px, a page's picture
local GD_ICON     = "Item_Book"   -- the tab's icon on Neat Rocco's bar
local GD_HEAD_RGB = "<RGB:0.95,0.78,0.45>"

local function t(key) return getText("UI_DanTraits_guide_" .. key) end

-- a page's lines as the rich text panel wants them
local function richText(page)
    local out = {}
    local tex = getTexture("media/ui/Guide/" .. page.id .. ".png")
    if tex then
        local w, h = GD_IMAGE_W, GD_IMAGE_W * 9 / 16
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
    self.list = ISScrollingListBox:new(0, 0, GD_LIST_W, self.height)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = fontHgt + 8
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list:setOnMouseDownFunction(self, self.onPagePicked)
    for _, page in ipairs(self.pages) do self.list:addItem(page.title, page) end
    self:addChild(self.list)
    self.text = ISRichTextPanel:new(GD_LIST_W + GD_GAP, 0, self.width - GD_LIST_W - GD_GAP, self.height)
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
    DanTraits_Guard("guide page", function()
        self.text:setText(richText(page))
        self.text:paginate()
        if self.text.setYScroll then self.text:setYScroll(0) end
    end)
end

function DanTraitsGuideView:onPagePicked(item)
    if item then self:showPage(item.id) end
end

-- the children follow the tab's size (the window can grow for another tab)
function DanTraitsGuideView:prerender()
    ISPanelJoypad.prerender(self)
    -- the window fits the tab, as vanilla's protection tab does (first, so the
    -- children are laid out for the grown size in the same frame)
    self:setWidthAndParentWidth(math.max(self.width, GD_MIN_W))
    self:setHeightAndParentHeight(math.max(self.height, GD_MIN_H))
    if self.list and (self.laidW ~= self.width or self.laidH ~= self.height) then
        self.laidW, self.laidH = self.width, self.height
        self.list:setHeight(self.height)
        self.text:setX(GD_LIST_W + GD_GAP)
        self.text:setWidth(self.width - GD_LIST_W - GD_GAP)
        self.text:setHeight(self.height)
        DanTraits_Guard("guide relayout", function() self.text:paginate() end)
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
        window.panel:activateView(t("Tab"))
        window:setVisible(true)
        local view = window.danTraitsGuideView
        if view and pageId then view:showPage(pageId) end
    end)
end

addTab()
Events.OnGameStart.Add(addTab)
