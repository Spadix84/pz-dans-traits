"""Build the reading data table for Dan's Vanilla Fixes from the installed game.

    python DansVanillaFixes/tools/gen_reading_data.py            write shared/DansVanillaFixes_ReadingData.lua
    python DansVanillaFixes/tools/gen_reading_data.py --print    print it instead
    python DansVanillaFixes/tools/gen_reading_data.py --stats    how many titles per family and medium

The game names an entertainment book, comic or magazine when it is created
(ItemCodeOnCreate, Java) from three registries whose static initialisers hold
every title: zombie/scripting/objects/Book (title key, cover type, one or more
BookSubjects), ComicBook (title key, issues) and Magazine (title key, one or
more MagazineSubjects). There is no JDK here, so this walks the bytecode of
each class's <clinit> straight out of projectzomboid.jar and pairs each
ldc'd title key with the enum constants pushed before its register call. The
item then carries the key in modData.literatureTitle, prefixed IGUI_BookTitle_,
IGUI_ComicTitle_ or IGUI_MagazineTitle_ (magazines add _month_year, comics an
issue number).

For every title the table gives a genre family (from the subject, see
FAMILY_OF; comics have no subject and are tagged by the words in their title,
COMIC_WORDS, which DansVanillaFixes_ReadingBooks.lua can override), a page
count and a hidden quality 1-5, both from a stable hash of the key so no two
titles are the same and a regeneration after a game update keeps the numbers.
The output is committed; the game never runs this.
"""
import os
import struct
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "lua", "shared", "DansVanillaFixes_ReadingData.lua")
JAR = os.environ.get("PZ_JAR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")
GAME_VERSION = "42.21"

# BookSubject -> family (the families tastes pick from; see plans/reading.md)
FAMILY_OF = {
    "HORROR": "horror", "OCCULT": "horror",
    "THRILLER": "thrillers", "CRIME_FICTION": "thrillers", "TRUE_CRIME": "thrillers", "POLICING": "thrillers",
    "ROMANCE": "romance", "SEXY": "romance", "RELATIONSHIP": "romance",
    "SCIFI": "scifi", "FANTASY": "scifi",
    "WESTERN": "westerns",
    "GENERAL_FICTION": "popular", "TEENS": "popular", "QUIGLEY": "popular", "HASS": "popular",
    "CLASSIC": "classics", "CLASSIC_FICTION": "classics", "CLASSIC_NONFICTION": "classics", "PLAY": "classics",
    "HISTORY": "history", "MILITARY_HISTORY": "history", "MILITARY": "history",
    "BIOGRAPHY": "truestories", "ADVENTURE_NON_FICTION": "truestories", "SAD_NON_FICTION": "truestories",
    "SPORTS": "sports", "GOLF": "sports", "BASEBALL": "sports",
    "BIBLE": "faith", "RELIGION": "faith",
    "NEW_AGE": "fringe", "QUACKERY": "fringe", "CONSPIRACY": "fringe",
    "SELF_HELP": "selfhelp", "DIET": "selfhelp", "FASHION": "selfhelp",
    "SCIENCE": "science", "NATURE": "science", "MEDICAL": "science", "COMPUTER": "science", "FARMING": "science",
    "ART": "arts", "CINEMA": "arts", "MUSIC": "arts", "PHOTO_SPECIAL": "arts",
    "BUSINESS": "serious", "LEGAL": "serious", "POLITICS": "serious", "PHILOSOPHY": "serious",
    "GENERAL_REFERENCE": "serious", "TRAVEL": "serious", "SCHOOL_TEXTBOOK": "serious",
    "CHILDS": "kids", "CHILDS_PICTURE_SPECIAL": "kids",
}
MAGAZINE_FAMILY_OF = {
    "ART": "arts", "BUSINESS": "serious", "CARS": "selfhelp", "CHILDS": "kids", "CINEMA": "arts",
    "CRIME": "thrillers", "FASHION": "selfhelp", "FIREARM": "history", "GAMING": "scifi", "GOLF": "sports",
    "HEALTH": "selfhelp", "HOBBY": "selfhelp", "HORROR": "horror", "HUMOR": "humor", "MILITARY": "history",
    "MUSIC": "arts", "OUTDOORS": "science", "POLICE": "thrillers", "POPULAR": "popular", "RICH": "selfhelp",
    "SCIENCE": "science", "SPORTS": "sports", "TECH": "science", "TEENS": "popular",
}
# comics by the words in the title key, first match wins; the rest are
# superhero and monster fare, which reads as Sci-Fi & Fantasy
COMIC_WORDS = [
    ("horror", ["Crypt", "Corpse", "Vampire", "Dracula", "Werewolf", "Franken", "Haunt", "Ghost", "Gore", "Shrieking",
                "Mortuary", "Cthulhu", "Shoggoth", "Icky", "PUTRID", "Curse", "Death", "Cemetery", "Needleface", "Zpeople",
                "Zoinks", "GrossOut", "Horseshoecrab", "Blood"]),
    ("westerns", ["Lasso", "Cactus", "Horse", "ShootingIrons", "CurseRyder", "Sequoia", "Redwood"]),
    ("thrillers", ["Detective", "Crime", "Police", "Spy", "Truthseeker", "Mercenary", "Omega", "Stockbroker", "Hyena"]),
    ("humor", ["Hooey", "Chuckle", "Idiot", "Toilet", "Imbroglio", "Flummoxer", "Farrago", "UMLAUT", "Thompsons",
               "Churl", "Shortchanger", "Toddler", "Uncouth", "Bungles"]),
    ("history", ["Commando", "Soldier", "Berets", "Raid", "Gladiator", "Ninja", "History", "Peril", "TrueNinja"]),
    ("kids", ["Woof", "Child", "Santa", "Kids", "Sidekick", "Dog", "Teen", "Jr", "MagicHoodie", "Millipede", "Bricklayer",
              "Foreman", "Trucker", "Tanktaur"]),
    ("romance", ["Bride", "Damsel", "Wedding", "Kiss", "Nurse", "Dames", "Risque", "Hisayo", "Kazusa", "Rikoto",
                 "Shonen", "Shikoku"]),
    ("scifi", []),
]

