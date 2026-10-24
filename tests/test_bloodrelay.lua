-- Offline test for DanTraits_BloodRelay.lua (client and server halves): a
-- doctor's panel asks about another player, the server passes it to the
-- patient's client within reach only, the answer comes back to the doctor
-- who asked and only the panel's numbers with it; asks are spaced out, old
-- answers go stale, and a client can't answer for someone else or push
-- answers nobody asked for.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.now = 100000

-- two players on two clients, and the server between them
local function online(id, x)
  local p = H.player()
  p._id, p._x = id, x
  p.getOnlineID = function() return p._id end
  p.getVehicle = function() return p._vehicle end
  p.DistTo = function(_, other) return math.abs(p._x - other._x) end
  return p
end
local doctor, patient = online(1, 0), online(2, 3)
local players = { [1] = doctor, [2] = patient }
function getPlayerByOnlineID(id) return players[id] end

local state = { vol = 0.7, cells = 0.8, loss = 0.002, volGain = 0.0001, cellGain = 0, tier = 1, weak = 0.2, shock = 0.4, death = 0.5 }
function DanTraits_BloodState(p) if p == patient then return state end return nil end

-- the wire: a client's command reaches the server; the server's reaches the one client,
-- which sees only its own player
local sent, onThisClient = {}, nil
function sendClientCommand(player, module, command, args)
  sent[#sent + 1] = "c:" .. command
  H.fire("OnClientCommand", module, command, player, args)
end
function sendServerCommand(player, module, command, args)
  sent[#sent + 1] = "s:" .. command .. ">" .. player._id
  local was = onThisClient
  onThisClient = player
  H.fire("OnServerCommand", module, command, args)
  onThisClient = was
end
function getNumActivePlayers() return 1 end
function getSpecificPlayer() return onThisClient end

isClient = function() return false end
H.load("server/DanTraits_BloodRelay.lua")
isClient = function() return true end
H.load("client/DanTraits_BloodRelay.lua")
H.expectHooks("OnClientCommand", "OnServerCommand")

-- 1. the first look asks; the answer arrives over the round trip, the patient's numbers
onThisClient = doctor
local got = DanTraits_PatientBloodState(doctor, patient)
assert(table.concat(sent, " ") == "c:bloodAsk s:bloodAsk>2 c:bloodTell s:bloodTell>1", table.concat(sent, " "))
-- (the wire here is instant, so the first call already has it; in game it is a moment later)
got = DanTraits_PatientBloodState(doctor, patient)
assert(got and got.vol == 0.7 and got.tier == 1 and got.weak == 0.2, "the patient's state")

-- 2. drawn every frame: no more asks until the answer is 3 s old
sent = {}
H.now = H.now + 2000; DanTraits_PatientBloodState(doctor, patient)
assert(#sent == 0, "fresh: no ask")
H.now = H.now + 1500; DanTraits_PatientBloodState(doctor, patient)
assert(#sent == 4, "3 s old: asked again")

-- 3. only the panel's numbers go across, and a missing one means none
state = { vol = 0.9, cells = 1, loss = 0, volGain = 0, cellGain = 0, tier = 0, weak = 0, shock = 0.4, death = 0.5, secret = "x", bloodDebug = true }
H.now = H.now + 4000; DanTraits_PatientBloodState(doctor, patient)
got = DanTraits_PatientBloodState(doctor, patient)
assert(got.vol == 0.9 and got.secret == nil and got.bloodDebug == nil, "only the panel's fields")
state = nil   -- the blood switched off
H.now = H.now + 4000; DanTraits_PatientBloodState(doctor, patient)
assert(DanTraits_PatientBloodState(doctor, patient) == nil, "blood off: nothing to show")
state = { vol = 0.6, cells = 1, loss = 0, volGain = 0, cellGain = 0, tier = 2, weak = 0, shock = 0.4, death = 0.5 }

-- 4. out of reach: the server doesn't pass it on, and the old answer goes stale after 10 s
patient._x = 10
sent = {}
H.now = H.now + 4000; DanTraits_PatientBloodState(doctor, patient)
assert(table.concat(sent, " ") == "c:bloodAsk", "too far: stops at the server")
H.now = H.now + 7000
assert(DanTraits_PatientBloodState(doctor, patient) == nil, "stale: not shown")
-- the same vehicle counts as within reach
patient._vehicle, doctor._vehicle = "car", "car"
sent = {}
H.now = H.now + 4000; DanTraits_PatientBloodState(doctor, patient)
assert(#sent == 4 and DanTraits_PatientBloodState(doctor, patient).vol == 0.6, "in the same car")
patient._vehicle, doctor._vehicle, patient._x = nil, nil, 3

-- 5. the server spaces a doctor's asks (a client that ignores its own spacing)
H.now = H.now + 1000
sent = {}
sendClientCommand(doctor, "DanTraits", "bloodAsk", { patient = 2 })
assert(#sent == 4, "the server lets the first through")
sent = {}
sendClientCommand(doctor, "DanTraits", "bloodAsk", { patient = 2 })
assert(#sent == 1, "a second within half a second stops at the server")

-- 6. an answer nobody asked for, or for someone else, goes nowhere
local third = online(3, 1); players[3] = third
sent = {}
H.now = H.now + 6000
sendClientCommand(third, "DanTraits", "bloodTell", { doctor = 1, state = state })
assert(#sent == 1, "unasked: dropped")
-- asked about the patient; a third player answers: it comes back as the third's, not the patient's
H.now = H.now + 1000
onThisClient = doctor
sendClientCommand(doctor, "DanTraits", "bloodAsk", { patient = 2 })
sent = {}
sendClientCommand(third, "DanTraits", "bloodTell", { doctor = 1, patient = 2, state = { vol = 0.1 } })
assert(#sent == 1, "the third player wasn't asked about: dropped")

-- 7. not in multiplayer: nothing asked, nothing shown (singleplayer reads mod data)
isClient = function() return false end
sent = {}
assert(DanTraits_PatientBloodState(doctor, patient) == nil and #sent == 0, "singleplayer: nothing")

H.pass()
