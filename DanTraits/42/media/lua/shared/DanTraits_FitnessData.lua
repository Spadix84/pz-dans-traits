-- Project Zomboid Vitality Project: fitness, the data (plans/fitness-overhaul.md).
--
-- What the other fitness files read: the muscle groups, the exercises this
-- mod adds to the game's own list, what each exercise counts as for a
-- plan, the plans and the magazines. Nothing here runs on the clock.
--
-- The game's Java Fitness reads FitnessExercises.exercisesType in init(), so
-- an entry added here at load time is a real exercise with its own
-- regularity. Every entry carries the fields Java reads (type, stiffness,
-- metabolics, xpMod) even when the window never shows it. Our own fields
-- start with dt:
--   dtAnim      the vanilla exercise whose animation it borrows (the
--               window's key is the animation variable; DanTraits_FitnessActions
--               swaps it at start)
--   dtItems     items that stand in for the weight, heaviest first; the
--               window equips the heaviest one carried (dtRef: the kilos the
--               real barbell or dumbbell weighs, for the XP factor)
--   dtHidden    counted from what the character does, never in the window
--               (jogging, carrying, hard work)
--   dtCustom    "stretch": our own timed action, not the game's fitness one
require "DanTraits"
pcall(function() require "Definitions/FitnessExercises" end)

DanTraits_FIT_GROUPS = { "arms", "chest", "core", "legs" }

