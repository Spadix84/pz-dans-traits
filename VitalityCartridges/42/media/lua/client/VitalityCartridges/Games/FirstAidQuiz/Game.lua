-- First Aid Quiz: ten questions a round on staying alive.
--
-- A bank of forty questions on bleeding and bandages, stitches and splints,
-- wound infection, concussion, blood loss and shock, fainting, the medicines,
-- thirst and the sun. Every answer is what the Vitality Project and the game
-- actually do (the texts name no file, the bank was checked against the Lua).
-- A round deals ten from a shuffled deck, so no question comes twice in a
-- round and four rounds go through all forty before the deck is shuffled
-- again. Each question shows its three answers in a shuffled order: up and
-- down pick, A answers. Then the right answer and why. START gives a round up.
--
-- Screens: the title (START ROUND, SOUND, the best and the rounds played), the
-- question, the answer, the summary. The summary's A or START saves the best
-- score, the rounds played and the sound on the cartridge (the console allows
-- a save only on a press).
--
-- For the Vitality Project. self.vitality = { rounds, lastScore, lastTotal }:
-- the rounds finished this power-on (from 0), and the score and length of the
-- last one, written when a round ends. Vitality reads it from outside
-- (DanTraits_SpiffBoy.lua); the game never reads the character, so it stays
-- deterministic.

require "VitalityCartridges/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "VitalityCartridges/Games/FirstAidQuiz/Music"

VitalityCartridgesFirstAidQuizGame = SpiffBoyGameBase:derive("VitalityCartridgesFirstAidQuizGame")

local Game = VitalityCartridgesFirstAidQuizGame
local Music = VitalityCartridges.FirstAidQuiz.Music
local gameText = SpiffBoy.GameTexts.of("FirstAidQuiz")
local SHADES = SpiffBoy.Cartridges.SHADES

local BANK = 40                  -- questions in EN.json: Q1 .. Q40
local ROUND = 10                 -- questions a round
-- each question's texts: Q<n> the question, Q<n>A the right answer, Q<n>B and
-- Q<n>C the wrong ones, Q<n>R why
local ANSWER_KEYS = { "A", "B", "C" }
local RIGHT = 1                  -- the right answer is the first of ANSWER_KEYS

-- the verdicts: a perfect round, then from these scores (8 is what Vitality rewards)
local MEDIC, AIDER = 8, 5

-- the art (sizes as make_first_aid_quiz_art.py draws them)
local KIT_W, KIT_H = 32, 24
local KIT_SHADES = { 1, 2, 4 }
local MARK = 11
local MARK_TICK, MARK_CROSS, MARK_PLUS = 0, 1, 2

-- the layout
local MARGIN = 4
local TEXT_W = 172               -- a question or a reason wraps to this
local HEADER_H = 15
local QUESTION_Y = 18            -- three lines at most
local ANSWER_Y, ANSWER_STEP = 62, 18
local BAR_X, BAR_W, BAR_H = 2, 176, 15
local REASON_Y = 38              -- four lines at most
local HINT_Y = 104
local BLINK = 30                 -- ticks a hint is shown, then hidden

local MAX_PLAYED = 999999

local MODE_TITLE, MODE_QUESTION, MODE_ANSWER, MODE_SUMMARY = "title", "question", "answer", "summary"
local MENU_START, MENU_SOUND, MENU_SIZE = 1, 2, 2
local MENU_Y, MENU_STEP, MENU_BAR = 50, 16, 120

local function ink(i)
    local s = SHADES[i]
    return s.r, s.g, s.b
end

local function readNumber(v, hi)
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.min(math.floor(v), hi)
end

local function readSound(save)
    local o = save.options
    return type(o) ~= "table" or o.sound ~= false
end

function Game:init()
    local art = self.context.art
    self.kit = art("kit")
    self.marks = art("marks")
    self.best = readNumber(self.save.best, ROUND)
    self.played = readNumber(self.save.played, MAX_PLAYED)
    self.soundOn = readSound(self.save)
    self.ticks = 0
    -- the deck: every question once, shuffled when a round would run past its end
    self.deck = {}
    for i = 1, BANK do self.deck[i] = i end
    self.deckAt = BANK + 1
    self.vitality = { rounds = 0 }
    self:enterTitle()
    self:applySound()
end

function Game:applySound()
    if self.soundOn then
        self.sequencer:play(Music.THEME)
    else
        self.sequencer:stop()
    end
end

function Game:cue(name)
    if self.soundOn then self.sequencer:effect(name) end
end

-- the deck ------------------------------------------------------------------------------

