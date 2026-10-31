-- Project Zomboid Vitality Project: Carpal Tunnel (Age 2.0, 2026-10-31; any age).
--
-- Annoying, never crippling. Long runs of the same hand work build a wrist
-- load (ctLoad, 0..1): each minute the action at the head of the queue is one
-- of the repetitive kinds (CT_WORK: crafting, building, sawing, chopping,
-- washing, repairs, vehicle parts) and the same kind as the minute before, the
-- run grows, and once the run is CT_RUN_MIN minutes long the load rises. A
-- change of task starts the run over, so alternating work never builds it.
-- Rest drains it, twice as fast asleep, and twice as fast again with a splint
-- on a forearm (the game's own splint, as for a fracture).
--
-- Past CT_LINE a numb, tingling spell runs until the load is back under
-- CT_CLEAR: fine actions take longer (inventory transfers, crafting, stitching,
-- pulling glass or a bullet, splinting: x CT_SLOW), a fine-work roll fails more
-- often (bad splints and rough stitches x CT_FAIL), and with the load high
-- light wakes you more easily at night (numb hands: the sleepWake hook,
-- x CT_WAKE). No weapon penalty and no pain beyond the nag.
--
-- Mod data: ctLoad, ctRun, ctLast (the work's action type), ctNumb, ctTold.
-- Console: carpal [load <0..1>].
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data
local clamp01 = DanTraits_Clamp01

local CT_WORK = {
    ISCraftAction = true, ISHandcraftAction = true, ISBuildAction = true, ISChopTreeAction = true,
    ISWashClothing = true, ISFixAction = true, ISDismantleAction = true, ISPlasterAction = true,
    ISUninstallVehiclePart = true, ISInstallVehiclePart = true, ISMoveablesAction = true,
    ISVitalityLaundryAction = true,
}
local CT_RUN_MIN    = 15      -- the same work this long before the load rises
local CT_RISE       = 0.004   -- load a minute of such work (two hours: 0.5)
local CT_EASE       = 0.002   -- off a minute at rest...
local CT_EASE_ASLEEP = 2      -- ...x this asleep...
local CT_EASE_SPLINT = 2      -- ...and x this with a splint on a forearm
local CT_LINE       = 0.5     -- a spell starts from here...
local CT_CLEAR      = 0.3     -- ...and ends under here
local CT_SLOW       = 1.2     -- fine actions take x this in a spell
local CT_FAIL       = 1.5     -- bad splint and rough stitch chance x this
local CT_WAKE_FROM  = 0.7     -- load from which numb hands wake you...
local CT_WAKE       = 1.5     -- ...x this
local CT_FINE_ACTIONS = { "ISInventoryTransferAction", "ISCraftAction", "ISHandcraftAction" }   -- adjustMaxTime
local CT_FINE_DURATION = { "ISStitch", "ISRemoveGlass", "ISRemoveBullet" }                     -- getDuration (and the splint)

local function has(player) return player ~= nil and hasTrait(player, "carpaltunnel") end

local function numb(player)
    local d = player and player:getModData().DanTraits
    return d ~= nil and has(player) and d.ctNumb == true
end
DanTraits_CarpalNumb = numb

-- the repetitive work at the head of the queue, by its action type, or nil
local function workNow(player)
    local action = DanTraits_QueueHead(player)
    local kind = action and action.Type
    if kind and CT_WORK[kind] then return kind end
    return nil
end

-- a splint on either forearm (the game's fracture splint)
local function splinted(player)
    local found = false
    pcall(function()
        local bd = player:getBodyDamage()
        for _, name in ipairs({ "ForeArm_L", "ForeArm_R" }) do
            local part = bd:getBodyPart(BodyPartType[name])
            if part and part:isSplint() then found = true end
        end
    end)
    return found
end

local function updateCarpalMinute(player, d)
    local load = d.ctLoad or 0
    local kind = DanTraits_Asleep(player) and nil or workNow(player)
    if kind then
        if kind == d.ctLast then d.ctRun = (d.ctRun or 0) + 1 else d.ctRun = 1 end
        d.ctLast = kind
        if d.ctRun >= CT_RUN_MIN then load = load + CT_RISE end
    else
        d.ctRun, d.ctLast = 0, nil
        local ease = CT_EASE
        if DanTraits_Asleep(player) then ease = ease * CT_EASE_ASLEEP end
        if splinted(player) then ease = ease * CT_EASE_SPLINT end
        load = load - ease
    end
    load = clamp01(load)
    if load < 0.001 then load = 0 end
    d.ctLoad = load
    if not d.ctNumb and load >= CT_LINE then
        d.ctNumb = true
        notify(player, "UI_DanTraits_CarpalNumb")
    elseif d.ctNumb and load < CT_CLEAR then
        d.ctNumb = nil
        notifyGood(player, "UI_DanTraits_CarpalEased")
    end
end

local function clearCarpal(player, d)
    if d then d.ctNumb, d.ctRun, d.ctLast = nil, nil, nil end
end

-- fine work in a spell
local function fail(chance, setter)
    if not numb(setter) then return nil end
    return chance * CT_FAIL
end
DanTraits_AddHook("splintBadSet", fail)
DanTraits_AddHook("stitchPoor", fail)

DanTraits_AddHook("sleepWake", function(m, player, d)
    if not has(player) or not d or (d.ctLoad or 0) < CT_WAKE_FROM then return nil end
    return m * CT_WAKE
end)

local function wrapCarpal()
    for _, name in ipairs(CT_FINE_ACTIONS) do
        DanTraits_Wrap(_G[name], "adjustMaxTime", "carpal-fine", function(original, self, ...)
            local t = original(self, ...)
            if type(t) == "number" and t > 1 and numb(self.character) then t = t * CT_SLOW end
            return t
        end)
    end
    local classes = {}
    for _, name in ipairs(CT_FINE_DURATION) do classes[#classes + 1] = _G[name] end
    DanTraits_ScaleActionTime(classes, "carpal-slow", numb, CT_SLOW)
end
wrapCarpal()
Events.OnGameStart.Add(wrapCarpal)

-- read by Moodles: 0 nothing, 1 tingling (a spell), 2 numb (a spell with the load high)
function DanTraits_CarpalMoodle(player, d)
    if not has(player) or not d or not d.ctNumb then return 0 end
    return (d.ctLoad or 0) >= CT_WAKE_FROM and 2 or 1
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.carpal = function(player, args)
    local d = traitData(player)
    if args[1] == "load" then d.ctLoad = clamp01(tonumber(args[2]) or d.ctLoad or 0) end
    return "carpal: load " .. string.format("%.2f", d.ctLoad or 0) .. ", run " .. tostring(d.ctRun or 0) .. " min of " .. tostring(d.ctLast)
        .. (d.ctNumb and ", numb" or "")
end

DanTraits_Every("minute", "CarpalTunnel", updateCarpalMinute, 40, { trait = "carpaltunnel", clear = clearCarpal })
