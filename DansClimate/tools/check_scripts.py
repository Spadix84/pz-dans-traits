"""Check Dan's Climate Control's scripts against each other: the things a typo breaks
silently until somebody tries it in game.

    python DansClimate/tools/check_scripts.py

  * the three central build recipes (scripts/DansClimate_entities.txt) have to be
    learned, need Welding, Maintenance and Electrical, build the tiles the Lua and the
    Java side look for, and use up the heavy unit item;
  * the two installer's manuals are long books (not magazines, not skill books) and
    between them teach every recipe, each by a name that exists;
  * every item the recipes and the loot table name exists (ours in our script, the
    game's in the game's scripts when the game is installed);
  * every translation key the Lua asks for by a literal, and every state the central
    units can be in, is in the EN files;
  * every sandbox option the Lua reads is declared;
  * the three comfort moodles have their texts and their icons.

`build.py --test` runs this too. Exit code 1 on any failure.
"""
import glob
import json
import os
import re
import sys

MOD = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(MOD, "42", "media")
GAME = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"

RECIPES = {
    # recipe: (skills, first tile, last tile, the unit item it uses up)
    "DansClimate_Furnace": ("MetalWelding:5;Maintenance:5;Electricity:5", 0, 3, "Base.HVACFurnace"),
    "DansClimate_CentralAC": ("MetalWelding:6;Maintenance:6;Electricity:7", 8, 11, "Base.HVACCondenser"),
    "DansClimate_Vent": ("MetalWelding:4;Maintenance:3;Electricity:2", 16, 17, None),
}
BOOKS = {
    "BookHVACHeating": ["DansClimate_Furnace", "DansClimate_Vent"],
    "BookHVACCooling": ["DansClimate_CentralAC", "DansClimate_Vent"],
}
TILES = "appliances_hvac_01_"
UNIT_STATES = ["NoBuilding", "Off", "NoPower", "NoVents", "Idle", "Running", "Thin"]
VENT_STATES = ["NoRoom", "None", "Heat", "Cool", "Both"]

failures = []
checks = 0


def check(ok, what):
    global checks
    checks += 1
    if not ok:
        failures.append(what)


def read(*parts):
    return open(os.path.join(MEDIA, *parts), encoding="utf-8").read()


def block(text, kind, name):
    """The body of `kind name { ... }`, braces matched."""
    m = re.search(r"\b%s\s+%s\s*\{" % (kind, re.escape(name)), text)
    if not m:
        return None
    depth, i = 1, m.end()
    while i < len(text) and depth:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[m.end():i - 1]


def translations():
    keys = {}
    for path in glob.glob(os.path.join(MEDIA, "lua", "shared", "Translate", "EN", "*.json")):
        keys.update(json.load(open(path, encoding="utf-8")))
    return keys


def game_items():
    """Item names the installed game's scripts define, or None without the game."""
    folder = os.path.join(GAME, "media", "scripts")
    if not os.path.isdir(folder):
        return None
    names = set()
    for path in glob.glob(os.path.join(folder, "**", "*.txt"), recursive=True):
        names.update(re.findall(r"^\s*item\s+(\w+)\s*$", open(path, encoding="utf-8", errors="replace").read(), re.M))
    return names


