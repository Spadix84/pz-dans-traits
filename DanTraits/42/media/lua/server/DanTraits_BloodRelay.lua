-- Project Zomboid Vitality Project: a doctor reads another player's blood
-- (multiplayer, the server's half; the client's is client/DanTraits_BloodRelay.lua).
--
-- Each client runs the blood for its own players (plans/multiplayer.md), so a
-- patient's volume is on the patient's client, not the doctor's. The doctor's
-- health panel asks (bloodAsk), this passes it on to the patient's client,
-- which answers with DanTraits_BloodState (bloodTell), and this passes that
-- back. Vanilla's health cheat goes the same way (ClientCommands.lua,
-- onHealthCheat).
--
-- An ask goes on only when the two are within reach (a few tiles, or the
-- same vehicle) and no more than twice a second from one doctor. An answer
-- goes back only to a doctor who asked about that player in the last few
-- seconds, says who it is from by the sender (not by what it claims), and
-- carries only the numbers the panel reads.
if isClient() then return end

local BR_REACH    = 4       -- tiles between doctor and patient
local BR_GAP_MS   = 500     -- one ask per doctor in this
local BR_ANSWER_MS = 5000   -- an answer is passed back this long after the ask
local BR_FIELDS = { "vol", "cells", "loss", "volGain", "cellGain", "tier", "weak", "shock", "death" }

local lastAsk = {}   -- doctor id -> ms
local asked = {}     -- "doctor:patient" -> ms

local function now() return getTimestampMs() end

local function idOf(player)
    local id = nil
    pcall(function() id = player:getOnlineID() end)
    return id
end

local function inReach(doctor, patient)
    local ok, close = pcall(function()
        local vehicle = doctor:getVehicle()
        if vehicle and vehicle == patient:getVehicle() then return true end
        return doctor:DistTo(patient) <= BR_REACH
    end)
    return ok and close == true
end

-- the panel's numbers and nothing else; false with none (the blood off)
local function clean(state)
    if type(state) ~= "table" then return false end
    local out = {}
    for _, k in ipairs(BR_FIELDS) do
        local v = tonumber(state[k])
        if v == nil then return false end
        out[k] = v
    end
    return out
end

local function onAsk(doctor, args)
    local doctorId = idOf(doctor)
    local patient = getPlayerByOnlineID(tonumber(args.patient))
    if doctorId == nil or not patient or patient == doctor then return end
    local t = now()
    if t - (lastAsk[doctorId] or -math.huge) < BR_GAP_MS then return end
    if not inReach(doctor, patient) then return end
    lastAsk[doctorId] = t
    asked[doctorId .. ":" .. tostring(idOf(patient))] = t
    sendServerCommand(patient, "DanTraits", "bloodAsk", { doctor = doctorId, patient = idOf(patient) })
end

local function onTell(patient, args)
    local patientId = idOf(patient)
    local doctorId = tonumber(args.doctor)
    if patientId == nil or doctorId == nil then return end
    local key = doctorId .. ":" .. patientId
    local at = asked[key]
    if not at or now() - at > BR_ANSWER_MS then return end
    asked[key] = nil
    local doctor = getPlayerByOnlineID(doctorId)
    if not doctor then return end
    sendServerCommand(doctor, "DanTraits", "bloodTell", { patient = patientId, state = clean(args.state) })
end

local function onClientCommand(module, command, player, args)
    if module ~= "DanTraits" or type(args) ~= "table" then return end
    if command == "bloodAsk" then onAsk(player, args)
    elseif command == "bloodTell" then onTell(player, args) end
end

Events.OnClientCommand.Add(onClientCommand)
