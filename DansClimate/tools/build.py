"""Build DansClimate.jar from java/src with the JDK's javac and jar.

    python DansClimate/tools/build.py            compile java/src, write 42/media/java/DansClimate.jar
    python DansClimate/tools/build.py --test     also compile java/test and run every *Test class
    python DansClimate/tools/build.py --game DIR the Project Zomboid folder, if not the default Steam one

Compiles against the game's projectzomboid.jar and the ZombieBuddy.jar in the game
folder (the version players run), for the Java the game ships (--release 25).
Needs a JDK 25: JAVA_HOME, else the newest Eclipse Adoptium jdk-25*, else javac on PATH.
Then deploy as usual: python deploy.py --mod DansClimate
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
SRC = os.path.join(MOD, "java", "src")
TEST = os.path.join(MOD, "java", "test")
OUT = os.path.join(MOD, "42", "media", "java", "DansClimate.jar")
GAME = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
RELEASE = "25"
EXE = ".exe" if os.name == "nt" else ""


def jdk_tool(name):
    """javac or jar from JAVA_HOME, the newest Adoptium JDK 25, or PATH."""
    homes = []
    if os.environ.get("JAVA_HOME"):
        homes.append(os.environ["JAVA_HOME"])
    homes += sorted(glob.glob(r"C:\Program Files\Eclipse Adoptium\jdk-25*"), reverse=True)
    for home in homes:
        exe = os.path.join(home, "bin", name + EXE)
        if os.path.isfile(exe):
            return exe
    exe = shutil.which(name)
    if exe:
        return exe
    raise SystemExit("no %s found: install a JDK 25 or set JAVA_HOME" % name)


def sources(root):
    return [os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs if f.endswith(".java")]


def run(cmd):
    r = subprocess.run(cmd)
    if r.returncode:
        raise SystemExit(r.returncode)


PACKAGE = "com/spadix84/dansclimate"
REF = re.compile(r"// (Field|Method|InterfaceMethod|class) (" + PACKAGE + r"/[\w$/]+)(?:\.(\w+|\"<init>\"))?")
METHOD_START = re.compile(r"^  \S.*\);$")
ADVICE = re.compile(r"zombie_buddy[./]Patch\$On(Enter|Exit)")   # javap writes a method's annotations with dots


def javap(tool, path, *flags):
    r = subprocess.run([tool, *flags, path], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(r.stderr)
    return r.stdout


def check_advice(javap_exe, classes):
    """ZombieBuddy copies @Patch.OnEnter/OnExit bodies into the game's class, so they may
    only use public classes and members of ours: anything else throws IllegalAccessError
    inside the game, which crashed it once (GameBridge.enabled, read from
    AirTemperaturePatch's advice). Fails the build on such a reference."""
    root = os.path.join(classes, *PACKAGE.split("/"))
    members = {}

    def declared(owner):
        if owner not in members:
            text = javap(javap_exe, os.path.join(classes, owner + ".class"), "-p")
            lines = text.splitlines()
            head = next(l for l in lines if "class " in l or "interface " in l or "enum " in l or "record " in l)
            members[owner] = (head.lstrip().startswith("public "), lines)
        return members[owner]

    problems = []
    for f in sorted(os.listdir(root)):
        if not f.endswith(".class"):
            continue
        text = javap(javap_exe, os.path.join(root, f), "-p", "-c", "-v")
        if "zombie_buddy/Patch$On" not in text:
            continue
        blocks, cur = [], None
        for line in text.splitlines():
            if METHOD_START.match(line):
                cur = [line]
                blocks.append(cur)
            elif line and not line[0].isspace():
                cur = None   # past the methods: class attributes (InnerClasses names Patch$OnExit too)
            elif cur is not None:
                cur.append(line)
        for block in blocks:
            body = "\n".join(block)
            if not ADVICE.search(body):
                continue
            for kind, owner, name in REF.findall(body):
                public_class, lines = declared(owner)
                where = "%s %s" % (f[:-6], block[0].strip())
                if not public_class:
                    problems.append("%s uses non-public class %s" % (where, owner))
                    continue
                if kind == "class" or not name or name == '"<init>"':
                    continue
                decls = [l for l in lines if re.search(r"[ .$]" + re.escape(name) + r"[(;]|[ .$]" + re.escape(name) + " =", l)]
                if not decls or not all(l.lstrip().startswith("public ") for l in decls):
                    problems.append("%s uses non-public %s.%s" % (where, owner.split("/")[-1], name))
    if problems:
        raise SystemExit("patch advice runs inside the game's class and may only use public members:\n  "
                         + "\n  ".join(sorted(set(problems))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=GAME, help="the Project Zomboid folder")
    ap.add_argument("--test", action="store_true", help="compile and run the tests in java/test")
    a = ap.parse_args()
    libs = [os.path.join(a.game, "projectzomboid.jar"), os.path.join(a.game, "ZombieBuddy.jar")]
    for lib in libs:
        if not os.path.isfile(lib):
            raise SystemExit("missing " + lib)
    javac, jar = jdk_tool("javac"), jdk_tool("jar")
    cp = os.pathsep.join(libs)
    with tempfile.TemporaryDirectory(prefix="dansclimate-") as tmp:
        classes = os.path.join(tmp, "classes")
        run([javac, "--release", RELEASE, "-encoding", "UTF-8", "-Xlint:all,-processing,-classfile",
             "-cp", cp, "-d", classes] + sources(SRC))
        check_advice(jdk_tool("javap"), classes)
        if a.test:
            tests = sources(TEST)
            if tests:
                tclasses = os.path.join(tmp, "tests")
                tcp = os.pathsep.join([classes, cp])
                run([javac, "--release", RELEASE, "-encoding", "UTF-8", "-cp", tcp, "-d", tclasses] + tests)
                java = os.path.join(os.path.dirname(javac), "java" + EXE)
                for t in sorted(tests):
                    name = os.path.relpath(t, TEST)[:-5].replace(os.sep, ".")
                    if name.endswith("Test"):
                        print("== " + name)
                        run([java, "-cp", os.pathsep.join([tclasses, tcp]), name])
        manifest = os.path.join(tmp, "MANIFEST.MF")
        with open(manifest, "w", newline="\n") as f:
            f.write("Implementation-Title: DansClimate\n")
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        if os.path.exists(OUT):
            os.remove(OUT)
        run([jar, "--create", "--file", OUT, "--manifest", manifest, "-C", classes, "."])
    print("built " + os.path.relpath(OUT, os.path.dirname(MOD)))


if __name__ == "__main__":
    sys.exit(main())