-- the body parts of each group (the game's stiffness areas: arms, chest, abs, legs)
DanTraits_FIT_PARTS = {
    arms  = { "ForeArm_L", "ForeArm_R", "UpperArm_L", "UpperArm_R" },
    chest = { "Torso_Upper" },
    core  = { "Torso_Lower" },
    legs  = { "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" },
}

-- what each exercise loads (per minute, x its intensity) and counts as for a
-- plan: upper, lower, push, pull, legs, cardio, carry, mobility, work.
-- load = { group = share }, 1 a full share; intensity 1.3 is the game's
-- FitnessHeavy. Exercises not in this list (another mod's) load their
-- vanilla stiffness areas at 1 and count as upper or lower by them.
DanTraits_FIT_EXERCISES = {
    squats        = { load = { legs = 1 }, kinds = { "lower", "legs" } },
    pushups       = { load = { arms = 1, chest = 1 }, kinds = { "upper", "push" } },
    situp         = { load = { core = 1 }, kinds = { "lower" } },
    burpees       = { load = { legs = 1, arms = 1, chest = 1 }, intensity = 1.3, kinds = { "upper", "lower", "legs", "push" }, breathless = true },
    barbellcurl   = { load = { arms = 1, chest = 1 }, intensity = 1.3, kinds = { "upper", "pull" }, weights = true },
    dumbbellpress = { load = { arms = 1 }, intensity = 1.3, kinds = { "upper", "push" }, weights = true },
    bicepscurl    = { load = { arms = 1 }, intensity = 1.3, kinds = { "upper", "pull" }, weights = true },
    dtimprovcurl  = { load = { arms = 1, chest = 1 }, intensity = 1.3, kinds = { "upper", "pull" }, improvised = true },
    dtonearmcurl  = { load = { arms = 1 }, intensity = 1.3, kinds = { "upper", "pull" }, improvised = true },
    dtpress       = { load = { arms = 1, chest = 1 }, intensity = 1.3, kinds = { "upper", "push" }, improvised = true },
    dtstretch     = { load = {}, kinds = { "mobility" }, stretch = true },
    dtjog         = { load = { legs = 0.67 }, kinds = { "cardio" } },
    dtcarry       = { load = { legs = 0.5, core = 0.5, arms = 0.33 }, kinds = { "carry" } },
    dtwork        = { load = { arms = 0.33, core = 0.33 }, kinds = { "work" } },
}

local AREA_GROUP = { arms = "arms", chest = "chest", abs = "core", legs = "legs" }

-- an exercise's entry here, or one built from the game's own definition
function DanTraits_FitExercise(key)
    local spec = DanTraits_FIT_EXERCISES[key]
    if spec then return spec end
    local def = FitnessExercises and FitnessExercises.exercisesType and FitnessExercises.exercisesType[key]
    if not def then return nil end
    spec = { load = {}, kinds = {} }
    local upper, lower = false, false
    local areas, text = {}, tostring(def.stiffness or "") .. ","
    local from = 1
    while true do
        local comma = string.find(text, ",", from, true)
        if not comma then break end
        areas[#areas + 1] = string.sub(text, from, comma - 1):match("^%s*(.-)%s*$")
        from = comma + 1
    end
    for _, area in ipairs(areas) do
        local g = AREA_GROUP[area]
        if g then
            spec.load[g] = 1
            if g == "legs" or g == "core" then lower = true else upper = true end
        end
    end
    if upper then spec.kinds[#spec.kinds + 1] = "upper" end
    if lower then spec.kinds[#spec.kinds + 1] = "lower" end
    DanTraits_FIT_EXERCISES[key] = spec
    return spec
end

-- improvised weights: two-handed and one-handed stand-ins, heaviest first
-- (vanilla weights: log 9, propane tank 10 full, car battery 5, sandbag and
-- the other bags 2 empty and more full, tyre 3, flour 2; a bucket is 1 empty
-- and 11 full of water, so only a full one counts)
DanTraits_FIT_TWO_HANDS = {
    "Base.Log", "Base.PropaneTank", "Base.BucketEmpty", "Base.Sandbag", "Base.Gravelbag", "Base.Dirtbag",
    "Base.CarBattery1", "Base.CarBattery2", "Base.CarBattery3", "Base.TirePiece",
}
DanTraits_FIT_ONE_HAND = {
    "Base.CarBattery1", "Base.CarBattery2", "Base.CarBattery3", "Base.PaintBlack", "Base.PaintBlue",
    "Base.PaintBrown", "Base.PaintCyan", "Base.PaintGreen", "Base.PaintGrey", "Base.PaintLightBlue",
    "Base.PaintLightBrown", "Base.PaintOrange", "Base.PaintPink", "Base.PaintPurple", "Base.PaintRed",
    "Base.PaintTurquoise", "Base.PaintWhite", "Base.PaintYellow", "Base.Vinegar_Jug", "Base.Flour2",
}
DanTraits_FIT_MIN_KG = 1.5

-- the entries this mod adds to the game's list
local function addExercises()
    local list = FitnessExercises and FitnessExercises.exercisesType
    if not list or list.dtstretch then return end
    local function text(key, ...) return getText and getText(key, ...) or key end
    local heavyName = text("IGUI_DanTraits_FitHeavyObject")   -- the window renames them for the stand-in carried
    local fitness = Metabolics and Metabolics.Fitness
    local heavy = Metabolics and Metabolics.FitnessHeavy or fitness
    list.dtimprovcurl = {
        type = "dtimprovcurl", name = text("IGUI_DanTraits_FitImprovCurl", heavyName), tooltip = text("IGUI_DanTraits_FitImprovCurl_Tooltip"),
        item = DanTraits_FIT_TWO_HANDS[1], prop = "twohands", stiffness = "arms,chest", metabolics = heavy, xpMod = 1.2,
        dtAnim = "barbellcurl", dtItems = DanTraits_FIT_TWO_HANDS, dtRef = 6,
    }
    list.dtonearmcurl = {
        type = "dtonearmcurl", name = text("IGUI_DanTraits_FitOneArmCurl", heavyName), tooltip = text("IGUI_DanTraits_FitOneArmCurl_Tooltip"),
        item = DanTraits_FIT_ONE_HAND[1], prop = "switch", stiffness = "arms", metabolics = heavy, xpMod = 1.8,
        dtAnim = "bicepscurl", dtItems = DanTraits_FIT_ONE_HAND, dtRef = 5,
    }
    list.dtpress = {
        type = "dtpress", name = text("IGUI_DanTraits_FitPress", heavyName), tooltip = text("IGUI_DanTraits_FitPress_Tooltip"),
        item = DanTraits_FIT_ONE_HAND[1], prop = "switch", stiffness = "arms,chest", metabolics = heavy, xpMod = 1.8,
        dtAnim = "dumbbellpress", dtItems = DanTraits_FIT_ONE_HAND, dtRef = 5,
    }
    list.dtstretch = {
        type = "dtstretch", name = text("IGUI_DanTraits_FitStretch"), tooltip = text("IGUI_DanTraits_FitStretch_Tooltip"),
        stiffness = "abs", metabolics = fitness, xpMod = 0, dtCustom = "stretch",
    }
    list.dtjog = { type = "dtjog", name = text("IGUI_DanTraits_FitJog"), stiffness = "legs", metabolics = fitness, xpMod = 0, dtHidden = true }
    list.dtcarry = { type = "dtcarry", name = text("IGUI_DanTraits_FitCarry"), stiffness = "legs", metabolics = fitness, xpMod = 0, dtHidden = true }
    list.dtwork = { type = "dtwork", name = text("IGUI_DanTraits_FitWork"), stiffness = "arms", metabolics = fitness, xpMod = 0, dtHidden = true }
end
DanTraits_FitAddExercises = addExercises
addExercises()

-- Plans: seven days, each a target. Done when the day's minutes of that
-- kind reach the target's minutes (work counts half toward full; rest is
-- done when the hard minutes stay under REST_MAX).
DanTraits_FIT_TARGETS = {
    upper    = { kinds = { "upper" }, min = 20 },
    lower    = { kinds = { "lower" }, min = 20 },
    push     = { kinds = { "push" }, min = 20 },
    pull     = { kinds = { "pull" }, min = 20 },
    legs     = { kinds = { "legs" }, min = 20 },
    full     = { hard = true, min = 20 },
    cardio   = { kinds = { "cardio" }, min = 20 },
    carry    = { kinds = { "carry" }, min = 20 },
    mobility = { kinds = { "mobility" }, min = 15 },
    rest     = { rest = true },
}
DanTraits_FIT_REST_MAX = 20   -- minutes of hard training that turn a rest day into a hard one

-- recipe: the magazine that teaches it (nil: everyone knows it)
DanTraits_FIT_PLANS = {
    { id = "full", days = { "full", "rest", "full", "rest", "full", "mobility", "rest" } },
    { id = "upperlower", recipe = "DanTraitsFitUpperLower", days = { "upper", "lower", "rest", "upper", "lower", "mobility", "rest" } },
    { id = "ppl", recipe = "DanTraitsFitPPL", days = { "push", "pull", "legs", "rest", "push", "pull", "rest" } },
    { id = "run", recipe = "DanTraitsFitRun", days = { "cardio", "rest", "cardio", "rest", "cardio", "mobility", "rest" } },
    { id = "strongman", recipe = "DanTraitsFitStrongman", days = { "carry", "full", "rest", "carry", "legs", "rest", "rest" } },
    { id = "recovery", recipe = "DanTraitsFitLimber", days = { "mobility", "full", "mobility", "cardio", "mobility", "rest", "rest" } },
}

function DanTraits_FitPlan(id)
    for _, plan in ipairs(DanTraits_FIT_PLANS) do
        if plan.id == id then return plan end
    end
    return nil
end

-- the magazines: what reading one teaches (a knowledge flag, like Living With
-- Type 1) and the lasting bonus to all experience of each skill, in percent
DanTraits_FIT_MAGAZINES = {
    { recipe = "DanTraitsFitUpperLower", item = "DanTraits.FitMagUpperLower", strength = 10 },
    { recipe = "DanTraitsFitPPL", item = "DanTraits.FitMagPPL", strength = 10 },
    { recipe = "DanTraitsFitRun", item = "DanTraits.FitMagRun", fitness = 10 },
    { recipe = "DanTraitsFitStrongman", item = "DanTraits.FitMagStrongman", strength = 5, fitness = 5 },
    { recipe = "DanTraitsFitLimber", item = "DanTraits.FitMagLimber", fitness = 10, recovery = 0.1 },
}

-- isRecipeActuallyKnown, not isRecipeKnown (that one answers true for a name
-- the game has no recipe for; found with the insulin magazine)
function DanTraits_FitKnows(player, recipe)
    if not recipe then return true end
    local known = false
    pcall(function() known = player:isRecipeActuallyKnown(recipe) end)
    return known == true
end

-- a Fitness Instructor knows every plan (not the magazines' bonuses)
function DanTraits_FitInstructor(player)
    local yes = false
    pcall(function()
        yes = CharacterProfession and CharacterProfession.FITNESS_INSTRUCTOR ~= nil
            and player:getDescriptor():isCharacterProfession(CharacterProfession.FITNESS_INSTRUCTOR) == true
    end)
    return yes
end

function DanTraits_FitKnowsPlan(player, plan)
    if not plan then return false end
    if not plan.recipe then return true end
    -- a Gym Regular knows the split every gym runs
    if plan.id == "upperlower" and DanTraits_HasTrait and DanTraits_HasTrait(player, "gymregular") then return true end
    return DanTraits_FitInstructor(player) or DanTraits_FitKnows(player, plan.recipe)
end

-- the magazines read: Strength and Fitness bonus (fractions) and recovery
function DanTraits_FitMagazineBonus(player)
    local strength, fitness, recovery = 0, 0, 0
    for _, mag in ipairs(DanTraits_FIT_MAGAZINES) do
        if DanTraits_FitKnows(player, mag.recipe) then
            strength = strength + (mag.strength or 0) / 100
            fitness = fitness + (mag.fitness or 0) / 100
            recovery = recovery + (mag.recovery or 0)
        end
    end
    return strength, fitness, recovery
end
