"""Copy the mod between this repo and the game's mod folder.

    python deploy.py            repo  -> ~/Zomboid/mods/DanTraits   (mirror: extra files in the game folder are removed)
    python deploy.py --pull     ~/Zomboid/mods/DanTraits -> repo    (for edits made in place while testing)
    python deploy.py --dry-run  show what would change, touch nothing
    python deploy.py --workshop repo  -> ~/Zomboid/Workshop/DanTraits  (the folder the
                                in-game Workshop uploader reads: workshop.txt, preview.png,
                                Contents/mods/DanTraits; the dev tools are left out)
    python deploy.py --patch    repo  -> ~/Zomboid/mods/ItemRarityModdedItems  (the separate
                                Item Rarity UI patch; mirror, like the default)

The game only reads the mod folder, so edit here, deploy, then restart the
game (registries and item scripts are read at boot; Lua is reloaded too).
"""
import argparse
import filecmp
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_MOD = os.path.join(HERE, "DanTraits")
GAME_MOD = os.path.join(os.path.expanduser("~"), "Zomboid", "mods", "DanTraits")
REPO_PATCH = os.path.join(HERE, "ItemRarityModdedItems")
GAME_PATCH = os.path.join(os.path.expanduser("~"), "Zomboid", "mods", "ItemRarityModdedItems")
REPO_WORKSHOP = os.path.join(HERE, "workshop")
GAME_WORKSHOP = os.path.join(os.path.expanduser("~"), "Zomboid", "Workshop", "DanTraits")
IGNORE = {"__pycache__", ".DS_Store", "Thumbs.db", ".gitkeep"}
# Build 42 looks for a common/ folder beside 42/; git cannot hold an empty one
KEEP_DIRS = {"common"}


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


def sync(src, dst, dry, skip=()):
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
        if rel not in s:
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
    """Mirror the mod into Contents/mods/DanTraits and copy workshop.txt and
    preview.png beside it. The game writes the item's id= into workshop.txt
    after the first upload; that line is kept so later uploads update the
    same item instead of making a new one."""
    contents = os.path.join(GAME_WORKSHOP, "Contents", "mods", "DanTraits")
    copied, removed, same = sync(REPO_MOD, contents, dry, skip={"tools"})
    copied = [os.path.join("Contents", "mods", "DanTraits", c) for c in copied]
    removed = [os.path.join("Contents", "mods", "DanTraits", r) for r in removed]
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pull", action="store_true", help="copy from the game folder into the repo")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--workshop", action="store_true", help="build the Workshop upload folder")
    ap.add_argument("--patch", action="store_true", help="deploy the Item Rarity UI patch mod instead")
    a = ap.parse_args()
    if a.workshop and (a.patch or a.pull):
        ap.error("--workshop builds the main mod's upload folder; it cannot be combined with --patch or --pull")
    if a.workshop:
        copied, removed, same = build_workshop(a.dry_run)
        print("%s -> %s" % (HERE, GAME_WORKSHOP))
        for rel in copied:
            print("  %s %s" % ("would copy" if a.dry_run else "copied", rel))
        for rel in removed:
            print("  %s %s" % ("would remove" if a.dry_run else "removed", rel))
        print("%d changed, %d removed, %d unchanged" % (len(copied), len(removed), same))
        return
    repo, game = (REPO_PATCH, GAME_PATCH) if a.patch else (REPO_MOD, GAME_MOD)
    src, dst = (game, repo) if a.pull else (repo, game)
    if not os.path.isdir(src):
        raise SystemExit("missing: " + src)
    copied, removed, same = sync(src, dst, a.dry_run)
    verb = "would copy" if a.dry_run else "copied"
    print("%s -> %s" % (src, dst))
    for rel in copied:
        print("  %s %s" % (verb, rel))
    for rel in removed:
        print("  %s %s" % ("would remove" if a.dry_run else "removed", rel))
    print("%d changed, %d removed, %d unchanged" % (len(copied), len(removed), same))


if __name__ == "__main__":
    main()
