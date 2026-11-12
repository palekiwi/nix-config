import fcntl
import os
import subprocess
import sys
from pathlib import Path

UNIT = "clipboard-speech.service"


def toggle(runtime, systemctl):
    def control(*args, **kwargs):
        return subprocess.run([systemctl, "--user", *args], check=True, **kwargs)

    with (Path(runtime) / "clipboard-speech.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = control(
            "show",
            "--property=ActiveState",
            "--value",
            UNIT,
            capture_output=True,
            text=True,
        ).stdout.strip()
        if state in {"active", "activating", "deactivating", "reloading"}:
            control("stop", UNIT)
        elif state in {"inactive", "failed"}:
            names = [
                name
                for name in ("DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY")
                if name in os.environ
            ]
            if names:
                control("import-environment", *names)
            control("start", UNIT)
        else:
            raise ValueError(f"unexpected clipboard speech state: {state!r}")


def main():
    try:
        toggle(os.environ["XDG_RUNTIME_DIR"], sys.argv[1])
        return 0
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"clipboard-speech-toggle: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