def main():
    entities = read("scripts", "DansClimate_entities.txt")
    items = read("scripts", "DansClimate_items.txt")
    ours = set(re.findall(r"^\s*item\s+(\w+)\s*$", items, re.M))
    vanilla = game_items()
    text = translations()
    lua = {os.path.basename(p): open(p, encoding="utf-8").read()
           for p in glob.glob(os.path.join(MEDIA, "lua", "**", "*.lua"), recursive=True)}
    java = open(os.path.join(MOD, "java", "src", "com", "spadix84", "dansclimate", "Units.java"), encoding="utf-8").read()

    def item_exists(full):
        name = full.split(".", 1)[1] if full.startswith("Base.") else full
        if name in ours:
            return True
        return vanilla is None or name in vanilla

    # -- the build recipes -------------------------------------------------------------
    central = lua["DansClimate_Central.lua"]
    tiledefs = read("DansClimate_tiledefinitions.tiles.txt").replace("\r\n", "\n")
    seen_sprites = set()
    for recipe, (skills, first, last, unit) in RECIPES.items():
        e = block(entities, "entity", recipe)
        check(e is not None, "entity %s is in DansClimate_entities.txt" % recipe)
        if e is None:
            continue
        check("NeedToBeLearn = true," in e, "%s has to be learned" % recipe)
        check("SkillRequired = %s," % skills in e, "%s needs %s" % (recipe, skills))
        named = re.findall(r"row\s*=\s*(\w+)\s*,", e)
        rows = set(named)
        want = {"%s%d" % (TILES, n) for n in range(first, last + 1)}
        check(rows == want, "%s builds tiles %d-%d and no others (has %s)" % (recipe, first, last, sorted(rows)))
        # The game refuses an entity that names a sprite twice, or a sprite another
        # entity has, and then the world does not load (SpriteConfigScript.checkScripts,
        # SpriteConfigManager.parseEntityScript). So: one face for each tile.
        check(len(named) == len(rows), "%s names no sprite twice (has %s)" % (recipe, named))
        check(not (rows & seen_sprites), "%s shares no sprite with another entity" % recipe)
        seen_sprites.update(rows)
        faces = re.findall(r"\bface\s+(\w+)", e)
        check(len(faces) == len(set(faces)) == len(rows) and set(faces) <= set("SENW"),
              "%s has one face for each tile (has %s)" % (recipe, faces))
        for sprite in sorted(rows):
            check("// %s\n" % sprite in tiledefs, "%s is in the tile definitions" % sprite)
        if unit:
            check("item 1 [%s]," % unit in e, "%s uses up %s" % (recipe, unit))
            body = block(items, "item", unit.split(".")[1])
            check(body is not None and "Weight = 40.0," in body, "%s is a heavy item of ours" % unit)
            check('item = "%s"' % unit in central, "DansClimate_Central.lua gives %s back" % unit)
        for full in re.findall(r"\[(Base\.\w+)\]", e):
            check(item_exists(full), "%s names an item that exists: %s" % (recipe, full))
        style = re.search(r"entityStyle\s*=\s*(\w+)\s*,", e)
        check(style is not None and block(entities, "entity", style.group(1)) is not None, "%s has its style" % recipe)
        check('"%s"' % recipe in central, "DansClimate_Central.lua knows the recipe %s" % recipe)
        check(recipe in text, "%s is named in Recipes.json" % recipe)
        tip = re.search(r"Tooltip\s*=\s*(\w+)\s*,", e)
        check(tip is not None and tip.group(1) in text, "%s has its build-menu tooltip" % recipe)
    check('HVAC_TILES = "%s"' % TILES in java, "Units.java looks for the same tiles")
    check('Central.TILESET = "%s"' % TILES.rstrip("_") in central, "and so does DansClimate_Central.lua")

    # -- the manuals ---------------------------------------------------------------------
    taught = set()
    for book, recipes in BOOKS.items():
        body = block(items, "item", book)
        check(body is not None, "item %s is in DansClimate_items.txt" % book)
        if body is None:
            continue
        check("ItemType = base:literature," in body, "%s is literature" % book)
        pages = re.search(r"NumberOfPages\s*=\s*(\d+)\s*,", body)
        check(pages is not None and int(pages.group(1)) >= 300, "%s is a long read" % book)
        check("magazine" not in body.lower() and "SkillTrained" not in body, "%s is neither a magazine nor a skill book" % book)
        learned = re.search(r"LearnedRecipes\s*=\s*([\w;]+)\s*,", body)
        got = learned.group(1).split(";") if learned else []
        check(got == recipes, "%s teaches %s (has %s)" % (book, recipes, got))
        for r in got:
            check(r in RECIPES and block(entities, "entity", r) is not None, "%s teaches a recipe that exists: %s" % (book, r))
        taught.update(got)
        check("Base." + book in text, "%s has a name" % book)
    check(taught == set(RECIPES), "between them the manuals teach every recipe")

    # -- items the loot table names ------------------------------------------------------
    loot = lua["DansClimate_Distributions.lua"]
    for full in re.findall(r'item\s*=\s*"(Base\.\w+)"', loot):
        check(item_exists(full) and (full in text or full.split(".")[1] not in ours), "loot item %s exists and has a name" % full)
    declared = set(re.findall(r"option\s+DansClimate\.(\w+)", read("sandbox-options.txt")))
    for option in set(re.findall(r'option\s*=\s*"(\w+)"', loot)) | set(re.findall(r'sandbox\("(\w+)"', "\n".join(lua.values()))):
        check(option in declared, "sandbox option %s is declared" % option)
        check("Sandbox_DansClimate%s" % option in text and "Sandbox_DansClimate%s_tooltip" % option in text,
              "sandbox option %s has its name and tooltip" % option)

    # -- translation keys ----------------------------------------------------------------
    for name, source in sorted(lua.items()):
        # a literal followed by .. is a prefix completed at run time: the states below
        for key in set(re.findall(r'getText\("([A-Za-z_]+_DansClimate_\w+)"(?!\s*\.\.)', source)):
            check(key in text, "%s asks for %s" % (name, key))
    for unit in ("Furnace", "CentralAC"):
        for state in UNIT_STATES:
            check("Tooltip_DansClimate_%s_%s" % (unit, state) in text, "tooltip for %s %s" % (unit, state))
        for key in ("ContextMenu_DansClimate_%s", "ContextMenu_DansClimate_%sRoom", "ContextMenu_DansClimate_Remove%s"):
            check(key % unit in text, "menu text %s" % (key % unit))
    for state in VENT_STATES:
        check("Tooltip_DansClimate_Vent_%s" % state in text, "tooltip for a vent %s" % state)
    for key in ("ContextMenu_DansClimate_Vent", "ContextMenu_DansClimate_RemoveVent"):
        check(key in text, "menu text %s" % key)
    for kinds in ("Heat", "Cool", "Both"):
        check("Tooltip_DansClimate_ThermostatCentral_%s" % kinds in text, "thermostat tooltip %s" % kinds)

    # -- the comfort moodles: texts for the levels they use, and their icons --------------
    client = lua["DansClimate_ComfortClient.lua"]
    for name, side, levels in (("ClimateChilly", "Bad", 2), ("ClimateStuffy", "Bad", 2), ("ClimateCosy", "Good", 2)):
        check('"%s"' % name in client, "DansClimate_ComfortClient.lua creates the moodle %s" % name)
        for level in range(1, levels + 1):
            for key in ("Moodles_%s_%s_lvl%d", "Moodles_%s_%s_desc_lvl%d"):
                check(text.get(key % (name, side, level)), "moodle text %s" % (key % (name, side, level)))
        for folder in ("ui", os.path.join("ui", "32")):
            check(os.path.exists(os.path.join(MEDIA, folder, name + ".png")), "moodle icon %s/%s.png" % (folder, name))

    if failures:
        print("check_scripts: %d of %d checks FAILED" % (len(failures), checks))
        for f in failures:
            print("  not true: " + f)
        return 1
    print("check_scripts: %d checks passed%s" % (checks, "" if vanilla is not None else " (game not found: vanilla item names not checked)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
