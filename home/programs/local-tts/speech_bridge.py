import argparse
import json
import os
import signal
import socket
import socketserver
import subprocess
import sys
import threading
import time
import uuid
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import http_engine

IP_FREEBIND = getattr(socket, "IP_FREEBIND", 15)
MAX_BODY = 8192
VOICES = frozenset(
    ("af_bella", "af_heart", "af_jessica", "af_sky", "bf_isabella", "am_echo")
)


class Stale(Exception):
    pass


def log(message):
    print(f"speech-bridge: {message}", file=sys.stderr, flush=True)


def player_command(player, volume, target=""):
    command = [
        player,
        "--raw",
        "--format=s16",
        "--rate=24000",
        "--channels=1",
        f"--volume={volume}",
        "--properties={ application.name = speak state.restore-props = false }",
    ]
    if target:
        command.append(f"--target={target}")
    command.append("-")
    return command


class Sink:
    def __init__(self, bridge, generation):
        self.bridge = bridge
        self.generation = generation
        self.player = None

    def writeframesraw(self, data):
        if self.player is None:
            self.player, padding = self.bridge.start_player(self.generation)
        else:
            padding = b""
        try:
            if padding:
                self.player.stdin.write(padding)
            self.player.stdin.write(data)
            self.player.stdin.flush()
        except (BrokenPipeError, ValueError):
            self.bridge.check(self.generation)
            raise

    def finish(self):
        if self.player is None:
            return 0
        try:
            self.player.stdin.close()
        except BrokenPipeError:
            pass
        return self.player.wait()

    def abandon(self):
        if self.player is not None:
            self.player.kill()
            try:
                self.player.stdin.close()
            except BrokenPipeError:
                pass
            self.player.wait()


