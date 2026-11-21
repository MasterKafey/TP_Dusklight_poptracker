"""Generate the tracker logic from the Dusklight apworld's world graph.

Usage:
    python tools/gen_logic.py path/to/tp_dusklight.apworld

Writes:
  scripts/logic_data.lua   world graph, macros, settings and location data as Lua tables
  locations/**/*.json      each mapped section's access rule becomes "$DLAccess|<location name>"

The requirement strings are parsed with a port of the apworld's parser (logic.py, itself a
port of the randomizer's requirement.cpp). Settings comparisons are kept as nodes and folded at
runtime once the slot's settings are known (scripts/logic.lua), since the tracker only learns
them on connect.
"""
from __future__ import annotations

import glob
import io
import json
import sys
import zipfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DATA = Path(__file__).resolve().parent / "data"

WORLD_FILES = (
    "world/Root.yaml",
    "world/overworld/Ordona Province.yaml",
    "world/overworld/Faron Province.yaml",
    "world/overworld/Eldin Province.yaml",
    "world/overworld/Lanayru Province.yaml",
    "world/overworld/Snowpeak Province.yaml",
    "world/overworld/Gerudo Desert.yaml",
    "world/dungeons/Forest Temple.yaml",
    "world/dungeons/Goron Mines.yaml",
    "world/dungeons/Lakebed Temple.yaml",
    "world/dungeons/Arbiters Grounds.yaml",
    "world/dungeons/Snowpeak Ruins.yaml",
    "world/dungeons/Temple of Time.yaml",
    "world/dungeons/City in the Sky.yaml",
    "world/dungeons/Palace of Twilight.yaml",
    "world/dungeons/Hyrule Castle.yaml",
)
# From the apworld's __init__.py: exits Midna pulls Link across as a wolf.
TWILIGHT_GATES = None  # read from the apworld source


class LogicError(RuntimeError):
    pass


class Parser:
    """Port of tp_dusklight.logic.Parser, without folding settings comparisons."""

    def __init__(self, macros: dict[str, str], items: set[str], settings: dict[str, dict]):
        self.macros = macros
        self.macro_order = {name: i for i, name in enumerate(macros)}
        self.items = items
        self.settings = settings
        self._limit = len(macros)
        self.referenced_items: set[str] = set()
        self.referenced_events: set[str] = set()

    def parse(self, req: str, limit: int | None = None):
        saved, self._limit = self._limit, (len(self.macros) if limit is None else limit)
        try:
            return self._parse(req)
        finally:
            self._limit = saved

    def parse_macro(self, name: str):
        return self.parse(self.macros[name], self.macro_order[name])

    def _number(self, s: str):
        if s in self.settings:
            return {"setting": s}
        return int(s)

    def _parse(self, req_str: str):
        logic = list(req_str)
        nesting = 1
        delim = "+"
        for i, ch in enumerate(logic):
            if ch == "(":
                nesting += 1
            elif ch == ")":
                nesting -= 1
            if nesting == 1 and ch == " ":
                logic[i] = delim
        if nesting != 1:
            raise LogicError(f"parenthesis mismatch: {req_str!r}")
        s = "".join(logic)
        parts: list[str] = []
        while True:
            pos = s.find(delim)
            if pos == -1:
                break
            if s[pos - 1] not in "!=><" and s[pos + 1] not in "!=><":
                parts.append(s[:pos])
                s = s[pos + 1:]
            else:
                s = s[:pos] + s[pos + 1:]
        parts.append(s)

        if len(parts) == 1:
            arg = parts[0].replace("_", " ")
            if arg == "Nothing":
                return ["true"]
            if arg == "Human Link":
                return ["human"]
            if arg == "Wolf Link":
                return ["wolf"]
            if arg == "Twilight Wolf":
                return ["twilight_wolf"]
            if arg == "Twilight Human":
                return ["twilight_human"]
            if arg.startswith("'"):
                self.referenced_events.add(arg[1:-1])
                return ["event", arg[1:-1]]
            if self.macro_order.get(arg, self._limit) < self._limit:
                return ["macro", arg]
            if arg in self.items:
                self.referenced_items.add(arg)
                return ["item", arg]
            for op in ("!=", "==", ">=", "<="):
                if op in arg:
                    comp = arg.rfind("=")
                    option = arg[comp + 1:]
                    setting = arg[:comp - 1]
                    if setting not in self.settings:
                        raise LogicError(f"unknown setting {setting!r}")
                    if option not in self.settings[setting]["options"]:
                        raise LogicError(f"unknown option {option!r} for {setting!r}")
                    return ["cmp", setting, op, option]
            if "count" in arg:
                inner = arg[arg.find("(") + 1:-1]
                item_name, count_str = inner.split(", ")
                if item_name not in self.items:
                    raise LogicError(f"unknown item {item_name!r}")
                self.referenced_items.add(item_name)
                return ["count", self._number(count_str), item_name]
            if arg == "Day":
                return ["day"]
            if arg == "Night":
                return ["night"]
            if "hearts" in arg:
                return ["hearts", self._number(arg[arg.find("(") + 1:-1])]
            if arg == "Impossible":
                return ["false"]
            if "golden bugs" in arg:
                return ["bugs", int(arg[arg.find("(") + 1:-1])]
            if "dungeons completed" in arg:
                return ["dungeons", self._number(arg[arg.find("(") + 1:-1])]
            raise LogicError(f"unrecognized symbol: {req_str!r}")
        if len(parts) == 2:
            raise LogicError(f"2 part expression: {req_str!r}")
        is_and = "and" in parts
        is_or = "or" in parts
        if is_and == is_or:
            raise LogicError(f"bad operator mix: {req_str!r}")
        args = []
        for p in parts:
            if p in ("and", "or"):
                continue
            if p.startswith("("):
                p = p[1:-1]
            args.append(self._parse(p))
        return ["and" if is_and else "or", *args]


