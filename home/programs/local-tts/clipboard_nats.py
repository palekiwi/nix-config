import argparse
import asyncio
import fcntl
import json
import os
from pathlib import Path
import sys
import uuid

import nats
import speak


async def toggle(nc, read_clipboard, max_chars=1000):
    async def request(subject, body):
        reply = await nc.request(subject, json.dumps(body).encode(), timeout=2)
        return json.loads(reply.data)

    state = await request("speech.query.state", {})
    if state["active"]:
        result = await request("speech.intent.stop", {"origin": "clipboard"})
        if not result.get("accepted"):
            raise ValueError("stop rejected")
        return
    text = speak.clean_markdown(read_clipboard()).strip()
    if not text:
        return
    utt = str(uuid.uuid4())
    for seq, start in enumerate(range(0, len(text), max_chars)):
        result = await request("speech.intent.say", {
            "utt": utt, "seq": seq, "final": start + max_chars >= len(text),
            "text": text[start:start + max_chars], "origin": "clipboard",
        })
        if not result.get("accepted"):
            raise ValueError("speech rejected (held, replaced or full)")


async def run(args):
    nc = await nats.connect(args.url, connect_timeout=2, max_reconnect_attempts=0)
    try:
        await toggle(nc, lambda: speak.read_input(
            argparse.Namespace(clipboard=True, file=None, text=[]), sys.stdin
        ), args.max_chars)
    finally:
        await nc.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--max-chars", type=int, default=1000)
    args = parser.parse_args()
    try:
        with (Path(os.environ["XDG_RUNTIME_DIR"]) / "clipboard-speech.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            asyncio.run(run(args))
        return 0
    except (KeyError, OSError, ValueError, nats.errors.Error) as error:
        print(f"clipboard-speech-toggle: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
