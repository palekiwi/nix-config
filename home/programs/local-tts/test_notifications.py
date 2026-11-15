import asyncio
import json
import shutil
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from cube_control import Controller, HostExecutor, decode, serve
from notifications import duration, notification, notify_argv
from test_cube_control import LiveTests


def event(**fields):
    return dict(
        v=1, sid="session-qa", host="casm", kind="settled", aborted=False, **fields
    )


class NotificationTests(unittest.IsolatedAsyncioTestCase):
    async def test_wording_and_identity(self):
        result = notification("agent.evt.session-qa.settled", event())
        self.assertEqual(result, {"summary": "session-qa idle", "body": "casm"})
        body = event(session_name="Worker", cwd="/project", error="secret failure text")
        body["aborted"] = True
        result = notification("agent.evt.session-qa.settled", body)
        self.assertEqual(result["summary"], "Worker idle (aborted, error)")
        self.assertEqual(result["body"], "/project\ncasm")
        self.assertNotIn("secret", str(result))
        calls = []

        async def call(subject, payload):
            calls.append((subject, payload))
            return {"accepted": True}

        await Controller(call).handle("agent.evt.session-qa.settled", event())
        self.assertEqual(calls[0][0], "host.cmd.notify")

    async def test_v2_layout(self):
        full = event(
            context="palekiwi/palekiwi/controller-design",
            context_title="Controller design for the NATS platform",
            session_name="named",
            cwd="/home/pl/code/palekiwi/palekiwi",
            run_id="20261114-134753-ae2a53-builder-1",
            agent="builder",
            errored=False,
            turn_ms=192_400,
            tools=14,
        )
        self.assertEqual(
            notification("agent.evt.session-qa.settled", full),
            {
                "summary": "Controller design for the NATS platform idle",
                "body": "palekiwi/palekiwi/controller-design\n"
                "~/code/palekiwi/palekiwi\n"
                "agent builder\n"
                "turn 3m12s, 14 tools\n"
                "casm",
            },
        )
        fallbacks = (
            ({"context": "o/r/ctx-slug", "session_name": "n"}, "ctx-slug idle"),
            ({"session_name": "named", "cwd": "/w/repo"}, "named idle"),
            ({"cwd": "/home/pl/code/repo/"}, "repo idle"),
            ({"context_title": "  ", "cwd": ""}, "session-qa idle"),
        )
        for fields, summary in fallbacks:
            self.assertEqual(
                notification("agent.evt.session-qa.settled", event(**fields))[
                    "summary"
                ],
                summary,
            )
        aborted = event(context_title="T", errored=True, turn_ms=999, tools=1)
        aborted["aborted"] = True
        self.assertEqual(
            notification("agent.evt.session-qa.settled", aborted),
            {"summary": "T idle (aborted, error)", "body": "turn 0s, 1 tool\ncasm"},
        )
        self.assertEqual(
            notification("agent.evt.session-qa.settled", event(errored=True))[
                "summary"
            ],
            "session-qa idle (error)",
        )
        self.assertEqual(
            [duration(v) for v in (0, 59_999, 60_000, 3_725_000, -1, "5", None)],
            ["0s", "59s", "1m00s", "1h02m", "", "", ""],
        )
        long = event(context_title="t" * 300, errored=True)
        long["aborted"] = True
        self.assertLessEqual(
            len(notification("agent.evt.session-qa.settled", long)["summary"]), 100
        )
        notify_argv("n", notification("agent.evt.session-qa.settled", long))

    async def test_deny_list(self):
        calls = []

        async def call(subject, payload):
            calls.append((subject, payload))
            return {"accepted": True}

        controller = Controller(call, ["summarizer", "compactor"])
        for agent in ("summarizer", "compactor"):
            result = await controller.handle(
                "agent.evt.session-qa.settled", event(agent=agent)
            )
            self.assertEqual(result, {"accepted": True, "reason": "denied agent"})
        self.assertEqual(calls, [])
        await controller.handle("agent.evt.session-qa.settled", event(agent="builder"))
        await controller.handle("agent.evt.session-qa.settled", event())
        self.assertEqual(len(calls), 2)
        with self.assertRaises(ValueError):
            await controller.handle(
                "agent.evt.session-qa.settled", {**event(agent="summarizer"), "v": 2}
            )
        await Controller(call).handle(
            "agent.evt.session-qa.settled", event(agent="summarizer")
        )
        self.assertEqual(len(calls), 3)

    async def test_subject_schema_and_malformed_payloads(self):
        for subject in (
            "agent.evt.other.settled",
            "agent.evt.session-qa.end",
            "agent.evt.session-qa.more.settled",
        ):
            with self.assertRaises(ValueError):
                notification(subject, event())
        for key, value in (
            ("v", 2),
            ("sid", []),
            ("host", None),
            ("aborted", "false"),
            ("kind", "end"),
        ):
            body = event()
            body[key] = value
            with self.assertRaises(ValueError):
                notification("agent.evt.session-qa.settled", body)
        for data in (b"[1]", b"{", b"\xff", b" " * 8193):
            with self.assertRaises(ValueError):
                decode(data, 8192)
        result = notification(
            "agent.evt.session-qa.settled",
            event(session_name="x" * 3000, cwd="y" * 3000),
        )
        self.assertLessEqual(len(result["body"]), 256)

    async def test_fixed_argv_sanitization_and_failure(self):
        payload = notification(
            "agent.evt.session-qa.settled",
            event(session_name="<b>$(touch /tmp/no)</b>\n\x00\u202e"),
        )
        args = notify_argv("/fixed/notify-send", payload)
        self.assertEqual(
            args[:5],
            [
                "/fixed/notify-send",
                "--app-name=Agent controller",
                "--urgency=normal",
                "--expire-time=8000",
                "--",
            ],
        )
        self.assertNotIn("<b>", args[-2])
        self.assertNotIn("\n", args[-2])
        self.assertNotIn("\u202e", args[-2])
        injected = notify_argv(
            "/fixed/notify-send",
            {"summary": "x idle", "body": "<i>a</i>\n\x00\u202eb\r\n\nc"},
        )
        self.assertEqual(injected[-1], "&lt;i&gt;a&lt;/i&gt;\nb\nc")

        class Process:
            returncode = 1

            async def wait(self):
                return 1

        with patch(
            "cube_control.asyncio.create_subprocess_exec", return_value=Process()
        ) as spawn:
            result = await HostExecutor("handy", "wpctl", "/fixed/notify-send").handle(
                "host.cmd.notify", {**payload, "ts": time.time()}
            )
            self.assertFalse(result["accepted"])
            spawn.assert_awaited_once_with(*args)
        with self.assertRaises(ValueError):
            notify_argv("notify-send", {"summary": "anything", "body": "x"})


