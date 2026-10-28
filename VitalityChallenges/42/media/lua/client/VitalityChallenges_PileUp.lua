-- Pile-Up: the first night of the outbreak. You fled Muldraugh north up the
-- highway and drove into the back of the traffic jam in a thunderstorm. Broken
-- leg, dead car, whatever you packed in the trunk. No win condition.
--
-- The map's own traffic-jam zones (two lanes, x 11637-11651, y 8637-8700)
-- roll a jam of wrecks on the north-south stretch. Just south of its tail the
-- highway bends and runs south-west; the spawn is on that diagonal (asphalt on
-- the B42 map), and your car sits a few tiles on toward the jam.
--
-- Only the world's first character crashed: a respawn arrives on foot, whole.
-- With the Vitality Project loaded the head that hit the wheel is concussed
-- (DanTraits_KnockHead; its Concussion sandbox switch still decides).

require "VitalityChallenges_Core"
local VC = VitalityChallenges

local X, Y, Z    = 11643, 8710, 0
local ROAD       = "NE"          -- the way the traffic was heading, toward West Point
local CAR_AHEAD  = 3             -- tiles from the spawn to your car
local CAR        = "Base.CarNormal"   -- a sedan worn down part by part (the smashed models broke the trunk)
local BODIES     = 3             -- around the jam's tail; the map's jam brings its own dead

local TRUNK = {
    "Base.Bag_Schoolbag",
    "Base.TinnedBeans", "Base.TinnedBeans", "Base.TinnedSoup", "Base.TinOpener",
    "Base.Crisps", "Base.Chocolate", "Base.Peanuts",
    "Base.PopBottle", "Base.PopBottle", { "Base.WaterBottle", water = 0.5 },
    "Base.Bandage", "Base.Bandage", "Base.RippedSheets", "Base.Pills",
    "Base.HandTorch", "Base.Whiskey", "Base.TireIron", "Base.Lighter",
}

local FRACTURE   = 30            -- fracture time; over 10 hobbles you
local LEG_PAIN   = 30
local HEAD_CUT   = 5
local START = {
    FATIGUE = 0.75,              -- 0..1; 0.7 to 0.8 is Tired
    PANIC   = 40,
    STRESS  = 0.4,
}
local KNOCK      = 0.35          -- the concussion's strength (0..1) with the Vitality Project: mild to moderate

VC.define({
    id = "VC_PileUp",
    mode = "Pile-Up",
    world = "Muldraugh, KY",
    x = X, y = Y, z = Z,
    image = "media/lua/client/VitalityChallenges_PileUp.png",
    video = "vc_pile_up.bik",
    everyCharacter = false,

    sandbox = {
        -- day one of the outbreak, 9 July; 1-hour days
        TimeSinceApo = 1, StartYear = 1, StartMonth = 7, StartDay = 9,
        StartTime = 6,                         -- the 9 PM preset; the scene sets 11 PM
        DayLength = 3,
        StarterKit = false,                    -- what you packed is in the trunk
        BoneFracture = true,                   -- the leg has to break, and matter
        InjurySeverity = 2,
        ZombieConfig = {
            -- a thin early crowd that builds over the first month
            PopulationMultiplier = 1.0,
            PopulationStartMultiplier = 0.3,
            PopulationPeakMultiplier = 1.5,
            PopulationPeakDay = 28,
        },
        -- a clear patch around the spawn: a minute to reach the trunk on one leg
        ZombieLore = { PlayerSpawnZombieRemoval = 3 },
    },

    start = { hour = 23, weather = { stage = "storm", hours = 6 } },

    scene = function()
        local cx, cy = VC.ahead(X, Y, ROAD, CAR_AHEAD)
        local car = VC.vehicle(CAR, cx, cy, Z, ROAD)
        VC.wreck(car, { engine = 0, fuel = { 0, 2 }, locked = false })
        VC.load(car, TRUNK)
        VC.bodies(cx - 2, cy - 2, cx + 2, cy + 5, Z, BODIES)
    end,

    player = function(player)
        VC.fracture(player, VC.side("LowerLeg"), FRACTURE, LEG_PAIN)
        VC.cut(player, "Head", HEAD_CUT)
        VC.stats(player, START)
    end,

    firstMinute = function(ctx)
        if ctx.vitality and DanTraits_KnockHead then
            local player = getSpecificPlayer(0)
            if player then DanTraits_KnockHead(player, 1, KNOCK) end
        end
    end,
})
