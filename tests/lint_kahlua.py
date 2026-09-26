"""Lint the mod's Lua for things the game's engine (Kahlua) rejects but the
offline tests' standard Lua accepts. No Lua is run: the files are tokenised
and scanned.

    python tests/lint_kahlua.py            every file under DanTraits/42/media/lua
    python tests/lint_kahlua.py vitality   files whose name contains "vitality"
    python tests/lint_kahlua.py --selftest check the checker against known-bad snippets

What is checked, and why (all confirmed against the game's jar, B42):
  * Globals that do not exist: next, assert, xpcall, dofile, loadfile. The
    base library registers pcall, print, select, type, tostring, tonumber,
    getmetatable, setmetatable, error, unpack, rawequal, rawget, rawset,
    setfenv, getfenv, collectgarbage; pairs and ipairs come from the table
    library; require and the rest come from the game.
  * string functions that do not exist: gmatch and rep (the string library
    has byte, char, find, format, gsub, len, lower, match, reverse, sub,
    upper, plus the game's split, trim, contains).
  * table.unpack (it is the global unpack), goto and the // operator (Lua 5.2+).
  * string.format specifiers outside d i u c x X o e E f g G q s and %%.
  * More than 200 local variables in one function (the file's top level is a
    function too) or more than 60 upvalues (enclosing locals a function
    reaches for, counting those its nested functions need). Both are
    compile-time errors that take the whole file down. A warning is given at
    80% of either limit.
  * Translation files (media/lua/shared/Translate/**/*.json): valid JSON with
    no duplicate keys, and every percent sign is either a placeholder (%1 to
    %9) or a literal written as %% the way vanilla does. The game runs these
    strings through Java's formatter, and a bare % throws at boot.

Table field names ({ next = 1 }, x.next) are not references and are not
flagged. The string methods are flagged on the colon form too (s:rep(3)),
because that is how they are usually called.
"""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(HERE), "DanTraits", "42", "media", "lua")

MISSING_GLOBALS = {"next", "assert", "xpcall", "dofile", "loadfile"}
MISSING_STRING = {"gmatch", "rep"}
FORMAT_OK = set("diucxXoeEfgGqs%")
MAX_LOCALS, MAX_UPVALUES = 200, 60
TRANSLATE = os.path.join(ROOT, "shared", "Translate")
PERCENT = re.compile("%%|%[1-9]|%")   # %% and %1..%9 are consumed as units; a lone % is the problem
WARN_AT = 0.8

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil",
            "not", "or", "repeat", "return", "then", "true", "until", "while", "goto"}
VALUE_WORDS = {"and", "or", "not", "nil", "true", "false", "function"}
CONTINUES_LINE = {"..", "+", "-", "*", "/", "%", "^", "and", "or", ",", ".", ":", "(", "{", "=", "==", "~=", "<", ">", "<=", ">="}

TOKEN = re.compile(r"""
    (?P<ws>[ \t\r]+) | (?P<nl>\n) |
    (?P<longcomment>--\[(?P<lc>=*)\[.*?\](?P=lc)\]) | (?P<comment>--[^\n]*) |
    (?P<longstring>\[(?P<ls>=*)\[.*?\](?P=ls)\]) |
    (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*') |
    (?P<number>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?) |
    (?P<name>[A-Za-z_][A-Za-z0-9_]*) |
    (?P<sym>\.\.\.|\.\.|==|~=|<=|>=|//|[-+*/%^#=<>(){}\[\];:,.])
""", re.S | re.X)


def tokenize(src):
    """(kind, text, line) for everything but whitespace and comments."""
    out, line, pos = [], 1, 0
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            raise SyntaxError("line %d: cannot tokenise %r" % (line, src[pos:pos + 20]))
        kind = m.lastgroup
        text = m.group(0)
        if kind in ("longstring", "string", "number", "name", "sym"):
            out.append((kind, text, line))
        line += text.count("\n")
        pos = m.end()
    return out


class Frame:
    def __init__(self, name, line):
        self.name, self.line = name, line
        self.blocks = [set()]       # stack of scopes, each a set of local names
        self.locals = 0             # declared in this function, nested functions excluded
        self.upvalues = set()

    def declare(self, name):
        self.blocks[-1].add(name)
        self.locals += 1

    def has(self, name):
        return any(name in b for b in self.blocks)