PAGES = {   # (lo, hi) by kind
    "S": (180, 380), "H": (250, 500), "B": (220, 440), "serious": (300, 650),
    "kids": (24, 64), "comic": (24, 48), "magazine": (60, 140),
}
QUALITY_BANDS = [(10, 1), (40, 2), (75, 3), (93, 4), (100, 5)]   # cumulative percent -> stars


def fnv(s):
    h = 0x811C9DC5
    for b in s.encode("utf8"):
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return h


def pages_for(key, lo, hi):
    return lo + fnv(key) % (hi - lo + 1)


def quality_for(key):
    roll = (fnv("q:" + key) >> 4) % 100
    for top, stars in QUALITY_BANDS:
        if roll < top:
            return stars
    return 3


# --- class file reading --------------------------------------------------------------

def u2(d, i):
    return struct.unpack(">H", d[i:i + 2])[0]


def u4(d, i):
    return struct.unpack(">I", d[i:i + 4])[0]


def parse_class(data):
    """The constant pool, every method's Code bytes by name, and resolvers."""
    n = u2(data, 8)
    i, k, cp = 10, 1, [None] * n
    while k < n:
        t = data[i]
        if t == 1:
            l = u2(data, i + 1)
            cp[k] = ("utf8", data[i + 3:i + 3 + l].decode("utf8", "replace"))
            i += 3 + l
        elif t in (7, 8, 16, 19, 20):
            cp[k] = (t, u2(data, i + 1))
            i += 3
        elif t in (9, 10, 11, 12):
            cp[k] = (t, u2(data, i + 1), u2(data, i + 3))
            i += 5
        elif t in (3, 4, 17, 18):
            cp[k] = (t,)
            i += 5
        elif t in (5, 6):
            cp[k] = (t,)
            i += 9
            k += 1
        elif t == 15:
            cp[k] = (t,)
            i += 4
        else:
            raise ValueError("constant tag %d" % t)
        k += 1

    def utf(ix):
        return cp[ix][1]

    def ref(ix):
        _, c, nt = cp[ix]
        return utf(cp[c][1]), utf(cp[nt][1]), utf(cp[nt][2])

    i += 6
    i += 2 + 2 * u2(data, i)

    def skip_attrs(i):
        count = u2(data, i)
        i += 2
        for _ in range(count):
            i += 6 + u4(data, i + 2)
        return i

    fields = u2(data, i)
    i += 2
    for _ in range(fields):
        i = skip_attrs(i + 6)
    methods, count = {}, u2(data, i)
    i += 2
    for _ in range(count):
        name = utf(u2(data, i + 2))
        attrs, j = u2(data, i + 6), i + 8
        for _ in range(attrs):
            if utf(u2(data, j)) == "Code":
                length = u4(data, j + 6 + 4)
                methods[name] = data[j + 14:j + 14 + length]
            j += 6 + u4(data, j + 2)
        i = j
    return cp, methods, ref, utf


