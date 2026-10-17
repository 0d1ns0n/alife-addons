import json
import pathlib
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.exit("нужен пакет lupa: pip install lupa")

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
ROOT = REPO / "mods" / "ALifeCamp" / "42" / "media" / "lua"
ADDON = REPO / "mods" / "ALifeCampCheats" / "42" / "media" / "lua"
LONG = {"camp_test4"}


def items(table):
    return [table[i] for i in range(1, len(table) + 1)]


def run(name):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = ROOT.as_posix()
    g.ADDON = ADDON.as_posix()
    g.MOCK = (HERE / "camp_mock.lua").as_posix()
    ui = json.load(open(ROOT / "shared" / "Translate" / "RU" / "UI.json", encoding="utf-8"))
    ui.update(json.load(open(ADDON / "shared" / "Translate" / "RU" / "UI.json", encoding="utf-8")))
    g.UIJSON = lua.table_from(ui)
    source = open(HERE / (name + ".lua"), encoding="utf-8").read()
    try:
        lua.execute(source)
    except Exception as error:
        return ["crash: " + str(error)[:160]], []
    result = g.RESULT
    return [str(x) for x in items(result.fails)], [str(x) for x in items(result.missing)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    everything = "--all" in sys.argv
    if args:
        names = args
    else:
        names = sorted(p.stem for p in HERE.glob("camp_test*.lua"))
        if not everything:
            names = [n for n in names if n not in LONG]
    failed = 0
    for name in names:
        fails, missing = run(name)
        status = "ok" if not fails and not missing else "FAIL"
        if status == "FAIL":
            failed += 1
        print("%-22s %s %s %s" % (name, status, fails if fails else "", ("missing keys: %s" % missing) if missing else ""))
    print("тестов: %d, с ошибками: %d" % (len(names), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
