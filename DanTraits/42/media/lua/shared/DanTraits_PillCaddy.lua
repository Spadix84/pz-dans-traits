-- Project Zomboid Vitality Project: the Pill Caddy, a weekly pill organiser
-- that holds medication only.
--
-- What fits: anything on the shared medication list (DanTraits_Drugs, so the
-- vanilla pills, the mod's bottles, the inhaler, insulin and nicotine gum)
-- plus the game's antibiotics. A whitelist, not "anything medical": bandages,
-- splints and the glucose meter stay out.
--   server/Items/DanTraits_PillCaddyAccept.lua  the item's AcceptItemFunction
--   client/DanTraits_PillCaddyTab.lua           its tab in the inventory window
--                                               (and the parent fix: on the belt the
--                                               game parents its container to the
--                                               character, which breaks its weight)
--   server/Items/DanTraits_Distributions.lua    where it is found, and what a
--                                               found one holds
-- It hangs on a small belt slot like a canteen (AttachmentType Walkie in the
-- item script). Capacity 1; the game makes that 2 for an Organized character
-- (capacity x 1.3, at least +1), as it does for a fanny pack.
--
-- A new character with a medical trait has a 1% chance to start with one.
require "DanTraits"
require "DanTraits_Meds"

local CADDY_ITEM       = "DanTraits.PillCaddy"
local CADDY_START_PCT  = 1       -- percent, once, for a new character with a medical trait

-- not on the drug list, but medication (lower-case item types)
local EXTRA_MEDS = { antibiotics = true, antibioticsbox = true }

-- the traits treated with medication
local MEDICAL_TRAITS = { "heart", "epilepsy", "diabetes1", "diabetes2", "spiraling", "ms",
    "asthma", "anemia", "migraine", "arthritis" }

function DanTraits_IsCaddyMed(item)
    if not item then return false end
    local kind = string.lower(tostring(item:getType() or ""))
    return DanTraits_DrugOfItem(kind) ~= nil or EXTRA_MEDS[kind] == true
end

function DanTraits_IsPillCaddy(item)
    return item ~= nil and item:getFullType() == CADDY_ITEM
end

local function hasMedicalTrait(player)
    for _, key in ipairs(MEDICAL_TRAITS) do
        if DanTraits_HasTrait(player, key) then return true end
    end
    return false
end

local function onCaddyCreatePlayer(playerNum, player)
    if not player or player:getHoursSurvived() > 0 then return end
    local d = DanTraits_Data(player)
    if d.caddyRolled then return end
    d.caddyRolled = true
    if not hasMedicalTrait(player) or ZombRand(100) >= CADDY_START_PCT then return end
    pcall(function() player:getInventory():AddItem(CADDY_ITEM) end)
end

Events.OnCreatePlayer.Add(onCaddyCreatePlayer)
