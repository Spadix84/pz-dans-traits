-- Project Zomboid Vitality Project: a doctor reads another player's blood
-- (multiplayer, the client's half; the server's is server/DanTraits_BloodRelay.lua,
-- which says how it goes).
--
-- Doctor: DanTraits_PatientBloodState(doctor, patient) is the patient's last
-- answer (DanTraits_BloodState's table), nil until one comes or once it is
-- old. Called each frame the health panel draws; it asks again once the
-- answer is a few seconds old, no more than once a second.
-- Patient: answers an ask about one of this client's players.
-- Singleplayer and split-screen read the patient's mod data directly, so
-- none of this runs there.
require "DanTraits"

local BR_FRESH_MS = 3000    -- ask again once the answer is this old...
local BR_ASK_MS   = 1000    -- ...but not more often than this
local BR_STALE_MS = 10000   -- an answer older than this is not shown

local known = {}   -- patient online id -> { state, at }
local asked = {}   -- patient online id -> ms

local function online() return isClient and isClient() end

function DanTraits_PatientBloodState(doctor, patient)
    if not online() or not doctor or not patient then return nil end
    local id = nil
    pcall(function() id = patient:getOnlineID() end)
    if id == nil then return nil end
    local now = getTimestampMs()
    local k = known[id]
    if (not k or now - k.at > BR_FRESH_MS) and now - (asked[id] or -math.huge) > BR_ASK_MS then
        asked[id] = now
        sendClientCommand(doctor, "DanTraits", "bloodAsk", { patient = id })
    end
    if k and now - k.at <= BR_STALE_MS then return k.state end
    return nil
end

local function onServerCommand(module, command, args)
    if module ~= "DanTraits" or type(args) ~= "table" then return end
    if command == "bloodAsk" then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            local id = nil
            pcall(function() id = player:getOnlineID() end)
            if player and id ~= nil and id == args.patient then
                local state = DanTraits_BloodState and DanTraits_BloodState(player) or false
                sendClientCommand(player, "DanTraits", "bloodTell", { doctor = args.doctor, state = state })
            end
        end
    elseif command == "bloodTell" and args.patient ~= nil then
        known[args.patient] = { state = type(args.state) == "table" and args.state or nil, at = getTimestampMs() }
    end
end

Events.OnServerCommand.Add(onServerCommand)
