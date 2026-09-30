"""Run the Kahlua lint (tests/lint_kahlua.py), the game API check
(tests/check_api.py: method names against the installed game), then every offline test with
fengari (standard Lua in Node; one Node process for all of them, tests/run_all.js, each test in
its own Lua state; fengari is pinned in tests/package.json and installed on the first run). Every test loads tests/harness.lua and ends with H.pass(), which
prints "<name>: all checks passed"; that exact suffix is what counts as a pass. The lint covers
the known gaps between the two: functions the game's Lua lacks, and the compiler's local and
upvalue limits. Anything else Kahlua-specific still needs the game.

    python tests/run_tests.py            lint, then all tests
    python tests/run_tests.py vitality   lint and test files matching "vitality"
"""
import ast
import glob
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
NOISE = ("not registered", "[DanTraits] character traits", "telemetry]", "SAMPLE:")
PASS_SUFFIX = ": all checks passed"   # what tests/harness.lua's H.pass prints as the last line


def report(name, ok, detail=(), failed=None, results=None):
    """Print one PASS/FAIL line (plus detail on a failure) and record it."""
    print("%s %s" % ("PASS" if ok else "FAIL", name))
    if not ok:
        for l in detail:
            print("    " + l)
    results.append((name, ok))


def run_lua_tests(tests):
    """Every test file in one Node process (tests/run_all.js gives each its own Lua state)."""
    if not os.path.isdir(os.path.join(HERE, "node_modules", "fengari")):
        # first run: fetch the pinned fengari from tests/package.json (about a second)
        subprocess.run(["npm", "install", "--no-audit", "--no-fund", "--no-package-lock"], cwd=HERE,
                       capture_output=True, text=True, shell=(os.name == "nt"))
    proc = subprocess.run(["node", "run_all.js"] + [os.path.basename(t) for t in tests], cwd=HERE,
                          capture_output=True, text=True)
    try:
        return json.loads(proc.stdout), None
    except ValueError:
        return None, (proc.stdout + proc.stderr).splitlines()[-12:]


def main():
    only = sys.argv[1:]
    tests = sorted(glob.glob(os.path.join(HERE, "test_*.lua")))
    if only:
        tests = [t for t in tests if any(o in os.path.basename(t) for o in only)]
    results = []     # (name, ok) for every check, so the total is counted, not typed
    for label, args in (("lint_kahlua.py --selftest", ["--selftest"]), ("lint_kahlua.py", only)):
        lint = subprocess.run([sys.executable, os.path.join(HERE, "lint_kahlua.py")] + args, cwd=HERE,
                              capture_output=True, text=True)
        ok = lint.returncode == 0
        detail = [l for l in (lint.stdout + lint.stderr).splitlines()
                  if not (ok and (l.startswith("lint:") or l.startswith("selftest:")))]
        report(label, ok, detail, results=results)
    # the dashboard (Python holding a page of HTML in a string) must at least parse
    dash = os.path.join(HERE, "..", "DanTraits", "tools", "dashboard.py")
    try:
        with open(dash, encoding="utf-8") as f:
            ast.parse(f.read())
        report("dashboard.py parses", True, results=results)
    except SyntaxError as e:
        report("dashboard.py parses", False, ["line %s: %s" % (e.lineno, e.msg)], results=results)
    # the mod's calls on the game's objects, against the installed game's jar (and the checker's own self-test)
    for label, args in (("check_api.py --selftest", ["--selftest"]), ("check_api.py", [])):
        api = subprocess.run([sys.executable, os.path.join(HERE, "check_api.py")] + args, cwd=HERE,
                             capture_output=True, text=True)
        out = (api.stdout + api.stderr).splitlines()
        skip = [l for l in out if l.startswith("SKIP")]
        if api.returncode == 0 and skip:
            print(skip[0])          # no jar on this machine: shown, counted as a pass, not hidden
            results.append((label, True))
        else:
            report(label, api.returncode == 0, out, results=results)
    parsed, crash = run_lua_tests(tests) if tests else ([], None)
    if crash is not None:
        for t in tests:
            report(os.path.basename(t), False, crash, results=results)
    else:
        for r in parsed:
            lines = [l for l in r["lines"] if not any(n in l for n in NOISE)]
            ok = r["ok"] and any(l.strip().endswith(PASS_SUFFIX) for l in lines)
            report(r["name"], ok, lines[-12:], results=results)
    failed = [n for n, ok in results if not ok]
    print("%d/%d passed" % (len(results) - len(failed), len(results)))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
