"""Check the mod's calls to the game's Java objects against the game itself.

Calling a method the object does not have fails inside pcall without
breaking anything, but Kahlua still dumps a stack trace to the log every
time, and the offline tests (which use stand-ins) cannot notice. This reads
the method tables out of the installed game's projectzomboid.jar (with
superclasses) and checks every call on a receiver whose type is known by
its name:

    part:foo()  bodyPart:foo()  is(part, "foo")  num(part, "foo")  partIs(part, "foo")   BodyPart
    getBodyDamage():foo()  bd:foo()                                                        BodyDamage
    player:foo()  character:foo()  playerObj:foo()  patient:foo()                          IsoPlayer
    getStats():foo()  stats:foo()                                                          Stats
    weapon:foo()                                                                           HandWeapon
    BodyPartType.foo(                                                                      BodyPartType (statics)

Receivers the table does not know are not checked. Without the game
installed (or with PZ_JAR pointing nowhere) it says so and passes.

    python tests/check_api.py
"""
import glob
import os
import re
import struct
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, "..", "DanTraits", "42", "media", "lua")
JAR = os.environ.get("PZ_JAR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")

CLASSES = {
    "BodyPart": "zombie/characters/BodyDamage/BodyPart",
    "BodyDamage": "zombie/characters/BodyDamage/BodyDamage",
    "IsoPlayer": "zombie/characters/IsoPlayer",
    "Stats": "zombie/characters/Stats",
    "HandWeapon": "zombie/inventory/types/HandWeapon",
    "BodyPartType": "zombie/characters/BodyDamage/BodyPartType",
}
PATTERNS = [
    (r"\b(?:part|bodyPart):(\w+)\(", "BodyPart"),
    (r"\b(?:is|num|partIs)\((?:part|bodyPart), \"(\w+)\"\)", "BodyPart"),
    (r"getBodyDamage\(\):(\w+)\(", "BodyDamage"),
    (r"\bbd:(\w+)\(", "BodyDamage"),
    (r"\b(?:player|character|playerObj|patient):(\w+)\(", "IsoPlayer"),
    (r"getStats\(\):(\w+)\(", "Stats"),
    (r"\bstats:(\w+)\(", "Stats"),
    (r"\bweapon:(\w+)\(", "HandWeapon"),
    (r"\bBodyPartType\.(\w+)\(", "BodyPartType"),
]


def class_methods(z, path):
    """Method names of one class file and the class it extends."""
    b = z.read(path + ".class")
    p = 8
    n = struct.unpack(">H", b[p:p + 2])[0]
    p += 2
    cp = [None] * n
    i = 1
    while i < n:
        t = b[p]
        p += 1
        if t == 1:
            size = struct.unpack(">H", b[p:p + 2])[0]
            cp[i] = b[p + 2:p + 2 + size].decode("utf-8", "replace")
            p += 2 + size
        elif t in (3, 4):
            p += 4
        elif t in (5, 6):
            p += 8
            i += 1
        elif t in (7, 8, 16, 19, 20):
            cp[i] = ("ref", struct.unpack(">H", b[p:p + 2])[0])
            p += 2
        elif t in (9, 10, 11, 12, 17, 18):
            p += 4
        elif t == 15:
            p += 3
        else:
            raise ValueError("constant tag %d in %s" % (t, path))
        i += 1
    _, _, sup = struct.unpack(">HHH", b[p:p + 6])
    p += 6
    parent = cp[cp[sup][1]] if sup else None
    count = struct.unpack(">H", b[p:p + 2])[0]
    p += 2 + 2 * count

    def members(p):
        c = struct.unpack(">H", b[p:p + 2])[0]
        p += 2
        names = []
        for _ in range(c):
            _, name, _, attrs = struct.unpack(">HHHH", b[p:p + 8])
            p += 8
            names.append(cp[name])
            for _ in range(attrs):
                p += 6 + struct.unpack(">I", b[p + 2:p + 6])[0]
        return p, names

    p, _ = members(p)
    _, methods = members(p)
    return set(methods), parent


def all_methods(z, path):
    out = set()
    while path:
        try:
            methods, path = class_methods(z, path)
        except KeyError:
            break
        out |= methods
    return out


def main():
    if not os.path.exists(JAR):
        print("check_api: game not found at %s; skipped" % JAR)
        return 0
    z = zipfile.ZipFile(JAR)
    tables = {k: all_methods(z, v) for k, v in CLASSES.items()}
    problems = []
    for path in sorted(glob.glob(os.path.join(LUA, "**", "*.lua"), recursive=True)):
        rel = os.path.relpath(path, os.path.join(HERE, ".."))
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                code = line.split("--", 1)[0]
                for pattern, cls in PATTERNS:
                    for name in re.findall(pattern, code):
                        if name not in tables[cls]:
                            problems.append("%s:%d: %s has no %s" % (rel, lineno, cls, name))
    for p in problems:
        print(p)
    print("check_api: %d problem(s)" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
