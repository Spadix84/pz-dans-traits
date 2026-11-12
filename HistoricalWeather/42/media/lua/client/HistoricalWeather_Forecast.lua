-- Historical Weather: the Forecast tab of the character window (sandbox option Forecast
-- Calendar, off by default).
--
-- A calendar of the next 30 days, a week to a row: each day's sky as an icon and its high
-- and low. Point at a day for its line underneath (today's when the mouse is elsewhere):
-- the sky in words, the high and low, the record's rain or snow, morning fog. The days come
-- from HistoricalWeather.day (shared), which reads the same hours the game is given, so the
-- calendar is never wrong. Days outside the record, or with no rain figure, show a "?": the
-- game's own weather. Fahrenheit and inches, or Celsius and millimetres, as the game's
-- display option says.
--
-- The tab is added when the window is built (createChildren, the way vanilla adds its own),
-- only when the sandbox option is on, so the window is otherwise as it was.
require "ISUI/ISPanelJoypad"
require "XpSystem/ISUI/ISCharacterInfoWindow"

HistoricalWeatherForecast = HistoricalWeatherForecast or {}
local HWF = HistoricalWeatherForecast

local DAYS     = 30
local BORDER   = 10
local CELL_W   = 62
local GAP      = 3       -- px between cells
local ICON     = 32
local ICON_DIR = "media/ui/HistoricalWeather/"
local UNKNOWN  = "media/ui/foraging/questionMark.png"   -- vanilla's

local WHITE, GREY, DIM = { 1, 1, 1 }, { 0.7, 0.7, 0.7 }, { 0.5, 0.5, 0.5 }
local HIGH, LOW = { 1, 0.72, 0.42 }, { 0.55, 0.75, 1 }
local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local function t(key, ...) return getText("UI_HistoricalWeather_" .. key, ...) end

function HWF.enabled()
    local sv = SandboxVars and SandboxVars.HistoricalWeather
    return sv ~= nil and sv.Forecast == true
end

local function celsius()
    local core = getCore and getCore()
    return core ~= nil and core:getOptionDisplayAsCelsius() == true
end

local function round(v) return math.floor(v + 0.5) end

-- the shown number for a temperature in C
local function degrees(c, inC)
    if inC then return round(c) end
    return round(c * 9 / 5 + 32)
end

-- an amount of rain (or snow, cm) in the shown units
local function amount(inches, snow, inC)
    if inches < 0.01 then return t("Trace") end
    if inC then
        if snow then return t("Cm", string.format("%.1f", inches * 2.54)) end
        return t("Mm", tostring(round(inches * 25.4)))
    end
    return t("In", string.format("%.2f", inches))
end

-- the line under the calendar for a day of the forecast
function HWF.describe(entry, inC)
    local date = t("Date", t(WEEKDAYS[entry.weekday + 1]), tostring(entry.d), t("Month" .. entry.m), tostring(entry.y))
    local w = entry.day
    if not w then return { date, t("Sky_unknown") } end
    local lines = { date .. ": " .. t("Sky_" .. w.sky) }
    if w.high and w.low then
        local unit = inC and "DegC" or "DegF"
        lines[#lines + 1] = t("HighLow", t(unit, tostring(degrees(w.high, inC))), t(unit, tostring(degrees(w.low, inC))))
    else
        lines[#lines + 1] = t("NoTemp")
    end
    if w.sky ~= "unknown" then
        if w.snowInches > 0 then lines[#lines + 1] = t("SnowLine", amount(w.snowInches, true, inC)) end
        if w.rainHours > 0 and w.rainInches > 0 then
            lines[#lines + 1] = t("RainLine", amount(w.rainInches, false, inC), tostring(math.max(1, round(w.rainHours))))
        end
        if w.fog and w.sky ~= "fog" then lines[#lines + 1] = t("FogLine") end
    end
    return lines
end

-- the 30 days from today, worked out once a day
local cache = { key = nil, days = nil }
function HWF.days()
    local gt = getGameTime()
    local y, m, d = gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1
    local key = y * 10000 + m * 100 + d
    if cache.key ~= key then
        cache.key, cache.days = key, HistoricalWeather.forecast(y, m, d, DAYS)
    end
    return cache.days
end

-- the cell (column 0..6, row 0..) of each day: today sits in its weekday's column
function HWF.layout(days)
    local out, first = {}, days[1].weekday
    for n, e in ipairs(days) do
        local slot = first + n - 1
        out[n] = { col = slot % 7, row = math.floor(slot / 7) }
    end
    return out
end

local textures = {}
local function icon(sky)
    if textures[sky] == nil then
        local path = sky == "unknown" and UNKNOWN or ICON_DIR .. sky .. ".png"
        textures[sky] = getTexture(path) or false
    end
    return textures[sky] or nil
end

-- the tab ---------------------------------------------------------------------------------

HistoricalWeatherForecastView = ISPanelJoypad:derive("HistoricalWeatherForecastView")
local View = HistoricalWeatherForecastView

function View:new(x, y, width, height, playerNum)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.hover = nil
    o.cells = {}
    return o
end

local function title(days)
    local a, b = days[1], days[#days]
    local from = t("Month" .. a.m)
    local to = t("Month" .. b.m)
    if a.y ~= b.y then return from .. " " .. a.y .. " - " .. to .. " " .. b.y end
    if a.m ~= b.m then return from .. " - " .. to .. " " .. b.y end
    return from .. " " .. b.y
end

function View:render()
    ISPanelJoypad.render(self)
    local days = HWF.days()
    local inC = celsius()
    local tm = getTextManager()
    local small = tm:getFontHeight(UIFont.Small)
    local medium = tm:getFontHeight(UIFont.Medium)
    local gridW = 7 * CELL_W + 6 * GAP
    local cellH = small * 2 + ICON + 6     -- the date, the icon, the high and low
    self.cellH = cellH
    local y = BORDER

    self:drawText(t("Title"), BORDER, y, 1, 1, 1, 1, UIFont.Medium)
    local month = title(days)
    self:drawTextRight(month, BORDER + gridW, y + medium - small, GREY[1], GREY[2], GREY[3], 1, UIFont.Small)
    y = y + medium + 6

    local anyKnown = false
    for _, e in ipairs(days) do if e.day then anyKnown = true end end
    if not anyKnown then
        for _, line in ipairs({ t("Outside1"), t("Outside2") }) do
            self:drawText(line, BORDER, y, GREY[1], GREY[2], GREY[3], 1, UIFont.Small)
            y = y + small
        end
        self:fit(gridW, y)
        return
    end

    for c = 0, 6 do
        local x = BORDER + c * (CELL_W + GAP)
        self:drawTextCentre(t(WEEKDAYS[c + 1]), x + CELL_W / 2, y, GREY[1], GREY[2], GREY[3], 1, UIFont.Small)
    end
    y = y + small + 2
    local top = y

    local layout = HWF.layout(days)
    local rows, anyUnknown = 0, false
    self.cells = {}
    for n, e in ipairs(days) do
        local cell = layout[n]
        local x = BORDER + cell.col * (CELL_W + GAP)
        local cy = top + cell.row * (cellH + GAP)
        rows = math.max(rows, cell.row + 1)
        self.cells[n] = { x = x, y = cy }
        local lit = (self.hover == n) and 0.22 or 0.1
        self:drawRect(x, cy, CELL_W, cellH, lit, 1, 1, 1)
        if n == 1 then
            self:drawRectBorder(x, cy, CELL_W, cellH, 0.9, HIGH[1], HIGH[2], HIGH[3])
        else
            self:drawRectBorder(x, cy, CELL_W, cellH, 0.25, 1, 1, 1)
        end
        local label = tostring(e.d)
        if e.d == 1 or n == 1 then label = label .. " " .. string.sub(t("Month" .. e.m), 1, 3) end
        self:drawText(label, x + 4, cy + 2, WHITE[1], WHITE[2], WHITE[3], 1, UIFont.Small)
        local w = e.day
        local sky = w and w.sky or "unknown"
        if sky == "unknown" then anyUnknown = true end
        local tex = icon(sky)
        if tex then
            self:drawTextureScaledAspect(tex, x + (CELL_W - ICON) / 2, cy + small + 2, ICON, ICON, 1, 1, 1, 1)
        end
        local ty = cy + cellH - small - 2
        if w and w.high and w.low then
            local hi = t("Deg", tostring(degrees(w.high, inC)))
            local lo = t("Deg", tostring(degrees(w.low, inC)))
            local hiW = tm:MeasureStringX(UIFont.Small, hi)
            local loW = tm:MeasureStringX(UIFont.Small, lo)
            local sx = x + (CELL_W - hiW - loW - 6) / 2
            self:drawText(hi, sx, ty, HIGH[1], HIGH[2], HIGH[3], 1, UIFont.Small)
            self:drawText(lo, sx + hiW + 6, ty, LOW[1], LOW[2], LOW[3], 1, UIFont.Small)
        else
            self:drawTextCentre("--", x + CELL_W / 2, ty, DIM[1], DIM[2], DIM[3], 1, UIFont.Small)
        end
    end
    y = top + rows * (cellH + GAP) + 4

    local shown = days[self.hover or 1]
    for i, line in ipairs(HWF.describe(shown, inC)) do
        local c = i == 1 and WHITE or GREY
        self:drawText(line, BORDER, y, c[1], c[2], c[3], 1, UIFont.Small)
        y = y + small
    end
    if anyUnknown then
        y = y + 4
        self:drawText(t("GameDays"), BORDER, y, DIM[1], DIM[2], DIM[3], 1, UIFont.Small)
        y = y + small
    end
    self:fit(gridW, y)
end

-- the window fits the tab, as vanilla's protection tab does
function View:fit(w, y)
    self:setWidthAndParentWidth(math.max(self.width, w + BORDER * 2))
    self:setHeightAndParentHeight(math.max(self.height, y + BORDER))
end

function View:onMouseMove(dx, dy)
    ISPanelJoypad.onMouseMove(self, dx, dy)
    local mx, my = self:getMouseX(), self:getMouseY()
    self.hover = nil
    for n, c in pairs(self.cells) do
        if mx >= c.x and mx < c.x + CELL_W and my >= c.y and my < c.y + (self.cellH or 0) then self.hover = n end
    end
end

function View:onMouseMoveOutside(dx, dy)
    ISPanelJoypad.onMouseMoveOutside(self, dx, dy)
    self.hover = nil
end

-- the shoulder buttons switch tabs, B lets go, left and right step through the days
function View:onJoypadDown(button)
    if button == Joypad.BButton then
        getPlayerInfoPanel(self.playerNum):toggleView(t("Tab"))
        setJoypadFocus(self.playerNum, nil)
    end
    if button == Joypad.LBumper or button == Joypad.RBumper then
        getPlayerInfoPanel(self.playerNum):onJoypadDown(button)
    end
end

function View:onJoypadDirLeft() self.hover = math.max(1, (self.hover or 1) - 1) end
function View:onJoypadDirRight() self.hover = math.min(DAYS, (self.hover or 1) + 1) end
function View:onJoypadDirUp() self.hover = math.max(1, (self.hover or 1) - 7) end
function View:onJoypadDirDown() self.hover = math.min(DAYS, (self.hover or 1) + 7) end

-- Neat Rocco's icon tab bar gives every mod's tab the same spanner; ours gets the sun, set
-- a frame later (it sets its icons after the window's own build)
local function setIcon(window, view)
    if not window.tabButtons or not window.subPanels then return end
    local tex = icon("clear")
    if not tex then return end
    for n, panel in pairs(window.subPanels) do
        local btn = window.tabButtons[n]
        if panel == view and btn and btn.setIcon then btn:setIcon(tex) end
    end
end

local function later(fn)
    local function once()
        Events.OnTick.Remove(once)
        pcall(fn)
    end
    Events.OnTick.Add(once)
end

function HWF.addTab(window)
    if not window.panel or not HWF.enabled() then return end
    local view = View:new(0, 8, window.width, window.height - 8, window.playerNum)
    view:initialise()
    view.infoText = getTextOrNull("UI_HistoricalWeather_Info")
    window.panel:addView(t("Tab"), view)
    window.historicalWeatherView = view
    later(function() setIcon(window, view) end)
end

if not HWF.wrapped then
    HWF.wrapped = true
    local original = ISCharacterInfoWindow.createChildren
    function ISCharacterInfoWindow:createChildren(...)
        local result = original(self, ...)
        local ok, err = pcall(HWF.addTab, self)
        if not ok then print("HistoricalWeather: forecast tab: " .. tostring(err)) end
        return result
    end
end
