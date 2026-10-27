-- Steady: a reflex test, how steady the hands and how quick the reactions are
-- right now.
--
-- A ring drifts round the screen on a seeded random walk; hold the cross on
-- it with the arrows for a round of 20 seconds. The score is the share of the
-- round's ticks the cross spent on the ring, and the verdict reads it: STEADY
-- (80% or more), SHAKY (50% or more), ALL OVER THE PLACE.
--
-- Screens: the title (PLAY, SOUND, the best), the round (two seconds of READY,
-- then the 20 seconds), the result. The result's A or START saves the best and
-- the sound on the cartridge (the console allows a save only on a press);
-- START in a round gives it up, unscored.
--
-- For the Vitality Project. self.vitality is set once, in init, and never
-- replaced: Vitality writes into it from outside (DanTraits_SpiffBoy.lua), once
-- a game minute, two inputs read here every tick, each 0..1 and 0 when absent:
--   tremor   shakes the cross, a push of up to 3 px a tick drawn from self.random
--   slow     delays the arrows, up to 20 ticks
-- The game writes active (true during a round) and lastScore (0..100, the last
-- finished round). It never reads the character, so it stays deterministic.

require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "SpiffBoy/Core/Random"
require "VitalityCartridges/Games/Steady/Music"

VitalityCartridgesSteadyGame = SpiffBoyGameBase:derive("VitalityCartridgesSteadyGame")

local Game = VitalityCartridgesSteadyGame
local Music = VitalityCartridges.Steady.Music
local gameText = SpiffBoy.GameTexts.of("Steady")
local SHADES = SpiffBoy.Cartridges.SHADES

local TICKS = 60                 -- ticks a second
local READY_TICKS = 2 * TICKS    -- the still start before the clock runs
local ROUND_TICKS = 20 * TICKS
local GO_TICKS = TICKS           -- GO! shows this long once the clock runs
local COUNT_FROM = 3             -- a tick cue on each of the last seconds

local STEADY_AT, SHAKY_AT = 80, 50

-- the field, under the bar at the top
local BAR_H = 14
local FIELD_TOP, FIELD_BOTTOM, FIELD_RIGHT = 15, 119, 179

-- the art (sizes as make_steady_art.py draws them)
local RING_CELL, RING_HALF = 15, 7     -- target.png: cell 0 the ring, cell 1 its inside
local CROSS_HALF = 4                   -- cross.png: 9x9

local ON_RADIUS = 5              -- the cross this close to the ring's centre is on it
local CROSS_SPEED = 1            -- pixels a tick an arrow moves the cross
local DRIFT_ACCEL = 0.04         -- the most the ring's speed changes in a tick, each way
local DRIFT_FROM, DRIFT_TO = 0.35, 0.7 -- the ring's top speed, rising through the round

local TREMOR_PX = 3              -- the shake at tremor 1, at most, pixels a tick
local TREMOR_KEEP = 0.75         -- share of the last tick's shake kept: a tremor sways, it does not flicker
local SLOW_TICKS = 20            -- the arrows' delay at slow 1
local LAG_SIZE = SLOW_TICKS + 1  -- the arrows of the last ticks, the current one included

local MODE_TITLE, MODE_ROUND, MODE_RESULT = "title", "round", "result"
local MENU_PLAY, MENU_SOUND, MENU_SIZE = 1, 2, 2
local MENU_Y, MENU_STEP, MENU_BAR = 52, 18, 100

local function ink(i)
    local s = SHADES[i]
    return s.r, s.g, s.b
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function readNumber(v, hi)
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.min(math.floor(v), hi)
end

local function readSound(save)
    local o = save.options
    return type(o) ~= "table" or o.sound ~= false
end

-- an input from Vitality: 0..1, and 0 when it is absent or not a number
local function readLevel(v)
    if type(v) ~= "number" or v ~= v then return 0 end
    return clamp(v, 0, 1)
end

-- the arrows this tick, a quick tap counting as well as a hold
local function arrows(input)
    local dx, dy = input:axes()
    local pressed = input.pressed
    if dx == 0 then dx = (pressed.right and 1 or 0) - (pressed.left and 1 or 0) end
    if dy == 0 then dy = (pressed.down and 1 or 0) - (pressed.up and 1 or 0) end
    return dx, dy
end

function Game:init()
    local art = self.context.art
    self.target = art("target")
    self.cross = art("cross")
    self.best = readNumber(self.save.best, 100)
    self.soundOn = readSound(self.save)
    self.ticks = 0
    self.lagX, self.lagY = {}, {}
    for i = 0, LAG_SIZE - 1 do self.lagX[i], self.lagY[i] = 0, 0 end
    self.vitality = {}
    self:enterTitle()
end

function Game:music(name)
    if self.soundOn then
        self.sequencer:play(name)
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
    self.selection = MENU_PLAY
    self.vitality.active = false
    self:music(Music.TITLE)
end

