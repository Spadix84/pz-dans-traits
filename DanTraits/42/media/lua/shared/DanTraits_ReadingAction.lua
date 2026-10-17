-- Project Zomboid Vitality Project: the long read. Wraps the vanilla read action
-- (ISReadABook) for the literature DanTraits_Reading.lua handles;
-- everything else goes through untouched. Never wraps new: in multiplayer
-- the game reads new's parameter names.
--
--   getDuration  the time for the pages this session reads, at our minutes
--                per page, scaled from vanilla's own answer so the character's
--                modifiers (Fast or Slow Reader, reading glasses, sitting,
--                other mods' wraps) carry over. A session is the rest of the
--                book from the bookmark, or a chapter's worth when the
--                action was started with readChapter set.
--   start        the plan for the session: from which page, how many
--   update       pages turned since the last tick get their relief (stress
--                and unhappiness by the immersion ramp: how many minutes
--                into the sitting, carried over from a sitting of the same
--                title put down moments ago), the
--                bookmark moves (character and copy), the family's page
--                count grows until the taste is found out, a disliked book
--                ticks boredom back now and then
--   perform      a session that stops short of the end hides the title from
--   complete     vanilla, so the game does not mark it read; a finished one
--                is marked as vanilla does it. Around vanilla's complete the
--                three stats are snapshotted and put back, so the lump at the
--                end is cancelled and only the drip counts; then the finish:
--                the record, the verdict, the Good Read moodle.
--   stop         an interrupted read keeps its bookmark; nothing else to do

require "TimedActions/ISReadABook"
require "DanTraits_Reading"

local R = DanTraits_Reading

local function infoOf(self)
    if self.readInfo == nil then
        local ok, info = pcall(R.info, self.item)
        self.readInfo = ok and info or false
    end
    return self.readInfo or nil
end

-- the session: from the bookmark, the rest of the book or a chapter of it
local function plan(self, info)
    local player = self.character
    local from = R.mark(player, self.item, info)
    local left = info.pages - from
    if left <= 0 then from, left = 0, info.pages end
    local span = left
    if self.readChapter then span = math.min(left, R.chapterPages(player, info)) end
    self.readPlan = { from = from, span = span }
    return self.readPlan
end

-- vanilla's own time for this item before the character's modifiers: the flat
-- 50 for a fast read, else five pages at the server's minutes per page
local function vanillaBase(self)
    local fast = false
    pcall(function() fast = ItemTag and ItemTag.FAST_READ and self.item:hasTag(ItemTag.FAST_READ) end)
    if fast then return 50 end
    local f = 1 / getGameTime():getMinutesPerDay() / 2
    return 5 * (self.minutesPerPage or 2.0) / f
end

-- the pages read so far this session for a job delta of 0..1
local function pagesAt(self, info, delta)
    local p = self.readPlan
    local pages = p.from + math.floor(p.span * math.max(0, math.min(1, delta)) + 1e-6)
    return math.min(info.pages, pages)
end

-- n new pages turned: relief, bookmark, taste, the disliked tick
local function turned(self, info, pagesNow)
    local rd = self.readSession
    local n = pagesNow - rd.pages
    if n <= 0 then return end
    rd.pages = pagesNow
    local player = self.character
    local mpp = R.minutesPerPage(player, info)
    local minutes = rd.minutes or 0
    R.applyPages(player, info, n, rd.reread, minutes + n * mpp / 2)
    rd.minutes = minutes + n * mpp
    R.sittingNote(player, info, rd.minutes)
    R.setMark(player, self.item, info, pagesNow)
    if not rd.reread then
        local verdict = R.notePages(player, info.family, n)
        if verdict then R.sayTaste(player, verdict) end
    end
    if R.tasteOf(player, info.family) == "disliked" then
        rd.tick = (rd.tick or 0) + n
        local per = R.DISLIKE_TICK_MIN / R.minutesPerPage(player, info)
        if rd.tick >= per then
            rd.tick = rd.tick - per
            R.dislikeTick(player)
        end
    end
end

-- the action ran to its end: whatever pages the last tick missed are turned now
local function settle(self, info)
    turned(self, info, pagesAt(self, info, 1))
end

-- run a vanilla method with the title hidden, so it is not marked read
local function withoutTitle(self, fn)
    local md
    pcall(function() md = self.item:getModData() end)
    local saved = md and md.literatureTitle
    if md then md.literatureTitle = nil end
    local ok, result = pcall(fn, self)
    if md then md.literatureTitle = saved end
    if not ok then error(result, 0) end
    return result
end

if not ISReadABook.danTraitsReadingWrapped then
    ISReadABook.danTraitsReadingWrapped = true

    local vanillaDuration = ISReadABook.getDuration
    function ISReadABook:getDuration(...)
        local t = vanillaDuration(self, ...)
        local info = infoOf(self)
        if not info or type(t) ~= "number" or t <= 1 then return t end
        local ok, ours = pcall(function()
            local p = plan(self, info)
            local f = 1 / getGameTime():getMinutesPerDay() / 2
            return t * (p.span * R.minutesPerPage(self.character, info) / f) / vanillaBase(self)
        end)
        if not ok or type(ours) ~= "number" then return t end
        return math.max(1, ours)
    end

    local vanillaStart = ISReadABook.start
    function ISReadABook:start(...)
        vanillaStart(self, ...)
        local info = infoOf(self)
        if not info then return end
        pcall(function()
            local p = self.readPlan or plan(self, info)
            local reread = R.finished(self.character, info.key)
            if not reread and info.raw then
                local ok, yes = pcall(function() return self.character:isLiteratureRead(info.raw) end)
                reread = ok and yes == true
            end
            self.readSession = { pages = p.from, reread = reread, minutes = R.sittingStart(self.character, info) }
        end)
    end

    local vanillaUpdate = ISReadABook.update
    function ISReadABook:update(...)
        vanillaUpdate(self, ...)
        local info = infoOf(self)
        if not info or not self.readSession then return end
        pcall(function() turned(self, info, pagesAt(self, info, self:getJobDelta())) end)
    end

    local vanillaStop = ISReadABook.stop
    function ISReadABook:stop(...)
        self.readSession = nil
        return vanillaStop(self, ...)
    end

    local vanillaPerform = ISReadABook.perform
    function ISReadABook:perform(...)
        local info = infoOf(self)
        local rd = self.readSession
        if not info or not rd then return vanillaPerform(self, ...) end
        pcall(settle, self, info)
        if rd.pages < info.pages then
            local args = { ... }
            return withoutTitle(self, function(s) return vanillaPerform(s, unpack(args)) end)
        end
        return vanillaPerform(self, ...)
    end

    local vanillaComplete = ISReadABook.complete
    function ISReadABook:complete(...)
        local info = infoOf(self)
        local rd = self.readSession
        if not info or not rd then return vanillaComplete(self, ...) end
        pcall(settle, self, info)
        local finished = rd.pages >= info.pages
        local stats = self.character:getStats()
        local b, s, u = stats:get(CharacterStat.BOREDOM), stats:get(CharacterStat.STRESS), stats:get(CharacterStat.UNHAPPINESS)
        local args = { ... }
        local ok, result
        if finished then
            ok, result = pcall(vanillaComplete, self, ...)
        else
            ok, result = pcall(withoutTitle, self, function(s) return vanillaComplete(s, unpack(args)) end)
        end
        stats:set(CharacterStat.BOREDOM, b)
        stats:set(CharacterStat.STRESS, s)
        stats:set(CharacterStat.UNHAPPINESS, u)
        if not ok then error(result, 0) end
        if finished and not rd.done then
            rd.done = true
            pcall(function()
                R.clearMark(self.character, self.item, info)
                local res = R.finish(self.character, info, rd.reread)
                R.sayFinish(self.character, info, res)
            end)
        end
        return result
    end
end

-- the halo notices (shared, so singleplayer and a client both see them)
function R.sayTaste(player, verdict)
    pcall(function()
        if verdict == "liked" then
            HaloTextHelper.addGoodText(player, getText("IGUI_DanTraits_Taste_liked"))
        elseif verdict == "disliked" then
            HaloTextHelper.addBadText(player, getText("IGUI_DanTraits_Taste_disliked"))
        else
            local text = getText("IGUI_DanTraits_Taste_neutral")
            if not pcall(HaloTextHelper.addText, player, text) then HaloTextHelper.addGoodText(player, text) end
        end
    end)
end

function R.sayFinish(player, info, res)
    pcall(function()
        if res.level <= 0 then return end
        HaloTextHelper.addGoodText(player, getText("IGUI_DanTraits_Finished_" .. tostring(res.level)))
    end)
end
