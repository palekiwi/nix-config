import asyncio
import shutil
import socket
import subprocess
import unittest
from unittest.mock import patch

import nats
from voice_control import Controller, HandyAdapter, request, serve


class ControllerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.calls = []
        self.observed = "unknown"
        self.reject = None

        async def call(subject, body):
            self.calls.append((subject, body))
            if subject == self.reject:
                raise ConnectionError("offline")
            if subject == "dictation.query.state":
                return {"observed": self.observed}
            return {"accepted": True}

        self.controller = Controller(call, "test-hold")

    async def test_every_toggle_stops_and_holds_before_command(self):
        for _ in range(3):
            self.calls.clear()
            await self.controller.handle("dictation.intent.toggle")
            self.assertEqual(
                [s for s, _ in self.calls],
                [
                    "speech.cmd.stop",
                    "speech.cmd.hold",
                    "dictation.cmd.toggle",
                    "dictation.query.state",
                ],
            )
            self.assertEqual(self.controller.observed, "unknown")

    async def test_start_renew_stop_and_matching_release(self):
        self.observed = "started"
        await self.controller.reconcile()
        await self.controller.reconcile()
        self.observed = "stopped"
        await self.controller.reconcile()
        subjects = [s for s, _ in self.calls]
        self.assertEqual(subjects.count("speech.cmd.stop"), 1)
        self.assertEqual(subjects.count("speech.cmd.hold"), 2)
        self.assertEqual(self.calls[-1], ("speech.cmd.release", {"id": "test-hold"}))

    async def test_unknown_does_not_renew_or_release(self):
        await self.controller.reconcile()
        self.assertEqual(self.calls, [("dictation.query.state", {})])
        self.observed = "started"
        await self.controller.reconcile()
        self.observed = "unknown"
        self.calls.clear()
        await self.controller.reconcile()
        self.assertEqual(self.calls, [("dictation.query.state", {})])

    async def test_speech_outage_prevents_handy_command(self):
        for rejected in ("speech.cmd.stop", "speech.cmd.hold"):
            self.calls.clear()
            self.reject = rejected
            with self.assertRaises(ConnectionError):
                await self.controller.handle("dictation.intent.toggle")
            self.assertNotIn("dictation.cmd.toggle", [s for s, _ in self.calls])

    async def test_cancel_also_stops_and_holds(self):
        await self.controller.handle("dictation.intent.cancel")
        self.assertEqual(self.calls[2][0], "dictation.cmd.cancel")
        self.assertEqual(self.controller.observed, "unknown")

    async def test_adapter_refuses_guessed_state(self):
        adapter = HandyAdapter("/missing/handy")
        self.assertEqual(
            (await adapter.handle("dictation.query.state"))["observed"], "unknown"
        )
        self.assertFalse((await adapter.handle("dictation.cmd.toggle"))["accepted"])

    async def test_adapter_cancel_does_not_claim_stopped(self):
        adapter = HandyAdapter("handy")

        class Process:
            returncode = 0

            async def wait(self):
                return 0

        with patch(
            "voice_control.asyncio.create_subprocess_exec", return_value=Process()
        ) as spawn:
            result = await adapter.handle("dictation.cmd.cancel")
        spawn.assert_awaited_once_with("handy", "--cancel")
        self.assertEqual(result, {"accepted": True, "observed": "unknown"})


@unittest.skipUnless(shutil.which("nats-server"), "requires nats-server")
class LiveTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        self.url = f"nats://127.0.0.1:{port}"
        self.server = await asyncio.create_subprocess_exec(
            "nats-server",
            "-p",
            str(port),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        for _ in range(100):
            try:
                self.nc = await nats.connect(
                    self.url, allow_reconnect=False, connect_timeout=0.1
                )
                break
            except OSError:
                await asyncio.sleep(0.02)
        self.adapter = asyncio.create_task(serve(self.url, "adapter", "/missing/handy"))
        await asyncio.sleep(0.1)

    async def asyncTearDown(self):
        self.adapter.cancel()
        await asyncio.gather(self.adapter, return_exceptions=True)
        await self.nc.close()
        if self.server.returncode is None:
            self.server.terminate()
        await asyncio.wait_for(self.server.wait(), 3)

    async def test_core_query_and_guarded_toggle(self):
        state = await request(self.nc, "dictation.query.state", {})
        self.assertEqual(state["observed"], "unknown")
        result = await request(self.nc, "dictation.cmd.toggle", {})
        self.assertEqual(result, {"accepted": False, "reason": "observer_unavailable"})

    async def test_outage_is_fatal(self):
        self.server.terminate()
        await asyncio.wait_for(self.server.wait(), 3)
        with self.assertRaises(ConnectionError):
            await asyncio.wait_for(self.adapter, 3)
