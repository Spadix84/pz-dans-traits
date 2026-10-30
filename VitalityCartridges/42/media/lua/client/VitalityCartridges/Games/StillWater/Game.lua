-- Still Water: paced breathing on a quiet pond.
--
-- A disc on the water grows while you breathe in and shrinks while you
-- breathe out. Hold A for the in-breath (and the hold after it), let go for
-- the out-breath (and the rest after it). Nothing to win or lose: the screen
-- shows how even the breathing is, and lily pads open as the even breaths
-- add up.
--
-- Screens: the title (BREATHE, PACE, SOUND, the totals), the session, the
-- summary. The summary's A or START saves the totals, the pace and the sound
-- on the cartridge (the console allows a save only on a press).
--
-- For the Vitality Project. self.vitality = { active, calm } is set every
-- tick: active during a session, calm 0..1 how even the breathing has been
-- over about one breath. Vitality reads it from outside (DanTraits_SpiffBoy.lua);
-- the game never reads the character, so it stays deterministic.

require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "VitalityCartridges/Games/StillWater/Music"

VitalityCartridgesStillWaterGame = SpiffBoyGameBase:derive("VitalityCartridgesStillWaterGame")

local Game = VitalityCartridgesStillWaterGame
local Music = VitalityCartridges.StillWater.Music
local gameText = SpiffBoy.GameTexts.of("StillWater")
local SHADES = SpiffBoy.Cartridges.SHADES

local TICKS = 60                 -- ticks a second

-- the paces: phases of { kind, seconds }; kind names the text and whether A is held
local PACES = {
    { key = "PaceCalm", phases = { { "In", 4 }, { "Out", 6 } } },
    { key = "PaceBox", phases = { { "In", 4 }, { "HoldIn", 4 }, { "Out", 4 }, { "HoldOut", 4 } } },
    { key = "Pace478", phases = { { "In", 4 }, { "HoldIn", 7 }, { "Out", 8 } } },
}
local HELD = { In = true, HoldIn = true, Out = false, HoldOut = false }

local GRACE = 24                 -- ticks either side of a change where both count
local EVEN = 0.8                 -- a breath with this share of its ticks matched is even
local PER_PAD = 5                -- even breaths for each lily pad to open
local PADS = 8

-- the art (sizes as make_still_water_art.py draws them)
local DISC_CELL, DISC_MIN, DISC_MAX, DISC_STEP = 82, 6, 40, 2
local RING_CELL, RING_MIN, RING_MAX, RING_STEP = 96, 6, 46, 2
local LILY_W, LILY_H = 16, 12
local LILY_SHADES = { 1, 3, 4 }
local GUIDE = 42                 -- the ring that shows the full breath
local CX, CY = 90, 60            -- the centre of the pond

-- the pads round the disc: left and right of it
local PAD_AT = {
    { 6, 22 }, { 26, 44 }, { 6, 66 }, { 26, 86 },
    { 158, 22 }, { 138, 44 }, { 158, 66 }, { 138, 86 },
}

local RIPPLE_EVERY = 30          -- ticks between ripples while in step
local RIPPLE_SPEED = 3           -- ticks a pixel of growth
local RIPPLES = 3
local HINT_TICKS = 5 * TICKS     -- the hint shows this long at the start of a session
local BAR_W = 60

local MODE_TITLE, MODE_SESSION, MODE_SUMMARY = "title", "session", "summary"
local MENU_BREATHE, MENU_PACE, MENU_SOUND, MENU_SIZE = 1, 2, 3, 3
local MENU_Y, MENU_STEP, MENU_BAR = 40, 18, 120