class Linter:
    def __init__(self, path, src):
        self.path = path
        self.problems = []      # (line, severity, message)
        self.toks = tokenize(src)
        self.frames = [Frame("<file>", 1)]
        self.pending_for = None
        self.brace_depth = 0
        self.trace = None       # set to a list to record (line, frames, blocks) per token

    def report(self, line, msg, warn=False):
        self.problems.append((line, "warning" if warn else "error", msg))

    def tok(self, i):
        return self.toks[i] if 0 <= i < len(self.toks) else (None, None, None)

    def resolve(self, name, line):
        """A bare name: local of this function, upvalue from an enclosing one, or a global."""
        if self.frames[-1].has(name):
            return
        for depth in range(len(self.frames) - 2, -1, -1):
            if self.frames[depth].has(name):
                for f in self.frames[depth + 1:]:
                    f.upvalues.add(name)
                return
        if name in MISSING_GLOBALS:
            self.report(line, "'%s' does not exist in the game's Lua" % name)

    def close_block(self, line):
        frame = self.frames[-1]
        if len(frame.blocks) > 1:
            frame.blocks.pop()
            return
        self.finish(frame)
        if len(self.frames) > 1:
            self.frames.pop()
        else:
            self.report(line, "unexpected 'end' at the top level")

    def finish(self, frame):
        if frame.name == "<file>":
            where = "the file's top level"
        else:
            where = "function %s (line %d)" % (frame.name, frame.line)
        for n, limit, what in ((frame.locals, MAX_LOCALS, "locals"), (len(frame.upvalues), MAX_UPVALUES, "upvalues")):
            if n > limit:
                self.report(frame.line, "%s has %d %s; the game's compiler allows %d" % (where, n, what, limit))
            elif n >= WARN_AT * limit:
                self.report(frame.line, "%s has %d %s; the limit is %d" % (where, n, what, limit), warn=True)

    def check_format(self, text, line):
        for m in re.finditer(r"%[-+ #0]*\d*(?:\.\d+)?([A-Za-z%])", text):
            if m.group(1) not in FORMAT_OK:
                self.report(line, "string.format specifier '%s' is not supported by the game's Lua" % m.group(0))

    def inspect(self, i):
        """Symbol and string checks for token i (names are handled by the caller)."""
        kind, text, line = self.toks[i]
        prev_text = self.tok(i - 1)[1]
        next_kind, next_text, _ = self.tok(i + 1)
        if kind == "sym":
            if text == "//":
                self.report(line, "'//' is Lua 5.3 integer division; the game's Lua is 5.1")
            elif text == "{":
                self.brace_depth += 1
            elif text == "}":
                self.brace_depth = max(0, self.brace_depth - 1)
            elif text in (".", ":") and next_kind == "name":
                if next_text in MISSING_STRING and (text == ":" or prev_text == "string"):
                    self.report(line, "string.%s does not exist in the game's Lua (loop over find/sub instead)" % next_text)
                if text == "." and prev_text == "table" and next_text == "unpack":
                    self.report(line, "table.unpack is Lua 5.2; the game has the global unpack")
        elif kind in ("string", "longstring"):
            # a format string: the literal follows format( on the same line
            j = i - 1
            while j >= 0 and self.toks[j][2] == line and self.toks[j][1] != "format":
                j -= 1
            if j >= 0 and self.toks[j][1] == "format" and self.toks[j][2] == line:
                self.check_format(text, line)

    def is_reference(self, i):
        """Token i is a name used as a value, not a field or a table key."""
        prev_text = self.tok(i - 1)[1]
        next_text = self.tok(i + 1)[1]
        if prev_text in (".", ":"):
            return False
        if self.brace_depth > 0 and next_text == "=" and prev_text in ("{", ",", ";"):
            return False
        return True

    def run(self):
        toks = self.toks
        i = 0
        while i < len(toks):
            kind, text, line = toks[i]
            if self.trace is not None:
                self.trace.append((line, text, len(self.frames), len(self.frames[-1].blocks)))
            prev_text = self.tok(i - 1)[1]
            next_kind, next_text, _ = self.tok(i + 1)

            if kind != "name":
                self.inspect(i)
                i += 1
                continue

            if text == "goto":
                self.report(line, "'goto' is Lua 5.2; the game's Lua is 5.1")
                i += 1
                continue

            if text == "function":
                # function NAME.x:y(params) | local function NAME(params) | function(params)
                j = i + 1
                name_parts = []
                while self.tok(j)[0] == "name" or self.tok(j)[1] in (".", ":"):
                    name_parts.append(self.tok(j)[1])
                    j += 1
                fname = "".join(name_parts) or "<anonymous>"
                if prev_text == "local" and self.tok(i + 1)[0] == "name":
                    self.frames[-1].declare(self.tok(i + 1)[1])
                elif name_parts:
                    self.resolve(name_parts[0], line)     # the local, global or table being assigned to
                frame = Frame(fname, line)
                self.frames.append(frame)
                if self.tok(j)[1] == "(":
                    j += 1
                    while self.tok(j)[1] != ")" and self.tok(j)[0] is not None:
                        if self.tok(j)[0] == "name":
                            frame.declare(self.tok(j)[1])
                        j += 1
                    j += 1
                i = j
                continue

            if text == "local":
                if next_text == "function":
                    i += 1
                    continue
                j = i + 1
                names = []
                while self.tok(j)[0] == "name" and self.tok(j)[1] not in KEYWORDS:
                    names.append(self.tok(j)[1])
                    j += 1
                    if self.tok(j)[1] != ",":
                        break
                    j += 1
                # the right-hand side is evaluated before the names exist: walk it
                # (up to the end of the statement) resolving references, then declare
                k = j
                if self.tok(k)[1] == "=":
                    k += 1
                    depth = 0
                    while k < len(toks):
                        tk, tt, tl = toks[k]
                        if tk == "name" and tt == "function":
                            break       # a function expression: the main loop scopes it, names declared below first
                        if tk == "name" and tt in KEYWORDS and tt not in VALUE_WORDS and depth == 0:
                            break
                        if tk == "sym" and tt in ("(", "{", "["):
                            depth += 1
                        elif tk == "sym" and tt in (")", "}", "]"):
                            depth -= 1
                        if tk == "name" and tt not in KEYWORDS and self.is_reference(k):
                            self.resolve(tt, tl)
                        self.inspect(k)
                        k += 1
                        if depth <= 0 and k < len(toks) and toks[k][2] != tl and toks[k][1] not in CONTINUES_LINE and toks[k - 1][1] not in CONTINUES_LINE:
                            break
                for n in names:
                    self.frames[-1].declare(n)
                i = k
                continue

            if text == "for":
                j = i + 1
                names = []
                while self.tok(j)[0] == "name" and self.tok(j)[1] not in KEYWORDS:
                    names.append(self.tok(j)[1])
                    j += 1
                    if self.tok(j)[1] != ",":
                        break
                    j += 1
                self.pending_for = names
                i = j
                continue

            if text in ("do", "then", "repeat", "else"):
                if text == "else":
                    self.frames[-1].blocks.pop()
                self.frames[-1].blocks.append(set())
                if text == "do" and self.pending_for:
                    for n in self.pending_for:
                        self.frames[-1].declare(n)
                    self.pending_for = None
                i += 1
                continue
            if text == "elseif":
                self.frames[-1].blocks.pop()      # the 'then' that follows opens the next branch
                i += 1
                continue
            if text in ("end", "until"):
                self.close_block(line)
                i += 1
                continue

            if text in KEYWORDS:
                i += 1
                continue

            if self.is_reference(i):
                self.resolve(text, line)
            i += 1

        while self.frames:
            self.finish(self.frames.pop())
        return self.problems


