import asyncio
import json
import shutil
import tempfile
import threading
import time
import unittest
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

from cube_control import Controller, HostExecutor, decode, serve
from notifications import duration, gotify_message, notification, notify_argv
from test_cube_control import LiveTests, free_port

TOKEN = "AbC.123-token"
IDLE_QA = "--\nsession-qa\n── idle\n"


class Gotify:
    def __init__(self, status=200, delay=0):
        self.requests = []
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                time.sleep(delay)
                length = int(self.headers["Content-Length"])
                owner.requests.append(
                    (
                        self.path,
                        dict(self.headers),
                        json.loads(self.rfile.read(length)),
                    )
                )
                self.send_response(status)
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"{}")

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = True
        self.server.handle_error = lambda *args: None
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


def token_file(directory, text=TOKEN + "\n", name="token"):
    path = Path(directory) / name
    path.write_text(text)
    return str(path)


def event(**fields):
    return dict(
        v=1, sid="session-qa", host="casm", kind="settled", aborted=False, **fields
    )


class NotificationTests(unittest.IsolatedAsyncioTestCase):
    async def test_wording_and_identity(self):
        result = notification("agent.evt.session-qa.settled", event())
        self.assertEqual(
            result,
            {"summary": "session-qa", "body": "── idle", "source": "interactive"},
        )
        body = event(session_name="Worker", cwd="/project", error="secret failure text")
        body["aborted"] = True
        result = notification("agent.evt.session-qa.settled", body)
        self.assertEqual(result["summary"], "Worker")
        self.assertEqual(result["body"], "── aborted, error")
        self.assertNotIn("secret", str(result))
        calls = []

        async def call(subject, payload):
            calls.append((subject, payload))
            return {"accepted": True}

        await Controller(call).handle("agent.evt.session-qa.settled", event())
        self.assertEqual(calls[0][0], "host.cmd.notify")

    async def test_interactive_layout(self):
        full = event(
            context="palekiwi/palekiwi/controller-design",
            context_title="Controller design for the NATS platform",
            session_name="named",
            session_description="  Simplify\nnotifications  ",
            tmux_window="notifications",
            tmux_session="palekiwi",
            cwd="/home/pl/code/palekiwi/palekiwi",
            errored=False,
            turn_ms=192_400,
            tools=14,
        )
        self.assertEqual(
            notification("agent.evt.session-qa.settled", full),
            {
                "summary": "notifications",
                "body": "Simplify notifications\n── idle · palekiwi",
                "source": "interactive",
            },
        )
        bare = event(tmux_window="w", tmux_session="s", cwd="/home/pl/x")
        self.assertEqual(
            notification("agent.evt.session-qa.settled", bare)["body"],
            "── idle · s",
        )
        described = event(tmux_window="w", session_description="Only text")
        self.assertEqual(
            notification("agent.evt.session-qa.settled", described)["body"],
            "Only text\n── idle",
        )
        tasked = event(
            tmux_window="w",
            tmux_session="s",
            session_description="Text",
            active_task="palekiwi/palekiwi/notifications/task/notify-task.md",
        )
        self.assertEqual(
            notification("agent.evt.session-qa.settled", tasked)["body"],
            "task: notify-task\nText\n── idle · s",
        )
        for missing in ("", " \n ", None, 3):
            self.assertEqual(
                notification(
                    "agent.evt.session-qa.settled",
                    event(tmux_window="w", active_task=missing),
                )["body"],
                "── idle",
            )
        blank = event(tmux_window="w", tmux_session=" \n ")
        self.assertEqual(
            notification("agent.evt.session-qa.settled", blank),
            {"summary": "w", "body": "── idle", "source": "interactive"},
        )
        fallbacks = (
            ({"tmux_window": " ", "session_name": "named"}, "named"),
            ({"context": "o/r/ctx-slug", "session_name": "n"}, "n"),
            ({"context": "o/r/ctx-slug", "cwd": "/w/repo"}, "ctx-slug"),
            ({"cwd": "/home/pl/code/repo/"}, "session-qa"),
            ({"context_title": "  ", "cwd": ""}, "session-qa"),
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
            {"summary": "T", "body": "── aborted, error", "source": "interactive"},
        )
        self.assertEqual(
            notification(
                "agent.evt.session-qa.settled", event(errored=True, tmux_session="s")
            )["body"],
            "── error · s",
        )
        self.assertEqual(
            [duration(v) for v in (0, 59_999, 60_000, 3_725_000, -1, "5", None)],
            ["0s", "59s", "1m00s", "1h02m", "", "", ""],
        )
        long = event(tmux_window="t" * 300, errored=True)
        long["aborted"] = True
        self.assertLessEqual(
            len(notification("agent.evt.session-qa.settled", long)["summary"]), 100
        )
        notify_argv("n", notification("agent.evt.session-qa.settled", long))

    async def test_headless_layout(self):
        run = event(
            agent="builder",
            run_id="20261114-134753-ae2a53-builder-1",
            session_name="named",
            session_description="Not shown",
            tmux_window="parent-window",
            tmux_session="palekiwi",
            context="palekiwi/palekiwi/controller-design",
            active_task="palekiwi/palekiwi/controller-design/task/layout.md",
            cwd="/home/pl/code/palekiwi/palekiwi",
        )
        self.assertEqual(
            notification("agent.evt.session-qa.settled", run),
            {"summary": "builder", "body": "── idle", "source": "headless"},
        )
        failed = event(agent="reviewer", errored=True)
        failed["aborted"] = True
        self.assertEqual(
            notification("agent.evt.session-qa.settled", failed),
            {
                "summary": "reviewer",
                "body": "── aborted, error",
                "source": "headless",
            },
        )
        self.assertEqual(
            notification("agent.evt.session-qa.settled", event(agent="")),
            {"summary": "session-qa", "body": "── idle", "source": "headless"},
        )

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

    async def test_gotify_routing(self):
        calls = []

        async def call(subject, payload):
            calls.append((subject, payload))
            return {"accepted": True}

        controller = Controller(call, ["summarizer"], (5, 7))
        result = await controller.handle(
            "agent.evt.session-qa.settled", event(context_title="Design", tools=2)
        )
        self.assertEqual(result, {"accepted": True, "channels": ["notify", "gotify"]})
        self.assertEqual([s for s, _ in calls], ["host.cmd.notify", "host.cmd.gotify"])
        notify, gotify = calls[0][1], calls[1][1]
        self.assertEqual(
            {k: gotify[k] for k in ("title", "message", "priority")},
            {"title": "Design", "message": "── idle", "priority": 5},
        )
        self.assertNotIn("source", gotify)
        self.assertEqual(notify["source"], "interactive")
        self.assertEqual(gotify["title"], notify["summary"])
        self.assertEqual(gotify["message"], notify["body"])
        self.assertNotEqual(gotify["id"], notify["id"])
        self.assertIsInstance(gotify["ts"], float)
        for fields in ({"aborted": True}, {"errored": True}):
            calls.clear()
            await controller.handle(
                "agent.evt.session-qa.settled", {**event(), **fields}
            )
            self.assertEqual(calls[1][1]["priority"], 7)
        for agent, expected in (
            ("builder", ["host.cmd.notify"]),
            ("", ["host.cmd.notify"]),
            ("summarizer", []),
        ):
            calls.clear()
            await controller.handle("agent.evt.session-qa.settled", event(agent=agent))
            self.assertEqual([s for s, _ in calls], expected)
        calls.clear()
        await Controller(call).handle("agent.evt.session-qa.settled", event())
        self.assertEqual([s for s, _ in calls], ["host.cmd.notify"])

    async def test_gotify_channels_are_independent(self):
        for failing in ("host.cmd.notify", "host.cmd.gotify"):
            calls = []

            async def call(subject, payload):
                calls.append(subject)
                if subject == failing:
                    raise TimeoutError
                return {"accepted": subject != failing}

            with self.assertRaisesRegex(RuntimeError, failing):
                await Controller(call, (), (5, 7)).handle(
                    "agent.evt.session-qa.settled", event()
                )
            self.assertEqual(calls, ["host.cmd.notify", "host.cmd.gotify"])

        async def reject(subject, payload):
            return {"accepted": subject == "host.cmd.notify"}

        with self.assertRaisesRegex(RuntimeError, "host.cmd.gotify rejected"):
            await Controller(reject, (), (5, 7)).handle(
                "agent.evt.session-qa.settled", event()
            )

    async def test_gotify_executor_posts_json_with_header(self):
        server = Gotify()
        self.addCleanup(server.close)
        with tempfile.TemporaryDirectory() as directory:
            for text in (TOKEN + "\n", f"GOTIFY_TOKEN={TOKEN}\n"):
                executor = HostExecutor(
                    "h", "w", "n", server.url + "/", token_file(directory, text)
                )
                result = await executor.handle(
                    "host.cmd.gotify",
                    {
                        "title": "<b>x</b>",
                        "message": "ctx\x00\u202e\n\ncasm",
                        "priority": 7,
                        "id": "i",
                        "ts": time.time(),
                    },
                )
                self.assertEqual(result, {"accepted": True, "status": 200})
        self.assertEqual(len(server.requests), 2)
        for path, headers, body in server.requests:
            self.assertEqual(path, "/message")
            self.assertEqual(headers["X-Gotify-Key"], TOKEN)
            self.assertEqual(headers["Content-Type"], "application/json")
            self.assertEqual(
                body, {"title": "<b>x</b>", "message": "ctx\ncasm", "priority": 7}
            )
        for body in (
            {"title": "x", "message": "m", "priority": 11},
            {"title": "x", "message": "m", "priority": True},
            {"title": " \n\x00", "message": "m", "priority": 5},
            {"title": "x" * 101, "message": "m", "priority": 5},
            {"title": "x", "message": "m" * 257, "priority": 5},
        ):
            with self.assertRaises(ValueError):
                gotify_message(body)
        with self.assertRaisesRegex(ValueError, "invalid command"):
            await HostExecutor("h", "w").handle(
                "host.cmd.gotify",
                {"title": "x", "message": "", "priority": 5, "ts": time.time()},
            )

    async def test_gotify_executor_failures(self):
        command = {"title": "x", "message": "m", "priority": 5}
        with tempfile.TemporaryDirectory() as directory:
            token = token_file(directory)
            missing = str(Path(directory) / "missing")
            server = Gotify(status=500)
            self.addCleanup(server.close)
            slow = Gotify(delay=5)
            self.addCleanup(slow.close)
            cases = (
                (server.url, token, urllib.error.HTTPError),
                (server.url, missing, FileNotFoundError),
                (server.url, token_file(directory, "bad token\n", "bad"), ValueError),
                (f"http://127.0.0.1:{free_port()}", token, urllib.error.URLError),
            )
            for url, path, error in cases:
                with self.assertRaises(error):
                    await HostExecutor("h", "w", "n", url, path).handle(
                        "host.cmd.gotify", {**command, "ts": time.time()}
                    )
            self.assertEqual(len(server.requests), 1)
            started = time.monotonic()
            with self.assertRaises(TimeoutError):
                await HostExecutor("h", "w", "n", slow.url, token).handle(
                    "host.cmd.gotify", {**command, "ts": time.time()}
                )
            self.assertLess(time.monotonic() - started, 3.5)

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
            event(
                tmux_window="x" * 3000,
                session_description="y" * 3000,
                tmux_session="z" * 3000,
            ),
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
            {"summary": "x", "body": "<i>a</i>\n\x00\u202eb\r\n\nc"},
        )
        self.assertEqual(injected[-1], "&lt;i&gt;a&lt;/i&gt;\nb\nc")
        icons = {
            "interactive": "/fixed/terminal.png",
            "headless": "/fixed/smart_toy.png",
        }
        iconned = notify_argv("/fixed/notify-send", payload, icons)
        self.assertEqual(
            iconned[:6],
            [
                "/fixed/notify-send",
                "--app-name=Agent controller",
                "--urgency=normal",
                "--expire-time=8000",
                "--icon=/fixed/terminal.png",
                "--",
            ],
        )
        self.assertEqual(iconned[6:], args[5:])
        headless = notification("agent.evt.session-qa.settled", event(agent="b"))
        self.assertIn(
            "--icon=/fixed/smart_toy.png",
            notify_argv("/fixed/notify-send", headless, icons),
        )
        self.assertNotIn(
            "--icon=/fixed/terminal.png",
            notify_argv("/fixed/notify-send", headless, {"interactive": "/x"}),
        )
        self.assertEqual(
            notify_argv("/fixed/notify-send", {"summary": "x", "body": ""}, icons)[4],
            "--",
        )
        for bad in (
            {"summary": "x", "body": "", "source": "/etc/passwd"},
            {"summary": "x", "body": "", "source": ["headless"]},
            {"summary": "\x00 \n", "body": "", "source": "headless"},
        ):
            with self.assertRaises(ValueError):
                notify_argv("/fixed/notify-send", bad, icons)

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
        with patch(
            "cube_control.asyncio.create_subprocess_exec", return_value=Process()
        ) as spawn:
            await HostExecutor(
                "handy",
                "wpctl",
                "/fixed/notify-send",
                notify_icons=icons,
            ).handle("host.cmd.notify", {**payload, "ts": time.time()})
            spawn.assert_awaited_once_with(*iconned)
        with self.assertRaises(ValueError):
            notify_argv("notify-send", {"summary": "anything", "body": "x" * 257})


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
                serve(
                    self.url,
                    "executor",
                    notify_send=str(executable),
                    notify_icons={
                        "interactive": "/fixed/terminal.png",
                        "headless": "/fixed/smart_toy.png",
                    },
                )
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
            self.assertIn(IDLE_QA, output.read_text())
            self.assertIn("--icon=/fixed/terminal.png", output.read_text())
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
            self.assertEqual(output.read_text().count(IDLE_QA), 2)
            await self.nc.publish(
                "agent.evt.session-qa.settled",
                json.dumps(event(agent="summarizer")).encode(),
            )
            while (await self.until("cube.evt.controller.result")).get(
                "reason"
            ) != "denied agent":
                pass
            await asyncio.sleep(0.1)
            self.assertEqual(output.read_text().count(IDLE_QA), 2)

    async def test_live_gotify_channel_and_failure(self):
        server = Gotify()
        self.addCleanup(server.close)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "calls"
            executable = Path(directory) / "notify"
            executable.write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" >> {output}\n')
            executable.chmod(0o700)
            token = token_file(directory)
            executor = asyncio.create_task(
                serve(
                    self.url,
                    "executor",
                    notify_send=str(executable),
                    gotify_url=server.url,
                    gotify_token_file=token,
                )
            )
            self.tasks.extend(
                [
                    executor,
                    asyncio.create_task(
                        serve(
                            self.url,
                            "controller",
                            deny_agents=["summarizer"],
                            gotify=(5, 7),
                        )
                    ),
                ]
            )
            await asyncio.sleep(0.2)

            async def settled(**fields):
                await self.nc.publish(
                    "agent.evt.session-qa.settled", json.dumps(event(**fields)).encode()
                )
                executions = []
                async with asyncio.timeout(3):
                    while True:
                        name, body = await self.events.get()
                        if name == "host.evt.execution":
                            executions.append(body)
                        elif name == "cube.evt.controller.result":
                            return body, executions

            result, executions = await settled()
            self.assertEqual(result["channels"], ["notify", "gotify"])
            self.assertEqual(
                [e["subject"] for e in executions],
                ["host.cmd.notify", "host.cmd.gotify"],
            )
            self.assertEqual(len(server.requests), 1)
            self.assertEqual(
                server.requests[0][2],
                {"title": "session-qa", "message": "── idle", "priority": 5},
            )
            result, executions = await settled(agent="builder")
            self.assertEqual(result["channels"], ["notify"])
            result, executions = await settled(agent="summarizer")
            self.assertEqual(result["reason"], "denied agent")
            self.assertEqual(len(server.requests), 1)
            self.assertEqual(output.read_text().count(IDLE_QA), 1)
            self.assertEqual(output.read_text().count("--\nbuilder\n── idle\n"), 1)
            Path(token).unlink()
            result, executions = await settled()
            self.assertFalse(result["accepted"])
            self.assertEqual(result["reason"], "RuntimeError")
            self.assertEqual(output.read_text().count(IDLE_QA), 2)
            self.assertEqual(
                executions,
                [
                    {"subject": "host.cmd.notify", "accepted": True, "returncode": 0},
                    {
                        "subject": "host.cmd.gotify",
                        "accepted": False,
                        "reason": "FileNotFoundError",
                    },
                ],
            )
            self.assertFalse(executor.done())
