import http.client
import json
import os
import select
import socket
import sys
import tempfile
import threading
import time
import unittest
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

import http_engine
import speech_bridge


class FakeKokoro:
    def __init__(self):
        self.requests = []
        self.modes = deque()
        self.default = "ok"
        self.requested = threading.Event()
        self.disconnects = 0
        self.connections = 0
        self.closed = 0
        self.release = threading.Event()
        self.lock = threading.Lock()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *args):
                pass

            def setup(self):
                super().setup()
                with owner.lock:
                    owner.connections += 1

            def finish(self):
                super().finish()
                with owner.lock:
                    owner.closed += 1

            def do_POST(self):
                try:
                    self.respond()
                except (OSError, ValueError):
                    self.close_connection = True

            def respond(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                with owner.lock:
                    owner.requests.append(body)
                    mode = owner.modes.popleft() if owner.modes else owner.default
                owner.requested.set()
                self.close_connection = True
                if mode == "error":
                    self.send_response(503)
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                if mode == "hold":
                    owner.hold(self.connection)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "audio/pcm")
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                self.chunk(b"abcd")
                if mode == "stall":
                    owner.hold(self.connection)
                    return
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()

            def chunk(self, data):
                self.wfile.write(f"{len(data):x}\r\n".encode() + data + b"\r\n")
                self.wfile.flush()

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.server_port}/v1/audio/speech"

    def hold(self, connection):
        while not self.release.is_set():
            readable, _, _ = select.select([connection], [], [], 0.02)
            if readable:
                try:
                    data = connection.recv(1)
                except OSError:
                    data = b""
                if not data:
                    with self.lock:
                        self.disconnects += 1
                    return

    def inputs(self):
        with self.lock:
            return [request["input"] for request in self.requests]

    def close(self):
        self.release.set()
        self.server.shutdown()
        self.server.server_close()


class BridgeTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.kokoro = FakeKokoro()
        self.addCleanup(self.kokoro.close)
        environment = patch.dict(os.environ, SPEAK_URL=self.kokoro.url)
        environment.start()
        self.addCleanup(environment.stop)
        self.logs = []
        logger = patch.object(speech_bridge, "log", self.logs.append)
        logger.start()
        self.addCleanup(logger.stop)
        self.player = self.root / "player"
        self.player.write_text(
            f"#!{sys.executable}\n"
            "import os, pathlib, sys\n"
            f"root = pathlib.Path({str(self.root)!r})\n"
            "pid = os.getpid()\n"
            "(root / f'argv-{pid}').write_text('\\n'.join(sys.argv[1:]))\n"
            "with open(root / 'players', 'a') as players:\n"
            "    players.write(f'{pid}\\n')\n"
            "with open(root / f'played-{pid}', 'wb') as played:\n"
            "    while data := os.read(0, 65536):\n"
            "        played.write(data)\n"
            "        played.flush()\n"
        )
        self.player.chmod(0o755)
        self.before_synthesis = None

    def start(self, max_queue=8, max_chars=100, say_slots=4, read_timeout=5.0):
        def synthesize(text, sink, on_connect):
            if self.before_synthesis is not None:
                self.before_synthesis()
            http_engine.generate(text, sink, "am_adam", 1.25, on_connect)

        self.bridge = speech_bridge.Bridge(
            synthesize,
            speech_bridge.player_command(str(self.player), "1.5"),
            max_queue,
        )
        worker = threading.Thread(target=self.bridge.run, daemon=True)
        worker.start()
        self.server = speech_bridge.Server(
            ("127.0.0.1", 0),
            self.bridge,
            max_chars,
            read_timeout=read_timeout,
            say_slots=say_slots,
        )
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()

        def stop():
            self.server.shutdown()
            self.server.server_close()
            self.bridge.close()
            worker.join(5)

        self.addCleanup(stop)
        return self.bridge

    def call(self, method, path, body=None, raw=None):
        connection = http.client.HTTPConnection(
            "127.0.0.1", self.server.server_port, timeout=5
        )
        try:
            data = raw if raw is not None else None
            if body is not None:
                data = json.dumps(body).encode()
            connection.request(method, path, data)
            response = connection.getresponse()
            content = response.read()
            return response.status, content
        finally:
            connection.close()

    def say(self, text):
        return self.call("POST", "/say", {"text": text})[0]

    def stop_speech(self):
        started = time.monotonic()
        status = self.call("POST", "/stop")[0]
        self.assertEqual(status, 204)
        self.assertLess(time.monotonic() - started, 1)

    def wait_for(self, condition, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(0.01)
        self.fail("timed out waiting for condition")

    def players(self):
        path = self.root / "players"
        if not path.exists():
            return []
        return [int(line) for line in path.read_text().split()]

    def played(self):
        return [
            (
                (self.root / f"played-{pid}").read_bytes()
                if (self.root / f"played-{pid}").exists()
                else b""
            )
            for pid in self.players()
        ]

    def alive(self, pid):
        try:
            state = Path(f"/proc/{pid}/stat").read_text().split(") ", 1)[1].split()[0]
        except (FileNotFoundError, ProcessLookupError):
            return False
        return state != "Z"

    def idle(self):
        return not self.bridge.health()["speaking"]

    def test_say_streams_into_one_player_per_sentence(self):
        self.start()
        self.assertEqual(self.say("first"), 202)
        self.assertEqual(self.say("second"), 202)
        self.wait_for(lambda: self.played() == [b"abcd", b"abcd"] and self.idle())
        self.assertEqual(self.kokoro.inputs(), ["first", "second"])
        self.assertEqual(
            {(r["voice"], r["speed"]) for r in self.kokoro.requests},
            {("am_adam", 1.25)},
        )
        argv = (self.root / f"argv-{self.players()[0]}").read_text().split("\n")
        self.assertIn("--volume=1.5", argv)
        self.assertIn("--format=s16", argv)
        self.assertIn(
            "--properties={ application.name = speak state.restore-props = false }",
            argv,
        )

    def test_enqueued_before_reply(self):
        self.kokoro.default = "hold"
        self.start()
        self.assertEqual(self.say("first"), 202)
        self.wait_for(self.kokoro.requested.is_set)
        self.assertEqual(self.say("second"), 202)
        self.assertEqual(self.bridge.health(), {"queued": 1, "speaking": True})
        status, body = self.call("GET", "/health")
        self.assertEqual((status, json.loads(body)["queued"]), (200, 1))

    def test_stop_before_kokoro_connects(self):
        self.start()
        self.before_synthesis = lambda: self.bridge.stop()
        self.assertEqual(self.say("first"), 202)
        self.wait_for(lambda: self.kokoro.connections == 1)
        self.wait_for(self.idle)
        self.before_synthesis = None
        self.assertEqual(self.say("second"), 202)
        self.wait_for(lambda: self.played() == [b"abcd"] and self.idle())
        self.assertEqual(self.kokoro.inputs(), ["second"])

    def test_stop_while_waiting_for_kokoro_response(self):
        self.kokoro.modes.append("hold")
        self.start()
        self.assertEqual(self.say("first"), 202)
        self.assertEqual(self.say("queued"), 202)
        self.wait_for(self.kokoro.requested.is_set)
        self.stop_speech()
        self.wait_for(lambda: self.kokoro.disconnects == 1, timeout=2)
        self.wait_for(self.idle, timeout=2)
        self.assertEqual(self.players(), [])
        self.assertEqual(self.say("after"), 202)
        self.wait_for(lambda: self.played() == [b"abcd"] and self.idle())
        self.assertEqual(self.kokoro.inputs(), ["first", "after"])
        self.assertEqual(self.logs, [])

    def test_stop_during_player_start(self):
        self.kokoro.modes.append("stall")
        bridge = self.start()
        spawn = bridge.spawn
        spawned = []

        def racing_spawn():
            player = spawn()
            spawned.append(player.pid)
            bridge.stop()
            return player

        bridge.spawn = racing_spawn
        self.assertEqual(self.say("first"), 202)
        self.wait_for(lambda: spawned and self.idle(), timeout=2)
        self.assertFalse(self.alive(spawned[0]))
        self.wait_for(lambda: self.kokoro.disconnects == 1, timeout=2)
        self.assertTrue(all(data == b"" for data in self.played()))
        bridge.spawn = spawn
        self.assertEqual(self.say("after"), 202)
        self.wait_for(lambda: self.played()[-1:] == [b"abcd"] and self.idle())
        self.assertEqual(self.logs, [])

    def test_stop_during_stalled_synthesis(self):
        self.kokoro.modes.append("stall")
        self.start()
        self.assertEqual(self.say("first"), 202)
        self.wait_for(lambda: self.played() == [b"abcd"])
        pid = self.players()[0]
        self.assertTrue(self.alive(pid))
        self.stop_speech()
        self.wait_for(lambda: not self.alive(pid), timeout=1)
        self.wait_for(lambda: self.kokoro.disconnects == 1, timeout=2)
        self.wait_for(self.idle, timeout=2)
        self.assertEqual(self.say("after"), 202)
        self.wait_for(lambda: self.played() == [b"abcd", b"abcd"] and self.idle())
        self.assertEqual(self.logs, [])

    def test_say_racing_stop_leaves_nothing_playing(self):
        self.kokoro.default = "stall"
        self.start(max_queue=64)
        for _ in range(20):
            threads = [
                threading.Thread(target=self.say, args=("racing",)),
                threading.Thread(target=self.call, args=("POST", "/stop")),
            ]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(5)
            self.stop_speech()
            self.wait_for(self.idle, timeout=2)
            self.assertEqual(self.bridge.health(), {"queued": 0, "speaking": False})
            self.assertFalse(any(self.alive(pid) for pid in self.players()))
        self.wait_for(lambda: self.kokoro.closed == self.kokoro.connections)
        self.assertEqual(self.logs, [])

    def test_stop_is_idempotent(self):
        self.start()
        self.stop_speech()
        self.stop_speech()

    def test_kokoro_error_drops_sentence_and_keeps_running(self):
        self.kokoro.modes.append("error")
        self.start()
        self.assertEqual(self.say("broken"), 202)
        self.assertEqual(self.say("after"), 202)
        self.wait_for(lambda: self.played() == [b"abcd"] and self.idle())
        self.assertEqual(len(self.logs), 1)
        self.assertNotIn("broken", self.logs[0])

    def test_request_limits(self):
        self.kokoro.default = "hold"
        self.start(max_queue=2, max_chars=10)
        self.assertEqual(self.call("POST", "/say", raw=b"{nope")[0], 400)
        self.assertEqual(self.call("POST", "/say", {"words": "x"})[0], 400)
        self.assertEqual(self.call("POST", "/say", ["x"])[0], 400)
        self.assertEqual(self.call("POST", "/say", {"text": 5})[0], 400)
        self.assertEqual(self.say("  "), 400)
        self.assertEqual(self.say("x" * 11), 413)
        self.assertEqual(self.call("POST", "/say", raw=b" " * 8193)[0], 413)
        self.assertEqual(self.call("POST", "/say", raw=b"\xff")[0], 400)
        self.assertEqual(self.call("POST", "/nowhere")[0], 404)
        self.assertEqual(self.call("GET", "/nowhere")[0], 404)
        self.assertEqual(self.say("x" * 10), 202)
        self.wait_for(self.kokoro.requested.is_set)
        self.assertEqual(self.say("two"), 202)
        self.assertEqual(self.say("three"), 202)
        self.assertEqual(self.say("four"), 503)
        self.assertEqual(self.bridge.health()["queued"], 2)

    def test_stop_served_while_say_saturated_and_slow_bodies_time_out(self):
        self.start(say_slots=2, read_timeout=0.5)
        slow = []
        for _ in range(2):
            client = socket.create_connection(("127.0.0.1", self.server.server_port))
            self.addCleanup(client.close)
            client.sendall(b"POST /say HTTP/1.1\r\nContent-Length: 20\r\n\r\n{")
            slow.append(client)
        self.wait_for(lambda: self.server.say_slots._value == 0)
        self.assertEqual(self.say("blocked"), 503)
        self.stop_speech()
        for client in slow:
            client.settimeout(2)
            self.assertEqual(client.recv(1024), b"")
        self.assertEqual(self.say("free"), 202)

    def test_binds_non_local_address_with_freebind(self):
        bridge = speech_bridge.Bridge(None, [], 1)
        server = speech_bridge.Server(("192.0.2.1", 0), bridge, 10)
        self.addCleanup(server.server_close)
        self.assertEqual(server.server_address[0], "192.0.2.1")
        self.assertEqual(
            server.socket.getsockopt(socket.IPPROTO_IP, speech_bridge.IP_FREEBIND), 1
        )


if __name__ == "__main__":
    unittest.main()
