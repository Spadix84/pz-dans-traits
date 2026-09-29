"""Run the Kahlua lint (tests/lint_kahlua.py), the game API check
(tests/check_api.py: method names against the installed game), then every offline test with
fengari (standard Lua in Node). The lint covers the known gaps between the
two: functions the game's Lua lacks, and the compiler's local and upvalue
limits. Anything else Kahlua-specific still needs the game.

    python tests/run_tests.py            lint, then all tests
    python tests/run_tests.py vitality   lint and test files matching "vitality"
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
NOISE = ("not registered", "[DanTraits] ate", "telemetry]", "SAMPLE:")


def main():
    only = sys.argv[1:]
    tests = sorted(glob.glob(os.path.join(HERE, "test_*.lua")))
    if only:
        tests = [t for t in tests if any(o in os.path.basename(t) for o in only)]
    failed = []
    for label, args in (("lint_kahlua.py --selftest", ["--selftest"]), ("lint_kahlua.py", only)):
        lint = subprocess.run([sys.executable, os.path.join(HERE, "lint_kahlua.py")] + args, cwd=HERE,
                              capture_output=True, text=True)
        print("%s %s" % ("PASS" if lint.returncode == 0 else "FAIL", label))
        for l in (lint.stdout + lint.stderr).splitlines():
            if lint.returncode == 0 and (l.startswith("lint:") or l.startswith("selftest:")):
                continue
            print("    " + l)
        if lint.returncode != 0:
            failed.append(label)
    # the dashboard (Python holding a page of HTML in a string) must at least parse
    import ast
    dash = os.path.join(HERE, "..", "DanTraits", "tools", "dashboard.py")
    try:
        with open(dash, encoding="utf-8") as f:
            ast.parse(f.read())
        print("PASS dashboard.py parses")
    except SyntaxError as e:
        print("FAIL dashboard.py parses")
        print("    line %s: %s" % (e.lineno, e.msg))
        failed.append("dashboard.py")
    # the mod's calls on the game's objects, against the installed game's jar
    api = subprocess.run([sys.executable, os.path.join(HERE, "check_api.py")], cwd=HERE, capture_output=True, text=True)
    print("%s check_api.py" % ("PASS" if api.returncode == 0 else "FAIL"))
    if api.returncode != 0:
        failed.append("check_api.py")
        for l in (api.stdout + api.stderr).splitlines():
            print("    " + l)
    for t in tests:
        name = os.path.basename(t)
        proc = subprocess.run(["npx", "-y", "-p", "fengari-node-cli", "fengari", name], cwd=HERE,
                              capture_output=True, text=True, shell=(os.name == "nt"))
        out = (proc.stdout + proc.stderr).splitlines()
        lines = [l for l in out if not any(n in l for n in NOISE)]
        ok = proc.returncode == 0 and any(("passed" in l or "ALL OK" in l) for l in lines)
        print("%s %s" % ("PASS" if ok else "FAIL", name))
        if not ok:
            failed.append(name)
            for l in lines[-12:]:
                print("    " + l)
    print("%d/%d passed" % (len(tests) + 4 - len(failed), len(tests) + 4))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
