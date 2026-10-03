-- Project Zomboid Vitality Project: Arthritis (Fumbler folded in).
-- Stiff, painful joints. Hands, forearms and legs carry a floor of the
-- game's own stiffness all the time (the fitness system's muscle
-- stiffness, which the game turns into pain and slower movement), and the
-- floor rises in the cold and the damp: a flare. Stiffness is not the pain
-- stat, so painkillers ease the ache but not the slowness. Every attack is
-- slower on top of that, more so in a flare. And the grip is unreliable: a
-- swing can slip, worse when panicked, hurt or tired, and worse again when
-- the joints are flaring. A slipped swing lands weak (the weapon's damage cut
-- for that one swing, put back when the attack finishes); only in a bad
-- flare can a slip throw the weapon to the ground, and the
-- ArthritisWeaponDrop sandbox option turns that off.
--
-- Mod data: artJoint, artStiffTarget, artCombatSet; on the weapon,
-- DanTraitsSlip = { min, max } while a slipped swing is weakened.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local fraction = DanTraits_StatFraction

-- joints
local ART_STIFF_BASE    = 12      -- stiffness floor on each joint part, warm and dry
local ART_STIFF_FLARE   = 45      -- floor at a full flare
local ART_COLD_FROM     = 15      -- degrees C: the cold factor climbs from here...
local ART_COLD_FULL     = 0       -- ...to full here
local ART_DAMP_WEIGHT   = 0.7     -- how much damp counts against cold
local ART_HUMID         = 0.8     -- humidity above this counts as half damp
local ART_FLARE_NOTICE  = 0.5     -- joint factor crossing this upward: a notice
-- combat
local ART_COMBAT_SLOW   = 0.15    -- every attack this much slower...
local ART_COMBAT_FLARE  = 0.15    -- ...and this much more at a full flare
-- grip
local FUMBLE_BASE       = 1       -- percent per weapon swing, calm and rested
local FUMBLE_PANIC      = 6       -- added at full panic
local FUMBLE_PAIN       = 6       -- added at full pain
local FUMBLE_FATIGUE    = 5       -- added at full fatigue
local FUMBLE_FLARE      = 4       -- added at a full flare
local SLIP_DAMAGE       = 0.35    -- a slipped swing hits for this share of the weapon's damage
local SLIP_DROP_FLARE   = 0.5     -- a slip can only throw the weapon at this flare or worse...
local SLIP_DROP_SHARE   = 0.33    -- ...and then one slip in three does
local SLIP_RESTORE_MS   = 3000    -- the weakened damage is put back after this long whatever happens

local JOINTS = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }

local clamp01 = DanTraits_Clamp01

-- 0..1 how much the weather is in the joints
local function jointFactor(player)
    local cold, damp = 0, 0
    pcall(function()
        local climate = getClimateManager()
        local temp = climate:getAirTemperatureForCharacter(player)
        cold = clamp01((ART_COLD_FROM - temp) / (ART_COLD_FROM - ART_COLD_FULL))
        local outside = false
        pcall(function() outside = player:isOutside() end)
        if outside then damp = math.max(damp, clamp01(climate:getRainIntensity() or 0)) end
        if (climate:getHumidity() or 0) > ART_HUMID then damp = math.max(damp, 0.5) end
    end)
    pcall(function() damp = math.max(damp, fraction(player:getStats(), CharacterStat.WETNESS)) end)
    return clamp01(math.max(cold, ART_DAMP_WEIGHT * damp))
end
DanTraits_ArthritisJoint = jointFactor

local function updateArthritisMinute(player, d)
    if not hasTrait(player, "arthritis") then return end
    local joint = DanTraits_RunHooks("arthritisJoint", jointFactor(player), player)   -- Age: sooner in the 40s
    local before = d.artJoint or 0
    d.artJoint = joint
    if joint >= ART_FLARE_NOTICE and before < ART_FLARE_NOTICE then notify(player, "UI_DanTraits_ArthritisFlare") end
    local target = ART_STIFF_BASE + (ART_STIFF_FLARE - ART_STIFF_BASE) * joint
    d.artStiffTarget = target
    pcall(function()
        local bd = player:getBodyDamage()
        for _, name in ipairs(JOINTS) do
            local part = bd:getBodyPart(BodyPartType[name])
            if part and (part:getStiffness() or 0) < target then part:setStiffness(target) end
        end
    end)
end

-- per frame: the game sets combat speed when an attack starts; scale it once each time it changes
local function updateArthritisFrame(player)
    local d = player:getModData().DanTraits
    if not d or not hasTrait(player, "arthritis") then return end
    local cs = nil
    pcall(function() cs = player:getCombatSpeed() end)
    if not cs or cs <= 0 or cs == d.artCombatSet then return end
    local slowed = cs * (1 - ART_COMBAT_SLOW - ART_COMBAT_FLARE * (d.artJoint or 0))
    pcall(function() player:setCombatSpeed(slowed) end)
    d.artCombatSet = slowed
end

