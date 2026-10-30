-- Spiffo Pup: the catch game PLAY opens. A ball is thrown in from the top, one
-- at a time, BALLS in a round, each a little faster; the pup runs left and
-- right along the floor to catch it. Each catch is Pup.CATCH_FUN fun, given
-- when the player confirms the round (the press that saves).
--
-- Positions in pixels of the screen, as floats; the round is played by the
-- arrows and seeded by the game's own self.random, so it repeats.

require "VitalityCartridges/Core"

VitalityCartridges.SpiffoPup = VitalityCartridges.SpiffoPup or {}

local Catch = {}
VitalityCartridges.SpiffoPup.Catch = Catch

Catch.BALLS = 8
Catch.PUP_W = 24                 -- the pup's cell
Catch.BALL = 6                   -- the ball's mask
Catch.TOP = 16                   -- where a ball comes in
Catch.FLOOR = 104                -- the floor line; the pup stands on it
Catch.PUP_Y = Catch.FLOOR - Catch.PUP_W
Catch.MOUTH = Catch.PUP_Y + 4    -- a ball this low over the pup is caught

local GAP = 30                   -- ticks between one ball and the next
local SPEED = 2                  -- the pup's run, pixels a tick while an arrow is held
local TAP = 4                    -- a quick tap moves this much
local FALL, FALL_STEP = 1.0, 0.1 -- the first ball's fall a tick, and what each next adds
local DRIFT = 0.5                -- the most a ball drifts sideways a tick
local REACH = 2                  -- the pup's paws reach this far past its sides' fur

-- a round on a screen of the given width, in pixels
function Catch.new(random, width)
    return {
        random = random,
        width = width,
        x = math.floor((width - Catch.PUP_W) / 2),
        thrown = 0, caught = 0,
        ball = nil, wait = GAP,
        event = nil,             -- "throw", "catch" or "miss" on the tick it happens
        over = false,
    }
end

local function throw(c)
    c.thrown = c.thrown + 1
    c.ball = {
        x = c.random:int(4, c.width - Catch.BALL - 4),
        y = Catch.TOP,
        vx = c.random:range(-DRIFT, DRIFT),
        vy = FALL + FALL_STEP * (c.thrown - 1),
    }
    c.event = "throw"
end

local function moveBall(c, b)
    b.x = b.x + b.vx
    if b.x < 0 then
        b.x, b.vx = 0, -b.vx
    elseif b.x > c.width - Catch.BALL then
        b.x, b.vx = c.width - Catch.BALL, -b.vx
    end
    local before = b.y + Catch.BALL
    b.y = b.y + b.vy
    local bottom = b.y + Catch.BALL
    -- crossing the pup's mouth line over the pup: caught
    if before < Catch.MOUTH and bottom >= Catch.MOUTH then
        local centre = b.x + Catch.BALL / 2
        if centre >= c.x - REACH and centre <= c.x + Catch.PUP_W + REACH then
            c.caught = c.caught + 1
            c.ball, c.wait, c.event = nil, GAP, "catch"
            return
        end
    end
    if bottom >= Catch.FLOOR then
        c.ball, c.wait, c.event = nil, GAP, "miss"
    end
end

-- one tick of the round; c.event names what happened in it
function Catch.tick(c, input)
    c.event = nil
    if c.over then return end
    local dx = input:axes()
    local pressed = input.pressed
    local move = dx * SPEED
    if dx == 0 then
        if pressed.left then move = move - TAP end
        if pressed.right then move = move + TAP end
    end
    c.x = math.max(0, math.min(c.width - Catch.PUP_W, c.x + move))
    if c.ball then
        moveBall(c, c.ball)
    elseif c.thrown >= Catch.BALLS then
        c.over = true
    else
        c.wait = c.wait - 1
        if c.wait <= 0 then throw(c) end
    end
end