# opcode -> instruction length for the ones that are not one byte
LENGTHS = {0x10: 2, 0xbc: 2, 0x15: 2, 0x16: 2, 0x17: 2, 0x18: 2, 0x19: 2, 0x36: 2, 0x37: 2, 0x38: 2, 0x39: 2,
           0x3a: 2, 0x12: 2, 0xa9: 2, 0x11: 3, 0x13: 3, 0x14: 3, 0xa7: 3, 0xbd: 3, 0xc0: 3, 0xbb: 3, 0xc6: 3,
           0xc7: 3, 0xc1: 3, 0xb2: 3, 0xb3: 3, 0xb4: 3, 0xb5: 3, 0xb6: 3, 0xb7: 3, 0xb8: 3, 0x84: 3, 0xc5: 4,
           0xb9: 5, 0xba: 5, 0xc8: 5, 0xc9: 5}
for _op in range(0x99, 0xa9):
    LENGTHS[_op] = 3


def registrations(data):
    """Walk <clinit>: for every putstatic, the strings and enum constants pushed since the last one."""
    cp, methods, ref, utf = parse_class(data)
    code, i, pushed, out = methods["<clinit>"], 0, [], []
    while i < len(code):
        op = code[i]
        if op in (0x12, 0x13):
            c = cp[code[i + 1] if op == 0x12 else u2(code, i + 1)]
            if c[0] == 8:
                pushed.append(("S", utf(c[1])))
        elif op == 0xb2:
            cls, name, _ = ref(u2(code, i + 1))
            pushed.append(("E", cls.rsplit("/", 1)[-1], name))
        elif op == 0xb3:
            if pushed:
                out.append(pushed)
            pushed = []
        elif op == 0xc4:
            i += 6 if code[i + 1] == 0x84 else 4
            continue
        elif op in (0xaa, 0xab):
            raise ValueError("switch in <clinit>")
        i += LENGTHS.get(op, 1)
    return out


def read_registry(jar, path, enum):
    """[(key, cover or None, [subjects])] for a registry class."""
    rows = []
    for pushed in registrations(jar.read(path)):
        keys = [p[1] for p in pushed if p[0] == "S"]
        if not keys:
            continue
        cover = [p[2] for p in pushed if p[0] == "E" and p[1] == "CoverType"]
        subjects = [p[2] for p in pushed if p[0] == "E" and p[1] == enum]
        rows.append((keys[0], cover[0] if cover else None, subjects))
    return rows


# --- the table ----------------------------------------------------------------------

def comic_family(key):
    for family, words in COMIC_WORDS:
        for w in words:
            if w in key:
                return family
    return "scifi"