def lint_translation(text):
    """Problems in one translation file's text: (line, severity, message)."""
    import json
    problems = []
    seen = {}

    def pairs(items):
        for key, _ in items:
            if key in seen:
                problems.append((0, "error", "duplicate key '%s' (the game keeps one and drops the other)" % key))
            seen[key] = True
        return dict(items)
    try:
        json.loads(text, object_pairs_hook=pairs)
    except ValueError as e:
        problems.append((0, "error", "not valid JSON: %s" % e))
        return problems
    for n, line in enumerate(text.splitlines(), 1):
        # look only inside the value, after the first ": "
        body = line.split(":", 1)[1] if ":" in line else ""
        for m in PERCENT.finditer(body):
            if m.group(0) != "%":
                continue
            problems.append((n, "error", "bare %% in a UI string (write %%%% for a percent sign, %%1 for a placeholder): %s" % line.strip()[:80]))
            break
    return problems


def lint_file(path):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    try:
        return Linter(path, src).run()
    except SyntaxError as e:
        return [(0, "error", str(e))]


NL = chr(10)
SELFTEST = [
    # (snippet, expected number of errors, what it checks)
    ("local k = next(t)", 1, "next"),
    ("assert(x, 'no')", 1, "assert"),
    ("pcall(function() return xpcall(f, g) end)", 1, "xpcall"),
    ("local s = string.rep('-', 3)", 1, "string.rep"),
    ("local s = ('-'):rep(3)", 1, ":rep"),
    ("for w in string.gmatch(line, '%S+') do end", 1, "string.gmatch"),
    ("local a, b = table.unpack(t)", 1, "table.unpack"),
    ("local a, b = unpack(t)", 0, "unpack is fine"),
    ("local h = n // 2", 1, "integer division"),
    ("local s = string.format('%5.2f %d %s %x %%', a, b, c, d)", 0, "supported format specifiers"),
    ("local s = string.format('%z %a', a, b)", 2, "unsupported format specifiers"),
    ("local s = ('%q'):format(x)", 0, "format via method"),
    ("local t = { next = 1, rep = 2 }; local v = t.next + t.rep; t.assert = 3", 0, "fields are not globals"),
    ("local next = 5; local v = next + 1", 0, "a local shadows the missing global"),
    (NL.join("local v%d = %d" % (i, i) for i in range(201)), 1, "201 top-level locals"),
    (NL.join("local v%d = %d" % (i, i) for i in range(200)), 0, "200 top-level locals"),
    (NL.join("local u%d = %d" % (i, i) for i in range(61)) + NL + "local function f() return " + " + ".join("u%d" % i for i in range(61)) + " end", 1, "61 upvalues"),
    (NL.join("local u%d = %d" % (i, i) for i in range(61)) + NL + "local function f() local function g() return " + " + ".join("u%d" % i for i in range(61)) + " end return g end", 2, "upvalues pass through the enclosing function"),
    (NL.join("local u%d = %d" % (i, i) for i in range(70)) + NL + "local function f(a)" + NL + " if a then return u1 elseif a == 2 then return u2 else return u3 end" + NL + "end" + NL + "local function g() return " + " + ".join("u%d" % i for i in range(61)) + " end", 1, "if/elseif/else does not leak the next function into the last"),
    (NL.join(["local function f(item)", "  local ok = pcall(function() return item.x end)", "  local function g() return ok end", "  return g", "end", "local function h() return f end"]), 0, "nested closures and pcall bodies close cleanly"),
]


