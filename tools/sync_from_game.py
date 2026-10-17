import json
import os
import pathlib
import shutil
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
GAME = pathlib.Path(os.environ.get("ZOMBOID_DIR", pathlib.Path.home() / "Zomboid")) / "mods"
OWN = ["ALifeCamp", "ALifeRU"]
PANEL_SRC = GAME / "CheatMenuPX" / "42" / "media" / "lua" / "client" / "CheatMenuMrZoloto"
SKIP_TESTS = {"camp_test_salvage"}
PANEL_KEYS = ("UI_CMRB_P_", "UI_CMRB_W_")
PANEL_INFO = (
    "name=Cheat Menu: расширенная панель\n"
    "id=CheatPanelPX\n"
    "author=0d1ns0n\n"
    "modversion=0.9\n"
    "versionMin=42.21.0\n"
    "require=CheatMenuPX\n"
    "description=Панель читов (F7), чит-меню по правому клику, быстрое меню (F8), действия с предметами, оживление с копией внешности. "
    "Дополнение к Cheat Menu от MrZoloto, ставить ПОСЛЕ него.\n"
)


def junk(name):
    low = name.lower()
    return ".bak" in low or low.endswith((".wip", ".disabled", ".pyc")) or low in ("__pycache__", "_orig_backup")


def ignore(_, names):
    return [n for n in names if junk(n)]


def fresh(dst):
    if dst.exists():
        shutil.rmtree(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)


def copy_mod(name):
    src = GAME / name
    dst = REPO / "mods" / name
    if not src.exists():
        print("skip", name, "(not found)")
        return
    fresh(dst)
    shutil.copytree(src, dst, ignore=ignore)
    print("synced", name)


def export_panel():
    dst = REPO / "mods" / "CheatPanelPX"
    if not PANEL_SRC.exists():
        print("skip CheatPanelPX (not found)")
        return
    fresh(dst)
    base = dst / "42" / "media" / "lua"
    panel = base / "client" / "CheatMenuMrZoloto" / "Panel"
    shutil.copytree(PANEL_SRC / "Panel", panel, ignore=ignore)
    extras = PANEL_SRC / "CheatMenuInventoryExtras.lua"
    if extras.exists():
        shutil.copyfile(extras, panel.parent / "CheatMenuInventoryExtras.lua")
    source = GAME / "CheatMenuPX" / "42" / "media" / "lua" / "shared" / "Translate" / "RU" / "UI.json"
    keys = json.load(open(source, encoding="utf-8"))
    mine = {k: v for k, v in keys.items() if k.startswith(PANEL_KEYS)}
    target = base / "shared" / "Translate" / "RU"
    target.mkdir(parents=True, exist_ok=True)
    json.dump(mine, open(target / "UI.json", "w", encoding="utf-8"), ensure_ascii=False, indent=4)
    open(dst / "42" / "mod.info", "w", encoding="utf-8", newline="\n").write(PANEL_INFO)
    print("exported CheatPanelPX,", len(mine), "strings")


def events_doc():
    source = GAME / "ALifeRU" / "42" / "media" / "lua" / "shared" / "Translate" / "RU" / "UI.json"
    data = json.load(open(source, encoding="utf-8"))
    rows = []
    for key, value in sorted(data.items()):
        if key.startswith("UI_ALRU_T_"):
            ident = key[len("UI_ALRU_T_"):]
            rows.append("| `%s` | %s | %s |" % (ident, value, data.get("UI_ALRU_D_" + ident, "")))
    text = "# События ALifeRU\n\n| Код | Название | Описание |\n|---|---|---|\n" + "\n".join(rows) + "\n"
    open(REPO / "docs" / "ALifeRU-events.md", "w", encoding="utf-8", newline="\n").write(text)
    print("events doc:", len(rows))


def tests():
    scratch = os.environ.get("CAMP_TESTS_SRC")
    if not scratch:
        return
    src = pathlib.Path(scratch)
    dst = REPO / "tools" / "tests"
    for path in [p for p in sorted(src.glob("camp_test*.lua")) if p.stem not in SKIP_TESTS] + [src / "camp_mock.lua"]:
        if path.exists():
            shutil.copyfile(path, dst / path.name)
    print("tests copied")


def main():
    for name in OWN:
        copy_mod(name)
    events_doc()
    tests()


if __name__ == "__main__":
    sys.exit(main())
