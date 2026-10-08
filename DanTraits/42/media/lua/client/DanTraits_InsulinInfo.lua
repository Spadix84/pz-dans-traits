-- Project Zomboid Vitality Project: insulin on a food's or a drink's tooltip.
-- A Type 1 character with First Aid 3 or more, or who has read Living With
-- Type 1, sees under a food's tooltip (or a sugary drink's: the whole bottle,
-- carton or mug) how fast its sugar hits and how many
-- insulin doses cover it (DanTraits_DiaFoodLines in DanTraits_Diabetes.lua
-- decides the words). A glucose meter's tooltip gets its last reading the
-- same way, with the advice it gave then (DanTraits_DiaMeterLines). The vanilla tooltip is drawn by Java from the item, so
-- the lines go in a strip drawn on below it. Near the bottom of the screen the
-- strip can run off it (the game places the tooltip before the strip is known).
require "ISUI/ISToolTipInv"
require "DanTraits"

local PAD_X, PAD_Y = 5, 4
local COLOUR = { r = 0.55, g = 0.8, b = 1, a = 1 }   -- the meter-blue of the mod's diabetes items

local function tooltipPlayer(self)
    local p
    pcall(function() p = self.tooltip:getCharacter() end)
    return p or getPlayer()
end

local function drawLines(self, lines)
    local font = UIFont.Small
    local tm = getTextManager()
    local lineH = tm:getFontHeight(font)
    local width = self.width
    for _, text in ipairs(lines) do width = math.max(width, tm:MeasureStringX(font, text) + PAD_X * 2) end
    local top = self.height
    local extra = #lines * lineH + PAD_Y * 2
    self:drawRect(0, top, width, extra, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, top - 1, width, extra + 1, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    for i, text in ipairs(lines) do
        self:drawText(text, PAD_X, top + PAD_Y + (i - 1) * lineH, COLOUR.r, COLOUR.g, COLOUR.b, COLOUR.a, font)
    end
end

-- the lines are worked out at most twice a second per item: the top tier runs
-- a four-hour forecast or two (DanTraits_DiaParts), and render is every frame
local CACHE_MS = 500
local cache = { item = nil, at = 0, lines = nil }
local function linesFor(player, item)
    local now = getTimestampMs and getTimestampMs() or 0
    if cache.item == item and now - cache.at < CACHE_MS then return cache.lines end
    local lines
    pcall(function() lines = DanTraits_DiaFoodLines(player, item) end)
    if not lines and DanTraits_DiaMeterLines then pcall(function() lines = DanTraits_DiaMeterLines(item) end) end
    cache.item, cache.at, cache.lines = item, now, lines
    return lines
end

DanTraits_Wrap(ISToolTipInv, "render", "insulin-info", function(original, self, ...)
    original(self, ...)
    if not self.item or (ISContextMenu.instance and ISContextMenu.instance.visibleCheck) then return end
    if not DanTraits_DiaFoodLines then return end
    local lines = linesFor(tooltipPlayer(self), self.item)
    if lines and #lines > 0 then pcall(drawLines, self, lines) end
end)
