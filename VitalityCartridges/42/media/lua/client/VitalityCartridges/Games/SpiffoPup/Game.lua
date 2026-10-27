-- Spiffo Pup: a raccoon kit that lives on the cartridge.
--
-- Hatch it from its egg, then keep it fed, played with and clean. Its needs
-- fall by the game hour (Pup.lua), also while the console is off: the pup and
-- the hours it was last brought up to date at live in the save, and the time
-- since is caught up (at most CATCH_UP_MAX hours) the moment the game learns
-- the hours again. Left sick for a day, it runs away, and A hatches a new egg.
--
-- Screens: the egg (A hatches), the room (left and right pick FEED, PLAY,
-- CLEAN or LIGHTS, A does it), the catch game PLAY opens (Catch.lua) and its
-- end. Each care is a press and saves: FEED, CLEAN and LIGHTS on their press,
-- PLAY on the press that confirms the end of the round; the hatch saves too,
-- and B (sound on or off) anywhere.
--
-- For the Vitality Project. self.vitality = {} from init. Vitality writes
-- vitality.hours, the world's age in game hours, once a game minute; without
-- it the game counts its own ticks while on, a game hour every OWN_TICKS (a day
-- of 1 hour). The game writes vitality.care (the lowest need, 0..1; 0 without
-- a pup), vitality.gone (it ran away and no new egg hatched yet) and
-- vitality.cared (care actions this power-on). It never reads the character,
-- so it stays deterministic.

require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "VitalityCartridges/Games/SpiffoPup/Music"
require "VitalityCartridges/Games/SpiffoPup/Pup"
require "VitalityCartridges/Games/SpiffoPup/Catch"

VitalityCartridgesSpiffoPupGame = SpiffBoyGameBase:derive("VitalityCartridgesSpiffoPupGame")

local Game = VitalityCartridgesSpiffoPupGame
local Music = VitalityCartridges.SpiffoPup.Music
local Pup = VitalityCartridges.SpiffoPup.Pup
local Catch = VitalityCartridges.SpiffoPup.Catch
local gameText = SpiffBoy.GameTexts.of("SpiffoPup")
local SHADES = SpiffBoy.Cartridges.SHADES

local TICKS = 60                 -- ticks a second
local OWN_TICKS = 150 * TICKS    -- the console's own clock: a game hour every 150 seconds
local CATCH_UP_MAX = 72          -- game hours caught up at once, at most: past running away either way

-- the art (sizes as make_spiffo_pup_art.py draws them)
local PUP = 24
local FRAME = { idle = 0, bob = 1, eat = 2, happy = 3, sick = 4, asleep = 5 }
local EGG_W, EGG_H = 16, 20
local MESS_W, MESS_H = 12, 10
local BOWL_W, BOWL_H = 14, 6
local THREE = { 1, 2, 3 }        -- shades 1 to 3: the art's 4s are the lit room's paper
local ALL_SHADES = { 1, 2, 3, 4 }

-- the room
local BAR_X = { 4, 64, 124 }
local BAR_Y, BAR_W, BAR_H = 14, 52, 3
local LOW = 25                   -- a need under this blinks
local FLOOR_Y = 88
local PUP_Y = FLOOR_Y - PUP
local MESS_AT = { { 10, 78 }, { 154, 78 }, { 32, 80 }, { 132, 80 } }
local WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H = 146, 24, 24, 18
local STATUS_Y = 90
local MENU_Y = 105
local MENU_X = { 23, 67, 112, 157 }
local MENU_FEED, MENU_PLAY, MENU_CLEAN, MENU_LIGHTS, MENU_SIZE = 1, 2, 3, 4, 4

local WANDER_MIN, WANDER_MAX = 30, 124
local WANDER_GAP_MIN, WANDER_GAP_MAX = 2 * TICKS, 6 * TICKS
local WALK_EVERY = 4             -- ticks a pixel of the pup's wander
local EAT_TICKS = 90
local HAPPY_TICKS = 60
local NOTE_TICKS = 2 * TICKS
local HATCH_TICKS = 90
local CRACK_TICKS = 40           -- the last of the hatch shows the egg cracked
local HINT_TICKS = 3 * TICKS

local EGG_X, EGG_Y = 82, 34

