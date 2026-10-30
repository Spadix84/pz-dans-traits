"""Copy a mod between this repo and the game's mod folder.

    python deploy.py                 repo/DanTraits -> ~/Zomboid/mods/DanTraits  (mirror: extra files in
                                     the game folder are removed) and, while ~/Zomboid/Workshop/DanTraits
                                     exists, into its Contents too: the game loads the Workshop copy in
                                     preference to the mods one, so the two are kept identical and it
                                     does not matter which it picks
    python deploy.py --mod NAME      the same for another of the mods in MODS below (repo/NAME ->
                                     ~/Zomboid/mods/NAME; mirror). The names, and the old flag each
                                     one still answers to:
                                         DanTraits                    (the default)
                                         DansVanillaFixes  --patch    Dan's Vanilla Fixes
                                         BaseUnloader      --unloader
                                         MapLegend         --legend
                                         VitalityCartridges --cartridges  the SpiffBoy cartridges
                                         VitalityChallenges --challenges  the challenge scenarios
    python deploy.py --pull          ~/Zomboid/mods/NAME -> repo  (for edits made in place while
                                     testing; adds and updates only, nothing in the repo is removed).
                                     Goes with --mod or any of the old flags.
    python deploy.py --dry-run       show what would change, touch nothing
    python deploy.py --workshop      repo -> ~/Zomboid/Workshop/DanTraits  (the folder the in-game
                                     Workshop uploader reads: workshop.txt, preview.png,
                                     Contents/mods/DanTraits; what the DanTraits row's `skip` names,
                                     tools/, is left out)
    One mod (or --workshop) a run.

The game only reads the mod folder, so edit here, deploy, then restart the
game (registries and item scripts are read at boot; Lua is reloaded too).
"""
import argparse
import filecmp
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ZOMBOID = os.path.join(os.path.expanduser("~"), "Zomboid")
# name: the folder in the repo and under ~/Zomboid/mods (the mod id); flag: the old
# option that still selects it; skip: folders left out of the Workshop build
MODS = [
    {"name": "DanTraits", "flag": None, "help": "the main mod (the default)", "skip": {"tools"}},
    {"name": "DansVanillaFixes", "flag": "--patch", "help": "the Dan's Vanilla Fixes mod"},
    {"name": "BaseUnloader", "flag": "--unloader", "help": "the Base Unloader mod"},
    {"name": "MapLegend", "flag": "--legend", "help": "the Map Legend mod"},
    {"name": "VitalityCartridges", "flag": "--cartridges", "help": "the Vitality Cartridges mod"},
    {"name": "VitalityChallenges", "flag": "--challenges", "help": "the Vitality Challenges mod"},
]
MAIN = MODS[0]["name"]   # the mod the Workshop folder holds
REPO_WORKSHOP = os.path.join(HERE, "workshop")
GAME_WORKSHOP = os.path.join(ZOMBOID, "Workshop", MAIN)
IGNORE = {"__pycache__", ".DS_Store", "Thumbs.db", ".gitkeep"}
# Build 42 looks for a common/ folder beside 42/; git cannot hold an empty one
KEEP_DIRS = {"common"}
# the tooltip strip both mods ship at the same path; the game loads one copy,
# so the two must not drift apart
SHARED = [os.path.join("42", "media", "lua", "client", "DanShared_Tooltip.lua")]
SHARED_BETWEEN = ("DanTraits", "DansVanillaFixes")


def mod(name):
    """The MODS row for a name, matched without regard to case."""
    for m in MODS:
        if m["name"].lower() == name.lower():
            return m
    raise SystemExit("no mod called %s; one of %s" % (name, ", ".join(m["name"] for m in MODS)))


def repo_dir(m):
    return os.path.join(HERE, m["name"])


def game_dir(m):
    return os.path.join(ZOMBOID, "mods", m["name"])


def walk(root, skip=()):
    out = {}
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE and os.path.relpath(os.path.join(base, d), root) not in skip]
        for f in files:
            if f in IGNORE or f.endswith(".pyc"):
                continue
            full = os.path.join(base, f)
            out[os.path.relpath(full, root)] = full
    return out


def sync(src, dst, dry, skip=(), delete=True):
    s, d = walk(src, skip), walk(dst)
    copied, removed, same = [], [], 0
    for rel, path in sorted(s.items()):
        target = os.path.join(dst, rel)
        if rel in d and filecmp.cmp(path, target, shallow=False):
            same += 1
            continue
        copied.append(rel)
        if not dry:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.copy2(path, target)
    for rel, path in sorted(d.items()):
        if delete and rel not in s:
            removed.append(rel)
            if not dry:
                os.remove(path)
    if not dry:
        for base, dirs, files in os.walk(dst, topdown=False):
            if not dirs and not files and base != dst and os.path.relpath(base, dst) not in KEEP_DIRS:
                os.rmdir(base)
        for keep in KEEP_DIRS:
            os.makedirs(os.path.join(dst, keep), exist_ok=True)
    return copied, removed, same


