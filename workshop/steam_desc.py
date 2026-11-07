"""Keep a Workshop page's description.txt and workshop.txt together, and under Steam's limit.

The page is written in description.txt (Steam BBCode, one paragraph a line). The game's
uploader reads workshop.txt, where the same text is one `description=` line per line of
the page, beside version=, id=, title=, tags= and visibility=. Steam's server counts the
description as the lines joined with "\\n" and a line break as TWO characters, and refuses
the upload past 8000 with result=8 (InvalidParam) after the content has already gone up
(the 1.5.0 upload, 2026-10-31). This script does both jobs:

    python workshop/steam_desc.py            the main mod's page (workshop/)
    python workshop/steam_desc.py maplegend  another page (workshop/maplegend/)
    python workshop/steam_desc.py --check    count only, rewrite nothing

It prints the count as Steam sees it and rewrites workshop.txt's description= lines from
description.txt, keeping every other line. Exit code 1 when over the limit (the file is
still rewritten, so the trim can be made in description.txt and the script run again).
"""
import io
import os
import sys

LIMIT = 8000
HERE = os.path.dirname(os.path.abspath(__file__))


def steam_count(lines):
    """Characters as Steam counts them: the text, plus two per line break."""
    return sum(len(l) for l in lines) + 2 * max(0, len(lines) - 1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv[1:]
    folder = os.path.abspath(args[0]) if args else HERE
    desc_path = os.path.join(folder, "description.txt")
    ws_path = os.path.join(folder, "workshop.txt")
    with io.open(desc_path, encoding="utf-8") as f:
        desc = f.read().rstrip("\n").split("\n")
    desc = [l.rstrip("\r") for l in desc]
    count = steam_count(desc)
    over = count > LIMIT
    print("%s: %d characters + %d line breaks = %d of %d%s" % (
        os.path.relpath(desc_path, HERE), sum(len(l) for l in desc), len(desc) - 1, count, LIMIT,
        " OVER THE LIMIT" if over else ""))
    if check:
        return 1 if over else 0
    with io.open(ws_path, encoding="utf-8") as f:
        ws = [l.rstrip("\r\n") for l in f]
    head = [l for l in ws if not l.startswith("description=")]
    # the description lines go where the first one was (after title=, as the game writes it)
    at = next((i for i, l in enumerate(ws) if l.startswith("description=")), len(head))
    at = min(at, len(head))
    out = head[:at] + ["description=" + l for l in desc] + head[at:]
    text = "\n".join(out) + "\n"
    with io.open(ws_path, encoding="utf-8") as f:
        old = f.read()
    if old != text:
        with io.open(ws_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("%s rewritten (%d description lines)" % (os.path.relpath(ws_path, HERE), len(desc)))
    else:
        print("%s unchanged" % os.path.relpath(ws_path, HERE))
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