local MODE_EGG, MODE_ROOM, MODE_CATCH, MODE_CAUGHT = "egg", "room", "catch", "caught"

local function ink(i)
    local s = SHADES[i]
    return s.r, s.g, s.b
end

local function readCount(v)
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.min(math.floor(v), 9999)
end

local function readSound(save)
    local o = save.options
    return type(o) ~= "table" or o.sound ~= false
end

-- the world's hours from Vitality, or nil when it gives none (or nonsense)
local function readHours(v)
    if type(v) ~= "number" or v ~= v or v < 0 or v > 1e9 then return nil end
    return v
end

function Game:init()
    local art = self.context.art
    self.pupArt = art("pup")
    self.eggArt = art("egg")
    self.messArt = art("mess")
    self.bowlArt = art("bowl")
    self.ballArt = art("ball")
    self.pup = Pup.read(self.save.pup)
    self.gone = self.pup == nil and self.save.gone == true
    self.pups = readCount(self.save.pups)
    self.soundOn = readSound(self.save)
    self.ticks = 0
    self.cared = 0
    self.tune = nil
    self.noteText, self.noteTicks = nil, 0
    self.eatTicks, self.happyTicks, self.hatchTicks = 0, 0, 0
    self.pupX, self.target, self.wanderWait = 78, 78, WANDER_GAP_MIN
    self.selection = MENU_FEED
    self.vitality = {}
    if self.pup then
        self:enterRoom()
    else
        self:enterEgg()
    end
    self:report()
end

function Game:cue(name)
    if self.soundOn then self.sequencer:effect(name) end
end

-- the music the screen wants, started only when it changes
function Game:keepTune()
    local want = nil
    if self.soundOn then
        if self.mode == MODE_CATCH then
            want = Music.CATCH
        elseif self.mode == MODE_ROOM and not self.pup.lights then
            want = Music.NIGHT
        else
            want = Music.ROOM
        end
    end
    if want == self.tune then return end
    self.tune = want
    if want then
        self.sequencer:play(want)
    else
        self.sequencer:stop()
    end
end

function Game:note(text)
    self.noteText, self.noteTicks = text, NOTE_TICKS
end

-- what Vitality reads, every tick
function Game:report()
    local v = self.vitality
    v.care = self.pup and Pup.lowest(self.pup) / Pup.FULL or 0
    v.gone = self.gone
    v.cared = self.cared
end

-- on a press: everything, in one write
function Game:writeSave()
    local save = self.save
    save.pup = self.pup and Pup.write(self.pup) or nil
    save.gone = self.gone
    save.pups = self.pups
    save.options = { sound = self.soundOn }
    self:persist()
end

-- screens -------------------------------------------------------------------------------

function Game:enterEgg()
    self.mode = MODE_EGG
    self.hatchTicks = 0
end

function Game:enterRoom()
    self.mode = MODE_ROOM
end

function Game:enterCatch()
    self.mode = MODE_CATCH
    self.catch = Catch.new(self.random)
    self.catchTicks = 0
end

function Game:enterCaught()
    self.mode = MODE_CAUGHT
    self.caughtTicks = 0
end

-- the clock ------------------------------------------------------------------------------

-- brings the pup up to the hours now: the world's when Vitality gives them,
-- else a tick of the console's own clock. A pup whose hours were the console's
-- own takes the world's as they are (the two do not compare); the world's
-- hours going back (a cartridge carried to a younger world) only move the
-- mark, so the pup never lives an hour twice nor gets one back.
function Game:tickClock()
    local p = self.pup
    if not p then return end
    local now = readHours(self.vitality.hours)
    if now == nil then
        Pup.advance(p, 1 / OWN_TICKS)
        p.at = p.at + 1 / OWN_TICKS
    elseif not p.world then
        p.at, p.world = now, true
    elseif now > p.at then
        Pup.advance(p, math.min(now - p.at, CATCH_UP_MAX))
        p.at = now
    elseif now < p.at then
        p.at = now
    end
    if p.gone then self:runAway() end
end

function Game:runAway()
    self.pup = nil
    self.gone = true
    self.catch = nil
    self:enterEgg()
    self:cue(Music.GONE)
end

-- ticks ---------------------------------------------------------------------------------

