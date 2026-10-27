-- Spiffo Walk: a pedometer pet.
--
-- Leave the console on in your pocket and Spiffo grows as you walk. An egg
-- hatches at 500 steps and grows into a pup (3000), grown (10000) and an
-- elder (30000). Every 1000 steps he finds a treasure, one of eight hats,
-- which he wears on the main screen. Today's steps count against a goal of
-- 2000.
--
-- Screens: home (Spiffo, the steps, today against the goal; A pats him, B
-- opens the hats, START switches the sound) and the hats (the eight
-- treasures, how many of each; A wears one or takes it off). News (hatched,
-- grown, a hat found, the goal met) waits on the home screen until a press.
-- Any press while there is something unsaved saves the totals, the stage,
-- the hats, today's count and the options (the console allows a save only on
-- a press): steps counted since the last save are kept only while the
-- console stays on.
--
-- For the Vitality Project. self.vitality = {} from init. Vitality writes
-- from outside, once a game minute, while the console is on with this game,
-- shown or in the pocket: steps, a running count of the character's steps
-- (never goes down), and day, the game day number. The game counts the rise
-- since it last looked; a fall, or a jump over 2000 at once, is not counted,
-- only taken as the new base. Without steps nothing counts; without day
-- everything is one day. Once it has seen steps, the game writes today (steps
-- counted today) and goalMet (today reached 2000) for Vitality to read
-- (DanTraits_SpiffBoy.lua); the game never reads the character, so it stays
-- deterministic.

require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "VitalityCartridges/Games/SpiffoWalk/Music"

VitalityCartridgesSpiffoWalkGame = SpiffBoyGameBase:derive("VitalityCartridgesSpiffoWalkGame")

local Game = VitalityCartridgesSpiffoWalkGame
local Music = VitalityCartridges.SpiffoWalk.Music
local gameText = SpiffBoy.GameTexts.of("SpiffoWalk")
local SHADES = SpiffBoy.Cartridges.SHADES

local TICKS = 60                 -- ticks a second

local GOAL = 2000                -- today's steps for the goal
local JUMP = 2000                -- a rise above this at once is a load or a teleport: not counted
local TREASURE_EVERY = 1000      -- steps for each treasure
local MAX_STEPS = 99999999
local MAX_HATS = 9999            -- of each kind
local NOTICES = 6                -- news kept waiting for a press

-- the stages by total steps; id names the texts Stage_<id> and Grew_<id>
local STAGES = {
    { id = "Egg", at = 0 },
    { id = "Hatched", at = 500 },
    { id = "Pup", at = 3000 },
    { id = "Grown", at = 10000 },
    { id = "Elder", at = 30000 },
}
local CRACKS = { 250, 400 }      -- the egg cracks at these totals

-- the treasures, in the order of hats.png; id names the text Hat_<id>
local HATS = { "TopHat", "Party", "Crown", "Bobble", "Cowboy", "Chef", "Cone", "Cap" }

