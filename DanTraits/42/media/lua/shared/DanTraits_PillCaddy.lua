-- Project Zomboid Vitality Project: the pill caddy, a rare belt container that
-- only holds medication.
--
-- The item is in media/scripts/DanTraits.txt. It hangs on the belt in the
-- walkie-talkie spot (AttachmentType = Walkie: both belt slots and the webbing
-- slots take it). What may go in is decided by DanTraits_IsMedication, through
-- AcceptItemFunction.DanPillCaddy (server/Items/DanTraits_PillCaddyAccept.lua).
-- Its own tab in the inventory window comes from client/DanTraits_PillCaddyTab.lua.
-- Loot: server/Items/DanTraits_Distributions.lua.
require "DanTraits"

-- lower-case item types (getType) that count as medication, besides every
-- item on the shared drug list (DanTraits_Drugs, DanTraits_Meds.lua)
DanTraits_PillCaddyMeds = {
    -- vanilla
    pills = true, pillsantidep = true, pillsbeta = true, pillssleepingtablets = true,
    pillsvitamins = true, antibiotics = true,
    -- this mod
    inhaler = true, insulinpen = true, metformin = true, ironpills = true,
    anticonvulsants = true, diazepam = true, nicotinegum = true,
    -- Multiple Sclerosis
    amantadine = true, baclofen = true, prednisone = true,
}

function DanTraits_IsMedication(item)
    if not item or not item.getType then return false end
    local kind = string.lower(tostring(item:getType() or ""))
    if DanTraits_PillCaddyMeds[kind] then return true end
    return DanTraits_DrugOfItem ~= nil and DanTraits_DrugOfItem(kind) ~= nil
end

function DanTraits_IsPillCaddy(item)
    return item ~= nil and item.getFullType ~= nil and item:getFullType() == "DanTraits.PillCaddy"
end
