"""Turn spikes/class_members.lua's output into docs/reference/members.json.

    python tools/members.py [members-raw.json]    (default: the run folder's)

The probe names the tables of static members itself. Instance members sit in tables with no name on them, so this
names each by the members it holds, with the rules in INSTANCE below: a table is a class's when it has all of that
class's listed members. A table no rule fits stays in "unnamed", with its members.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import run_lua  # noqa: E402

OUT = ROOT / "docs" / "reference" / "members.json"

# class -> members its instance table must have (and, where two classes share members, ones it must not have).
INSTANCE = {
    "DoApp.DoApp": ({"currentScore", "doCommand", "versionString"}, set()),
    "DoUI.DoUI": ({"showFolderChooser"}, {"currentScore"}),
    "DoScore.Score": ({"flows", "players", "layouts", "openScoreID", "title"}, set()),
    "DoCore.ScriptHost": ({"convertFolderOfScores", "createNewScore"}, set()),
    "DoCore.Flow": ({"voiceStreams", "removePlayer"}, set()),
    "DoCore.FlowElements": ({"barDivisions", "dynamics", "tonalityDivisions"}, set()),
    "DoCore.Layout": ({"addFlow", "removeFlow"}, set()),
    "DoCore.Player": ({"instruments"}, {"flows", "voiceStreams", "addFlow", "clefs"}),
    "DoCore.ScoreLibraries": ({"brushstyles", "clefs", "instruments", "penstyles"}, set()),
    "DoCore.FlowInstrument": ({"id", "name", "streams"}, set()),
    "DoCore.Instrument": ({"id", "name"}, {"streams"}),
    "DoCore.EventStream": ({"createNote", "dump", "blockInstances"}, set()),
    "DoCore.EventBlockInstance": ({"block", "events", "position"}, set()),
    "DoCore.EventBlock": ({"events", "id"}, {"block", "position", "propertyTable", "subElements", "dump"}),
    "DoCore.EventPropertyTable": ({"get", "set", "getPropertyNames"}, set()),
    "DoCore.EventPropertyEntry": ({"context", "name", "value"}, set()),
    "DoCore.NoteEvent": ({"pitchWithSpelling"}, {"secondaryPosition"}),
    "DoCore.GraceNoteEvent": ({"pitchWithSpelling", "secondaryPosition"}, set()),
    "DoCore.TextEvent": ({"text", "propertyTable"}, set()),
    "DoCore.TupletEvent": ({"tupletDef"}, set()),
    "DoCore.TonalityDivisionEvent": ({"tonalityDivisionElementID"}, set()),
    "DoCore.ClefEvent": ({"nonTransposingClefEntity", "transposingClefEntity"}, set()),
    "DoCore.OttavaLineEvent": ({"ottavaLineDefinitionID"}, set()),
    "DoCore.BreakEvent": ({"isSystemBreak", "isFrameBreak"}, set()),
    "DoCore.BarDivisionTable": ({"createBarDivisionElement", "elements"}, set()),
    "DoCore.DynamicTable": ({"createDynamicGroup", "elements"}, set()),
    "DoCore.DynamicGroupElement": ({"createImmediateChange", "subElements"}, set()),
    "DoCore.CaretLocation": ({"flowInstrument", "voiceNumber", "advance"}, set()),
    "DoCore.StepTimeInput": ({"caret", "fromText"}, set()),
    "DoCore.MIDIPitchWithSpelling": ({"noteName", "octave", "accidentalType", "pitch"}, set()),
    "DoCore.Interval": ({"numDiatonicSteps", "numOctaves"}, set()),
    "DoCore.IntervalDegree": ({"chromaticDelta", "degree"}, set()),
    "DoCore.RhythmicLength": ({"numerator", "denominator"}, set()),
    "DoCore.Variant": ({"toString", "valid"}, set()),
    "DoCore.TupletDefinition": ({"left", "right", "notatedDuration"}, set()),
}

# Event classes with no members of their own share the base event's members, so their tables can't be told apart.
PLAIN_EVENTS = ["DoCore.Event", "DoCore.RestEvent", "DoCore.BarRestEvent", "DoCore.BarDivisionEvent",
                "DoCore.DynamicGroupEvent"]
PLAIN_EVENT_MEMBERS = {"duration", "endPosition", "id", "position", "propertyTable"}


def own(members):
    return {m["name"] for m in members}


def build(raw):
    classes = {name: {} for name in raw["classes"]}
    for name, members in raw["members"].items():
        classes.setdefault(name, {})["static"] = sorted(own(members))
    unnamed, plain = [], 0
    for table in raw["unmatched"]:
        names = own(table["members"])
        public = {n for n in names if not n.startswith("__")}
        if "_G" in names or not public:
            continue  # the globals table, and luabind's own class metatables
        if public == {"attributes", "methods", "name"}:
            continue  # luabind's class_info results
        if public == PLAIN_EVENT_MEMBERS:
            plain += 1
            continue
        fits = [c for c, (need, avoid) in INSTANCE.items() if need <= names and not (avoid & names)]
        if len(fits) == 1 and "instance" not in classes.get(fits[0], {}):
            classes.setdefault(fits[0], {})["instance"] = sorted(names)
        else:
            unnamed.append(sorted(names))
    if plain:  # only when the scan saw such a table
        for name in PLAIN_EVENTS:
            classes.setdefault(name, {})["instance"] = sorted(PLAIN_EVENT_MEMBERS | {"__eq", "__len", "__tostring"})
    return {"dorico": raw["dorico"], "classes": classes, "plainEventTables": plain,
            "unnamed": sorted(unnamed)}


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else run_lua.RUN_DIR / "members-raw.json"
    out = build(json.loads(src.read_text(encoding="utf-8")))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=1, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    named = sum(1 for c in out["classes"].values() if c)
    print(f"{len(out['classes'])} classes, {named} with members, {len(out['unnamed'])} tables unnamed, "
          f"{out['plainEventTables']} plain event tables -> {OUT}")


if __name__ == "__main__":
    main()
