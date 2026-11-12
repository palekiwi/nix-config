import argparse
import json
import os
import signal
import socket
import socketserver
import subprocess
import sys
import threading
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import http_engine

IP_FREEBIND = getattr(socket, "IP_FREEBIND", 15)
MAX_BODY = 8192


class Stale(Exception):
    pass


def log(message):
    print(f"speech-bridge: {message}", file=sys.stderr, flush=True)


def player_command(player, volume):
    return [
        player,
        "--raw",
        "--format=s16",
        "--rate=24000",
        "--channels=1",
        f"--volume={volume}",
        "--properties={ application.name = speak state.restore-props = false }",
        "-",
    ]


class Sink:
    def __init__(self, bridge, generation):
        self.bridge = bridge
        self.generation = generation
        self.player = None

    def writeframesraw(self, data):
        if self.player is None:
            self.player = self.bridge.start_player(self.generation)
        try:
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

    def __init__(self, synthesize, command, max_queue):
        self.synthesize = synthesize
        self.command = command
        self.max_queue = max_queue
        self.lock = threading.Lock()
        self.ready = threading.Condition(self.lock)
        self.queue = deque()
        self.generation = 0
        self.player = None
        self.socket = None
        self.speaking = False
        self.closed = False

    def say(self, text):
        with self.lock:
            if len(self.queue) >= self.max_queue:
                return False
            self.queue.append((self.generation, text))
            self.ready.notify()
            return True

    def stop(self):
        with self.lock:
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
            return {"queued": len(self.queue), "speaking": self.speaking}

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
            if generation == self.generation:
                self.player = player
                return player
        player.kill()
        player.stdin.close()
        player.wait()
        raise Stale()

    def run(self):
        while True:
            with self.lock:
                while not self.queue and not self.closed:
                    self.ready.wait()
                if self.closed:
                    return
                generation, text = self.queue.popleft()
                self.speaking = True
            try:
                self.speak(generation, text)
            finally:
                with self.lock:
                    self.player = None
                    self.socket = None
                    self.speaking = False

    def speak(self, generation, text):
        sink = Sink(self, generation)
        try:
            self.check(generation)
            self.synthesize(text, sink, lambda sock: self.connected(generation, sock))
            code = sink.finish()
            self.check(generation)
            if code:
                log(f"player exited with status {code}")
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
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--voice", default="af_bella")
    parser.add_argument("--speed", type=float, default=1.0)
    parser.add_argument("--volume", default=os.environ.get("SPEAK_VOLUME", "1"))
    parser.add_argument("--max-chars", type=int, default=1000)
    parser.add_argument("--max-queue", type=int, default=64)
    parser.add_argument("--player", default=os.environ.get("SPEAK_PLAYER", "pw-play"))
    args = parser.parse_args(argv)

    def synthesize(text, sink, on_connect):
        http_engine.generate(text, sink, args.voice, args.speed, on_connect)

    bridge = Bridge(
        synthesize, player_command(args.player, args.volume), args.max_queue
    )
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
        server.server_close()
        worker.join(timeout=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