function Game:enterRound()
    self.mode = MODE_ROUND
    self.roundTicks = 0          -- from the start of READY
    self.playTicks = 0           -- from GO
    self.onTicks = 0
    self.on = false
    -- the ring's walk has a generator of its own, so the shake does not change its course
    self.walk = SpiffBoyRandom.new(self.random:int(1, SpiffBoyRandom.MODULUS - 1))
    self.tx, self.ty = 90, math.floor((FIELD_TOP + FIELD_BOTTOM) / 2)
    self.vx, self.vy = 0, 0
    self.cx, self.cy = self.tx, self.ty
    self.shakeX, self.shakeY = 0, 0
    for i = 0, LAG_SIZE - 1 do self.lagX[i], self.lagY[i] = 0, 0 end
    self.lagHead = 0
    self.vitality.active = true
    self:music(Music.ROUND)
end

function Game:enterResult()
    self.mode = MODE_RESULT
    self.resultTicks = 0
    self.score = math.floor(100 * self.onTicks / ROUND_TICKS + 0.5)
    self.newBest = self.score > self.best
    if self.newBest then self.best = self.score end
    self.vitality.active = false
    self.vitality.lastScore = self.score
    self.sequencer:stop()
    self:cue(self.newBest and Music.BEST or Music.END)
end

-- ticks ---------------------------------------------------------------------------------

function Game:tick(inputs, tick)
    local input = inputs[1]
    self.ticks = self.ticks + 1
    if self.mode == MODE_TITLE then
        self:tickTitle(input)
    elseif self.mode == MODE_ROUND then
        self:tickRound(input)
    else
        self:tickResult(input)
    end
end

function Game:tickTitle(input)
    local pressed = input.pressed
    if pressed.up then
        self.selection = (self.selection - 2 + MENU_SIZE) % MENU_SIZE + 1
        self.sequencer:effect(Music.MOVE)
    elseif pressed.down then
        self.selection = self.selection % MENU_SIZE + 1
        self.sequencer:effect(Music.MOVE)
    end
    if pressed.a or pressed.start then
        self.sequencer:effect(Music.SELECT)
        if self.selection == MENU_PLAY then
            self:enterRound()
        else
            self.soundOn = not self.soundOn
            self:music(Music.TITLE)
        end
    end
end

function Game:tickRound(input)
    if input.pressed.start then
        self:enterTitle()
        return
    end
    self.roundTicks = self.roundTicks + 1
    if self.roundTicks <= READY_TICKS then
        if self.roundTicks == READY_TICKS then self:cue(Music.GO) end
        return
    end
    self.playTicks = self.playTicks + 1
    self:drift()
    self:steer(input)
    self:shake()
    self.cx = clamp(self.cx, CROSS_HALF, FIELD_RIGHT - CROSS_HALF)
    self.cy = clamp(self.cy, FIELD_TOP + CROSS_HALF, FIELD_BOTTOM - CROSS_HALF)
    local dx, dy = self.cx - self.tx, self.cy - self.ty
    self.on = dx * dx + dy * dy <= ON_RADIUS * ON_RADIUS
    if self.on then self.onTicks = self.onTicks + 1 end
    local left = ROUND_TICKS - self.playTicks
    if left <= 0 then
        self:enterResult()
    elseif left % TICKS == 0 and left <= COUNT_FROM * TICKS then
        self:cue(Music.TICK)
    end
end

-- the ring: its speed wanders by a little each tick, up to a top speed that
-- rises through the round, and it bounces off the edges of the field
function Game:drift()
    local walk = self.walk
    self.vx = self.vx + walk:range(-DRIFT_ACCEL, DRIFT_ACCEL)
    self.vy = self.vy + walk:range(-DRIFT_ACCEL, DRIFT_ACCEL)
    local top = DRIFT_FROM + (DRIFT_TO - DRIFT_FROM) * self.playTicks / ROUND_TICKS
    local speed2 = self.vx * self.vx + self.vy * self.vy
    if speed2 > top * top then
        local k = top / math.sqrt(speed2)
        self.vx, self.vy = self.vx * k, self.vy * k
    end
    self.tx, self.vx = self:bounce(self.tx + self.vx, self.vx, RING_HALF + 1, FIELD_RIGHT - RING_HALF - 1)
    self.ty, self.vy = self:bounce(self.ty + self.vy, self.vy, FIELD_TOP + RING_HALF + 1, FIELD_BOTTOM - RING_HALF - 1)
end

function Game:bounce(v, speed, lo, hi)
    if v < lo then return lo + (lo - v), -speed end
    if v > hi then return hi - (v - hi), -speed end
    return v, speed
end

-- the arrows go in at one end of the lag ring and come out slow ticks later
function Game:steer(input)
    local dx, dy = arrows(input)
    local head = self.lagHead
    self.lagX[head], self.lagY[head] = dx, dy
    local delay = math.floor(readLevel(self.vitality.slow) * SLOW_TICKS + 0.5)
    local at = (head - delay + LAG_SIZE) % LAG_SIZE
    self.cx = self.cx + self.lagX[at] * CROSS_SPEED
    self.cy = self.cy + self.lagY[at] * CROSS_SPEED
    self.lagHead = (head + 1) % LAG_SIZE
