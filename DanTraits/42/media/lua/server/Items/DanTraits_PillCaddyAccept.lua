-- Project Zomboid Vitality Project: what the Pill Caddy accepts (its
-- AcceptItemFunction; the list is DanTraits_IsCaddyMed in
-- shared/DanTraits_PillCaddy.lua). It lives here, after vanilla's
-- Items/AcceptItemFunction.lua, because that file starts the table afresh.
require "Items/AcceptItemFunction"

function AcceptItemFunction.DanPillCaddy(container, item)
    return DanTraits_IsCaddyMed ~= nil and DanTraits_IsCaddyMed(item)
end