class Bridge:
    """Queue of sentences spoken one at a time, cancellable by stop()."""

    def __init__(
        self,
        synthesize,
        command,
        max_queue,
        leading_silence_ms=0,
        voice="af_bella",
    ):
        if not isinstance(voice, str) or not voice:
            raise ValueError("default voice must be a nonempty string")
        self.voice = voice
        self.voices = VOICES | {voice}
        self.synthesize = synthesize
        self.command = command
        self.max_queue = max_queue
        if not 0 <= leading_silence_ms <= 2000:
            raise ValueError("leading silence must be between 0 and 2000 ms")
        self.leading_silence = bytes(48 * leading_silence_ms)
        self.lock = threading.RLock()
        self.ready = threading.Condition(self.lock)
        self.queue = deque()
        self.generation = 0
        self.player = None
        self.socket = None
        self.speaking = False
        self.closed = False
        self.current = None
        self.retired = deque(maxlen=1024)
        self.holds = {}
        self.emit = lambda subject, body: None

    def event(self, kind, reason=None, utterance=None):
        body = dict(utterance or self.current or {})
        if reason:
            body["reason"] = reason
        self.emit(f"speech.evt.{kind}", body)

    def held(self):
        now = time.monotonic()
        self.holds = {key: end for key, end in self.holds.items() if end > now}
        return bool(self.holds)

    def retire(self):
        if self.current:
            self.retired.append(self.current["utt"])
            self.current = None

    def reject(self, body, reason):
        self.event(
            "rejected",
            reason,
            {key: body[key] for key in ("utt", "origin", "sid") if key in body},
        )
        return False

    def intent(self, body, max_chars):
        with self.lock:
            utt, seq, final, text, origin = (
                body.get(key) for key in ("utt", "seq", "final", "text", "origin")
            )
            if (
                not isinstance(utt, str)
                or not 0 < len(utt) <= 128
                or type(seq) is not int
                or seq < 0
                or type(final) is not bool
                or not isinstance(text, str)
                or len(text) > max_chars
                or not isinstance(origin, str)
                or not 0 < len(origin) <= 128
                or ("sid" in body and not isinstance(body["sid"], str))
                or (not text.strip() and not final)
                or ("voice" in body and not isinstance(body["voice"], str))
            ):
                return self.reject({}, "invalid")
            voice = body.get("voice", self.voice)
            if voice not in self.voices:
                return self.reject(body, "voice")
            if utt in self.retired:
                return self.reject(body, "stale")
            if self.held():
                self.retired.append(utt)
                return self.reject(body, "held")
            same = self.current and self.current["utt"] == utt
            if seq != (self.next_seq if same else 0):
                return self.reject(body, "sequence")
            if same and (self.final or origin != self.current["origin"]):
                return self.reject(body, "finalized" if self.final else "origin")
            if same and voice != self.current["voice"]:
                return self.reject(body, "voice")
            if same and len(self.queue) >= self.max_queue:
                return self.reject(body, "queue_full")
            if not same:
                self.stop("replaced")
                self.current = {
                    key: body[key] for key in ("utt", "origin", "sid") if key in body
                }
                self.current["voice"] = voice
                self.source = "nats"
                self.next_seq = 0
                self.final = False
                self.started = False
            self.next_seq += 1
            self.final = final
            if text.strip():
                self.queue.append((self.generation, text, voice))
                self.ready.notify()
            self.complete()
            return True

    def complete(self):
        if self.current and self.final and not self.queue and not self.speaking:
            self.event("finished")
            self.retire()

    def hold(self, identity, ttl):
        if not isinstance(identity, str) or not 0 < len(identity) <= 128:
            raise ValueError("invalid hold id")
        if type(ttl) not in (int, float) or not 0 < ttl <= 300:
            raise ValueError("invalid hold ttl")
        with self.lock:
            self.holds[identity] = time.monotonic() + ttl
            self.stop("held")

    def release(self, identity):
        if not isinstance(identity, str):
            raise ValueError("invalid hold id")
        with self.lock:
            self.holds.pop(identity, None)

    def say(self, text):
        with self.lock:
            if self.held():
                return self.reject({"origin": "http"}, "held")
            if self.current and self.source != "http":
                self.stop("replaced")
            if len(self.queue) >= self.max_queue:
                return False
            if not self.current:
                self.current = {
                    "utt": str(uuid.uuid4()),
                    "origin": "http",
                    "voice": self.voice,
                }
                self.source = "http"
                self.final = True
                self.started = False
            self.queue.append((self.generation, text, self.voice))
            self.ready.notify()
            return True

    def stop(self, reason="requested"):
        with self.lock:
            if self.current:
                self.event("stopped", reason)
                self.retire()
            self.generation += 1
            self.queue.clear()
            if self.player is not None:
                self.player.kill()
            if self.socket is not None:
                try:
                    self.socket.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass

    def close(self):
        self.stop()
        with self.lock:
            self.closed = True
            self.ready.notify_all()

    def health(self):
        with self.lock:
            return {
                "queued": len(self.queue),
                "speaking": self.speaking,
                "active": self.current is not None,
                "utterance": self.current,
                "held": self.held(),
            }

    def check(self, generation):
        with self.lock:
            if generation != self.generation:
                raise Stale()

    def connected(self, generation, sock):
        with self.lock:
            if generation == self.generation:
                self.socket = sock
                return
        raise Stale()

    def spawn(self):
        return subprocess.Popen(
            self.command,
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def start_player(self, generation):
        player = self.spawn()
        with self.lock:
            valid = generation == self.generation
            first = valid and self.current and not self.started
            if valid:
                self.player = player
                if first:
                    self.started = True
                    self.event("started")
        if not valid:
            player.kill()
            player.stdin.close()
            player.wait()
            raise Stale()
        return player, self.leading_silence if first else b""

    def run(self):
        while True:
            with self.lock:
                while not self.queue and not self.closed:
                    self.ready.wait()
                if self.closed:
                    return
                generation, text, voice = self.queue.popleft()
                self.speaking = True
            success = False
            try:
                success = self.speak(generation, text, voice)
            finally:
                with self.lock:
                    self.player = None
                    self.socket = None
                    self.speaking = False
                    if (
                        not success
                        and generation == self.generation
                        and self.source == "nats"
                    ):
                        self.stop("failed")
                    self.complete()

    def speak(self, generation, text, voice):
        sink = Sink(self, generation)
        try:
            self.check(generation)
            self.synthesize(
                text, sink, lambda sock: self.connected(generation, sock), voice
            )
            code = sink.finish()
            self.check(generation)
            if code:
                log(f"player exited with status {code}")
            return code == 0
        except Stale:
            sink.abandon()
        except Exception as error:
            sink.abandon()
            try:
                self.check(generation)
            except Stale:
                return
            log(f"synthesis failed ({type(error).__name__}: {error}); sentence dropped")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def setup(self):
        self.timeout = self.server.read_timeout
        super().setup()

    def log_message(self, *args):
        pass

    def reply(self, status, body=None):
        data = b"" if body is None else json.dumps(body).encode("utf-8")
        self.close_connection = True
        self.send_response(status)
        if body is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, self.server.bridge.health())
        else:
            self.reply(404)

    def do_POST(self):
        if self.path == "/stop":
            self.server.bridge.stop()
            self.reply(204)
        elif self.path == "/say":
            if not self.server.say_slots.acquire(blocking=False):
                self.reply(503)
                return
            try:
                self.say()
            finally:
                self.server.say_slots.release()
        else:
            self.reply(404)

    def say(self):
        if self.headers.get("Transfer-Encoding"):
            self.reply(400)
            return
        try:
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            self.reply(400)
            return
        if length < 0:
            self.reply(400)
            return
        if length > MAX_BODY:
            self.reply(413)
            return
        try:
            body = self.rfile.read(length)
        except OSError:
            self.close_connection = True
            return
        if len(body) != length:
            self.close_connection = True
            return
        try:
            text = json.loads(body.decode("utf-8"))["text"]
        except (ValueError, TypeError, KeyError):
            self.reply(400)
            return
        if not isinstance(text, str) or not text.strip():
            self.reply(400)
            return
        if len(text) > self.server.max_chars:
            self.reply(413)
            return
        self.reply(202 if self.server.bridge.say(text) else 503)