end

-- the tremor: a push that sways from tick to tick, never past its limit
function Game:shake()
    local tremor = readLevel(self.vitality.tremor)
    if tremor <= 0 then
        self.shakeX, self.shakeY = 0, 0
        return
    end
    local limit = TREMOR_PX * tremor
    local kick = limit * (1 - TREMOR_KEEP) * 2
    local random = self.random
    self.shakeX = clamp(self.shakeX * TREMOR_KEEP + random:range(-kick, kick), -limit, limit)
    self.shakeY = clamp(self.shakeY * TREMOR_KEEP + random:range(-kick, kick), -limit, limit)
    self.cx = self.cx + self.shakeX
    self.cy = self.cy + self.shakeY
end

function Game:tickResult(input)
    self.resultTicks = self.resultTicks + 1
    local pressed = input.pressed
    if pressed.a or pressed.start then
        self.sequencer:effect(Music.SELECT)
        self:saveRound()
        self:enterTitle()
    end
end

-- on the press that confirms the result: the best and the sound, in one write
function Game:saveRound()
    local save = self.save
    save.best = self.best
    save.options = { sound = self.soundOn }
    self:persist()
end

function Game:verdict()
    if self.score >= STEADY_AT then return gameText("VerdictSteady") end
    if self.score >= SHAKY_AT then return gameText("VerdictShaky") end
    return gameText("VerdictAllOver")
end

-- drawing ------------------------------------------------------------------------------

function Game:draw(screen)
    screen:clear(ink(4))
    if self.mode == MODE_TITLE then
        self:drawTitle(screen)
    elseif self.mode == MODE_ROUND then
        self:drawRound(screen)
    else
        self:drawResult(screen)
    end
end

function Game:drawTitle(screen)
    local centre = math.floor(screen.width / 2)
    screen:textCentre(gameText("Title"), centre, 8, ink(1))
    screen:textCentre(gameText("Subtitle"), centre, 24, ink(2))
    local labels = {
        gameText("Play"),
        self.soundOn and gameText("SoundOn") or gameText("SoundOff"),
    }
    for i = 1, MENU_SIZE do
        local y = MENU_Y + (i - 1) * MENU_STEP
        if i == self.selection then
            screen:rect(centre - MENU_BAR / 2, y, MENU_BAR, screen:lineHeight(), ink(1))
            screen:textCentre(labels[i], centre, y, ink(4))
        else
            screen:textCentre(labels[i], centre, y, ink(2))
        end
    end
    screen:textCentre(gameText("Best", self.best), centre, 100, ink(2))
end

function Game:drawRound(screen)
    local width = screen.width
    local centre = math.floor(width / 2)
    screen:rect(0, BAR_H, width, 1, ink(2))
    -- the ring, its inside lit while the cross is on it, then the cross
    local rx, ry = math.floor(self.tx) - RING_HALF, math.floor(self.ty) - RING_HALF
    if self.on then
        screen:sheet(self.target, RING_CELL, 0, RING_CELL, RING_CELL, rx, ry, 1, 3)
        screen:sheet(self.target, 0, 0, RING_CELL, RING_CELL, rx, ry, 1, 1)
    else
        screen:sheet(self.target, 0, 0, RING_CELL, RING_CELL, rx, ry, 1, 2)
    end
    screen:sprite(self.cross, math.floor(self.cx) - CROSS_HALF, math.floor(self.cy) - CROSS_HALF, nil, nil, 1, 1)
    -- the bar: READY and the hint first, then the clock and the share so far
    if self.playTicks == 0 then
        screen:textCentre(gameText("Ready"), centre, 0, ink(1))
        screen:textCentre(gameText("HintRound"), centre, 104, ink(2))
        return
    end
    local left = math.ceil((ROUND_TICKS - self.playTicks) / TICKS)
    screen:text(gameText("Time", left), 4, 0, ink(1))
    if self.playTicks < GO_TICKS then
        screen:textCentre(gameText("Go"), centre, 0, ink(1))
    end
    local share = math.floor(100 * self.onTicks / self.playTicks + 0.5)
    screen:textRight(gameText("OnShare", share), width - 4, 0, ink(1))
end

function Game:drawResult(screen)
    local centre = math.floor(screen.width / 2)
    screen:textCentre(self:verdict(), centre, 16, ink(1))
    screen:textCentre(gameText("Score", self.score), centre, 42, ink(1))
    screen:textCentre(gameText("Best", self.best), centre, 60, ink(2))
    local blink = math.floor(self.resultTicks / 30) % 2 == 0
    if self.newBest and blink then
        screen:textCentre(gameText("NewBest"), centre, 78, ink(1))
    end
    if blink then
        screen:textCentre(gameText("HintSave"), centre, 100, ink(2))
    end
end