local function ink(i)
    local s = SHADES[i]
    return s.r, s.g, s.b
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- 0..1 eased, so the disc starts and ends each breath slowly
local function ease(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function readNumber(v, hi)
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.min(math.floor(v), hi)
end

local function readPace(save)
    local p = save.pace
    if type(p) ~= "number" or p < 1 or p > #PACES then return 1 end
    return math.floor(p)
end

local function readSound(save)
    local o = save.options
    return type(o) ~= "table" or o.sound ~= false
end

function Game:init()
    local art = self.context.art
    self.disc = art("disc")
    self.ring = art("ring")
    self.lily = art("lily")
    self.totalBreaths = readNumber(self.save.breaths, 999999)
    self.totalSeconds = readNumber(self.save.seconds, 99999999)
    self.bestRun = readNumber(self.save.bestRun, 9999)
    self.pace = readPace(self.save)
    self.soundOn = readSound(self.save)
    self.ticks = 0
    self.vitality = { active = false, calm = 0 }
    self:enterTitle()
    self:applySound()
end

function Game:applySound()
    if self.soundOn then
        self.sequencer:play(Music.POND)
    else
        self.sequencer:stop()
    end
end

function Game:cue(name)
    if self.soundOn then self.sequencer:effect(name) end
end

-- screens -------------------------------------------------------------------------------

function Game:enterTitle()
    self.mode = MODE_TITLE
    self.selection = MENU_BREATHE
    self.vitality.active = false
end

function Game:enterSession()
    self.mode = MODE_SESSION
    self.phase = 1
    self.phaseTick = 0
    self.sessionTicks = 0
    self.calm = 0
    self.breathTicks, self.breathMatched = 0, 0
    self.evenBreaths, self.run, self.sessionBestRun = 0, 0, 0
    self.matched = false
    self.ripples = {}
    self.rippleWait = 0
    self.vitality.active, self.vitality.calm = true, 0
    self:cue(Music.IN)
end

function Game:enterSummary()
    self.mode = MODE_SUMMARY
    self.vitality.active = false
    self.summaryTicks = 0
end

-- the pace -----------------------------------------------------------------------------

function Game:phases()
    return PACES[self.pace].phases
end

function Game:cycleTicks()
    local n = 0
    for _, ph in ipairs(self:phases()) do n = n + ph[2] * TICKS end
    return n
end

function Game:phaseLength(i)
    return self:phases()[i][2] * TICKS
end

function Game:kindAt(i)
    return self:phases()[i][1]
end

-- whether A should be held this tick; near a change, the other answer counts too
function Game:wanted()
    local phases = self:phases()
    local n = #phases
    local kind = self:kindAt(self.phase)
    local want = HELD[kind]
    local prev = HELD[self:kindAt((self.phase - 2 + n) % n + 1)]
    local nextWant = HELD[self:kindAt(self.phase % n + 1)]
    local left = self:phaseLength(self.phase) - self.phaseTick
    local early = self.phaseTick < GRACE and prev ~= want
    local late = left <= GRACE and nextWant ~= want
    return want, early, late, prev, nextWant
end

-- the disc's radius now
function Game:radius()
    local kind = self:kindAt(self.phase)
    local t = ease(self.phaseTick / self:phaseLength(self.phase))
    if kind == "In" then return DISC_MIN + (DISC_MAX - DISC_MIN) * t end
    if kind == "Out" then return DISC_MAX - (DISC_MAX - DISC_MIN) * t end
    if kind == "HoldIn" then return DISC_MAX end
    return DISC_MIN
end

-- ticks ---------------------------------------------------------------------------------

function Game:tick(inputs, tick)
    local input = inputs[1]
    self.ticks = self.ticks + 1
    if self.mode == MODE_TITLE then
        self:tickTitle(input)
    elseif self.mode == MODE_SESSION then
        self:tickSession(input)
    else
        self:tickSummary(input)
    end
end

function Game:changePace(step)
    self.pace = (self.pace - 1 + step + #PACES) % #PACES + 1
    self:cue(Music.MOVE)
end

function Game:tickTitle(input)
    local pressed = input.pressed
    if pressed.up then
        self.selection = (self.selection - 2 + MENU_SIZE) % MENU_SIZE + 1
        self:cue(Music.MOVE)
    elseif pressed.down then
        self.selection = self.selection % MENU_SIZE + 1
        self:cue(Music.MOVE)
    end
    if self.selection == MENU_PACE and (pressed.left or pressed.right) then
        self:changePace(pressed.left and -1 or 1)
    end
    if pressed.a or pressed.start then
        if self.selection == MENU_BREATHE then
            self:cue(Music.SELECT)
            self:enterSession()
        elseif self.selection == MENU_PACE then
            self:changePace(1)
        else
            self.soundOn = not self.soundOn
            self:applySound()
            self:cue(Music.SELECT)
        end
    end
end

function Game:tickSession(input)
    if input.pressed.start then
        self:enterSummary()
        return
    end
    self.sessionTicks = self.sessionTicks + 1
    local held = input.held.a == true
    local want, early, late, prev, nextWant = self:wanted()
    local ok = held == want or (early and held == prev) or (late and held == nextWant)
    self.matched = ok
    local m = ok and 1 or 0
    self.calm = self.calm + (m - self.calm) / self:cycleTicks()
    self.vitality.calm = self.calm
    self.breathTicks = self.breathTicks + 1
    self.breathMatched = self.breathMatched + m
    self:tickRipples(ok)
    self.phaseTick = self.phaseTick + 1
    if self.phaseTick >= self:phaseLength(self.phase) then self:nextPhase() end
end

function Game:nextPhase()
    self.phaseTick = 0
    self.phase = self.phase % #self:phases() + 1
    local kind = self:kindAt(self.phase)
    if self.phase == 1 then self:endBreath() end
    if kind == "In" then
        self:cue(Music.IN)
    elseif kind == "Out" then
        self:cue(Music.OUT)
    else
        self:cue(Music.HOLD)
    end
end

-- one whole cycle done: was it even?
function Game:endBreath()
    local share = self.breathTicks > 0 and self.breathMatched / self.breathTicks or 0
    self.breathTicks, self.breathMatched = 0, 0
    if share < EVEN then
        self.run = 0
        return
    end
    self.evenBreaths = self.evenBreaths + 1
    self.run = self.run + 1
    if self.run > self.sessionBestRun then self.sessionBestRun = self.run end
    if self.evenBreaths % PER_PAD == 0 and self.evenBreaths / PER_PAD <= PADS then self:cue(Music.BLOOM) end
end

function Game:tickRipples(ok)
    local kept = {}
    for _, r in ipairs(self.ripples) do
        r.age = r.age + 1
        local radius = r.from + math.floor(r.age / RIPPLE_SPEED)
        if radius <= RING_MAX then kept[#kept + 1] = r end
    end
    self.ripples = kept
    if self.rippleWait > 0 then self.rippleWait = self.rippleWait - 1 end
    if ok and self.rippleWait <= 0 and #self.ripples < RIPPLES then
        self.ripples[#self.ripples + 1] = { from = math.floor(self:radius()) + 2, age = 0 }
        self.rippleWait = RIPPLE_EVERY
    end
end

function Game:tickSummary(input)
    self.summaryTicks = self.summaryTicks + 1
    local pressed = input.pressed
    if pressed.a or pressed.start then
        self:cue(Music.SELECT)
        self:saveSession()
        self:enterTitle()
    end
end

-- on the press that confirms the summary: everything that changed, in one write
function Game:saveSession()
    self.totalBreaths = math.min(self.totalBreaths + self.evenBreaths, 999999)
    self.totalSeconds = math.min(self.totalSeconds + math.floor(self.sessionTicks / TICKS), 99999999)
    if self.sessionBestRun > self.bestRun then self.bestRun = self.sessionBestRun end
    local save = self.save
    save.breaths = self.totalBreaths
    save.seconds = self.totalSeconds
    save.bestRun = self.bestRun
    save.pace = self.pace
    save.options = { sound = self.soundOn }
    self:persist()
end

-- drawing ------------------------------------------------------------------------------

function Game:draw(screen)
    screen:clear(ink(2))
    if self.mode == MODE_TITLE then
        self:drawTitle(screen)
    elseif self.mode == MODE_SESSION then
        self:drawSession(screen)
    else
        self:drawSummary(screen)
    end
end

function Game:drawRing(screen, radius, shade)
    local i = clamp(math.floor((radius - RING_MIN) / RING_STEP + 0.5), 0, math.floor((RING_MAX - RING_MIN) / RING_STEP))
    local half = math.floor(RING_CELL / 2)
    screen:sheet(self.ring, i * RING_CELL, 0, RING_CELL, RING_CELL, CX - half, CY - half, 1, shade)
end

function Game:drawDisc(screen, radius, shade)
    local i = clamp(math.floor((radius - DISC_MIN) / DISC_STEP + 0.5), 0, math.floor((DISC_MAX - DISC_MIN) / DISC_STEP))
    local half = math.floor(DISC_CELL / 2)
    screen:sheet(self.disc, i * DISC_CELL, 0, DISC_CELL, DISC_CELL, CX - half, CY - half, 1, shade)
end

function Game:drawPads(screen, open)
    for i, at in ipairs(PAD_AT) do
        local cell = i <= open and 1 or 0
        screen:layers(self.lily, cell * LILY_W, LILY_W, LILY_H, at[1], at[2], LILY_SHADES)
    end
end

function Game:drawTitle(screen)
    local centre = math.floor(screen.width / 2)
    screen:textCentre(gameText("Title"), centre, 8, ink(4))
    local labels = {
        gameText("Breathe"),
        gameText("Pace", gameText(PACES[self.pace].key)),
        self.soundOn and gameText("SoundOn") or gameText("SoundOff"),
    }
    for i = 1, MENU_SIZE do
        local y = MENU_Y + (i - 1) * MENU_STEP
        if i == self.selection then
            screen:rect(centre - MENU_BAR / 2, y, MENU_BAR, screen:lineHeight(), ink(4))
            screen:textCentre(labels[i], centre, y, ink(1))
        else
            screen:textCentre(labels[i], centre, y, ink(3))
        end
    end
    local minutes = math.floor(self.totalSeconds / 60)
    screen:textCentre(gameText("Totals", self.totalBreaths, minutes), centre, 100, ink(3))
end

function Game:drawSession(screen)
    local width = screen.width
    for _, r in ipairs(self.ripples) do
        self:drawRing(screen, r.from + math.floor(r.age / RIPPLE_SPEED), 3)
    end
    self:drawRing(screen, GUIDE, 1)
    self:drawDisc(screen, self:radius(), self.matched and 4 or 3)
    self:drawPads(screen, math.min(PADS, math.floor(self.evenBreaths / PER_PAD)))
    -- the phase and its seconds left
    local kind = self:kindAt(self.phase)
    local left = math.ceil((self:phaseLength(self.phase) - self.phaseTick) / TICKS)
    screen:textCentre(gameText(kind) .. " " .. tostring(left), math.floor(width / 2), 2, ink(4))
    -- the bottom line: the hint at first, then how even it is and the breaths
    local y = 104
    if self.sessionTicks < HINT_TICKS then
        screen:textCentre(gameText("HintSession"), math.floor(width / 2), y, ink(4))
        return
    end
    screen:text(gameText("Even"), 4, y, ink(4))
    local x = 4 + screen:textWidth(gameText("Even")) + 3
    screen:rect(x, y + 4, BAR_W, 6, ink(1))
    local fill = math.floor(BAR_W * clamp(self.calm, 0, 1))
    if fill > 0 then screen:rect(x, y + 4, fill, 6, ink(4)) end
    screen:textRight(gameText("HintEnd"), width - 4, y, ink(3))
end

function Game:drawSummary(screen)
    local centre = math.floor(screen.width / 2)
    screen:textCentre(gameText("Done"), centre, 12, ink(4))
    local seconds = math.floor(self.sessionTicks / TICKS)
    screen:textCentre(gameText("Time", math.floor(seconds / 60), seconds % 60), centre, 40, ink(4))
    screen:textCentre(gameText("EvenBreaths", self.evenBreaths), centre, 58, ink(4))
    screen:textCentre(gameText("LongestRun", self.sessionBestRun), centre, 76, ink(3))
    if math.floor(self.summaryTicks / 30) % 2 == 0 then
        screen:textCentre(gameText("HintSave"), centre, 100, ink(3))
    end
end
