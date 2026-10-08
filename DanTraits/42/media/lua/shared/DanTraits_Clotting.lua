-- Project Zomboid Vitality Project: clotting powder (styptic powder, the
-- kind barbers, vets and medics kept in 1993).
--
-- Not a trait: anyone can use it. Packed into a bleeding wound from the
-- health panel (right-click a bleeding part with no dressing on it;
-- ISVitalityClotAction, the menu in DanTraits_Client.lua). It stings
-- (CLOT_PAIN, less with First Aid), and then:
--   a scratch or cut   stops bleeding there and then
--   a deep wound       its bleeding time halved (CLOT_DEEP_TIME) and, while
--                      the clot holds, it bleeds at a quarter (CLOT_RATE).
--                      It still wants stitches.
--   shard or bullet in the powder can't pack around it: x0.6 (CLOT_LODGED)
--   Hemophilia         the blood won't clot on its own: nothing stops, the
--                      bleed only halves (CLOT_HEMO)
-- A bandage over it stacks: together a deep wound bleeds at a fortieth of
-- open, and soaks the bandage that much slower (DanTraits_WoundCare.lua
-- reads the rate through DanTraits_BloodPartRate, which asks
-- DanTraits_ClotFactor). The clot holds CLOT_HOURS, until the part stops
-- bleeding, or until the wound tears or opens again (WoundCare calls
-- DanTraits_ClotBreak). With the blood system off only the bleeding time
-- changes, which is what vanilla's health loss reads.
--
-- Mod data: clot[part name] = game minutes the clot has left.
require "DanTraits"

local traitData = DanTraits_Data
local num = DanTraits_PartNum
local is = DanTraits_PartIs

local CLOT_RATE      = 0.25    -- x a deep wound's blood loss while the clot holds
local CLOT_LODGED    = 0.6     -- ...with a shard or a bullet still in it
local CLOT_HEMO      = 0.5     -- ...for a hemophiliac
local CLOT_DEEP_TIME = 0.5     -- x a deep wound's bleeding time when it is packed
local CLOT_HOURS     = 12      -- how long a clot holds
local CLOT_PAIN      = 20      -- pain on the part (it stings), less half the First Aid level
local CLOT_XP        = 5       -- First Aid xp, as a bandage

local function partName(part)
    local name = ""
    pcall(function() name = tostring(part:getType()) end)
    return name
end

local lodged = DanTraits_PartLodged
local function hemophiliac(player) return DanTraits_HasTrait(player, "hemophilia") end

-- x the part's blood loss: 1 with no clot on it
function DanTraits_ClotFactor(player, part)
    if not player or not part then return 1 end
    local d = player:getModData().DanTraits
    local left = d and d.clot and d.clot[partName(part)]
    if not left or left <= 0 then return 1 end
    local factor = CLOT_RATE
    if lodged(part) then factor = math.max(factor, CLOT_LODGED) end
    if hemophiliac(player) then factor = math.max(factor, CLOT_HEMO) end
    return factor
end

function DanTraits_ClotBreak(player, part)
    local d = player and player:getModData().DanTraits
    if d and d.clot then d.clot[partName(part)] = nil end
end

-- can the powder go on this part now: bleeding, and no dressing in the way.
-- Returns ok, and the reason when not ("bandaged", "notBleeding").
function DanTraits_ClotCanApply(part)
    if not part or num(part, "getBleedingTime") <= 0 then return false, "notBleeding" end
    if is(part, "bandaged") then return false, "bandaged" end
    return true
end

-- the powder packed in (the action's complete): true if it went on
function DanTraits_ApplyClot(patient, part, level)
    if not patient or not part or not DanTraits_ClotCanApply(part) then return false end
    local name = partName(part)
    local t = num(part, "getBleedingTime")
    local deep = num(part, "getDeepWoundTime") > 0 or is(part, "deepWounded")
    local stuck = lodged(part)
    local hemo = hemophiliac(patient)
    local stopped = false
    if not hemo and not stuck then
        if deep then
            pcall(function() part:setBleedingTime(t * CLOT_DEEP_TIME) end)
        else
            pcall(function()
                part:setBleedingTime(0)
                part:setBleeding(false)
            end)
            stopped = true
        end
    end
    local d = traitData(patient)
    d.clot = d.clot or {}
    if stopped then d.clot[name] = nil else d.clot[name] = CLOT_HOURS * 60 end
    local pain = math.max(0, CLOT_PAIN - (level or 0) / 2)
    pcall(function() part:setAdditionalPain(math.min(100, part:getAdditionalPain() + pain)) end)
    local label = name
    pcall(function() label = BodyPartType.getDisplayName(part:getType()) or name end)
    DanTraits_NotifyFmtGood(patient, stopped and "UI_DanTraits_ClotStopped" or "UI_DanTraits_ClotSlowed", label)
    return true
end
DanTraits_ClotXp = CLOT_XP

-- the clots wear off, or have nothing left to do
local function updateClotMinute(player, d)
    if not d.clot then return end
    local bd = player:getBodyDamage()
    for name, left in pairs(d.clot) do
        local part = nil
        pcall(function() part = bd:getBodyPart(BodyPartType[name]) end)
        left = left - 1
        if left <= 0 or not part or num(part, "getBleedingTime") <= 0 then
            d.clot[name] = nil
        else
            d.clot[name] = left
        end
    end
end

-- console: clot <part> (pack it, at First Aid 0) | clot clear
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.clot = function(player, args)
    if string.lower(tostring(args[1] or "")) == "clear" then
        traitData(player).clot = nil
        return "clots cleared"
    end
    local part = DanTraits_PartOf(player, args[1])
    if not part then return "clot <part> | clot clear" end
    local ok, why = DanTraits_ClotCanApply(part)
    if not ok then return "clot: " .. tostring(why) end
    DanTraits_ApplyClot(player, part, 0)
    return "clot on " .. partName(part) .. ", bleeding time " .. tostring(num(part, "getBleedingTime"))
        .. ", x" .. tostring(DanTraits_ClotFactor(player, part))
end

DanTraits_Every("minute", "Clotting", updateClotMinute, 19)
