"""Copy the mod between this repo and the game's mod folder.

    python deploy.py            repo  -> ~/Zomboid/mods/DanTraits   (mirror: extra files in the game folder are removed)
    python deploy.py --pull     ~/Zomboid/mods/DanTraits -> repo    (for edits made in place while testing)
    python deploy.py --dry-run  show what would change, touch nothing

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
IGNORE = {"__pycache__", ".DS_Store", "Thumbs.db"}


def walk(root):
    out = {}
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE]
        for f in files:
            if f in IGNORE or f.endswith(".pyc"):
                continue
            full = os.path.join(base, f)
            out[os.path.relpath(full, root)] = full
    return out


def sync(src, dst, dry):
    s, d = walk(src), walk(dst)
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
            if not dirs and not files and base != dst:
                os.rmdir(base)
    return copied, removed, same


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pull", action="store_true", help="copy from the game folder into the repo")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    src, dst = (GAME_MOD, REPO_MOD) if a.pull else (REPO_MOD, GAME_MOD)
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