class Server(ThreadingHTTPServer):
    """HTTP front end binding with IP_FREEBIND, with bounded connections."""

    daemon_threads = True
    block_on_close = False
    allow_reuse_address = True
    request_queue_size = 16

    def __init__(
        self,
        address,
        bridge,
        max_chars,
        read_timeout=5.0,
        say_slots=4,
        connections=32,
    ):
        self.bridge = bridge
        self.max_chars = max_chars
        self.read_timeout = read_timeout
        self.say_slots = threading.BoundedSemaphore(say_slots)
        self.connections = threading.BoundedSemaphore(connections)
        super().__init__(address, Handler)

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IP, IP_FREEBIND, 1)
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]

    def process_request(self, request, client_address):
        if not self.connections.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.connections.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.connections.release()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Speak text sent over HTTP.")
    parser.add_argument("--nats-url")
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--voice", default="af_bella")
    parser.add_argument("--speed", type=float, default=1.0)
    parser.add_argument("--volume", default=os.environ.get("SPEAK_VOLUME", "1"))
    parser.add_argument("--max-chars", type=int, default=1000)
    parser.add_argument("--max-queue", type=int, default=64)
    parser.add_argument("--leading-silence-ms", type=int, default=0)
    parser.add_argument("--player", default=os.environ.get("SPEAK_PLAYER", "pw-play"))
    parser.add_argument("--target", default=os.environ.get("SPEAK_TARGET", ""))
    args = parser.parse_args(argv)

    def synthesize(text, sink, on_connect, voice):
        http_engine.generate(text, sink, voice, args.speed, on_connect)

    bridge = Bridge(
        synthesize,
        player_command(args.player, args.volume, args.target),
        args.max_queue,
        args.leading_silence_ms,
        args.voice,
    )
    transport = None
    if args.nats_url:
        from speech_nats import Transport

        transport = Transport(bridge, args.nats_url, args.max_chars)
        transport.start()
    worker = threading.Thread(target=bridge.run, daemon=True)
    worker.start()
    server = Server((args.host, args.port), bridge, args.max_chars)

    def terminate(signum, frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    log(f"listening on {args.host}:{args.port}")
    try:
        server.serve_forever()
    finally:
        bridge.close()
        if transport:
            transport.close()
        server.server_close()
        worker.join(timeout=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
