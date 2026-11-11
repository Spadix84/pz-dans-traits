-- Brick Smoker (Vitality Appliances): its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so this
-- only has to put the page in the table. Without the Vitality Project the table sits
-- unused. Plain English only: the Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "bricksmoker", title = "Brick Smoker", mod = "VitalityAppliances", order = 41,
    body = {
        "Light a fire, load the meat, come back tomorrow to jerky. A brick smoker you build yourself, for making the hunt last.",
        "",
        "## Building it",
        "- Build menu, Masonry: 16 clay bricks, 3 units of mortar or concrete, a sheet of metal and 2 metal bars, with a mason's trowel. Needs Masonry 3.",
        "- It has to stand outdoors with nothing over it, or the fire won't draw. Roof it over and the fire chokes.",
        "",
        "## The fire",
        "- Right-click the smoker, Brick Smoker, Add Fuel. Wood only: a log is 6 hours, a plank or firewood 2, a branch or charcoal 1. The firebox holds 24 hours.",
        "- Fill It Up takes the biggest pieces in reach first. Wood can come from your inventory, a crate or the floor.",
        "- Light it with a lighter or matches. Put it out whenever you like: the fuel left stays for next time.",
        "",
        "## Smoking",
        "- Put In Meat and Fish loads every raw piece you carry. Meat, game, poultry, fish and seafood all work; rotten or burnt meat doesn't.",
        "- 8 hours of smoke: Smoked. Ready to eat, keeps about two weeks.",
        "- 24 hours: Smoke-Dried. Like jerky, lighter to carry, keeps about four months. A little thirsty-making.",
        "- Nothing in the chamber spoils while the fire burns. Hover the menu to see each piece's progress.",
        "- Each piece keeps its own nutrition, and smoked meat still goes in stews, soups and sandwiches.",
        "",
        "## Need to know",
        "- Time away counts: leave it lit, go looting, and it catches up when you come back (as far as the fuel lasts).",
        "- Built for singleplayer; multiplayer is untested.",
    },
})
