import os
import pathlib
import shutil
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
GAME = pathlib.Path(os.environ.get("ZOMBOID_DIR", pathlib.Path.home() / "Zomboid")) / "mods"


def main():
    names = sys.argv[1:] or [p.name for p in sorted((REPO / "mods").iterdir()) if p.is_dir()]
    GAME.mkdir(parents=True, exist_ok=True)
    for name in names:
        source = REPO / "mods" / name
        target = GAME / name
        if not source.exists():
            print("нет такого мода:", name)
            continue
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
        print("установлен", name, "->", target)
    print("Включи моды в игре: Моды, затем отметь нужные.")


if __name__ == "__main__":
    main()
