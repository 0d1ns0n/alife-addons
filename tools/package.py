import pathlib
import re
import shutil
import sys
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
MODS = ["ALifeCamp", "ALifeRU"]
DIST = REPO / "dist"


def info(mod):
    text = open(REPO / "mods" / mod / "42" / "mod.info", encoding="utf-8").read()
    fields = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
    return fields


def build_zip(mod):
    fields = info(mod)
    target = DIST / ("%s-%s.zip" % (mod, fields.get("modversion", "0")))
    DIST.mkdir(exist_ok=True)
    root = REPO / "mods" / mod
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob("*")):
            if path.is_file():
                archive.write(path, pathlib.Path(mod) / path.relative_to(root))
    print("zip", target.name)


def build_workshop(mod):
    fields = info(mod)
    base = DIST / "Workshop" / mod
    if base.exists():
        shutil.rmtree(base)
    shutil.copytree(REPO / "mods" / mod, base / "Contents" / "mods" / mod)
    description = re.sub(r"\s+", " ", fields.get("description", ""))
    lines = [
        "version=1",
        "title=" + fields.get("name", mod),
        "description=" + description,
        "tags=Build 42",
        "visibility=private",
    ]
    open(base / "workshop.txt", "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("workshop folder", base)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "zip"
    names = sys.argv[2:] or MODS
    for mod in names:
        if mode == "workshop":
            build_workshop(mod)
        else:
            build_zip(mod)


if __name__ == "__main__":
    main()
