"""tools/members.py: naming the tables spikes/class_members.lua found."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import members  # noqa: E402


def scan(*tables):
    """A scan's output with these unnamed tables, each a set of member names."""
    return {"dorico": "6.2.30", "classes": ["DoCore.Event", "DoCore.RestEvent"], "members": {},
            "unmatched": [{"members": [{"name": n} for n in sorted(t)]} for t in tables]}


class PlainEventTests(unittest.TestCase):
    def test_plain_event_classes_come_only_from_tables_the_scan_found(self):
        # members.json lists only what a probe saw
        out = members.build(scan())
        self.assertEqual(out["plainEventTables"], 0)
        for name in members.PLAIN_EVENTS:
            self.assertNotIn("instance", out["classes"].get(name, {}), name)

    def test_a_plain_event_table_names_every_plain_event_class(self):
        out = members.build(scan(members.PLAIN_EVENT_MEMBERS))
        self.assertEqual(out["plainEventTables"], 1)
        for name in members.PLAIN_EVENTS:
            self.assertIn("propertyTable", out["classes"][name]["instance"], name)


if __name__ == "__main__":
    unittest.main()
