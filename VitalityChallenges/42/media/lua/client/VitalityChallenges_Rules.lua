-- Vitality Challenges: rules a challenge switches on in its spec.
--
--   noDriving = true   no engine starts and no hotwiring: the two timed actions'
--                      isValid say no while the challenge is ours and has the
--                      rule, and an engine found running under the driver is
--                      shut off on the minute. Cars stay, as loot, cover and a
--                      place to sit out a storm.
--   oneLife = true     the post-death screen's continue button is off (as the
--                      game does for CDDA), and a new character made in the
--                      world afterwards is turned back to the main menu.
--   goal = { x1, y1, x2, y2, z }   inside that box on floor z or higher wins:
--                      a summary, the record line, then play on as you like.
-- With any of them the walk is tallied in the world's ModData (tiles on foot,
-- kills, days since the start) and each ending is appended to
-- Zomboid/Lua/VitalityChallenges.txt, one line per run.

require "VitalityChallenges_Core"
local VC = VitalityChallenges

local RECORD_FILE = "VitalityChallenges.txt"
local STEP_CAP    = 60      -- tiles in one game minute past which a move is a teleport, not a walk
local NOTE_GAP_MS = 4000    -- a held key asks isValid every tick; one line per four seconds

local function ruled(spec) return spec and (spec.noDriving or spec.oneLife or spec.goal) end

local function currentSpec()
    local c = VC.current()
    return c and c.spec, c
end

local lastNote = -NOTE_GAP_MS
local function note(player, text)
    local now = getTimestampMs and getTimestampMs() or 0
    if now - lastNote < NOTE_GAP_MS then return end
    lastNote = now
    pcall(function() HaloTextHelper.addBadText(player, text) end)
end

local worldHours = VC.worldHours

-- the walk ----------------------------------------------------------------------

local function tally(ctx)
    local t = ctx.state.tally
    if not t then
        t = { tiles = 0, startH = worldHours() }
        ctx.state.tally = t
    end
    return t
end

local function step(ctx, player)
    local t = tally(ctx)
    local x, y = player:getX(), player:getY()
    if t.x and not player:getVehicle() then
        local dx, dy = x - t.x, y - t.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= STEP_CAP then t.tiles = t.tiles + d end
    end
    t.x, t.y = x, y
end

local function professionName(player)
    local name = "?"
    pcall(function()
        local prof = player:getDescriptor():getCharacterProfession()
        name = tostring(prof)
        local def = CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
        if def and def:getUIName() then name = def:getUIName() end
    end)
    return name
end

-- what the summary and the record say: days, tiles, kills, profession, and
-- how far short of the goal's middle (when there is a goal)
function VC.summary(ctx, player)
    local t = tally(ctx)
    local s = {
        days = math.max(0, (worldHours() - t.startH) / 24),
        tiles = math.floor(t.tiles + 0.5),
        kills = 0,
        profession = professionName(player),
    }
    pcall(function() s.kills = player:getZombieKills() end)
    local goal = ctx.spec.goal
    if goal then
        local gx, gy = (goal.x1 + goal.x2) / 2, (goal.y1 + goal.y2) / 2
        local dx, dy = player:getX() - gx, player:getY() - gy
        s.short = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
    end
    return s
end

local function record(id, result, s)
    pcall(function()
        local w = getFileWriter(RECORD_FILE, true, true)
        w:write(string.format("%s\t%s\tdays %.1f\ttiles %d\tkills %d\t%s\n", id, result, s.days, s.tiles, s.kills, s.profession))
        w:close()
    end)
end
VC.record = record

local function summaryLines(s)
    return {
        getText("IGUI_VC_SummaryWalk", string.format("%.1f", s.days), tostring(s.tiles)),
        getText("IGUI_VC_SummaryKills", tostring(s.kills), s.profession),
    }
end

local function dialog(text, onOk)
    pcall(function()
        local w, h = 460, 240
        local x = (getCore():getScreenWidth() - w) / 2
        local y = (getCore():getScreenHeight() - h) / 2
        local box = ISModalRichText:new(x, y, w, h, text, false, nil, onOk, 0)
        box:initialise()
        box:addToUIManager()
    end)
