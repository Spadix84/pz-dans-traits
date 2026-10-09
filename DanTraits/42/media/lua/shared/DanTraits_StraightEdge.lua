-- Project Zomboid Vitality Project: Straight Edge.
--
-- Never touches alcohol or tobacco, whatever the day has been like. Drink
-- is refused (the drink action will not start or carry on with anything
-- alcoholic in the container, and alcoholic food is refused like
-- Vegetarian's meat), and so is tobacco: cigarettes, cigars and pipes (the
-- eat action, through the core's refuseFood hook) and a pack or chewing
-- tobacco (the pill action). What the character gives up: the relief a
-- drink or a cigarette brings to pain, panic, stress and a low mood, which
-- matters most in a depressive episode or after a bad fright. Nicotine gum
-- is not tobacco and is allowed.
--
-- Not with Alcoholic, Smoker, Hollow Legs or A Really Bad Day (which starts
-- the character blind drunk).
--
-- Other mods light a smoke without the eat action. I Don't Need A Lighter
-- lights one off a stove, a fire or the car's lighter through timed actions
-- of its own (and takes a cigarette out of a pack with another), TrueSmoking
-- through LightSmoke. Each of those is refused the same way when it is
-- loaded, and its Smoke options on the stove and in the inventory are greyed
-- out by DanTraits_Client.lua.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

local SE_REASON = "UI_DanTraits_StraightEdgeRefuse"

local function alcoholicFood(item)
    local ok, res = pcall(function() return item:isAlcoholic() end)
    return ok and res == true
end

local function tobacco(item)
    if not DanTraits_NicotineOf then return false end
    local kind = ""
    pcall(function() kind = item:getType() end)
    return DanTraits_NicotineOf(kind, item) ~= nil
end

-- the text key for refusing this item, or nil
function DanTraits_StraightEdgeRefuses(player, item)
    if not item or not hasTrait(player, "straightedge") then return nil end
    if tobacco(item) or alcoholicFood(item) then return SE_REASON end
    return nil
end

DanTraits_AddHook("refuseFood", function(reason, player, item)
    if reason then return nil end
    return DanTraits_StraightEdgeRefuses(player, item)
end)

local function alcoholicContainer(container)
    local ok, res = pcall(function() return container:getProperties():getAlcohol() > 0 end)
    return ok and res == true
end

-- refuse at the start of an action and on every check while it runs, one notice an attempt
local function refuseAction(class, tag, test)
    for _, name in ipairs({ "isValidStart", "isValid" }) do
        DanTraits_Wrap(class, name, tag, function(original, self, ...)
            if self.character and hasTrait(self.character, "straightedge") and test(self) then
                if not self.danTraitsSeShown then
                    self.danTraitsSeShown = true
                    DanTraits_Notify(self.character, SE_REASON)
                end
                return false
            end
            return original(self, ...)
        end)
    end
end

-- other mods' smoke actions, by global name: the smokable is action.item,
-- or action.pack for I Don't Need A Lighter's take-a-cigarette action.
-- Looked up again at game start, since those files may load after this one.
local OTHER_SMOKE_ACTIONS = { "IsStoveLighting", "IsStoveSmoking", "IsCarLighting", "IsCarSmoking",
    "IDNALTakeCigarette", "LightSmoke" }

local function smokingTobacco(action)
    local item = action.item or action.pack
    return item ~= nil and tobacco(item)
end

local function wrapStraightEdge()
    if ISDrinkFluidAction then
        refuseAction(ISDrinkFluidAction, "straightedge-drink", function(action) return alcoholicContainer(action.fluidContainer) end)
    end
    if ISTakePillAction then
        refuseAction(ISTakePillAction, "straightedge-pill", smokingTobacco)
    end
    for _, name in ipairs(OTHER_SMOKE_ACTIONS) do
        local class = _G[name]
        if type(class) == "table" then refuseAction(class, "straightedge-" .. name, smokingTobacco) end
    end
end
wrapStraightEdge()
Events.OnGameStart.Add(wrapStraightEdge)