TRANSLATION_SELFTEST = [
    ('{ "UI_a": "Blood sugar: %1", "UI_b": "100%%", "UI_c": "Humidity: %1 %%" }', 0, "placeholders and %% are fine"),
    ('{ "UI_a": "Irritation 25%: warning only." }', 1, "bare percent"),
    ('{ "UI_a": "cuts it by 80%.<br>" }', 1, "percent before a dot"),
    ('{ "UI_a": "%s of %d" }', 1, "C-style specifiers are not placeholders"),
    ('{ "UI_a": "x", "UI_a": "y" }', 1, "duplicate key"),
    ('{ "UI_a": "x", }', 1, "trailing comma is not JSON"),
]


def selftest():
    bad = 0
    for text, expected, what in TRANSLATION_SELFTEST:
        errors = [p for p in lint_translation(text) if p[1] == "error"]
        if len(errors) != expected:
            bad += 1
            print("selftest FAIL: %s: expected %d error(s), got %d: %s" % (what, expected, len(errors), [p[2] for p in errors]))
    for snippet, expected, what in SELFTEST:
        problems = Linter("<selftest>", snippet + NL).run()
        errors = [p for p in problems if p[1] == "error"]
        if len(errors) != expected:
            bad += 1
            print("selftest FAIL: %s: expected %d error(s), got %d: %s" % (what, expected, len(errors), [p[2] for p in errors]))
    print("selftest: %d case(s), %d failed" % (len(SELFTEST) + len(TRANSLATION_SELFTEST), bad))
    return 1 if bad else 0


def main(argv):
    if argv[1:] == ["--selftest"]:
        return selftest()
    only = argv[1:]
    files = sorted(glob.glob(os.path.join(ROOT, "**", "*.lua"), recursive=True))
    files += sorted(glob.glob(os.path.join(TRANSLATE, "**", "*.json"), recursive=True))
    if only:
        files = [f for f in files if any(o.lower() in os.path.basename(f).lower() for o in only)]
    errors = warnings = 0
    for path in files:
        rel = os.path.relpath(path, os.path.dirname(HERE))
        if path.endswith(".json"):
            with open(path, encoding="utf-8") as f:
                found = lint_translation(f.read())
        else:
            found = lint_file(path)
        for line, severity, msg in found:
            print("%s:%d: %s: %s" % (rel, line, severity, msg))
            if severity == "error":
                errors += 1
            else:
                warnings += 1
    print("lint: %d file(s), %d error(s), %d warning(s)" % (len(files), errors, warnings))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