# --- Lua serialisation -----------------------------------------------------------------------

def lua(v, indent=""):
    if v is True:
        return "true"
    if v is False:
        return "false"
    if v is None:
        return "nil"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        inner = ", ".join(f"[{lua(k)}] = {lua(x)}" for k, x in v.items())
        return "{" + inner + "}"
    raise TypeError(v)


def settings_table(raw) -> dict[str, dict]:
    out = {}
    for node in raw:
        options = []
        for opt in node["Options"]:
            label = str(next(iter(opt))) if isinstance(opt, dict) else str(opt)
            lo, sep, hi = label.partition("-")
            if sep and lo.isdigit() and hi.isdigit():
                options.extend(str(n) for n in range(int(lo), int(hi) + 1))
            else:
                options.append(label)
        out[node["Name"]] = {"options": options, "default": str(node["Default Option"])}
    return out


class Apworld:
    def __init__(self, path: Path):
        self.path = path
        if path.is_dir():
            self._read = lambda n: (path / n).read_bytes()
        else:
            z = zipfile.ZipFile(path)
            names = z.namelist()

            def read(n: str) -> bytes:
                for x in names:
                    if x.endswith("/" + n):
                        return z.read(x)
                raise FileNotFoundError(n)
            self._read = read

    def yaml(self, name: str):
        return yaml.safe_load(io.TextIOWrapper(io.BytesIO(self._read("data/" + name)), encoding="utf-8"))

    def text(self, name: str) -> str:
        return self._read(name).decode("utf-8")


def twilight_gates(src: str) -> list[str]:
    start = src.index("TWILIGHT_GATES = frozenset({")
    end = src.index("})", start)
    return [line.strip().strip(",").strip('"') for line in src[start:end].splitlines()[1:]
            if line.strip().startswith('"')]


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    ap = Apworld(Path(sys.argv[1]))
    items_raw = ap.yaml("items.yaml")
    locations_raw = ap.yaml("locations.yaml")
    macros = {str(k): str(v) for k, v in ap.yaml("macros.yaml").items()}
    settings = settings_table(ap.yaml("settings_list.yaml"))
    gates = twilight_gates(ap.text("__init__.py"))
    items = {it["Name"]: it for it in items_raw}
    parser = Parser(macros, set(items), settings)

    macro_ast = {name: parser.parse_macro(name) for name in macros}
    areas = []
    for f in WORLD_FILES:
        for node in ap.yaml(f):
            areas.append({
                "name": node["Name"],
                "twilight": node.get("Twilight", "") or "",
                "can_change_time": bool(node.get("Can Change Time", False)),
                "can_transform": node.get("Can Transform", "Always") or "Always",
                "can_warp": bool(node.get("Can Warp", False)),
                "map_sector": node.get("Map Sector", "") or "",
                "events": [[str(k), parser.parse(str(v))] for k, v in (node.get("Events") or {}).items()],
                "locations": [[str(k), parser.parse(str(v))] for k, v in (node.get("Locations") or {}).items()],
                "exits": [[str(k), parser.parse(str(v))] for k, v in (node.get("Exits") or {}).items()],
            })
    # Twilight clearing macros, compiled by the apworld with every form allowed.
    for tw in sorted({a["twilight"] for a in areas if a["twilight"]}):
        name = f"Can Complete {tw} Twilight"
        if name not in macros:
            raise LogicError(f"missing macro {name!r}")

    locs = {}
    for loc in locations_raw:
        cats = sorted({c for c in (loc.get("Categories") or []) if c}
                      | (set(loc["Metadata"]) if isinstance(loc.get("Metadata"), dict) else set()))
        locs[loc["Name"]] = {"item": loc.get("Original Item", "Nothing"), "cats": cats}
    item_meta = {}
    for name, it in items.items():
        m = {}
        for key, field in (("small_key_of", "Dungeon Small Key"), ("big_key_of", "Dungeon Big Key"),
                           ("compass_of", "Dungeon Compass"), ("map_of", "Dungeon Map")):
            if it.get(field):
                m[key] = it[field]
        if m:
            item_meta[name] = m

    item_codes = {k: v for k, v in json.loads((DATA / "item_codes.json").read_text("utf-8")).items()
                  if not k.startswith("_")}
    out = [
        "-- GENERATED by tools/gen_logic.py from the Dusklight apworld. Do not edit by hand.",
        "DL_SETTINGS = " + lua({k: v for k, v in settings.items()}),
        "DL_ITEM_CODES = " + lua(item_codes),
        "DL_GOLDEN_BUGS = " + lua([n for n in items if n.startswith(("Male ", "Female "))]),
        "DL_TWILIGHT_GATES = " + lua({g: True for g in gates}),
        "DL_ITEM_META = " + lua(item_meta),
        "DL_MACROS = {",
    ]
    out += [f"\t[{lua(k)}] = {lua(v)}," for k, v in macro_ast.items()]
    out.append("}")
    out.append("DL_MACRO_ORDER = " + lua(list(macros)))
    out.append("DL_AREAS = {")
    for a in areas:
        out.append("\t" + lua(a) + ",")
    out.append("}")
    out.append("DL_LOCATIONS = {")
    for name, l in locs.items():
        out.append(f"\t[{lua(name)}] = {lua(l)},")
    out.append("}")
    (ROOT / "scripts/logic_data.lua").write_text("\n".join(out) + "\n", "utf-8")

    # Items the logic mentions that the tracker cannot count are reported: they are either
    # only ever placed vanilla (the logic collects them itself) or need adding to item_codes.json.
    uncounted = sorted(n for n in parser.referenced_items if n not in item_codes)
    print(f"areas: {len(areas)}, macros: {len(macros)}, locations: {len(locs)}")
    print(f"logic items not tracked by the pack ({len(uncounted)}): {uncounted}")

    rewrite_locations()
    return 0


