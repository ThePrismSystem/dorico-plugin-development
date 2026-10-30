"""tools/setfield.ps1 on a box the form helper makes, without Dorico: it sets each kind of field, and it exits 3 when a
field doesn't take the value. Needs the Windows desktop.

    python tests/dorico/test_setfield.py
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "tools"))
import harness  # noqa: E402
import run_tests  # noqa: E402

TITLE = "setfield test"
# The form helper's script for a box with one field of each kind, written to the path in arg[1].
MAKE = """
package.path = "tests/lib/?.lua;" .. package.path
local form = require("helpers").load("examples/fundamentals/17-ask-and-report.lua", "form")
local f = assert(io.open(arg[1], "wb"))
f:write("\\239\\187\\191" .. form.script("TITLE", {
  { key = "words", label = "Words", kind = "text", default = "" },
  { key = "tick", label = "Tick", kind = "check", default = false },
  { key = "pick", label = "Pick", kind = "choice", default = "one", choices = { "one", "two" } },
}))
f:close()
""".replace("TITLE", TITLE)


def setfield(kind, index, value):
    return subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(harness.SETFIELD),
                           "-Window", TITLE, "-Kind", kind, "-Index", str(index), "-Value", value],
                          capture_output=True, text=True)


@unittest.skipUnless(sys.platform == "win32", "needs the Windows desktop")
class SetFieldTests(unittest.TestCase):
    def setUp(self):
        folder = Path(tempfile.mkdtemp(prefix="hbuc-setfield-"))
        self.answer = folder / "answer.txt"
        script = folder / "box.ps1"
        lua = run_tests.find_lua()
        self.assertIsNotNone(lua, "no Lua 5.2")
        maker = folder / "make.lua"
        maker.write_text(MAKE, encoding="utf-8")
        subprocess.run([lua, str(maker), str(script)], cwd=ROOT, check=True)
        self.box = subprocess.Popen(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                                     "-Out", str(self.answer)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(self.close)
        self.assertTrue(harness.run_lua.wait_for(lambda: TITLE in harness.run_lua.open_windows(), 60),
                        "the box didn't open")

    def close(self):
        if self.box.poll() is None:
            harness.click(TITLE, "Cancel")
        try:
            self.box.wait(30)
        except subprocess.TimeoutExpired:
            self.box.kill()

    def test_sets_each_kind_of_field(self):
        for kind, value in (("text", "hello"), ("check", "true"), ("choice", "1")):
            proc = setfield(kind, 0, value)
            self.assertEqual(proc.returncode, 0, proc.stdout)
        self.assertTrue(harness.click(TITLE, "OK"))
        self.box.wait(30)
        self.assertEqual(self.answer.read_text(encoding="utf-8"), "words=hello\ntick=True\npick=two")

    def test_a_choice_the_list_doesnt_have_exits_3(self):
        proc = setfield("choice", 0, "5")
        self.assertEqual(proc.returncode, 3, proc.stdout)
        self.assertIn("couldn't set", proc.stdout)

    def test_a_field_that_isnt_there_exits_3(self):
        proc = setfield("text", 4, "hello")
        self.assertEqual(proc.returncode, 3, proc.stdout)


if __name__ == "__main__":
    unittest.main()
