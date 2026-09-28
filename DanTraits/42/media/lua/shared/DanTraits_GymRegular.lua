-- Project Zomboid Vitality Project: Gym Regular.
-- Positive, cheap: a new character starts with every exercise's regularity
-- at GYM_REGULARITY (0..100) instead of nothing, the same head start the
-- game gives a Fitness Instructor (theirs is 40 to 60). Regularity is what
-- the fitness window's bar shows: it grows with each rep, decays two hours
-- after a day without that exercise, and feeds Vitality's exercise score
-- (and through it Type 2 resistance and depressive relief) from day one.
--
-- The game stores regularity as Java floats, so it is raised through the
-- fitness system's own incRegularity rather than written into the map
-- (a number put there from Lua would be a double, and the game would
-- crash reading it back). init() first, so a profession that already comes
-- with regularity keeps it: this trait only tops up, never lowers.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local traitData = DanTraits_Data

local GYM_REGULARITY = 50
local GYM_MAX_STEPS  = 5000   -- incRegularity calls per exercise before giving up (each adds about 0.07)

-- Raise every exercise's regularity to at least the target. Returns the
-- number of exercises that ended at or above it, so a failure (fitness not
-- ready yet) can be retried instead of being marked done.
local function applyGymRegular(player, target)
    local done, total = 0, 0
    local ok = pcall(function()
        local fitness = player:getFitness()
        fitness:init()
        for name, _ in pairs(FitnessExercises.exercisesType) do
            total = total + 1
            local before = fitness:getRegularity(name) or 0
            if before >= target then
                done = done + 1
            else
                fitness:setCurrentExercise(name)
                local steps = 0
                local value = before
                while value < target and steps < GYM_MAX_STEPS do
                    fitness:incRegularity()
                    steps = steps + 1
                    local now = fitness:getRegularity(name) or 0
                    if now <= value then break end   -- not moving: stop rather than spin
                    value = now
                end
                if value >= target then done = done + 1 end
            end
        end
        fitness:setCurrentExercise(nil)
    end)
    return ok and total > 0 and done == total
end
DanTraits_ApplyGymRegular = applyGymRegular

local function onGymRegularCreate(player)
    if not player or not hasTrait(player, "gymregular") then return end
    local d = traitData(player)
    if d.gymRegularApplied or player:getHoursSurvived() > 0 then return end
    local target = DanTraits_RunHooks("gymRegularity", GYM_REGULARITY, player)   -- Age: higher in the 20s
    if applyGymRegular(player, target) then d.gymRegularApplied = true end
end

local function onGymRegularCreatePlayer(playerNum, player)
    onGymRegularCreate(player)
end

-- Second chance at game start, in case the fitness tables were not ready
-- when the character was created.
local function onGymRegularGameStart()
    onGymRegularCreate(getSpecificPlayer(0))
end

Events.OnCreatePlayer.Add(onGymRegularCreatePlayer)
Events.OnGameStart.Add(onGymRegularGameStart)
