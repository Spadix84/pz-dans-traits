-- Base Unloader: its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so
-- this only has to put the page in the table. Without the Vitality Project the
-- table sits unused and this mod works as before. Plain English only: the
-- Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "baseunloader", title = "Base Unloader", mod = "BaseUnloader", order = 20,
    body = {
        "Come home from a loot run and have the character put it all away. You say once where each kind of thing lives; after that a run needs almost no dragging.",
        "",
        "## Starting a run",
        "Right-click the car for Unload trunk to base, any container or the items in a loot window for Unload to base, or your own items for Put away what I am carrying. A window opens: left, what is in the source grouped by type and where each type goes; right, every container in the base with its name, kind, room, floor, distance and how full it is.",
        "",
        "## Telling it where things go",
        "- Drag a type onto a container and that type lives there from now on, for this save. Dragging items straight out of the game's inventory windows onto a container row does the same. Hold Ctrl while dropping to send just those items, this run only.",
        "- Suggest fills the gaps from what the base already holds: the container with most of that type, the fridge or freezer for perishables, then the category, then a suitable kind of container.",
        "- Right-click a type to unassign it or its whole category; right-click a container to send everything unassigned there or clear it.",
        "- Hover a row and the container lights up in the world. Double-click a row to rename it; the loot window shows the name too.",
        "",
        "## The base",
        "Draw base zones with Base zones... on the world's right-click menu (the game's click-and-drag zone tool). Pieces with the same name are one zone, and a zone reaches a few floors up and down. With no zone nearby, the base is the building you are in or beside plus the ground round the source. Tag containers with categories from the loot window's icon menu, and mark some Off limits so nothing is ever put in them.",
        "",
        "## The run",
        "Press Start. The character walks to the source, loads a trip's worth into worn bags within the carry weight, walks the base putting things down nearest container first, and goes back for more until nothing with a home is left. Favourites and anything worn or held are never touched. A zombie, a key press or a reload only pauses it: Resume unloading is on the right-click menu.",
        "",
        "## Base inventory",
        "Base inventory... on the world menu lists everything stored in your base zones by type and container: search, sort, hover to light a container up, double-click to walk there. Right-click items of a type anywhere and the menu says how many are at base and where.",
        "",
        "## Need to know",
        "- Rules are per save. Zones out of range keep their last count, shown grey with its age.",
        "- Containers named with Smarter Storage show that name here.",
        "- Singleplayer for now.",
    },
})
