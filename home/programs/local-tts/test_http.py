import json
import os
import signal
import socket
import threading
import time
import unittest
import unittest.mock
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import test_speak


class HTTPTests(unittest.TestCase):
    script = test_speak.PipelineTests.script
    start = test_speak.PipelineTests.start
    stop = test_speak.PipelineTests.stop
    wait_for = test_speak.PipelineTests.wait_for

    def setUp(self):
        test_speak.PipelineTests.setUp(self)
        self.request = None
        self.mode = "stream"
        self.release = threading.Event()
        self.disconnected = threading.Event()
        self.addCleanup(self.release.set)
        owner = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *args):
                pass

            def do_POST(self):
                owner.request = json.loads(
                    self.rfile.read(int(self.headers["Content-Length"]))
                )
                (owner.root / "requested").touch()
                self.close_connection = True
                if owner.mode == "error":
                    self.send_response(503)
                    self.send_header("Content-Length", "13")
                    self.end_headers()
                    self.wfile.write(b"private input")
                    return
                self.send_response(200)
                self.send_header(
                    "Content-Type",
                    "application/json" if owner.mode == "json" else "audio/pcm",
                )
                if owner.mode == "short":
                    self.send_header("Content-Length", "100")
                    self.end_headers()
                    self.wfile.write(b"abcd")
                    return
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                try:
                    if owner.mode != "empty":
                        self.chunk(b"abcd")
                    if owner.mode == "stream":
                        if not owner.release.wait(8):
                            raise RuntimeError("client did not receive early audio")
                    elif owner.mode == "cancel":
                        while not owner.release.is_set():
                            self.chunk(b"x" * 16384)
                        return
                    elif owner.mode == "truncated":
                        self.close_connection = True
                        return
                    elif owner.mode == "odd":
                        self.chunk(b"x")
                    self.wfile.write(b"0\r\n\r\n")
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError, socket.timeout):
                    owner.disconnected.set()

            def chunk(self, data):
                self.connection.settimeout(3)
                self.wfile.write(f"{len(data):x}\r\n".encode() + data + b"\r\n")
                self.wfile.flush()

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.env.update(
            SPEAK_BACKEND="http",
            SPEAK_URL=f"http://127.0.0.1:{self.server.server_port}/v1/audio/speech",
        )

    def test_streams_before_response_completion(self):
        self.script(
            "player",
            "assert '--format=s16' in sys.argv\n"
            "assert os.read(0, 4) == b'abcd'\n"
            "(root / 'received').touch()\n"
            "assert sys.stdin.buffer.read() == b''\n",
        )
        process = self.start()
        self.wait_for(lambda: (self.root / "received").exists())
        self.assertIsNone(process.poll())
        self.assertEqual(
            self.request,
            dict(
                model="kokoro",
                voice="af_bella",
                input="private input",
                response_format="pcm",
                stream=True,
                speed=1,
            ),
        )
        self.release.set()
        out, err = process.communicate(timeout=5)
        self.assertEqual((process.returncode, out, err), (0, b"", b""))

    def test_generate_passes_voice_speed_and_socket(self):
        import http_engine

        self.mode = "plain"
        frames = []
        sockets = []

        class Output:
            def writeframesraw(self, data):
                frames.append(data)

        with unittest.mock.patch.dict(os.environ, self.env):
            http_engine.generate(
                "hello",
                Output(),
                voice="am_adam",
                speed=1.25,
                on_connect=sockets.append,
            )
        self.assertEqual(b"".join(frames), b"abcd")
        self.assertEqual(len(sockets), 1)
        self.assertIsInstance(sockets[0], socket.socket)
        self.assertEqual(
            (self.request["voice"], self.request["speed"], self.request["input"]),
            ("am_adam", 1.25, "hello"),
        )

    def test_output_wav_is_complete_and_replaced_atomically(self):
        output = self.root / "out.wav"
        output.write_bytes(b"old")
        process = self.start("--output", str(output))
        self.wait_for(lambda: (self.root / "requested").exists())
        time.sleep(0.1)
        self.assertEqual(output.read_bytes(), b"old")
        self.release.set()
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, err)
        with wave.open(str(output)) as audio:
            self.assertEqual(
                (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()),
                (1, 2, 24000),
            )
            self.assertEqual(audio.readframes(10), b"abcd")
        self.assertEqual(list(self.root.glob(".speak-*")), [])
        self.assertFalse((self.root / "player.pid").exists())

    def test_errors_preserve_output_without_echoing_input(self):
        for mode in ("error", "json", "truncated", "odd", "empty", "short"):
            with self.subTest(mode=mode):
                self.mode = mode
                output = self.root / "out.wav"
                output.write_bytes(b"old")
                process = self.start("--output", str(output))
                _, err = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 1, err)
                self.assertNotIn(b"private input", err)
                if mode == "error":
                    self.assertIn(b"HTTP 503", err)
                self.assertEqual(output.read_bytes(), b"old")
                self.assertEqual(list(self.root.glob(".speak-*")), [])

    def test_connection_failure_does_not_fall_back(self):
        self.env["SPEAK_URL"] = "http://127.0.0.1:0/v1/audio/speech"
        self.script("engine", "(root / 'cpu-used').touch()\n")
        process = self.start("--output", str(self.root / "out.wav"))
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 1, err)
        self.assertFalse((self.root / "cpu-used").exists())
        self.assertFalse((self.root / "out.wav").exists())

    def test_cancel_closes_request_and_kills_player(self):
        self.mode = "cancel"
        self.script(
            "player",
            "(root / 'player.pid').write_text(str(os.getpid()))\ntime.sleep(60)\n",
        )
        for sig in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig):
                self.disconnected.clear()
                (self.root / "player.pid").unlink(missing_ok=True)
                (self.root / "requested").unlink(missing_ok=True)
                process = self.start()
                self.wait_for(
                    lambda: (
                        (self.root / "player.pid").exists()
                        and (self.root / "requested").exists()
                    )
                )
                pid = (self.root / "player.pid").read_text()
                process.send_signal(sig)
                _, err = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 130, err)
                self.assertFalse(os.path.exists(f"/proc/{pid}"))
                self.assertTrue(self.disconnected.wait(5))

    def test_cancel_output_preserves_destination(self):
        output = self.root / "out.wav"
        output.write_bytes(b"old")
        process = self.start("--output", str(output))
        self.wait_for(lambda: (self.root / "requested").exists())
        process.send_signal(signal.SIGINT)
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 130, err)
        self.assertEqual(output.read_bytes(), b"old")

    def test_player_failure_closes_request(self):
        self.mode = "cancel"
        self.script("player", "assert os.read(0, 4) == b'abcd'\nraise SystemExit(7)\n")
        process = self.start()
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 1, err)
        self.assertTrue(self.disconnected.wait(5))

    def test_explicit_cpu_override(self):
        self.script(
            "engine",
            "assert sys.stdin.read() == 'private input'\nos.write(1, b'abcd')\n",
        )
        self.script(
            "player",
            "assert '--format=f32' in sys.argv\nassert sys.stdin.buffer.read() == b'abcd'\n",
        )
        process = self.start("--backend", "cpu")
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, err)
        self.assertIsNone(self.request)


if __name__ == "__main__":
    unittest.main()