def build(jar):
    books, comics, magazines = [], [], []
    for key, cover, subjects in read_registry(jar, "zombie/scripting/objects/Book.class", "BookSubject"):
        if not subjects:
            continue
        family = FAMILY_OF[subjects[0]]
        cover = {"SOFTCOVER": "S", "HARDCOVER": "H", "BOTH": "B"}[cover]
        if family in ("serious", "science"):
            lo, hi = PAGES["serious"]
        elif family == "kids":
            lo, hi = PAGES["kids"]
        elif subjects[0] == "PHOTO_SPECIAL":
            lo, hi = 48, 120
        else:
            lo, hi = PAGES[cover]
        books.append((key, family, pages_for(key, lo, hi), quality_for(key), cover))
    for key, _, _ in read_registry(jar, "zombie/scripting/objects/ComicBook.class", "BookSubject"):
        comics.append((key, comic_family(key), pages_for(key, *PAGES["comic"]), quality_for(key)))
    for key, _, subjects in read_registry(jar, "zombie/scripting/objects/Magazine.class", "MagazineSubject"):
        family = MAGAZINE_FAMILY_OF[subjects[0]] if subjects else "popular"
        magazines.append((key, family, pages_for(key, *PAGES["magazine"]), quality_for(key)))
    return books, comics, magazines


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(books, comics, magazines):
    lines = [
        "-- Dan's Vanilla Fixes: the reading table. GENERATED by",
        "-- DansVanillaFixes/tools/gen_reading_data.py from projectzomboid.jar (%s);" % GAME_VERSION,
        "-- do not edit, rerun the tool after a game update. Hand overrides and the",
        "-- real books live in DansVanillaFixes_ReadingBooks.lua.",
        "--",
        "-- One line per vanilla title, keyed by the title key the game keeps in",
        "-- modData.literatureTitle (without its IGUI_BookTitle_ / IGUI_ComicTitle_ /",
        "-- IGUI_MagazineTitle_ prefix): { family, pages, quality 1-5, cover (books:",
        "-- S softcover, H hardcover, B either) }.",
        "DVF_ReadingData = DVF_ReadingData or {}",
        "local D = DVF_ReadingData",
        'D.generated = "%s"' % GAME_VERSION,
        "D.books, D.comics, D.magazines = {}, {}, {}",
        "local function B(k, f, p, q, c) D.books[k] = { f, p, q, c } end",
        "local function C(k, f, p, q) D.comics[k] = { f, p, q } end",
        "local function M(k, f, p, q) D.magazines[k] = { f, p, q } end",
        "",
    ]
    for key, family, pages, quality, cover in books:
        lines.append('B(%s, "%s", %d, %d, "%s")' % (lua_string(key), family, pages, quality, cover))
    lines.append("")
    for key, family, pages, quality in comics:
        lines.append('C(%s, "%s", %d, %d)' % (lua_string(key), family, pages, quality))
    lines.append("")
    for key, family, pages, quality in magazines:
        lines.append('M(%s, "%s", %d, %d)' % (lua_string(key), family, pages, quality))
    lines.append("")
    lines.append("D.counts = { books = %d, comics = %d, magazines = %d }" % (len(books), len(comics), len(magazines)))
    return "\n".join(lines) + "\n"


def stats(books, comics, magazines):
    from collections import Counter
    for label, rows in (("books", books), ("comics", comics), ("magazines", magazines)):
        fam = Counter(r[1] for r in rows)
        q = Counter(r[3] for r in rows)
        print("%s: %d" % (label, len(rows)))
        print("  families: " + ", ".join("%s %d" % kv for kv in sorted(fam.items())))
        print("  quality:  " + ", ".join("%d* %d" % kv for kv in sorted(q.items())))
        pages = [r[2] for r in rows]
        print("  pages:    %d-%d, mean %.0f" % (min(pages), max(pages), sum(pages) / len(pages)))


def main(argv):
    if not os.path.isfile(JAR):
        raise SystemExit("no game jar at %s (set PZ_JAR)" % JAR)
    with zipfile.ZipFile(JAR) as jar:
        books, comics, magazines = build(jar)
    if "--stats" in argv:
        stats(books, comics, magazines)
        return
    text = render(books, comics, magazines)
    if "--print" in argv:
        sys.stdout.write(text)
        return
    with open(OUT, "w", encoding="utf8", newline="\n") as f:
        f.write(text)
    print("wrote %s: %d books, %d comics, %d magazines" % (os.path.relpath(OUT, os.getcwd()), len(books), len(comics), len(magazines)))


if __name__ == "__main__":
    main(sys.argv[1:])
