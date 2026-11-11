-- Finds smokers as they load or get built, and runs the lit ones every ten game minutes.
-- server/ runs in singleplayer and on a multiplayer host, where the fire burns.
require "Smoker_Core"

MapObjects.OnLoadWithSprite(Smoker.spriteNames(), Smoker.onLoad, 5)
Events.OnObjectAdded.Add(function(obj)
    if Smoker.isSmoker(obj) then Smoker.limitContainer(obj) end
end)
Events.EveryTenMinutes.Add(Smoker.tick)