def build_workshop(dry):
    """Mirror the main mod into Contents/mods/DanTraits (without what its row's `skip`
    names) and copy workshop.txt and preview.png beside it. The game writes the item's
    id= into workshop.txt after the first upload; that line is kept so later uploads
    update the same item instead of making a new one."""
    main = mod(MAIN)
    contents = os.path.join(GAME_WORKSHOP, "Contents", "mods", MAIN)
    copied, removed, same = sync(repo_dir(main), contents, dry, skip=main.get("skip", ()))
    copied = [os.path.join("Contents", "mods", MAIN, c) for c in copied]
    removed = [os.path.join("Contents", "mods", MAIN, r) for r in removed]
    preview = os.path.join(REPO_WORKSHOP, "preview.png")
    target = os.path.join(GAME_WORKSHOP, "preview.png")
    if os.path.isfile(target) and filecmp.cmp(preview, target, shallow=False):
        same += 1
    else:
        copied.append("preview.png")
        if not dry:
            shutil.copy2(preview, target)
    with open(os.path.join(REPO_WORKSHOP, "workshop.txt"), encoding="utf-8") as f:
        lines = f.read().splitlines()
    target = os.path.join(GAME_WORKSHOP, "workshop.txt")
    if not any(l.startswith("id=") for l in lines) and os.path.isfile(target):
        with open(target, encoding="utf-8") as f:
            ids = [l for l in f.read().splitlines() if l.startswith("id=") and l[3:].strip()]
        if ids:
            lines.insert(1, ids[0])
    text = "\n".join(lines) + "\n"
    old = None
    if os.path.isfile(target):
        with open(target, encoding="utf-8") as f:
            old = f.read()
    if old == text:
        same += 1
    else:
        copied.append("workshop.txt")
        if not dry:
            with open(target, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
    return copied, removed, same


def show(src, dst, copied, removed, same, dry, note=""):
    print("%s -> %s%s" % (src, dst, note))
    for rel in copied:
        print("  %s %s" % ("would copy" if dry else "copied", rel))
    for rel in removed:
        print("  %s %s" % ("would remove" if dry else "removed", rel))
    print("%d changed, %d removed, %d unchanged" % (len(copied), len(removed), same))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pull", action="store_true", help="copy from the game folder into the repo")
    ap.add_argument("--dry-run", action="store_true")
    mode = ap.add_mutually_exclusive_group()   # one mod (or the Workshop folder) a run
    mode.add_argument("--mod", dest="mod", metavar="NAME", default=MAIN,
                      help="the mod to deploy: %s (default %s)" % (", ".join(m["name"] for m in MODS), MAIN))
    for m in MODS:
        if m["flag"]:   # the old flags, kept as aliases of --mod NAME
            mode.add_argument(m["flag"], dest="mod", action="store_const", const=m["name"],
                              help="deploy %s (the same as --mod %s)" % (m["help"], m["name"]))
    mode.add_argument("--workshop", action="store_true", help="build the Workshop upload folder")
    a = ap.parse_args()
    if not a.pull:
        first, second = (repo_dir(mod(n)) for n in SHARED_BETWEEN)
        for rel in SHARED:
            if not filecmp.cmp(os.path.join(first, rel), os.path.join(second, rel), shallow=False):
                raise SystemExit("%s differs between %s and %s: make them the same first" % ((rel,) + SHARED_BETWEEN))
    if a.workshop and a.pull:
        ap.error("--workshop builds the main mod's upload folder; it cannot be combined with --pull")
    if a.workshop:
        copied, removed, same = build_workshop(a.dry_run)
        show(HERE, GAME_WORKSHOP, copied, removed, same, a.dry_run)
        return
    m = mod(a.mod)
    repo, game = repo_dir(m), game_dir(m)
    src, dst = (game, repo) if a.pull else (repo, game)
    if not os.path.isdir(src):
        raise SystemExit("missing: " + src)
    copied, removed, same = sync(src, dst, a.dry_run, delete=not a.pull)   # a pull adds and updates, never removes
    show(src, dst, copied, removed, same, a.dry_run)
    # The game loads ~/Zomboid/Workshop/DanTraits/Contents/mods/DanTraits in preference to
    # ~/Zomboid/mods/DanTraits while the upload folder exists, so a deploy that left it
    # stale looked like it did nothing. Keep the two identical.
    if not a.pull and m["name"] == MAIN and os.path.isdir(GAME_WORKSHOP):
        copied, removed, same = build_workshop(a.dry_run)
        show(HERE, GAME_WORKSHOP, copied, removed, same, a.dry_run, " (the game loads this copy while it exists)")


if __name__ == "__main__":
    main()
