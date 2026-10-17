-- The extra lines under an item's tooltip, shared by Vitality (the reading
-- lines) and Dan's Vanilla Fixes (item info, the collection line). Both mods
-- ship this same file at the same path, so with both on the game loads one
-- copy; the global and the wrap flag keep it to one strip even if it ran
-- twice. Keep the two copies identical (tests/test_iteminfo.lua checks).
--
-- A feature registers a source: DanShared_Tooltip.add(id, order, fn(player, item)
-- -> { { text, r, g, b }, ... } or nil). Every source's lines go in one strip
-- drawn under vanilla's tooltip, lowest order first, so two features never
-- draw over each other. The Java tooltip is drawn from the item, so the strip
-- sits below it; near the bottom of the screen it can run off.
require "ISUI/ISToolTipInv"

DanShared_Tooltip = DanShared_Tooltip or { sources = {} }
local T = DanShared_Tooltip

local PAD_X, PAD_Y = 5, 4

function T.add(id, order, fn)
    for i, s in ipairs(T.sources) do
        if s.id == id then table.remove(T.sources, i) break end
    end
    T.sources[#T.sources + 1] = { id = id, order = order, fn = fn }
    table.sort(T.sources, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
end

-- every source's lines for this item, or nil
function T.lines(player, item)
    if not player or not item then return nil end
    local all = {}
    for _, s in ipairs(T.sources) do
        local ok, lines = pcall(s.fn, player, item)
        if ok and type(lines) == "table" then
            for _, line in ipairs(lines) do all[#all + 1] = line end
        end
    end
    return #all > 0 and all or nil
end

local function tooltipPlayer(self)
    local p
    pcall(function() p = self.tooltip:getCharacter() end)
    return p or getSpecificPlayer(0)
end

local function drawLines(self, lines)
    local font = UIFont.Small
    local tm = getTextManager()
    local width = self.width
    for _, line in ipairs(lines) do
        width = math.max(width, tm:MeasureStringX(font, line[1]) + PAD_X * 2)
    end
    local lineH = tm:getFontHeight(font)
    local top = self.height
    local extra = lineH * #lines + PAD_Y * 2
    self:drawRect(0, top, width, extra, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, top - 1, width, extra + 1, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local y = top + PAD_Y
    for _, line in ipairs(lines) do
        self:drawText(line[1], PAD_X, y, line[2], line[3], line[4], 1, font)
        y = y + lineH
    end
end

if not ISToolTipInv.danSharedTooltipWrapped then
    ISToolTipInv.danSharedTooltipWrapped = true
    local vanillaRender = ISToolTipInv.render
    function ISToolTipInv:render()
        vanillaRender(self)
        if not self.item or (ISContextMenu.instance and ISContextMenu.instance.visibleCheck) then return end
        local ok, lines = pcall(T.lines, tooltipPlayer(self), self.item)
        if ok and lines then pcall(drawLines, self, lines) end
    end
end