function Game:tick(inputs, tick)
    local input = inputs[1]
    self.ticks = self.ticks + 1
    self:tickClock()
    if self.noteTicks > 0 then self.noteTicks = self.noteTicks - 1 end
    if self.eatTicks > 0 then self.eatTicks = self.eatTicks - 1 end
    if self.happyTicks > 0 then self.happyTicks = self.happyTicks - 1 end
    if self.mode == MODE_EGG then
        self:tickEgg(input)
    elseif self.mode == MODE_ROOM then
        self:tickRoom(input)
    elseif self.mode == MODE_CATCH then
        self:tickCatch(input)
    else
        self:tickCaught(input)
    end
    if input.pressed.b then self:toggleSound() end
    self:keepTune()
    self:report()
end

function Game:toggleSound()
    self.soundOn = not self.soundOn
    self:note(self.soundOn and gameText("SoundOn") or gameText("SoundOff"))
    self:cue(Music.SELECT)
    self:writeSave()
end

function Game:tickEgg(input)
    if self.hatchTicks > 0 then
        self.hatchTicks = self.hatchTicks - 1
        if self.hatchTicks <= 0 then
            self.happyTicks = HAPPY_TICKS
            self:enterRoom()
        end
        return
    end
    local pressed = input.pressed
    if pressed.a or pressed.start then self:hatch() end
end

-- a new pup from the egg, its clock the world's when known
function Game:hatch()
    local now = readHours(self.vitality.hours)
    self.pup = Pup.new(now or 0, now ~= nil)
    self.gone = false
    self.pups = math.min(self.pups + 1, 9999)
    self.pupX, self.target = 78, 78
    self.hatchTicks = HATCH_TICKS
    self:cue(Music.HATCH)
    self:writeSave()
end

function Game:tickRoom(input)
    local pressed = input.pressed
    if pressed.left then
        self.selection = (self.selection - 2 + MENU_SIZE) % MENU_SIZE + 1
        self:cue(Music.MOVE)
    elseif pressed.right then
        self.selection = self.selection % MENU_SIZE + 1
        self:cue(Music.MOVE)
    end
    if pressed.a then self:act(self.selection) end
    self:wander()
end

-- one care action, from the menu
function Game:act(choice)
    local p = self.pup
    if choice == MENU_PLAY then
        if not p.lights then
            self:note(gameText("Asleep"))
            self:cue(Music.NO)
            return
        end
        self:cue(Music.SELECT)
        self:enterCatch()
        return
    end
    if choice == MENU_FEED then
        if not Pup.feed(p) then
            self:note(gameText("Full"))
            self:cue(Music.NO)
            return
        end
        self.eatTicks = EAT_TICKS
        self:note(gameText("Yum"))
        self:cue(Music.EAT)
    elseif choice == MENU_CLEAN then
        if not Pup.clean(p) then
            self:note(gameText("AlreadyClean"))
            self:cue(Music.NO)
            return
        end
        self.happyTicks = HAPPY_TICKS
        self:note(gameText("Sparkle"))
        self:cue(Music.CLEAN)
    else
        Pup.toggleLights(p)
        self:note(p.lights and gameText("Morning") or gameText("Night"))
        self:cue(Music.LIGHTS)
    end
    self.cared = self.cared + 1
    self:writeSave()
end

-- awake and well, the pup potters about the room
function Game:wander()
    local p = self.pup
    if self.eatTicks > 0 or not p.lights or p.sick then return end
    self.wanderWait = self.wanderWait - 1
    if self.wanderWait <= 0 then
        self.target = self.random:int(WANDER_MIN, WANDER_MAX)
        self.wanderWait = self.random:int(WANDER_GAP_MIN, WANDER_GAP_MAX)
    end
    if self.ticks % WALK_EVERY == 0 and self.pupX ~= self.target then
        self.pupX = self.pupX + (self.target > self.pupX and 1 or -1)
    end
end

function Game:tickCatch(input)
    local c = self.catch
    self.catchTicks = self.catchTicks + 1
    Catch.tick(c, input)
    if c.event == "catch" then
        self.happyTicks = 20
        self:cue(Music.CAUGHT)
    elseif c.event == "miss" then
        self:cue(Music.MISS)
    elseif c.event == "throw" then
        self:cue(Music.THROW)
    end
    if c.over or input.pressed.start then self:enterCaught() end
