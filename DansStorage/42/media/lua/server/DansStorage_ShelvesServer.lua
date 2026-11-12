-- Storage shelves as their chunks load: the accept-item function isn't saved, so each
-- shelf tile gets it back here, and its overlay is checked (singleplayer and the server;
-- a client gets the function as the loot window opens, DansStorage_ShelvesClient.lua).
-- Once a game minute every shelf seen is looked at again, so its look follows whatever
-- changed it outside a transfer.
if isClient() then return end
require "DansStorage_Shelves"

local Shelves = DansStorage.Shelves

MapObjects.OnLoadWithSprite(Shelves.spriteNames(), Shelves.ensure, 5)
Events.EveryOneMinute.Add(Shelves.syncAll)