-- Fisher-Yates, from the console's seeded generator
function Game:shuffle(list)
    for i = #list, 2, -1 do
        local j = self.random:int(1, i)
        list[i], list[j] = list[j], list[i]
    end
end

-- the next ROUND questions off the deck
function Game:deal()
    if self.deckAt + ROUND - 1 > BANK then
        self:shuffle(self.deck)
        self.deckAt = 1
    end
    local round = {}
    for k = 1, ROUND do round[k] = self.deck[self.deckAt + k - 1] end
    self.deckAt = self.deckAt + ROUND
    return round
end

-- screens -------------------------------------------------------------------------------

function Game:enterTitle()
    self.mode = MODE_TITLE
    self.selection = MENU_START
end

function Game:enterRound()
    self.round = self:deal()
    self.index = 0
    self.score = 0
    self.newBest = false
    self:enterQuestion()
end

-- the next question of the round: its lines wrapped and its answers shuffled, once
function Game:enterQuestion()
    self.mode = MODE_QUESTION
    self.index = self.index + 1
    self.question = self.round[self.index]
    local n = self.question
    self.order = { 1, 2, 3 }
    self:shuffle(self.order)
    self.lines = self.screen:wrapText(gameText("Q" .. n), TEXT_W)
    self.answers = {}
    for i, k in ipairs(self.order) do self.answers[i] = gameText("Q" .. n .. ANSWER_KEYS[k]) end
    self.selection = 1
end

function Game:enterAnswer(right)
    self.mode = MODE_ANSWER
    self.wasRight = right
    local n = self.question
    self.rightText = gameText("Q" .. n .. ANSWER_KEYS[RIGHT])
    self.reason = self.screen:wrapText(gameText("Q" .. n .. "R"), TEXT_W)
    self.answerTicks = 0
end

-- the round is over: what Vitality reads, and the best
function Game:enterSummary()
    self.mode = MODE_SUMMARY
    self.summaryTicks = 0
    self.played = math.min(self.played + 1, MAX_PLAYED)
    if self.score > self.best then
        self.best = self.score
        self.newBest = true
    end
    local v = self.vitality
    v.rounds = v.rounds + 1
    v.lastScore = self.score
    v.lastTotal = ROUND
    self:cue(self.score == ROUND and Music.PERFECT or Music.DONE)
end

-- ticks ---------------------------------------------------------------------------------

function Game:tick(inputs, tick)
    local input = inputs[1]
    self.ticks = self.ticks + 1
    if self.mode == MODE_TITLE then
        self:tickTitle(input)
    elseif self.mode == MODE_QUESTION then
        self:tickQuestion(input)
    elseif self.mode == MODE_ANSWER then
        self:tickAnswer(input)
    else
        self:tickSummary(input)
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
        if self.selection == MENU_START then
            self:enterRound()
        else
            self.soundOn = not self.soundOn
            self:applySound()
        end
    end
end

function Game:tickQuestion(input)
    local pressed = input.pressed
    if pressed.start then
        self:enterTitle()
        return
    end
    local n = #self.answers
    if pressed.up then
        self.selection = (self.selection - 2 + n) % n + 1
        self:cue(Music.MOVE)
    elseif pressed.down then
        self.selection = self.selection % n + 1
        self:cue(Music.MOVE)
    end
    if pressed.a then
        local right = self.order[self.selection] == RIGHT
        if right then self.score = self.score + 1 end
        self:cue(right and Music.RIGHT or Music.WRONG)
        self:enterAnswer(right)
    end
end

-- A goes on; START gives the round up, except after the last answer, where
-- both go to the summary
function Game:tickAnswer(input)
    self.answerTicks = self.answerTicks + 1
    local pressed = input.pressed
    local last = self.index >= ROUND
    if pressed.start and not last then
        self:enterTitle()
    elseif pressed.a or pressed.start then
        self.sequencer:effect(Music.SELECT)
        if last then
            self:enterSummary()
        else
            self:enterQuestion()
        end
    end
end

function Game:tickSummary(input)
    self.summaryTicks = self.summaryTicks + 1
    local pressed = input.pressed
    if pressed.a or pressed.start then
        self.sequencer:effect(Music.SELECT)
        self:saveRound()
        self:enterTitle()
    end
end

-- on the press that confirms the summary: everything that changed, in one write
function Game:saveRound()
    local save = self.save
    save.best = self.best
    save.played = self.played
    save.options = { sound = self.soundOn }
    self:persist()
end

-- drawing ------------------------------------------------------------------------------