end

-- the round's end: its confirming press gives the fun and saves
function Game:tickCaught(input)
    self.caughtTicks = self.caughtTicks + 1
    local pressed = input.pressed
    if pressed.a or pressed.start then
        Pup.play(self.pup, self.catch.caught)
        self.cared = self.cared + 1
        self.happyTicks = HAPPY_TICKS
        self:cue(Music.SELECT)
        self.catch = nil
        self:enterRoom()
        self:writeSave()
    end
end

-- drawing ------------------------------------------------------------------------------

function Game:draw(screen)
    if self.mode == MODE_EGG then
        self:drawEgg(screen)
    elseif self.mode == MODE_ROOM then
        self:drawRoom(screen)
    elseif self.mode == MODE_CATCH then
        self:drawCatch(screen)
    else
        self:drawCaught(screen)
    end
end

-- the frame of the pup now; moving says it is on its way somewhere
function Game:frame(moving)
    local p = self.pup
    if self.eatTicks > 0 then return FRAME.eat end
    if self.happyTicks > 0 then return FRAME.happy end
    if not p.lights then return FRAME.asleep end
    if p.sick then return FRAME.sick end
    local beat = moving and 8 or 30
    return math.floor(self.ticks / beat) % 2 == 0 and FRAME.idle or FRAME.bob
end

function Game:drawPup(screen, frame, x, y, shades)
    screen:layers(self.pupArt, frame * PUP, PUP, PUP, math.floor(x), y, shades)
end

function Game:drawBar(screen, label, value, x, fg, dim)
    local low = value < LOW and math.floor(self.ticks / 20) % 2 == 0
    screen:text(label, x, 0, ink(low and dim or fg))
    screen:rect(x, BAR_Y, BAR_W, BAR_H, ink(dim))
    local fill = math.floor(BAR_W * value / Pup.FULL + 0.5)
    if fill > 0 then screen:rect(x, BAR_Y, fill, BAR_H, ink(fg)) end
end