# --- locations/*.json -----------------------------------------------------------------------

LOCATION_FILES = ("locations/overworld/*.json", "locations/dungeons/*.json")
SKIP_FILES = ("main map.json",)


def rewrite_locations() -> None:
    """Point every mapped section at the generated logic.

    A mapped section's rule becomes "$DLAccess|<name>" (or "$DLEvent|<event>" for the sections
    listed in event_sections.json). The old region rules on the locations
    above it are removed and pushed down into the sections that are not mapped (hint signs,
    boss markers, scents...), so those keep exactly the rule they had.
    """
    paths = json.loads((DATA / "location_paths.json").read_text("utf-8"))
    by_path = {p: "$DLAccess|" + name for name, ps in paths.items() for p in ps}
    # Non-check sections (howling stones, scents) follow a world graph event.
    events = json.loads((DATA / "event_sections.json").read_text("utf-8"))
    for p, value in events.items():
        if not p.startswith("_"):
            event, inspect = value
            rule = "$DLEvent|" + event
            by_path[p] = "{" + rule + "}" if inspect else rule
    found = set()

    def combine(a: list[str] | None, b: list[str] | None) -> list[str] | None:
        if not a:
            return b
        if not b:
            return a
        out = []
        for x in a:
            for y in b:
                out.append(", ".join(s for s in (x, y) if s))
        return out

    def has_mapped(node, prefix) -> bool:
        path = (prefix + "/" if prefix else "") + node["name"]
        if any(("@" + path + "/" + s.get("name", "")) in by_path for s in node.get("sections") or []):
            return True
        return any(has_mapped(c, path) for c in node.get("children") or [])

    def walk(node, prefix, inherited):
        path = (prefix + "/" if prefix else "") + node["name"]
        if not has_mapped(node, prefix):
            # Untouched subtree: put back the rules its ancestors lost.
            if inherited:
                node["access_rules"] = combine(inherited, node.get("access_rules"))
            return
        rules = combine(inherited, node.pop("access_rules", None))
        for s in node.get("sections") or []:
            code = "@" + path + "/" + s.get("name", "")
            rule = by_path.get(code)
            if rule:
                found.add(code)
                s["access_rules"] = [rule]
            else:
                s["access_rules"] = combine(rules, s.get("access_rules"))
        for c in node.get("children") or []:
            walk(c, path, rules)

    for pattern in LOCATION_FILES:
        for f in sorted(glob.glob(str(ROOT / pattern))):
            if Path(f).name in SKIP_FILES:
                continue
            raw = Path(f).read_text("utf-8-sig")
            data = json.loads(raw)
            for top in data:
                if "name" in top:
                    walk(top, "", None)
            Path(f).write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", "utf-8")
    missing = sorted(set(by_path) - found)
    print(f"sections pointed at the logic: {len(found)}")
    if missing:
        print(f"mapped paths with no section ({len(missing)}):")
        for p in missing:
            print("  ", p)


if __name__ == "__main__":
    sys.exit(main())
