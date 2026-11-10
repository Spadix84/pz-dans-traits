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
--                a strip drawn on below it (DanShared_Tooltip.lua); near
--                the bottom of the screen it can run off.

require "ISUI/ISEquippedItem"
require "DanShared_Tooltip"
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

-- copies[entry]: the selected items that are that entry, so a title can be
-- set Unwanted by what is written on the copies in hand (a magazine's issue)
local function onCollect(entries, player, on, copies)
    for _, e in ipairs(entries) do C.set(player, e, on, copies and copies[e]) end
    local win = DVF_CollectionWindow.instances[player:getPlayerNum()]
    if win then win:changed() end
end

function C.onContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local entries, copies, allOwned = {}, {}, true
    for _, item in ipairs(ISInventoryPane.getActualItems(items)) do
        local e = C.entryFor(item)
        if e then
            if not copies[e] then
                copies[e] = {}
                entries[#entries + 1] = e
            end
            table.insert(copies[e], item)
            if C.needsAdding(player, e, item) then allOwned = false end
        end
    end
    if #entries == 0 then return end
    if allOwned then
        context:addOption(getText("ContextMenu_DVF_CollectionRemove"), entries, onCollect, player, false)
    else
        -- adds the ones not yet ticked; the ones already in stay in, and an
        -- issue of a ticked magazine that is not Unwanted yet is set so
        context:addOption(getText("ContextMenu_DVF_CollectionAdd"), entries, onCollect, player, true, copies)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(C.onContextMenu)

-- tooltip -----------------------------------------------------------------------

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

DanShared_Tooltip.add("collection", 30, function(player, item)
    local text, r, g, b = C.tooltipLine(player, item)
    if text then return { { text, r, g, b } } end
end)
