-- Vitality Challenges: its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so
-- this only has to put the page in the table. Without the Vitality Project the
-- table sits unused and the challenges work as before. Plain English only: the
-- Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "vitalitychallenges", title = "Vitality Challenges", mod = "VitalityChallenges", order = 60,
    body = {
        "Three scenarios in the game's Challenges menu. Each works on its own; with the Vitality Project loaded its systems join in.",
        "",
        "## Pile-Up",
        "You fled Muldraugh on the first night and drove into the back of a traffic jam on the highway in a thunderstorm. Your leg is broken, the car is dead, and whatever you packed is still in the trunk. No win condition: survive. With the Vitality Project the crash also leaves you concussed.",
        "",
        "## Nomad",
        "A year on, in a December blizzard at the far south-west edge of the map, walk to the top floor of the Louisville tower. No car will start and you get one life. You carry what you need: a big hiking bag, a tent, three days of food, a map with the tower circled, and weapons by profession, better ones for some traits. With the Vitality Project you start with your medication.",
        "",
        "## The Last Broadcast",
        "Two weeks in, the radio has gone quiet. Clear the LBMW reporter's studio in south Louisville and put the station back on the air at six every evening: thirty shows, never more than two days apart, as the listeners grow.",
        "",
        "## Need to know",
        "- Each challenge sets its own sandbox; the Vitality Project's sandbox switches still apply where it is loaded.",
        "- Singleplayer.",
    },
})
