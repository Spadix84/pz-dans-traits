-- Dan's Vanilla Fixes: the ways into the collection checklist (the rules are
-- in shared/DansVanillaFixes_Collection.lua, the window in
-- client/DansVanillaFixes_CollectionUI.lua).
--
--   sidebar      a clipboard button under the vanilla ones opens and closes
--                the window; it lights up while the window is open
--   right-click  "Add to collection" / "Remove from collection" on anything
--                that is on the list (every selected item)
--   tooltip      a line under the vanilla tooltip: green "In your
--                collection", or grey "Not in your collection yet". The
--                tooltip is drawn by Java from the item, so the line goes in
--                a strip drawn on below it; near the bottom of the screen it
--                can run off.

require "ISUI/ISEquippedItem"
require "ISUI/ISToolTipInv"
require "ISUI/ISInventoryPane"
require "DansVanillaFixes_Collection"
require "DansVanillaFixes_CollectionUI"

local C = DVF_Collection

-- sidebar -----------------------------------------------------------------------

-- the icon size the sidebar uses (vanilla's setTextureWidth, a local there)
function C.sidebarSize()
    local size = getCore():getOptionSidebarSize()
    if size == 6 then size = getCore():getOptionFontSizeReal() - 1 end
    local width = ({ [2] = 64, [3] = 80, [4] = 96, [5] = 128 })[size] or 48
    return width, width * 0.75
end

local function icon(on, width)
    return getTexture("media/ui/DVF/Collection_" .. (on and "On" or "Off") .. "_" .. width .. ".png")
end

local function onSidebar(sidebar)
    DVF_CollectionWindow.toggle(sidebar.chr)
end

local function addButton(sidebar)
    local w, h = C.sidebarSize()
    local btn = ISButton:new(0, sidebar:getHeight() + 15, w, h, "", sidebar, onSidebar)
    btn:setImage(icon(false, w))
    btn.internal = "DVF_COLLECTION"
    btn:initialise()
    btn:instantiate()
    btn:setDisplayBackground(false)
    btn:ignoreWidthChange()
    btn:ignoreHeightChange()
    sidebar:addChild(btn)
    sidebar:addMouseOverToolTipItem(btn, getText("IGUI_DVF_Collection_Title"))
    sidebar.dvfCollectionBtn = btn
    sidebar.dvfCollectionIcons = { [false] = icon(false, w), [true] = icon(true, w) }
    sidebar:shrinkWrap()
end

if not ISEquippedItem.dvfCollectionWrapped then
    ISEquippedItem.dvfCollectionWrapped = true

    local vanillaInit = ISEquippedItem.initialise
    function ISEquippedItem:initialise()
        vanillaInit(self)
        -- split-screen players 2-4 get no sidebar buttons from vanilla either
        if self.invBtn then
            local ok, err = pcall(addButton, self)
            if not ok then print("[DansVanillaFixes] collection sidebar button: " .. tostring(err)) end
        end
    end

    local vanillaPrerender = ISEquippedItem.prerender
    function ISEquippedItem:prerender()
        vanillaPrerender(self)
        local btn = self.dvfCollectionBtn
        if btn and self.dvfCollectionIcons then
            btn:setImage(self.dvfCollectionIcons[DVF_CollectionWindow.isOpen(self.chr:getPlayerNum())])
        end
    end
end

-- right-click -------------------------------------------------------------------

local function onCollect(entries, player, on)
    for _, e in ipairs(entries) do C.set(player, e, on) end
    local win = DVF_CollectionWindow.instances[player:getPlayerNum()]
    if win then win:changed() end
end

function C.onContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local entries, seen, allOwned = {}, {}, true
    for _, item in ipairs(ISInventoryPane.getActualItems(items)) do
        local e = C.entryFor(item)
        if e and not seen[e] then
            seen[e] = true
            entries[#entries + 1] = e
            if not C.has(player, e) then allOwned = false end
        end
    end
    if #entries == 0 then return end
    if allOwned then
        context:addOption(getText("ContextMenu_DVF_CollectionRemove"), entries, onCollect, player, false)
    else
        -- adds the ones not yet ticked; the ones already in stay in
        context:addOption(getText("ContextMenu_DVF_CollectionAdd"), entries, onCollect, player, true)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(C.onContextMenu)

-- tooltip -----------------------------------------------------------------------

local PAD_X, PAD_Y = 5, 4

local function tooltipPlayer(self)
    local p
    pcall(function() p = self.tooltip:getCharacter() end)
    return p or getSpecificPlayer(0)
end

-- the line for an item on the list, or nil
function C.tooltipLine(player, item)
    local e = C.entryFor(item)
    if not e or not player then return nil end
    if C.has(player, e) then
        local g = getCore():getGoodHighlitedColor()
        return getText("IGUI_DVF_Collection_Have"), g:getR(), g:getG(), g:getB()
    end
    return getText("IGUI_DVF_Collection_Missing"), 0.6, 0.6, 0.6
end

local function drawLine(self, text, r, g, b)
    local font = UIFont.Small
    local tm = getTextManager()
    local width = math.max(self.width, tm:MeasureStringX(font, text) + PAD_X * 2)
    local top = self.height
    local extra = tm:getFontHeight(font) + PAD_Y * 2
    self:drawRect(0, top, width, extra, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, top - 1, width, extra + 1, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(text, PAD_X, top + PAD_Y, r, g, b, 1, font)
end

if not ISToolTipInv.dvfCollectionWrapped then
    ISToolTipInv.dvfCollectionWrapped = true
    local vanillaRender = ISToolTipInv.render
    function ISToolTipInv:render()
        vanillaRender(self)
        if not self.item or (ISContextMenu.instance and ISContextMenu.instance.visibleCheck) then return end
        local ok, text, r, g, b = pcall(C.tooltipLine, tooltipPlayer(self), self.item)
        if ok and text then pcall(drawLine, self, text, r, g, b) end
    end
end