end
VC.dialog = dialog

-- the goal --------------------------------------------------------------------------

local function inGoal(goal, player)
    local x, y, z = player:getX(), player:getY(), player:getZ()
    return z >= goal.z and x >= goal.x1 and x <= goal.x2 and y >= goal.y1 and y <= goal.y2
end

local function win(c, ctx, player)
    local s = VC.summary(ctx, player)
    ctx.state.won = s
    record(c.id, "won", s)
    local lines = summaryLines(s)
    dialog(getText("IGUI_" .. c.id .. "_Won") .. " <LINE> <LINE> " .. lines[1] .. " <LINE> " .. lines[2])
    if c.spec.win then VC.guard(c.id .. ".win", c.spec.win, ctx, player, s) end
end

-- every minute, for a challenge with rules ------------------------------------------

local function minute(c)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    local ctx = VC.context(c)
    local spec = c.spec
    step(ctx, player)
    if spec.noDriving then
        local v = player:getVehicle()
        if v and v:isDriver(player) and v:isEngineRunning() then
            v:shutOff()
            note(player, getText("IGUI_VC_EngineDies"))
        end
    end
    if spec.goal and not ctx.state.won and not ctx.state.over and inGoal(spec.goal, player) then
        win(c, ctx, player)
    end
end

-- one life ---------------------------------------------------------------------------

local function turnAway()
    local done = false
    local function show()
        if done then return end
        done = true
        Events.OnTick.Remove(show)
        dialog(getText("IGUI_VC_OneLifeOver"), function() getCore():exitToMenu() end)
    end
    Events.OnTick.Add(show)
end

table.insert(VC.rules, {
    name = "rules",
    init = function(c)
        if not ruled(c.spec) then return end
        Events.EveryOneMinute.Add(function() VC.guard(c.id .. ".rules", minute, c) end)
    end,
    addPlayer = function(c, player, ctx)
        if c.spec.oneLife and ctx.state.over then
            turnAway()
            return true
        end
        if ruled(c.spec) then tally(ctx) end
        return false
    end,
    death = function(c, player, ctx)
        if not ruled(c.spec) or ctx.state.over then return end
        ctx.state.over = "died"
        local s = VC.summary(ctx, player)
        ctx.state.died = s
        record(c.id, "died", s)
        local panel = ISPostDeathUI and ISPostDeathUI.instance and ISPostDeathUI.instance[player:getPlayerNum()]
        if panel and panel.lines then
            for _, line in ipairs(summaryLines(s)) do table.insert(panel.lines, line) end
            if s.short then table.insert(panel.lines, getText("IGUI_VC_Short", tostring(s.short))) end
        end
    end,
})

-- the game's hooks ------------------------------------------------------------------

local function blockDriving(cls)
    if not cls or cls.vcNoDriving then return end
    local isValid = cls.isValid
    cls.isValid = function(self, ...)
        local spec = currentSpec()
        if spec and spec.noDriving then
            note(self.character, getText("IGUI_VC_WontStart"))
            return false
        end
        return isValid(self, ...)
    end
    cls.vcNoDriving = true
end

local function hookDeathScreen()
    if not ISPostDeathUI or ISPostDeathUI.vcOneLife then return end
    local createChildren = ISPostDeathUI.createChildren
    ISPostDeathUI.createChildren = function(self, ...)
        createChildren(self, ...)
        local spec = currentSpec()
        if spec and spec.oneLife and self.buttonRespawn then
            self.buttonRespawn:setEnable(false)
            pcall(function() self.buttonRespawn:enableDisabledColor() end)
            pcall(function() self.buttonRespawn:setTitle(getText("IGUI_PostDeath_Challenge")) end)
        end
    end
    ISPostDeathUI.vcOneLife = true
end

Events.OnGameStart.Add(function()
    blockDriving(ISStartVehicleEngine)
    blockDriving(ISHotwireVehicle)
    hookDeathScreen()
end)
