-- Slow Cooker (Vitality Appliances): its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so
-- this only has to put the page in the table. Without the Vitality Project the
-- table sits unused and this mod works as before. Plain English only: the
-- Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "slowcooker", title = "Slow Cooker", mod = "VitalityAppliances", order = 40,
    body = {
        "Dump it in, switch it on, go loot. Dinner is ready when you get back. A countertop slow cooker with a removable crock and nine Kentucky home-cooking recipes from 1993.",
        "",
        "## The cooker",
        "- Low and slow: about four times slower than a stove, and it never burns anything.",
        "- Keeps warm: food in a cooker that is switched on does not spoil. Switch it off and the clock starts again.",
        "- Runs on grid or generator power, and on a generator it sips fuel: about a fifth of what a stove burns. Sits on a counter or table, moves like any furniture. It only takes its stoneware crock; crocks come with cookers found as loot.",
        "- Uncommon: kitchen cupboards, kitchenware aisles and appliance stores.",
        "",
        "## Two ways to cook",
        "- Crock stew: throw in anything that goes in a stew, up to twelve ingredients.",
        "- Recipes: right-click the cooker, choose Slow Cooker..., pick a dish and tick the ingredients, or press Auto-pick. The window lists what you carry and what is in reach: counters, fridges, the floor. Anything nearby is picked up on the way. A green dot means everything for that dish is in reach. Dishes unlock as Cooking rises (Soup Beans and Ham and Chili at 0, Kentucky Burgoo at 8), or read a recipe card for one dish, or the Kentucky Slow Cooker Favorites booklet for all nine. A named dish lifts your mood more than plain stew.",
        "",
        "## Serving",
        "Right-click the cooked crock: Serve a Bowl with an empty bowl in your inventory (the rest stays warm), Move to Cooking Pot to carry the whole meal, or Pour on Ground for a batch that has gone off.",
        "",
        "## With the Vitality Project",
        "Anything from the crock counts as home cooking: it moves your diet score half again as much, and each named dish counts towards variety on its own. Neither mod needs the other.",
        "",
        "## Need to know",
        "- Safe to add mid-save: containers you have not opened yet can roll cookers, cards and booklets.",
        "- Built for singleplayer; multiplayer is untested.",
    },
})
