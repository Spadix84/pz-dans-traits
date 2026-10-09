-- Offline test for DanTraits_Anger.lua: the Angry moodle's level, weapon wear,
-- the swing's endurance, the curse and its gap, slower reading, sloppier
-- splints, stitches and vehicle parts, and the sandbox switch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
ISReadABook = { getDuration = function(self) return self.time or 400 end }
VehicleUtils = { calculateInstallationSuccess = function(perks) return perks == "hard" and 40 or 100, perks == "hard" and 60 or 0 end }
H.load("Anger")
H.expectHooks("OnWeaponHitXp", "OnWeaponSwing", "OnGameStart")
H.expectEvery("minute", "Anger")

local near = H.near
local p = H.player(); H.current = p
p.getMaintenanceMod = function() return 1 end
local said = {}
p.Say = function(_, line) said[#said + 1] = line end
local function anger(v) p._st.anger = v end

local function weapon(o)
  o = o or {}
  local w = { _c = o.condition or 10 }
  function w:isRanged() return o.ranged == true end
  function w:getType() return o.type or "Axe" end
  function w:getCondition() return self._c end
  function w:setCondition(v) self._c = v end
  function w:getConditionLowerChance() return 9 end
  return w
end

-- 1. the level: from the stat when the moodle cannot be read, else the moodle's own
anger(0); assert(DanTraits_AngerLevel(p) == 0, "calm")
anger(0.1); assert(DanTraits_AngerLevel(p) == 1, "irritated")
anger(0.3); assert(DanTraits_AngerLevel(p) == 2, "annoyed")
anger(0.6); assert(DanTraits_AngerLevel(p) == 3, "angry")
anger(0.8); assert(DanTraits_AngerLevel(p) == 4, "furious")
MoodleType.ANGRY = "angry"
local m = H.player({ moodles = { angry = 2 }, anger = 0.9 })
assert(DanTraits_AngerLevel(m) == 2, "the moodle's level wins over the stat")
MoodleType.ANGRY = nil

-- 2. rough: an extra wear roll per melee hit, from Annoyed up, never the last point
H.rollf = 0
local axe = weapon()
anger(0.1); H.fire("OnWeaponHitXp", p, axe, {}, 1, 1)
assert(axe._c == 10, "irritated: only the warning")
anger(0.3); H.fire("OnWeaponHitXp", p, axe, {}, 1, 1)
assert(axe._c == 9, "annoyed: the weapon wears")
H.rollf = 0.03   -- annoyed 0.5 / 20 = 0.025, angry 1 / 20 = 0.05
H.fire("OnWeaponHitXp", p, axe, {}, 1, 1)
assert(axe._c == 9, "the roll scales with the level: annoyed misses")
anger(0.6); H.fire("OnWeaponHitXp", p, axe, {}, 1, 1)
assert(axe._c == 8, "angry hits")
H.rollf = 0
local worn = weapon({ condition = 1 }); H.fire("OnWeaponHitXp", p, worn, {}, 1, 1)
assert(worn._c == 1, "never the last point")
local gun = weapon({ ranged = true }); H.fire("OnWeaponHitXp", p, gun, {}, 1, 1)
assert(gun._c == 10, "not a firearm")
local hands = weapon({ type = "BareHands" }); H.fire("OnWeaponHitXp", p, hands, {}, 1, 1)
assert(hands._c == 10, "not bare hands")
local other = H.player({ anger = 0.9 }); other.getMaintenanceMod = p.getMaintenanceMod
H.fire("OnWeaponHitXp", other, axe, {}, 1, 1)
assert(axe._c == 8, "only the local player")

-- 3. furious: every melee swing costs endurance
anger(0.6); H.fire("OnWeaponSwing", p, axe)
near(p._st.endurance, 1, 1e-9, "angry: no extra cost")
anger(0.8); H.fire("OnWeaponSwing", p, axe)
near(p._st.endurance, 0.996, 1e-9, "furious: the swing costs more")
H.fire("OnWeaponSwing", p, gun)
near(p._st.endurance, 0.996, 1e-9, "not a shot")

-- 4. loud: from Angry up a curse zombies hear, with the cough's gap
local d = DanTraits_Data(p)
anger(0.3); H.minute()
assert(#said == 0 and #H.sounds == 0, "annoyed: quiet")
anger(0.6); H.minute()
assert(#said == 1 and said[1] == "UI_DanTraits_AngerCurse1", "angry: a curse")
assert(H.sounds[1] == 8 and d.angCurses == 1, "heard at 8 tiles")
H.minute()
assert(#said == 1, "not again inside the gap")
H.hours = H.hours + 4 / 60
p._asleep = true; H.minute()
assert(#said == 1, "not asleep")
p._asleep = false
H.roll = 999999; H.minute()
assert(#said == 1, "and only on the roll")
H.roll = 0; anger(0.8); H.minute()
assert(#said == 2 and H.sounds[2] == 14, "furious: louder")
assert(d.coughGap > H.hours, "a curse starts the shared gap")
assert(not DanTraits_Cough(p, 10, "test"), "so a cough waits its turn")

-- 5. can't concentrate: reading takes longer
local function read(who, time) return setmetatable({ character = who, time = time }, { __index = ISReadABook }):getDuration() end
anger(0.1); near(read(p), 400, 1e-9, "irritated: as is")
anger(0.3); near(read(p), 460, 1e-9, "annoyed")
anger(0.6); near(read(p), 520, 1e-9, "angry")
anger(0.8); near(read(p), 600, 1e-9, "furious")
near(read(p, 1), 1, 1e-9, "instant stays instant")

-- 6. sloppy: splints, stitches, vehicle parts
anger(0.6)
near(DanTraits_RunHooks("splintBadSet", 0.2, p), 0.3, 1e-9, "bad set likelier")
near(DanTraits_RunHooks("stitchPoor", 0.2, p), 0.3, 1e-9, "rough stitches likelier")
anger(0.1)
near(DanTraits_RunHooks("stitchPoor", 0.2, p), 0.2, 1e-9, "irritated: as is")
anger(0.8)
local s, f = VehicleUtils.calculateInstallationSuccess("easy", p)
assert(s == 80 and f == 20, "a part you have the skill for can still go wrong")
s, f = VehicleUtils.calculateInstallationSuccess("hard", p)
assert(s == 20 and f == 80, "and a hard one is worse")
anger(0)
s, f = VehicleUtils.calculateInstallationSuccess("easy", p)
assert(s == 100 and f == 0, "calm: the game's own chances")

-- 7. the sandbox option turns it all off
SandboxVars = { DanTraits = { AngerEffects = false } }
anger(0.8)
assert(DanTraits_AngerLevel(p) == 0, "off: no level")
near(read(p), 400, 1e-9, "off: reading as is")
H.hours = H.hours + 1; H.minute()
assert(#said == 2, "off: no curse")
SandboxVars = nil

-- 8. the console command sets the stat
assert(DanTraits_ExtraCommands.anger(p, { "0.6" }):find("0.6", 1, true), "anger 0.6")
near(p._st.anger, 0.6, 1e-9, "set")

H.pass()
