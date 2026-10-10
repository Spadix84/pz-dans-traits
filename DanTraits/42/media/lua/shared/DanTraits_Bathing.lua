-- Project Zomboid Vitality Project: Take A Bath And Shower (TakeABathAndShowerNew) compatibility.
require "DanTraits"

-- Does nothing unless Take A Bath And Shower is loaded. No dependency either way.
--
-- That mod cleans the body's blood and dirt a little at a time while you
-- bathe or shower (Germaphobe reads the same visual every minute, so the
-- relief comes on its own), soaks you (Multiple Sclerosis cools faster wet),
-- warms or chills the body toward the water (an MS character in a hot bath
-- heats up: by design on both sides), and its bath salts do what the names
-- say (a calming salt is the game's beta-blocker effect, a happy one its
-- antidepressant effect): those are its features and are left alone. An MDD
-- character zeroes the game's antidepressant timer every minute anyway, so a
-- happy salt does nothing for them.
--
-- The one thing this file does: a bath or a shower washes sun block off.
-- Take A Bath fires OnBathingEnd(character) when either ends (its client
-- files load after this one, so the event is looked up at game start).
--
-- Dan's Vanilla Fixes has its own file for the clothes washed in the bath
-- (its hand-wash floors apply there too).
local installed = false

local function onBathingEnd(player)
    if not player then return end
    local local0 = getSpecificPlayer and getSpecificPlayer(0)
    if local0 and player ~= local0 then return end
    if not DanTraits_SunblockLeft or DanTraits_SunblockLeft(player) <= 0 then return end
    local d = DanTraits_Data(player)
    d.sbBlockMin = 0
    DanTraits_Notify(player, "UI_DanTraits_SunblockWashed")
end
DanTraits_BathingEnded = onBathingEnd   -- tests

local function install()
    if installed then return end
    local ev = Events and Events.OnBathingEnd
    if type(ev) ~= "table" or type(ev.Add) ~= "function" then return end
    installed = true
    ev.Add(onBathingEnd)
    print("[DanTraits] Take A Bath And Shower found: a bath washes sun block off")
end

Events.OnGameStart.Add(install)
