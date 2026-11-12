import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "home/programs/gui/dmenu/xrandr.nu"
PANEL = "eDP-1 connected primary 1920x1200+0+0 (normal)"
EXTERNAL = "DP-3 connected 3440x1440+0+0 (normal)"


class DisplayLayoutTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.calls = self.root / "calls"
        self.calls.touch()
        self.state = self.root / "state"
        self.state.write_text(PANEL + "\n" + EXTERNAL + "\n")
        self.env = dict(os.environ, FIXTURE=str(self.root), HOST="pale", CHOICE="ultrawide")
        self.env["PATH"] = f"{self.root}:{os.environ['PATH']}"
        self.command("xrandr", '''import os, pathlib, sys
root = pathlib.Path(os.environ["FIXTURE"])
if sys.argv[1:] == ["--query"]:
    print((root / "state").read_text())
    sys.exit(0)
with (root / "calls").open("a") as f:
    f.write("xrandr " + " ".join(sys.argv[1:]) + "\\n")
sys.exit(1 if (root / "fail").exists() else 0)
''')
        self.command("uname", 'import os\nprint(os.environ["HOST"])\n')
        self.command("dmenu", '''import os, pathlib, sys
root = pathlib.Path(os.environ["FIXTURE"])
(root / "menu").write_text(sys.stdin.read())
print(os.environ["CHOICE"])
''')
        for name in ("awesome-client", "systemctl", "notify-send"):
            self.command(name, f'''import os, pathlib, sys
with (pathlib.Path(os.environ["FIXTURE"]) / "calls").open("a") as f:
    f.write({name!r} + " " + " ".join(sys.argv[1:]) + "\\n")
''')

    def command(self, name, text):
        path = self.root / name
        path.write_text("#!/usr/bin/env python3\n" + text)
        path.chmod(0o755)

    def run_profile(self, *args, success=True):
        result = subprocess.run(
            ["nu", str(SCRIPT), *args], env=self.env,
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return self.calls.read_text()

    def test_auto_docked_layout_only(self):
        calls = self.run_profile("--profile", "auto", "--layout-only")
        self.assertEqual(calls.splitlines(), [
            "xrandr --output DP-3 --mode 3440x1440 --rate 59.97 --pos 0x0 --primary --output eDP-1 --off",
        ])
        self.assertFalse((self.root / "menu").exists())

    def test_auto_builtin_disconnected_external(self):
        self.state.write_text(PANEL + "\nDP-3 disconnected\n")
        calls = self.run_profile("--profile", "auto", "--layout-only")
        self.assertEqual(calls.splitlines(), [
            "xrandr --output eDP-1 --auto --primary --output DP-3 --off",
        ])

    def test_auto_builtin_absent_external(self):
        self.state.write_text(PANEL + "\n")
        calls = self.run_profile("--profile", "auto", "--layout-only")
        self.assertEqual(calls, "xrandr --output eDP-1 --auto --primary\n")

    def test_explicit_profile_does_not_auto_select(self):
        calls = self.run_profile("--profile", "builtin", "--layout-only")
        self.assertIn("--output eDP-1 --auto --primary", calls)
        self.assertIn("--output DP-3 --off", calls)
        self.assertNotIn("awesome-client", calls)
        self.assertNotIn("systemctl", calls)

    def test_noninteractive_session_profile(self):
        calls = self.run_profile("--profile", "ultrawide")
        self.assertIn("awesome-client awesome.restart()", calls)
        self.assertIn("systemctl --user restart opentabletdriver", calls)
        self.assertFalse((self.root / "menu").exists())

    def test_interactive_menu(self):
        calls = self.run_profile()
        self.assertEqual((self.root / "menu").read_text().splitlines(), [
            "builtin", "ultrawide", "huion", "builtin+huion", "ultrawide+viture", "ultrawide+huion",
        ])
        self.assertEqual([line.split()[0] for line in calls.splitlines()], [
            "xrandr", "awesome-client", "systemctl",
        ])

    def test_cancel(self):
        self.env["CHOICE"] = ""
        self.assertEqual(self.run_profile(), "")

    def test_invalid_profile(self):
        self.assertEqual(self.run_profile("--profile", "invalid", success=False), "")

    def test_failure_has_no_session_effects(self):
        (self.root / "fail").touch()
        calls = self.run_profile("--profile", "auto", "--layout-only", success=False)
        self.assertNotIn("awesome-client", calls)
        self.assertNotIn("systemctl", calls)
        self.assertNotIn("notify-send", calls)

    def test_unknown_active_output_fails_without_mutation(self):
        self.assertEqual(self.run_profile("--profile", "huion", success=False), "")

    def test_deck_profiles_unchanged(self):
        self.env["HOST"] = "deck"
        self.env["CHOICE"] = "dual"
        self.state.write_text("eDP-1 connected\nDP-1 connected\n")
        calls = self.run_profile()
        self.assertIn("--output DP-1 --auto --primary", calls)
        self.assertIn("--output eDP-1 --rotate right --auto --below DP-1", calls)
        self.assertIn("awesome-client awesome.restart()", calls)

    def test_single_source_and_no_autostart_layout(self):
        module = (ROOT / "hosts/pale/awesome.nix").read_text()
        self.assertIn("import ../../home/programs/gui/dmenu/xrandr.nix", module)
        self.assertIn("displayManager.sessionCommands", module)
        self.assertEqual(module.count("--profile auto --layout-only"), 2)
        self.assertNotIn("3440", module)
        self.assertFalse((ROOT / "hosts/pale/display-layout.sh").exists())
        autostart = (ROOT / "home/config/awesome/pale.autostart.sh").read_text()
        self.assertNotIn("display-layout", autostart)
        self.assertNotIn("xrandr", autostart)
        self.assertNotIn("--watch", SCRIPT.read_text())

    def test_split_uses_pale_primary_only(self):
        rc = (ROOT / "home/config/awesome/rc.lua").read_text()
        setup = rc.split("local function setup_fake_screens(s)", 1)[1]
        setup = "local function setup_fake_screens(s)" + setup.split(
            "setup_fake_screens(screen)", 1
        )[0]
        code = setup + '''
FAKE_RESIZE_DELTA = 0
for _, host in ipairs({"pale", "deck"}) do
  awesome = { hostname = host }
  local resized, added = 0, 0
  local panel = { geometry = { x = 0, y = 0, width = 1920, height = 1200 } }
  local wide = { geometry = { x = 0, y = 0, width = 3440, height = 1440 } }
  wide.fake_resize = function(_, x, y, width, height)
    assert(x == 1720 and width == 1720 and height == 1440)
    resized = resized + 1
  end
  local screens = { panel, primary = wide }
  screens.fake_add = function(x, y, width, height)
    assert(x == 0 and width == 1720 and height == 1440)
    added = added + 1
  end
  setup_fake_screens(screens)
  assert(resized == (host == "pale" and 1 or 0))
  assert(added == resized)
end
'''
        result = subprocess.run(["luajit", "-e", code], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
