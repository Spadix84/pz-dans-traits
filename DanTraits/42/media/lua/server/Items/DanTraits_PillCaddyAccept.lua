-- The pill caddy takes medication only (shared/DanTraits_PillCaddy.lua).
-- Lives under server/Items next to vanilla's AcceptItemFunction.lua, which
-- creates the table with "AcceptItemFunction = {}": loading after it keeps
-- this function from being wiped.
require "Items/AcceptItemFunction"
require "DanTraits_PillCaddy"

AcceptItemFunction = AcceptItemFunction or {}

function AcceptItemFunction.DanPillCaddy(container, item)
    return DanTraits_IsMedication(item)
end