function Game:draw(screen)
    screen:clear(ink(4))
    if self.mode == MODE_TITLE then
        self:drawTitle(screen)
    elseif self.mode == MODE_QUESTION then
        self:drawQuestion(screen)
    elseif self.mode == MODE_ANSWER then
        self:drawAnswer(screen)
    else
        self:drawSummary(screen)
    end
end

function Game:drawMark(screen, cell, x, y, shade)
    screen:sheet(self.marks, cell * MARK, 0, MARK, MARK, x, y, 1, shade)
end

-- the dark strip along the top: a line on the left, the score on the right
function Game:drawHeader(screen, left, x)
    screen:rect(0, 0, screen.width, HEADER_H, ink(1))
    screen:text(left, x or MARGIN, 1, ink(4))
    screen:textRight(gameText("Score", self.score), screen.width - MARGIN, 1, ink(3))
end

function Game:drawLines(screen, lines, y)
    for i = 1, #lines do
        screen:text(lines[i], MARGIN, y + (i - 1) * screen:lineHeight(), ink(1))
    end
end

function Game:drawHint(screen, hint, ticks)
    if math.floor(ticks / BLINK) % 2 == 0 then
        screen:textCentre(hint, math.floor(screen.width / 2), HINT_Y, ink(2))
    end
end

local function verdictOf(score)
    if score >= ROUND then return gameText("Perfect") end
    if score >= MEDIC then return gameText("Medic") end
    if score >= AIDER then return gameText("Aider") end
    return gameText("Reading")
end

function Game:drawTitle(screen)
    local centre = math.floor(screen.width / 2)
    screen:textCentre(gameText("Title"), centre, 4, ink(1))
    screen:layers(self.kit, 0, KIT_W, KIT_H, centre - KIT_W / 2, 22, KIT_SHADES)
    local labels = { gameText("Start"), self.soundOn and gameText("SoundOn") or gameText("SoundOff") }
    for i = 1, MENU_SIZE do
        local y = MENU_Y + (i - 1) * MENU_STEP
        if i == self.selection then
            screen:rect(centre - MENU_BAR / 2, y, MENU_BAR, screen:lineHeight(), ink(1))
            screen:textCentre(labels[i], centre, y, ink(4))
        else
            screen:textCentre(labels[i], centre, y, ink(2))
        end
    end
    screen:textCentre(gameText("Best", self.best, ROUND), centre, 88, ink(1))
    screen:textCentre(gameText("Played", self.played), centre, 104, ink(2))
end

function Game:drawQuestion(screen)
    self:drawHeader(screen, gameText("Question", self.index, ROUND))
    self:drawLines(screen, self.lines, QUESTION_Y)
    for i, answer in ipairs(self.answers) do
        local y = ANSWER_Y + (i - 1) * ANSWER_STEP
        local chosen = i == self.selection
        screen:rect(BAR_X, y - 1, BAR_W, BAR_H, ink(chosen and 1 or 3))
        screen:text(answer, BAR_X + MARGIN, y, ink(chosen and 4 or 1))
    end
end

function Game:drawAnswer(screen)
    local mark = self.wasRight and MARK_TICK or MARK_CROSS
    self:drawHeader(screen, self.wasRight and gameText("Right") or gameText("Wrong"), MARGIN + MARK + 3)
    self:drawMark(screen, mark, MARGIN, 2, 4)
    screen:rect(BAR_X, QUESTION_Y - 1, BAR_W, BAR_H, ink(2))
    screen:text(self.rightText, BAR_X + MARGIN, QUESTION_Y, ink(4))
    self:drawLines(screen, self.reason, REASON_Y)
    local hint = self.index >= ROUND and gameText("HintResults") or gameText("HintNext")
    self:drawHint(screen, hint, self.answerTicks)
end

function Game:drawSummary(screen)
    local centre = math.floor(screen.width / 2)
    local title = gameText("Done")
    local half = math.floor(screen:textWidth(title) / 2)
    screen:textCentre(title, centre, 8, ink(1))
    self:drawMark(screen, MARK_PLUS, centre - half - MARK - 6, 10, 1)
    self:drawMark(screen, MARK_PLUS, centre + half + 6, 10, 1)
    screen:textCentre(gameText("Result", self.score, ROUND), centre, 32, ink(1))
    screen:textCentre(verdictOf(self.score), centre, 50, ink(2))
    if self.newBest then
        screen:textCentre(gameText("NewBest"), centre, 72, ink(1))
    else
        screen:textCentre(gameText("Best", self.best, ROUND), centre, 72, ink(2))
    end
    self:drawHint(screen, gameText("HintSave"), self.summaryTicks)
end