-- grip ---------------------------------------------------------------------
local function fumbleChance(player)
    local chance = FUMBLE_BASE
    pcall(function()
        local stats = player:getStats()
        chance = chance
            + (stats:get(CharacterStat.PANIC) or 0) / 100 * FUMBLE_PANIC
            + (stats:get(CharacterStat.PAIN) or 0) / 100 * FUMBLE_PAIN
            + (stats:get(CharacterStat.FATIGUE) or 0) * FUMBLE_FATIGUE
        local d = player:getModData().DanTraits
        chance = chance + (d and d.artJoint or 0) * FUMBLE_FLARE
    end)
    return chance
end
DanTraits_FumbleChance = fumbleChance

-- percent per swing that the grip slips: Arthritis's, plus anything else
-- that makes the hands clumsy (the gripSlip hook: sumatriptan's day after).
-- Only Arthritis in a bad flare can turn a slip into a drop.
function DanTraits_GripSlipChance(player)
    local chance = hasTrait(player, "arthritis") and fumbleChance(player) or 0
    return DanTraits_RunHooks("gripSlip", chance, player)
end

-- percent per swing that the weapon is thrown outright: other traits' shakes
-- (a diabetic low, alcohol withdrawal, MS heat), Arthritis or not. An
-- arthritic slip is separate (DanTraits_GripSlipChance).
function DanTraits_SwingDropChance(player)
    local chance = 0
    if DanTraits_ExtraFumble then
        local ok, extra = pcall(DanTraits_ExtraFumble, player)
        if ok and extra then chance = chance + extra end
    end
    return DanTraits_RunHooks("swingDrop", chance, player)
end

-- drop whatever is in the primary hand at the character's feet; true if something dropped
local function dropWeapon(player)
    local item = player:getPrimaryHandItem()
    local square = player:getCurrentSquare()
    if not item or not square then return false end

    player:removeFromHands(item)
    player:getInventory():Remove(item)
    square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    -- the text key keeps its old Fumbler name so existing translations still match
    notify(player, "UI_DanTraits_FumblerDrop")
    return true
end
DanTraits_FumbleDrop = dropWeapon

-- a slipped swing: the weapon's damage is cut until the attack finishes. The
-- game reads it at the hit point, after OnWeaponSwing. The originals ride on
-- the weapon's mod data, so a save caught mid-swing is put right on the next
-- swing; pending lists the weapons to put back by time, in case the attack
-- never reports finishing.
local pending = {}

local function now()
    local t = 0
    pcall(function() t = getTimestampMs() end)
    return t
end

local function restoreWeapon(weapon)
    if not weapon then return end
    pcall(function()
        local md = weapon:getModData()
        local orig = md and md.DanTraitsSlip
        if not orig then return end
        weapon:setMinDamage(orig.min)
        weapon:setMaxDamage(orig.max)
        md.DanTraitsSlip = nil
    end)
    for i = #pending, 1, -1 do
        if pending[i].weapon == weapon then table.remove(pending, i) end
    end
end
DanTraits_GripRestore = restoreWeapon

local function weakenSwing(player, weapon)
    pcall(function()
        local md = weapon:getModData()
        if not md.DanTraitsSlip then
            local min, max = weapon:getMinDamage(), weapon:getMaxDamage()
            md.DanTraitsSlip = { min = min, max = max }
            weapon:setMinDamage(min * SLIP_DAMAGE)
            weapon:setMaxDamage(max * SLIP_DAMAGE)
        end
    end)
    for i = #pending, 1, -1 do
        if pending[i].weapon == weapon then table.remove(pending, i) end
    end
    pending[#pending + 1] = { weapon = weapon, at = now() + SLIP_RESTORE_MS }
    notify(player, "UI_DanTraits_GripSlip")
end

local function onWeaponSwing(player, weapon)
    if not weapon then return end
    restoreWeapon(weapon)   -- anything left over from a save mid-swing
    -- other traits' shakes throw the weapon outright
    local drop = DanTraits_SwingDropChance(player)
    if drop > 0 and ZombRand(1000) < drop * 10 then
        dropWeapon(player)
        return
    end
    -- an arthritic grip slips: a weak swing, or in a bad flare sometimes the weapon goes
    local slip = DanTraits_GripSlipChance(player)
    if slip <= 0 or ZombRand(1000) >= slip * 10 then return end
    local d = player:getModData().DanTraits
    if hasTrait(player, "arthritis") and (d and d.artJoint or 0) >= SLIP_DROP_FLARE and DanTraits_SandboxOn("ArthritisWeaponDrop")
        and ZombRand(100) < SLIP_DROP_SHARE * 100 then
        dropWeapon(player)
        return
    end
    weakenSwing(player, weapon)
end

local function onAttackFinished(player, weapon)
    if weapon then restoreWeapon(weapon) end
end

-- every frame, for anyone: put back weakened weapons whose time is up
local function restoreDue()
    if #pending == 0 then return end
    local t = now()
    for i = #pending, 1, -1 do
        local entry = pending[i]
        if t >= entry.at then restoreWeapon(entry.weapon) end
    end
end

Events.OnWeaponSwing.Add(onWeaponSwing)
Events.OnPlayerAttackFinished.Add(onAttackFinished)
DanTraits_Every("frame", "ArthritisGrip", restoreDue, 40)
DanTraits_Every("minute", "Arthritis", updateArthritisMinute, 40)
DanTraits_Every("frame", "Arthritis", updateArthritisFrame, 40)