@unittest.skipUnless(
    shutil.which("nats-server") and shutil.which("mosquitto"), "requires brokers"
)
class NotificationLiveTests(LiveTests):
    async def test_live_only_notifications_and_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "calls"
            executable = Path(directory) / "notify"
            executable.write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" >> {output}\n')
            executable.chmod(0o700)
            await self.nc.publish(
                "agent.evt.session-qa.settled", json.dumps(event()).encode()
            )
            await self.nc.flush()
            executor = asyncio.create_task(
                serve(self.url, "executor", notify_send=str(executable))
            )
            controller = asyncio.create_task(serve(self.url, "controller"))
            self.tasks.extend([executor, controller])
            await asyncio.sleep(0.2)
            self.assertFalse(output.exists())
            for subject, data in (
                ("agent.evt.session-qa.end", event()),
                ("agent.evt.session-qa.settled", []),
            ):
                await self.nc.publish(subject, json.dumps(data).encode())
            await asyncio.sleep(0.1)
            self.assertFalse(output.exists())
            await self.nc.publish(
                "agent.evt.session-qa.settled", json.dumps(event()).encode()
            )
            result = await self.until("host.evt.execution")
            self.assertTrue(result["accepted"])
            self.assertIn("session-qa idle", output.read_text())
            original = output.read_text()
            controller.cancel()
            await asyncio.gather(controller, return_exceptions=True)
            await self.nc.publish(
                "agent.evt.session-qa.settled", json.dumps(event()).encode()
            )
            await self.nc.flush()
            self.tasks.append(
                asyncio.create_task(
                    serve(self.url, "controller", deny_agents=["summarizer"])
                )
            )
            await asyncio.sleep(0.2)
            self.assertEqual(output.read_text(), original)
            await self.nc.publish(
                "agent.evt.session-qa.settled", json.dumps(event()).encode()
            )
            await self.until("host.evt.execution")
            self.assertEqual(output.read_text().count("session-qa idle"), 2)
            await self.nc.publish(
                "agent.evt.session-qa.settled",
                json.dumps(event(agent="summarizer")).encode(),
            )
            while (await self.until("cube.evt.controller.result")).get(
                "reason"
            ) != "denied agent":
                pass
            await asyncio.sleep(0.1)
            self.assertEqual(output.read_text().count("session-qa idle"), 2)