function Game:drawRoom(screen)
    local p = self.pup
    local lit = p.lights
    local bg, fg, dim = 4, 1, 3
    if not lit then bg, fg, dim = 2, 4, 1 end
    screen:clear(ink(bg))
    self:drawBar(screen, gameText("Food"), p.food, BAR_X[1], fg, dim)
    self:drawBar(screen, gameText("Fun"), p.fun, BAR_X[2], fg, dim)
    self:drawBar(screen, gameText("Clean"), p.clean, BAR_X[3], fg, dim)
    -- the window: daylight, or the moon
    screen:rect(WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H, ink(lit and 3 or 1))
    screen:rect(WINDOW_X + 2, WINDOW_Y + 2, WINDOW_W - 4, WINDOW_H - 4, ink(lit and 4 or 1))
    screen:rect(WINDOW_X + WINDOW_W / 2 - 1, WINDOW_Y, 2, WINDOW_H, ink(lit and 3 or 2))
    if not lit then screen:rect(WINDOW_X + 5, WINDOW_Y + 4, 3, 3, ink(4)) end
    screen:rect(0, FLOOR_Y, screen.width, 1, ink(lit and 3 or 1))
    for i = 1, math.min(p.messes, #MESS_AT) do
        local at = MESS_AT[i]
        screen:layers(self.messArt, 0, MESS_W, MESS_H, at[1], at[2], THREE)
    end
    local x = math.floor(self.pupX)
    local frame = self:frame(self.pupX ~= self.target)
    self:drawPup(screen, frame, x, PUP_Y, lit and THREE or ALL_SHADES)
    if self.eatTicks > 0 then
        screen:layers(self.bowlArt, 0, BOWL_W, BOWL_H, x + 5, PUP_Y + PUP - BOWL_H, THREE)
    elseif frame == FRAME.asleep then
        local up = math.floor(self.ticks / 40) % 2
        screen:text(gameText("Snore"), x + 20, PUP_Y - 8 - up * 3, ink(fg))
        screen:text(gameText("Snore"), x + 26, PUP_Y - 16 + up * 3, ink(3))
    end
    -- the status line: a note, or the day and how it is
    local centre = math.floor(screen.width / 2)
    if self.noteTicks > 0 and self.noteText then
        screen:textCentre(self.noteText, centre, STATUS_Y, ink(fg))
    else
        screen:text(gameText("Day", math.floor(p.age / 24) + 1), 4, STATUS_Y, ink(fg))
        if p.sick and math.floor(self.ticks / 30) % 2 == 0 then
            screen:textRight(gameText("Sick"), screen.width - 4, STATUS_Y, ink(fg))
        end
    end
    self:drawMenu(screen, bg, fg)
end

function Game:drawMenu(screen, bg, fg)
    for i = 1, MENU_SIZE do
        local label
        if i == MENU_FEED then
            label = gameText("Feed")
        elseif i == MENU_PLAY then
            label = gameText("Play")
        elseif i == MENU_CLEAN then
            label = gameText("CleanUp")
        else
            label = gameText("Lights")
        end
        local cx = MENU_X[i]
        if i == self.selection then
            local w = screen:textWidth(label) + 6
            screen:rect(cx - math.floor(w / 2), MENU_Y, w, screen:lineHeight(), ink(fg))
            screen:textCentre(label, cx, MENU_Y, ink(bg))
        else
            screen:textCentre(label, cx, MENU_Y, ink(fg))
        end
    end
end

function Game:drawCatch(screen)
    local c = self.catch
    screen:clear(ink(4))
    screen:text(gameText("Caught", c.caught), 4, 0, ink(1))
    screen:textRight(gameText("Ball", math.max(c.thrown, 1), Catch.BALLS), screen.width - 4, 0, ink(3))
    screen:rect(0, Catch.FLOOR, screen.width, 1, ink(1))
    if c.ball then
        screen:sprite(self.ballArt, math.floor(c.ball.x), math.floor(c.ball.y), Catch.BALL, Catch.BALL, 1, 1)
    end
    local frame = self.happyTicks > 0 and FRAME.happy
        or (math.floor(self.ticks / 8) % 2 == 0 and FRAME.idle or FRAME.bob)
    self:drawPup(screen, frame, c.x, Catch.PUP_Y, THREE)
    local centre = math.floor(screen.width / 2)
    if self.catchTicks < HINT_TICKS then
        screen:textCentre(gameText("CatchHint"), centre, Catch.FLOOR + 2, ink(1))
    else
        screen:textCentre(gameText("HintStop"), centre, Catch.FLOOR + 2, ink(3))
    end
end

function Game:drawCaught(screen)
    local c = self.catch
    local centre = math.floor(screen.width / 2)
    screen:clear(ink(4))
    screen:textCentre(gameText("GoodPup"), centre, 8, ink(1))
    screen:textCentre(gameText("CaughtOf", c.caught, Catch.BALLS), centre, 28, ink(1))
    screen:textCentre(gameText("FunGain", c.caught * Pup.CATCH_FUN), centre, 44, ink(2))
    self:drawPup(screen, FRAME.happy, centre - PUP / 2, 64, THREE)
    if math.floor(self.caughtTicks / 30) % 2 == 0 then
        screen:textCentre(gameText("HintDone"), centre, 100, ink(3))
    end
end

function Game:drawEgg(screen)
    local centre = math.floor(screen.width / 2)
    screen:clear(ink(4))
    screen:textCentre(gameText("Title"), centre, 4, ink(1))
    local hatching = self.hatchTicks > 0
    local cell, x = 0, EGG_X
    if hatching then
        if self.hatchTicks <= CRACK_TICKS then
            cell = 1
        elseif math.floor(self.hatchTicks / 6) % 2 == 0 then
            x = x + 1
        else
            x = x - 1
        end
    end
    screen:layers(self.eggArt, cell * EGG_W, EGG_W, EGG_H, x, EGG_Y, THREE)
    if hatching then
        screen:textCentre(gameText("Hatching"), centre, 66, ink(1))
        return
    end
    if self.gone then
        screen:textCentre(gameText("RanAway"), centre, 62, ink(1))
        screen:textCentre(gameText("TooLong"), centre, 76, ink(2))
    end
    if math.floor(self.ticks / 30) % 2 == 0 then
        screen:textCentre(self.gone and gameText("NewEgg") or gameText("Hatch"), centre, 100, ink(3))
    end
end