-- the art (sizes as make_spiffo_walk_art.py draws them)
local CELL = 32
local EGG_CELLS = 3              -- whole, cracked, about to hatch
local FRAMES = 4                 -- each later stage: stand, blink, left foot up, right foot up
local HEAD_TOP = { 12, 16, 13, 6, 6 }   -- the first row of the head (the egg's top) in a cell, by stage
local SPIFFO_SHADES = { 1, 2, 3 } -- shade 4 is the paper behind him
local HAT_W, HAT_H = 16, 10
local ICON = 8
local ICON_HEART, ICON_PAW, ICON_STAR = 0, 1, 2
local GROUND_W, GROUND_H = 180, 8

-- home
local GROUND_Y = 84              -- the ground line, Spiffo's feet on it
local SPIFFO_X = 74              -- the left of his cell
local TODAY_Y, BAR_Y, LINE_Y = 86, 101, 105
local BAR_X, BAR_W, BAR_H = 4, 172, 3
local NOTICE_Y, NOTICE_H = 17, 16
local WALK_HOLD = 4 * TICKS      -- he walks this long after the last rise (Vitality writes once a game minute)
local STEP_TICKS = 12            -- ticks a walking frame
local SCROLL_TICKS = 3           -- ticks a pixel of ground while walking
local PAT_TICKS = 60
local BLINK_TICKS = 8
local BLINK_GAP_MIN, BLINK_GAP_MAX = 150, 330
local LINE_TICKS = 3 * TICKS     -- the bottom line changes this often
local LINES = 3                  -- the next stage, the buttons, the sound

-- the hats screen: a grid of four by two
local GRID_X, GRID_Y = 10, 18
local SLOT_W, SLOT_H = 40, 30
local GRID_COLS = 4

local MODE_HOME, MODE_HATS = "home", "hats"
local BUTTONS = { "up", "down", "left", "right", "a", "b", "start" }

local function ink(i)
    local s = SHADES[i]
    return s.r, s.g, s.b
end

local function readNumber(v, hi)
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.min(math.floor(v), hi)
end

local function readHats(save)
    local hats = {}
    local saved = type(save.hats) == "table" and save.hats or {}
    for i = 1, #HATS do hats[i] = readNumber(saved[i], MAX_HATS) end
    return hats
end

local function readOptions(save)
    local o = type(save.options) == "table" and save.options or {}
    local hat = o.hat
    if type(hat) ~= "number" or hat < 0 or hat > #HATS then hat = 0 end
    return o.sound ~= false, math.floor(hat)
end

local function stageOf(steps)
    local stage = 1
    for i, s in ipairs(STAGES) do
        if steps >= s.at then stage = i end
    end
    return stage
end

local function anyPressed(pressed)
    for _, b in ipairs(BUTTONS) do
        if pressed[b] then return true end
    end
    return false
end

function Game:init()
    local art = self.context.art
    self.spiffo = art("spiffo")
    self.hatsArt = art("hats")
    self.icons = art("icons")
    self.ground = art("ground")
    local save = self.save
    self.steps = readNumber(save.steps, MAX_STEPS)
    self.stage = stageOf(self.steps)
    self.hats = readHats(save)
    self.today = readNumber(save.today, MAX_STEPS)
    self.day = type(save.day) == "number" and math.floor(save.day) or nil
    self.goalDays = readNumber(save.goalDays, 99999)
    self.soundOn, self.hat = readOptions(save)
    if self.hat > 0 and self.hats[self.hat] == 0 then self.hat = 0 end
    self.nextTreasure = (math.floor(self.steps / TREASURE_EVERY) + 1) * TREASURE_EVERY
    self.lastSeen = nil          -- Vitality's count when last looked at; nil until the first look
    self.seen = false            -- whether Vitality's inputs have been seen since power on
    self.dirty = false
    self.notices = {}
    self.ticks = 0
    self.walkTicks, self.patTicks, self.blinkTicks = 0, 0, 0
    self.scroll = 0
    self.nextBlink = self.random:int(BLINK_GAP_MIN, BLINK_GAP_MAX)
    self.vitality = {}
    self:enterHome()
    self:applySound()
end

function Game:applySound()
    if self.soundOn then
        self.sequencer:play(Music.STROLL)
    else
        self.sequencer:stop()
    end
end

function Game:cue(name)
    if self.soundOn then self.sequencer:effect(name) end
end

-- screens -------------------------------------------------------------------------------

function Game:enterHome()
    self.mode = MODE_HOME
end

function Game:enterHats()
    self.mode = MODE_HATS
    self.selection = self.hat > 0 and self.hat or 1
end

-- the steps ----------------------------------------------------------------------------

-- Vitality's inputs, once a tick: a new day first, then the rise in steps
function Game:readVitality()
    local v = self.vitality
    local steps = v.steps
    if type(steps) ~= "number" then return end
    self.seen = true
    local day = v.day
    if type(day) == "number" and math.floor(day) ~= self.day then self:newDay(math.floor(day)) end
    steps = math.floor(steps)
    local last = self.lastSeen
    self.lastSeen = steps
    if last == nil then return end   -- the first look only sets the base
    local rise = steps - last
    if rise <= 0 or rise > JUMP then return end
    self:addSteps(rise)
end

function Game:newDay(day)
    self.day = day
    self.today = 0
    self.dirty = true
end

function Game:addSteps(n)
    local wasMet = self.today >= GOAL
    self.steps = math.min(self.steps + n, MAX_STEPS)
    self.today = math.min(self.today + n, MAX_STEPS)
    self.dirty = true
    self.walkTicks = WALK_HOLD
    if not wasMet and self.today >= GOAL then
        self.goalDays = math.min(self.goalDays + 1, 99999)
        self:notify("Goal")
        self:cue(Music.GOAL)
    end
    local stage = stageOf(self.steps)
    if stage > self.stage then
        self.stage = stage
        self:notify("Grew_" .. STAGES[stage].id)
        self:cue(stage == 2 and Music.HATCH or Music.GROW)
    end
    while self.steps >= self.nextTreasure do
        self.nextTreasure = self.nextTreasure + TREASURE_EVERY
        self:findTreasure()
    end
end

-- a hat, picked by the console's seeded generator, worn at once
function Game:findTreasure()
    local i = self.random:int(1, #HATS)
    self.hats[i] = math.min(self.hats[i] + 1, MAX_HATS)
    self.hat = i
    self:notify("Found", gameText("Hat_" .. HATS[i]))
    self:cue(Music.TREASURE)
end

function Game:notify(key, arg)
    if #self.notices >= NOTICES then return end
    self.notices[#self.notices + 1] = { key = key, arg = arg }
end

function Game:writeVitality()
    if not self.seen then return end
    local v = self.vitality
    v.today = self.today
    v.goalMet = self.today >= GOAL
end

-- ticks ---------------------------------------------------------------------------------

function Game:tick(inputs, tick)
    local input = inputs[1]
    self.ticks = self.ticks + 1
    self:readVitality()
    self:tickLife()
    if self.mode == MODE_HOME then
        self:tickHome(input)
    else
        self:tickHats(input)
    end
    self:writeVitality()
    -- the press that answers anything: everything new, in one write
    if self.dirty and anyPressed(input.pressed) then self:saveAll() end
end

-- the animations, shown or in the pocket
function Game:tickLife()
    if self.walkTicks > 0 then
        self.walkTicks = self.walkTicks - 1
        if self.ticks % SCROLL_TICKS == 0 then self.scroll = (self.scroll + 1) % GROUND_W end
    end
    if self.patTicks > 0 then self.patTicks = self.patTicks - 1 end
    if self.blinkTicks > 0 then
        self.blinkTicks = self.blinkTicks - 1
    else
        self.nextBlink = self.nextBlink - 1
        if self.nextBlink <= 0 then
            self.blinkTicks = BLINK_TICKS
            self.nextBlink = self.random:int(BLINK_GAP_MIN, BLINK_GAP_MAX)
        end
    end
end

function Game:tickHome(input)
    local pressed = input.pressed
    if #self.notices > 0 then
        -- any press puts the news away, one at a time
        if anyPressed(pressed) then
            table.remove(self.notices, 1)
            self.sequencer:effect(Music.MOVE)
        end
        return
    end
    if pressed.a then
        self.patTicks = PAT_TICKS
        self:cue(Music.PAT)
    elseif pressed.b then
        self.sequencer:effect(Music.SELECT)
        self:enterHats()
    elseif pressed.start then
        self.soundOn = not self.soundOn
        self.dirty = true
        self:applySound()
        self.sequencer:effect(Music.SELECT)
    end
end

function Game:tickHats(input)
    local pressed = input.pressed
    local n = #HATS
    if pressed.left or pressed.right then
        self.selection = (self.selection - 1 + (pressed.left and -1 or 1) + n) % n + 1
        self.sequencer:effect(Music.MOVE)
    elseif pressed.up or pressed.down then
        self.selection = (self.selection - 1 + GRID_COLS) % n + 1
        self.sequencer:effect(Music.MOVE)
    end
    if pressed.a then
        local i = self.selection
        if self.hats[i] == 0 then
            self.sequencer:effect(Music.NOPE)
        else
            self.hat = self.hat == i and 0 or i
            self.dirty = true
            self.sequencer:effect(Music.SELECT)
        end
    elseif pressed.b or pressed.start then
        self.sequencer:effect(Music.SELECT)
        self:enterHome()
    end
end

-- on a press while something is new: everything, in one write
function Game:saveAll()
    local save = self.save
    save.steps = self.steps
    save.stage = self.stage
    local hats = {}
    for i = 1, #HATS do hats[i] = self.hats[i] end
    save.hats = hats
    save.today = self.today
    save.day = self.day
    save.goalDays = self.goalDays
    save.options = { sound = self.soundOn, hat = self.hat }
    self:persist()
    self.dirty = false
end

-- drawing ------------------------------------------------------------------------------

function Game:draw(screen)
    screen:clear(ink(4))
    if self.mode == MODE_HOME then
        self:drawHome(screen)
    else
        self:drawHats(screen)
    end
end

-- the cell of Spiffo now: the egg by its cracks, a stage by blinking and walking
function Game:cell()
    if self.stage == 1 then
        local c = 0
        for i, at in ipairs(CRACKS) do
            if self.steps >= at then c = i end
        end
        return c
    end
    local frame = 0
    if self.walkTicks > 0 then
        local step = math.floor(self.ticks / STEP_TICKS) % 4
        if step == 1 then frame = 2 elseif step == 3 then frame = 3 end
    end
    if frame == 0 and self.blinkTicks > 0 then frame = 1 end
    return EGG_CELLS + (self.stage - 2) * FRAMES + frame
end

function Game:drawSpiffo(screen)
    local x, y = SPIFFO_X, GROUND_Y - CELL
    -- a pat: the egg wobbles; Spiffo hops
    if self.patTicks > 0 then
        local beat = math.floor(self.patTicks / 6) % 2
        if self.stage == 1 then x = x + (beat == 0 and -1 or 1) else y = y - beat end
    end
    screen:layers(self.spiffo, self:cell() * CELL, CELL, CELL, x, y, SPIFFO_SHADES)
    if self.hat > 0 then
        local hx = x + math.floor((CELL - HAT_W) / 2)
        local hy = y + HEAD_TOP[self.stage] + 2 - HAT_H
        screen:layers(self.hatsArt, (self.hat - 1) * HAT_W, HAT_W, HAT_H, hx, hy)
    end
    if self.patTicks > 0 and self.stage > 1 then
        -- hearts rising beside his head
        local rise = math.floor((PAT_TICKS - self.patTicks) / 4)
        local top = y + HEAD_TOP[self.stage]
        screen:sheet(self.icons, ICON_HEART * ICON, 0, ICON, ICON, x - 4, top - rise, 1, 1)
        screen:sheet(self.icons, ICON_HEART * ICON, 0, ICON, ICON, x + CELL - 4, top + 4 - rise, 1, 2)
    end
end

function Game:drawHome(screen)
    local width = screen.width
    -- the top line: the stage and the total
    screen:text(gameText("Stage_" .. STAGES[self.stage].id), 4, 1, ink(1))
    screen:textRight(gameText("Steps", self.steps), width - 4, 1, ink(1))
    -- the ground, scrolling while he walks, and Spiffo on it
    screen:sheet(self.ground, self.scroll, 0, GROUND_W, GROUND_H, 0, GROUND_Y - GROUND_H + 1, 1, 2)
    self:drawSpiffo(screen)
    -- today against the goal
    screen:text(gameText("Today", math.min(self.today, 99999), GOAL), 4, TODAY_Y, ink(1))
    if self.today >= GOAL then
        screen:sheet(self.icons, ICON_STAR * ICON, 0, ICON, ICON, width - 4 - ICON, TODAY_Y + 3, 1, 1)
    end
    screen:rect(BAR_X, BAR_Y, BAR_W, BAR_H, ink(3))
    local fill = math.floor(BAR_W * math.min(self.today, GOAL) / GOAL)
    if fill > 0 then screen:rect(BAR_X, BAR_Y, fill, BAR_H, ink(1)) end
    -- the bottom line: the next stage, the buttons, the sound, in turn
    screen:textCentre(self:bottomLine(), math.floor(width / 2), LINE_Y, ink(2))
    -- news waiting for a press
    local notice = self.notices[1]
    if notice then
        screen:rect(2, NOTICE_Y, width - 4, NOTICE_H, ink(1))
        screen:rect(3, NOTICE_Y + 1, width - 6, NOTICE_H - 2, ink(4))
        screen:sheet(self.icons, ICON_PAW * ICON, 0, ICON, ICON, 6, NOTICE_Y + 4, 1, 2)
        screen:textCentre(gameText(notice.key, notice.arg), math.floor(width / 2), NOTICE_Y + 1, ink(1))
    end
end

function Game:bottomLine()
    local line = math.floor(self.ticks / LINE_TICKS) % LINES
    if line == 1 then return gameText("HintHome") end
    if line == 2 then return self.soundOn and gameText("SoundOn") or gameText("SoundOff") end
    local nextStage = STAGES[self.stage + 1]
    if nextStage then return gameText("Next", gameText("Stage_" .. nextStage.id), nextStage.at) end
    return gameText("GoalDays", self.goalDays)
end

function Game:drawHats(screen)
    local width = screen.width
    local centre = math.floor(width / 2)
    local kinds = 0
    for i = 1, #HATS do
        if self.hats[i] > 0 then kinds = kinds + 1 end
    end
    screen:textCentre(gameText("HatsTitle", kinds, #HATS), centre, 1, ink(1))
    for i = 1, #HATS do
        local sx = GRID_X + ((i - 1) % GRID_COLS) * SLOT_W
        local sy = GRID_Y + math.floor((i - 1) / GRID_COLS) * SLOT_H
        if i == self.selection then
            screen:rect(sx, sy, SLOT_W, SLOT_H, ink(1))
            screen:rect(sx + 1, sy + 1, SLOT_W - 2, SLOT_H - 2, ink(4))
        end
        local slotCentre = sx + math.floor(SLOT_W / 2)
        if self.hats[i] > 0 then
            screen:layers(self.hatsArt, (i - 1) * HAT_W, HAT_W, HAT_H, slotCentre - HAT_W / 2, sy + 4)
            screen:textCentre(gameText("Count", self.hats[i]), slotCentre, sy + 15, ink(2))
        else
            screen:textCentre(gameText("Unknown"), slotCentre, sy + 8, ink(3))
        end
        if i == self.hat then
            screen:sheet(self.icons, ICON_STAR * ICON, 0, ICON, ICON, sx + 2, sy + 2, 1, 1)
        end
    end
    local i = self.selection
    local name = self.hats[i] > 0 and gameText("Hat_" .. HATS[i]) or gameText("NotFound")
    screen:textCentre(name, centre, 80, ink(1))
    local hint = (self.hats[i] > 0 and i == self.hat) and gameText("HintTakeOff") or gameText("HintWear")
    screen:textCentre(hint, centre, 100, ink(2))
end
