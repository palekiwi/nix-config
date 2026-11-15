import asyncio
import json
import threading

import nats


class Transport:
    def __init__(self, bridge, url, max_chars):
        self.bridge = bridge
        self.url = url
        self.max_chars = max_chars
        self.loop = asyncio.new_event_loop()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.nc = None
        self.stopping = False

    def start(self):
        self.bridge.emit = self.emit
        self.thread.start()

    def run(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_until_complete(self.serve())
        self.loop.close()

    async def error(self, error):
        pass

    async def serve(self):
        while not self.stopping:
            try:
                self.nc = await nats.connect(
                    self.url,
                    connect_timeout=1,
                    max_reconnect_attempts=-1,
                    reconnect_time_wait=1,
                    pending_size=0,
                    error_cb=self.error,
                )
                for subject in (
                    "speech.intent.*",
                    "speech.cmd.*",
                    "speech.query.state",
                ):
                    await self.nc.subscribe(subject, cb=self.message)
                await self.nc.flush()
                while not self.stopping:
                    await asyncio.sleep(0.1)
                break
            except (OSError, nats.errors.Error):
                if self.nc:
                    await self.nc.close()
                await asyncio.sleep(1)
        if self.nc:
            await self.nc.close()

    async def message(self, msg):
        try:
            if msg.subject == "speech.query.state":
                result = self.bridge.health()
            else:
                if len(msg.data) > 8192:
                    raise ValueError("oversize")
                body = json.loads(msg.data)
                if not isinstance(body, dict):
                    raise ValueError("invalid message")
                if msg.subject == "speech.intent.say":
                    accepted = self.bridge.intent(body, self.max_chars)
                elif msg.subject in ("speech.intent.stop", "speech.cmd.stop"):
                    self.bridge.stop(
                        "requested"
                        if msg.subject == "speech.intent.stop"
                        else "command"
                    )
                    accepted = True
                elif msg.subject == "speech.cmd.hold":
                    self.bridge.hold(body.get("id"), body.get("ttl"))
                    accepted = True
                elif msg.subject == "speech.cmd.release":
                    self.bridge.release(body.get("id"))
                    accepted = True
                else:
                    raise ValueError("unknown subject")
                result = {"accepted": accepted}
        except (ValueError, TypeError):
            result = {"accepted": False, "reason": "invalid"}
        if msg.reply:
            await self.publish(msg.reply, result)

    async def publish(self, subject, body):
        if self.nc and self.nc.is_connected:
            try:
                await self.nc.publish(subject, json.dumps(body).encode())
            except (OSError, nats.errors.Error):
                pass

    def emit(self, subject, body):
        if (
            not self.stopping
            and self.loop.is_running()
            and self.nc
            and self.nc.is_connected
        ):
            self.loop.call_soon_threadsafe(
                lambda: self.loop.create_task(self.publish(subject, body))
            )

    def close(self):
        self.stopping = True
        self.thread.join(timeout=3)
