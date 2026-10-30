-- Vitality Challenges: the radio channels a challenge can air on (The Last
-- Broadcast, plans/last-broadcast.md). The vanilla dynamic radio creates or finds
-- every entry of DynamicRadio.channels on OnLoadRadioScripts and keeps it in
-- DynamicRadio.cache by uuid, where the client airs on it with setAiringBroadcast.
--   LBMW - Kentucky Radio (93.2) is vanilla's own channel (RadioData.xml), silent
--   after day 7: register = false finds it instead of making a second one.
--   A station of our own (the plan's spare, 96.4) is not registered until a
--   challenge airs on it: an entry here goes into every save that loads the mod,
--   challenge or not, and stays in its dynamicRadio mod data.
require "radio/ISDynamicRadio"

local CHANNELS = {
    { name = "LBMW - Kentucky Radio", freq = 93200, category = "Radio", uuid = "68775c28-19e1-4737-9ba5-ce681d15f52d", register = false },
}

if DynamicRadio and DynamicRadio.channels then
    for _, entry in ipairs(CHANNELS) do
        local known = false
        for _, c in ipairs(DynamicRadio.channels) do
            if c.uuid == entry.uuid then known = true end
        end
        if not known then table.insert(DynamicRadio.channels, entry) end
    end
end
