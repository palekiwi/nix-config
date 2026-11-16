import asyncio
import json
import shutil
import socket
import subprocess
import threading
import time
import unittest
from unittest.mock import patch

import speech_bridge


def chunk(utt="a", seq=0, final=False, text="hello", origin="pi"):
    return dict(utt=utt, seq=seq, final=final, text=text, origin=origin)


class OwnershipTests(unittest.TestCase):
    def setUp(self):
        self.bridge = speech_bridge.Bridge(lambda *args: None, [], 3)
        self.events = []
        self.bridge.emit = lambda subject, body: self.events.append((subject, body))

    def test_replace_and_reject_stopped_chunks(self):
        b = self.bridge
        self.assertTrue(b.intent(chunk(), 100))
        generation = b.generation
        self.assertTrue(b.intent(chunk(seq=1), 100))
        self.assertEqual(b.generation, generation)
        self.assertEqual(len(b.queue), 2)
        self.assertTrue(b.intent(chunk("b"), 100))
        self.assertEqual(list(b.queue), [(b.generation, "hello", "af_bella")])
        self.assertFalse(b.intent(chunk(seq=2), 100))
        b.stop()
        self.assertFalse(b.intent(chunk("b", seq=1), 100))
        self.assertEqual(self.events[-1][1]["reason"], "stale")

    def test_empty_final_waits_for_playback(self):
        b = self.bridge
        b.intent(chunk(), 100)
        self.assertFalse(b.intent(chunk(seq=2), 100))
        self.assertTrue(b.intent(chunk(seq=1, final=True, text=""), 100))
        self.assertFalse(b.intent(chunk(seq=2), 100))
        self.assertTrue(b.health()["active"])
        worker = threading.Thread(target=b.run)
        worker.start()
        deadline = time.monotonic() + 2
        while b.health()["active"] and time.monotonic() < deadline:
            time.sleep(0.01)
        b.close()
        worker.join(2)
        self.assertFalse(b.health()["active"])
        self.assertIn("speech.evt.finished", [s for s, _ in self.events])
        self.assertFalse(b.intent(chunk(seq=2), 100))

    def test_empty_final_without_audio_finishes(self):
        b = self.bridge
        self.assertTrue(b.intent(chunk(final=True, text=""), 100))
        self.assertFalse(b.health()["active"])
        self.assertEqual(self.events[-1][0], "speech.evt.finished")

    def test_holds_renew_release_and_expire(self):
        b = self.bridge
        with patch("speech_bridge.time.monotonic", return_value=10):
            b.intent(chunk(), 100)
            b.hold("dictation", 2)
            self.assertFalse(b.say("legacy"))
            self.assertFalse(b.intent(chunk("blocked"), 100))
        with patch("speech_bridge.time.monotonic", return_value=11):
            b.hold("dictation", 3)
            b.hold("other", 1)
            b.release("dictation-old")
        with patch("speech_bridge.time.monotonic", return_value=13):
            self.assertTrue(b.health()["held"])
            self.assertFalse(b.intent(chunk("blocked"), 100))
            b.release("dictation")
            self.assertFalse(b.health()["held"])
            b.hold("expiry", 1)
        with patch("speech_bridge.time.monotonic", return_value=15):
            self.assertTrue(b.say("legacy"))
            self.assertFalse(b.intent(chunk("blocked"), 100))
            self.assertTrue(b.intent(chunk("fresh"), 100))
        for ttl in (0, -1, 301, float("nan"), float("inf"), True):
            with self.assertRaises(ValueError):
                b.hold("bad", ttl)

    def test_http_queue_and_shared_ownership(self):
        b = self.bridge
        b.say("first")
        b.say("second")
        self.assertEqual([text for _, text, _ in b.queue], ["first", "second"])
        b.intent(chunk(origin="http"), 100)
        b.say("legacy replaces NATS even with http origin")
        self.assertEqual(len(b.queue), 1)
        self.assertFalse(b.intent(chunk(seq=1, origin="http"), 100))

    def test_voice_defaults_and_allowlist(self):
        b = self.bridge
        self.assertEqual(
            speech_bridge.VOICES,
            {"af_bella", "af_heart", "af_jessica", "af_sky", "bf_isabella", "am_echo"},
        )
        self.assertTrue(b.intent(chunk("default"), 100))
        self.assertEqual(b.queue[-1][2], "af_bella")
        self.assertEqual(b.health()["utterance"]["voice"], "af_bella")
        for voice in sorted(speech_bridge.VOICES):
            self.assertTrue(b.intent(dict(chunk(voice), voice=voice), 100))
            self.assertEqual(list(b.queue), [(b.generation, "hello", voice)])
            self.assertEqual(b.health()["utterance"]["voice"], voice)
        self.assertTrue(b.say("legacy"))
        self.assertEqual(b.queue[-1][2], "af_bella")
        self.assertEqual(b.health()["utterance"]["voice"], "af_bella")

    def test_invalid_voice_rejected_without_interrupting(self):
        b = self.bridge
        self.assertTrue(b.intent(dict(chunk(), voice="af_heart"), 100))
        generation = b.generation
        for voice in (None, 5, ["af_heart"], {"name": "af_heart"}, True):
            self.assertFalse(b.intent(dict(chunk("bad"), voice=voice), 100))
            self.assertEqual(self.events[-1][1]["reason"], "invalid")
        for voice in ("af_nova", "", "AF_BELLA", "af_bella ", "../af_bella"):
            self.assertFalse(b.intent(dict(chunk("bad"), voice=voice), 100))
            self.assertEqual(
                self.events[-1],
                (
                    "speech.evt.rejected",
                    {"utt": "bad", "origin": "pi", "reason": "voice"},
                ),
            )
        self.assertEqual(b.generation, generation)
        self.assertEqual(b.current["utt"], "a")
        self.assertNotIn("speech.evt.stopped", [s for s, _ in self.events])
        self.assertTrue(b.intent(dict(chunk("bad"), voice="am_echo"), 100))

    def test_voice_consistent_within_utterance(self):
        b = self.bridge
        self.assertTrue(b.intent(dict(chunk(), voice="bf_isabella"), 100))
        self.assertFalse(b.intent(dict(chunk(seq=1), voice="af_sky"), 100))
        self.assertEqual(self.events[-1][1]["reason"], "voice")
        self.assertFalse(b.intent(chunk(seq=1), 100))
        self.assertEqual(self.events[-1][1]["reason"], "voice")
        self.assertTrue(b.intent(dict(chunk(seq=1), voice="bf_isabella"), 100))
        self.assertEqual([voice for _, _, voice in b.queue], ["bf_isabella"] * 2)
        self.assertTrue(b.intent(chunk("b"), 100))
        self.assertFalse(b.intent(dict(chunk("b", seq=1), voice="af_heart"), 100))
        self.assertTrue(b.intent(dict(chunk("b", seq=1), voice="af_bella"), 100))
        self.assertTrue(b.intent(chunk("b", seq=2), 100))
        self.assertEqual([voice for _, _, voice in b.queue], ["af_bella"] * 3)

    def test_configured_default_voice(self):
        b = speech_bridge.Bridge(lambda *args: None, [], 3, voice="bf_emma")
        self.assertTrue(b.intent(chunk(), 100))
        self.assertTrue(b.intent(dict(chunk(seq=1), voice="bf_emma"), 100))
        self.assertEqual([voice for _, _, voice in b.queue], ["bf_emma"] * 2)
        self.assertTrue(b.intent(dict(chunk("b"), voice="af_bella"), 100))
        self.assertEqual(b.queue[-1][2], "af_bella")
        for voice in ("", None, 5):
            with self.assertRaises(ValueError):
                speech_bridge.Bridge(lambda *args: None, [], 3, voice=voice)


