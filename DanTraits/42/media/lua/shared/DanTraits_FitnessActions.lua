-- Project Zomboid Vitality Project: fitness, the game's fitness action
-- (plans/fitness-overhaul.md, section 0).
--
-- ISFitnessAction plays the animation named by the window's key (the
-- ExerciseType variable) and gives the server its rep period by the
-- exercise's type. An exercise this mod adds borrows a vanilla one's
-- animation (dtAnim, DanTraits_FitnessData.lua): start sets the variable
-- from the borrowed key, serverStart takes the borrowed period, and the
-- regularity stays the new exercise's own.
--
-- Each rep (exeLooped, where the game adds the experience) is marked in
-- DanTraits_FitRep for DanTraits_Fitness.lua's experience handler. A
-- multiplayer client never runs exeLooped (vanilla counts reps on the server),
-- so there the rep is taken off the ActiveAnimLooped event instead. Never
-- new(): multiplayer reads its parameter names (see DanTraits_Wrap).
--
-- DanTraits_FitPickWeight(player, def) is the heaviest stand-in carried for
-- an improvised exercise (an item of dtItems at DanTraits_FIT_MIN_KG or more);
-- the window equips it.
require "DanTraits"
require "DanTraits_FitnessData"
pcall(function() require "TimedActions/ISFitnessAction" end)

DanTraits_FitRep = nil

-- the heaviest stand-in carried, its full type and kilos; nil, 0 for none
function DanTraits_FitPickWeight(player, def)
    local best, bestKg = nil, 0
    if not player or not def or not def.dtItems then return nil, 0 end
    pcall(function()
        local inv = player:getInventory()
        for _, fullType in ipairs(def.dtItems) do
            local items = inv:getAllTypeRecurse(fullType)
            for i = 0, (items and items:size() or 0) - 1 do
                local kg = DanTraits_FitItemKg and DanTraits_FitItemKg(items:get(i)) or 0
                if kg >= DanTraits_FIT_MIN_KG and kg > bestKg then best, bestKg = fullType, kg end
            end
        end
    end)
    return best, bestKg
end

local function wrapFitnessAction()
    if not ISFitnessAction then return end

    DanTraits_Wrap(ISFitnessAction, "start", "fitness-anim", function(original, self, ...)
        local anim = self.exeData and self.exeData.dtAnim
        if not anim then return original(self, ...) end
        local key = self.exercise
        self.exercise = anim
        local ok, res = pcall(original, self, ...)
        self.exercise = key
        if not ok then error(res, 0) end
        return res
    end)

    DanTraits_Wrap(ISFitnessAction, "serverStart", "fitness-anim", function(original, self, ...)
        local anim = self.exeData and self.exeData.dtAnim
        if not anim then return original(self, ...) end
        local key = self.exeDataType
        self.exeDataType = anim
        local ok, res = pcall(original, self, ...)
        self.exeDataType = key
        pcall(function() self.fitness:setCurrentExercise(key) end)
        if not ok then error(res, 0) end
        return res
    end)

    -- one rep done: it counts toward the muscles, the day and the plan
    -- (DanTraits_Fitness.lua), and a set of so many reps is done when they are
    local function repDone(self)
        self.dtRepn = (self.dtRepn or 0) + 1
        if DanTraits_FitOnRep then DanTraits_Guard("fitness-rep", DanTraits_FitOnRep, self.character, self.exeDataType) end
        if self.dtReps and math.max(self.repnb or 0, self.dtRepn) >= self.dtReps then
            pcall(function()
                self.character:setVariable("ExerciseStarted", false)
                self.character:setVariable("ExerciseEnded", true)
            end)
            self:forceStop()
        end
    end

    -- single-player and the server: the game counts the rep in exeLooped
    DanTraits_Wrap(ISFitnessAction, "exeLooped", "fitness-rep", function(original, self, ...)
        DanTraits_FitRep = { player = self.character, key = self.exeDataType }
        local ok, res = pcall(original, self, ...)
        DanTraits_FitRep = nil
        if not ok then error(res, 0) end
        repDone(self)
        return res
    end)

    -- a multiplayer client never runs exeLooped (vanilla's animEvent calls it on
    -- the server or in single-player only), so the rep is counted off the loop
    -- event there; the mod's minute clock runs on the client, so this is where
    -- the muscles are (2026-10-22)
    DanTraits_Wrap(ISFitnessAction, "animEvent", "fitness-rep-client", function(original, self, event, ...)
        local res = original(self, event, ...)
        if event == "ActiveAnimLooped" and isClient and isClient() then
            local started = false
            pcall(function() started = self:isStarted() == true end)
            if started then repDone(self) end
        end
        return res
    end)

    -- the set's reps: the window asks for them (DanTraits_FitnessUI.lua puts the
    -- count in DanTraits_FitPendingReps) and the bar over the head counts them off
    DanTraits_Wrap(ISFitnessAction, "start", "fitness-reps", function(original, self, ...)
        local res = original(self, ...)
        local pending = DanTraits_FitPendingReps[self.character]
        if pending then
            -- the count is for the exercise the window asked for; a set that never
            -- started (its get-up or unequip cancelled) is not inherited by the
            -- next action, this mod's or another's (2026-10-22)
            DanTraits_FitPendingReps[self.character] = nil
            if type(pending) == "table" and pending.key == self.exeDataType then
                self.dtReps = pending.reps
                pcall(function() self.action:setUseProgressBar(true) end)
            end
        end
        return res
    end)
    DanTraits_Wrap(ISFitnessAction, "update", "fitness-reps", function(original, self, ...)
        local res = original(self, ...)
        if self.dtReps and self.dtReps > 0 then
            pcall(function() self:setJobDelta(math.min(1, math.max(self.repnb or 0, self.dtRepn or 0) / self.dtReps)) end)
        end
        return res
    end)
end

-- the window's next set, by player: { reps, key = the exercise asked for }
DanTraits_FitPendingReps = DanTraits_FitPendingReps or {}
wrapFitnessAction()
Events.OnGameStart.Add(wrapFitnessAction)
