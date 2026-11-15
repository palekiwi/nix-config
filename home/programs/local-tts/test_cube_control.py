import asyncio
import json
import shutil
import socket
import subprocess
import time
import unittest
from unittest.mock import patch

import nats
from cube_control import CubeController, HostExecutor, decode, gesture, serve
from voice_control import request


class PolicyTests(unittest.IsolatedAsyncioTestCase):
    async def test_mappings_without_observer_or_holds(self):
        calls = []

        async def call(subject, body):
            calls.append((subject, body))
            return {"accepted": True}

        controller = CubeController(call)
        for action in (
            "tap",
            "flip90",
            "shake",
            "rotate_left",
            "rotate_right",
            "slide",
        ):
            await controller.handle(
                f"cube.evt.pale_cube.{action}",
                {
                    "action": action,
                    "angle": -26.9 if action == "rotate_left" else 26.9,
                    "ts": time.time(),
                },
            )
        self.assertEqual(
            [s for s, _ in calls],
            [
                "speech.cmd.stop",
                "speech.cmd.stop",
                "host.cmd.handy",
                "host.cmd.volume",
                "host.cmd.volume",
            ],
        )
        self.assertEqual(calls[2][1]["action"], "toggle")
        self.assertEqual(calls[3][1]["delta"], -6)
        self.assertEqual(calls[4][1]["delta"], 6)

    async def test_validation(self):
        for angle in (True, "5; evil", float("nan"), float("inf"), 361, -5):
            with self.assertRaises(ValueError):
                gesture({"action": "rotate_right", "angle": angle})
        for data in (b"[]", b"x" * 4097):
            with self.assertRaises(ValueError):
                decode(data)
        controller = CubeController(None)
        with self.assertRaises(ValueError):
            await controller.handle(
                "cube.evt.pale_cube.tap", {"action": "tap", "ts": time.time() - 3}
            )
        with self.assertRaises(ValueError):
            await controller.handle(
                "cube.evt.pale_cube.shake", {"action": "tap", "ts": time.time()}
            )

    async def test_mechanical_allowlist_and_failure(self):
        class Process:
            returncode = 7

            async def wait(self):
                return 7

        executor = HostExecutor("handy", "wpctl")
        with patch(
            "cube_control.asyncio.create_subprocess_exec", return_value=Process()
        ) as spawn:
            for subject, body, expected in (
                (
                    "host.cmd.handy",
                    {"action": "toggle"},
                    ("handy", "--toggle-transcription"),
                ),
                ("host.cmd.handy", {"action": "cancel"}, ("handy", "--cancel")),
                (
                    "host.cmd.volume",
                    {"delta": 6},
                    ("wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "6%+"),
                ),
                (
                    "host.cmd.volume",
                    {"delta": -6},
                    ("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "6%-"),
                ),
            ):
                result = await executor.handle(subject, {**body, "ts": time.time()})
                self.assertFalse(result["accepted"])
                spawn.assert_awaited_with(*expected)
            for subject, body in (
                ("host.cmd.exec", {"command": "evil"}),
                ("host.cmd.volume", {"delta": True}),
                ("host.cmd.volume", {"delta": 73}),
                ("host.cmd.handy", {"action": "evil"}),
            ):
                with self.assertRaises(ValueError):
                    await executor.handle(subject, {**body, "ts": time.time()})


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@unittest.skipUnless(
    shutil.which("nats-server") and shutil.which("mosquitto"), "requires brokers"
)
class LiveTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.port = free_port()
        self.url = f"nats://127.0.0.1:{free_port()}"
        self.servers = []
        self.tasks = []
        for args in (
            ("nats-server", "-p", self.url.rsplit(":", 1)[1]),
            ("mosquitto", "-p", str(self.port)),
        ):
            self.servers.append(
                await asyncio.create_subprocess_exec(
                    *args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
            )
        await asyncio.sleep(0.2)
        self.nc = await nats.connect(self.url, allow_reconnect=False)
        self.events = asyncio.Queue()

        async def event(msg):
            await self.events.put((msg.subject, json.loads(msg.data)))

        await self.nc.subscribe("cube.>", cb=event)
        await self.nc.subscribe("host.evt.>", cb=event)
        await self.nc.subscribe("speech.cmd.>", cb=event)

        async def stop(msg):
            await msg.respond(b'{"accepted":true}')

        await self.nc.subscribe("speech.cmd.stop", cb=stop)
        await self.nc.flush()

    async def asyncTearDown(self):
        for task in self.tasks:
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)
        await self.nc.close()
        for server in self.servers:
            if server.returncode is None:
                server.terminate()
            await server.wait()

    async def mqtt(self, topic, payload, retained=False):
        args = [
            "mosquitto_pub",
            "-h",
            "127.0.0.1",
            "-p",
            str(self.port),
            "-t",
            topic,
            "-m",
            payload,
        ]
        if retained:
            args.append("-r")
        process = await asyncio.create_subprocess_exec(*args)
        self.assertEqual(await process.wait(), 0)

    async def until(self, subject):
        async with asyncio.timeout(3):
            while True:
                name, body = await self.events.get()
                if name == subject:
                    return body

    async def test_mqtt_nats_execution_and_no_retained_replay(self):
        await self.mqtt("zigbee2mqtt/Cube", '{"action":"shake"}', True)
        for mode in ("controller", "executor", "relay"):
            self.tasks.append(
                asyncio.create_task(
                    serve(
                        self.url,
                        mode,
                        handy=shutil.which("true"),
                        wpctl=shutil.which("false"),
                        host="127.0.0.1",
                        port=self.port,
                    )
                )
            )
        await asyncio.sleep(0.3)
        self.assertTrue(self.events.empty())
        await self.mqtt("zigbee2mqtt/Other", '{"action":"shake"}')
        await self.mqtt("zigbee2mqtt/Cube", '{"action":"rotate_left","angle":"bad"}')
        await asyncio.sleep(0.1)
        self.assertTrue(self.events.empty())
        await self.mqtt("zigbee2mqtt/Cube", '{"action":"shake"}')
        result = await self.until("host.evt.execution")
        self.assertTrue(result["accepted"])
        for action in ("tap", "flip90"):
            await self.mqtt("zigbee2mqtt/Cube", json.dumps({"action": action}))
            await self.until("speech.cmd.stop")
        result = await request(
            self.nc, "host.cmd.volume", {"delta": 5, "ts": time.time()}
        )
        self.assertFalse(result["accepted"])
        self.servers[0].terminate()
        await self.servers[0].wait()
        for task in self.tasks:
            with self.assertRaises(ConnectionError):
                await asyncio.wait_for(task, 3)