@unittest.skipUnless(shutil.which("nats-server"), "requires nats-server")
class TransportTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        import nats
        import speech_nats

        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            self.port = sock.getsockname()[1]
        self.url = f"nats://127.0.0.1:{self.port}"
        self.server = None
        self.bridge = speech_bridge.Bridge(lambda *args: None, [], 10)
        self.transport = speech_nats.Transport(self.bridge, self.url, 1000)
        self.transport.start()
        self.addAsyncCleanup(self.cleanup)
        self.assertTrue(self.bridge.say("works without NATS"))
        self.start_server()
        self.client = await nats.connect(self.url)
        await self.wait_ready()

    def start_server(self):
        self.server = subprocess.Popen(
            ["nats-server", "-a", "127.0.0.1", "-p", str(self.port)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", self.port), timeout=0.1):
                    return
            except OSError:
                time.sleep(0.02)
        self.fail("server failed to start")

    async def wait_ready(self):
        for _ in range(100):
            try:
                await self.client.request("speech.query.state", timeout=0.1)
                return
            except Exception:
                await asyncio.sleep(0.05)
        self.fail("bridge did not connect")

    async def request(self, subject, body):
        reply = await self.client.request(subject, json.dumps(body).encode(), timeout=1)
        return json.loads(reply.data)

    async def cleanup(self):
        self.transport.close()
        if hasattr(self, "client"):
            await self.client.close()
        if self.server:
            self.server.terminate()
            self.server.wait(timeout=3)

    async def test_voice_over_nats(self):
        say = "speech.intent.say"
        body = dict(chunk("v"), voice="af_jessica")
        self.assertTrue((await self.request(say, body))["accepted"])
        self.assertEqual(self.bridge.health()["utterance"]["voice"], "af_jessica")
        body = dict(chunk("v", seq=1), voice="am_echo")
        self.assertFalse((await self.request(say, body))["accepted"])
        body = dict(chunk("w"), voice="af_nova")
        self.assertFalse((await self.request(say, body))["accepted"])
        self.assertEqual(self.bridge.health()["utterance"]["utt"], "v")

    async def test_live_commands_outage_reconnect_no_replay(self):
        self.assertTrue((await self.request("speech.intent.say", chunk()))["accepted"])
        await self.request("speech.cmd.hold", {"id": "dict", "ttl": 30})
        self.assertFalse(
            (await self.request("speech.intent.say", chunk("held")))["accepted"]
        )
        self.server.terminate()
        self.server.wait(3)
        self.server = None
        await asyncio.sleep(0.3)
        self.assertFalse(self.bridge.say("HTTP respects hold while NATS down"))
        self.bridge.release("dict")
        self.assertTrue(self.bridge.say("HTTP survives outage"))
        self.bridge.stop()
        self.start_server()
        await self.wait_ready()
        self.assertFalse(self.bridge.health()["active"])
        self.assertTrue(
            (await self.request("speech.intent.say", chunk("new")))["accepted"]
        )
        await self.request("speech.intent.stop", {})
        self.assertFalse(
            (await self.request("speech.intent.say", chunk("new", seq=1)))["accepted"]
        )
