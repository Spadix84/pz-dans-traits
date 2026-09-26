"""Run every offline test with fengari (standard Lua in Node; the game's Kahlua
has gaps fengari does not catch, such as no `next`, so this is a first line,
not the last word).

    python tests/run_tests.py            all
    python tests/run_tests.py vitality   just test_vitality.lua
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
    print("%d/%d passed" % (len(tests) - len(failed), len(tests)))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
