import argparse
import asyncio
import json
import math
import time
import uuid

import nats
from notifications import agent_of, notification, notify_argv
from voice_control import request

DEVICE = "pale_cube"
TOPIC = "zigbee2mqtt/Cube"
ACTIONS = {"shake", "tap", "flip90", "flip180", "slide", "rotate_left", "rotate_right"}


def decode(data, limit=4096):
    if len(data) > limit:
        raise ValueError("payload too large")
    body = json.loads(data)
    if not isinstance(body, dict):
        raise ValueError("expected object")
    return body


def gesture(body):
    action = body.get("action")
    if not isinstance(action, str) or action not in ACTIONS:
        raise ValueError("invalid action")
    result = {"action": action}
    if action.startswith("rotate_"):
        angle = body.get("angle")
        if (
            type(angle) not in (int, float)
            or not math.isfinite(angle)
            or abs(angle) > 360
        ):
            raise ValueError("invalid angle")
        if (action == "rotate_left" and angle > 0) or (
            action == "rotate_right" and angle < 0
        ):
            raise ValueError("angle direction mismatch")
        result["angle"] = angle
    return result


def fresh(body):
    ts = body.get("ts")
    if (
        type(ts) not in (int, float)
        or not math.isfinite(ts)
        or not 0 <= time.time() - ts <= 2
    ):
        raise ValueError("expired event")


class CubeController:
    def __init__(self, call):
        self.call = call

    async def handle(self, subject, body):
        fresh(body)
        event = gesture(body)
        action = event["action"]
        if subject != f"cube.evt.{DEVICE}.{action}":
            raise ValueError("subject mismatch")
        if action in ("tap", "flip90"):
            command, payload = "speech.cmd.stop", {}
        elif action == "shake":
            command, payload = "host.cmd.handy", {"action": "toggle"}
        elif action.startswith("rotate_"):
            step = (abs(int(event["angle"])) + 4) // 5
            command, payload = (
                "host.cmd.volume",
                {"delta": step if action == "rotate_right" else -step},
            )
        else:
            return {"accepted": True, "reason": "unbound"}
        if command.startswith("host."):
            payload.update(ts=time.time(), id=str(uuid.uuid4()))
        result = await self.call(command, payload)
        if result.get("accepted") is not True:
            raise RuntimeError(f"command rejected: {command}")
        return result


class Controller(CubeController):
    def __init__(self, call, deny_agents=()):
        super().__init__(call)
        self.deny_agents = frozenset(deny_agents)

    async def handle(self, subject, body):
        if subject.startswith("agent."):
            payload = notification(subject, body)
            agent = agent_of(body)
            if agent and agent in self.deny_agents:
                print(
                    f"agent controller: dropped settled from agent {agent}", flush=True
                )
                return {"accepted": True, "reason": "denied agent"}
            payload.update(ts=time.time(), id=str(uuid.uuid4()))
            result = await self.call("host.cmd.notify", payload)
            if result.get("accepted") is not True:
                raise RuntimeError("notification rejected")
            return result
        return await super().handle(subject, body)


class HostExecutor:
    def __init__(self, handy, wpctl, notify_send="notify-send"):
        self.handy = handy
        self.wpctl = wpctl
        self.notify_send = notify_send

    async def handle(self, subject, body):
        fresh(body)
        if subject == "host.cmd.notify":
            args = notify_argv(self.notify_send, body)
        elif subject == "host.cmd.handy" and body.get("action") in ("toggle", "cancel"):
            args = [
                self.handy,
                "--toggle-transcription" if body["action"] == "toggle" else "--cancel",
            ]
        elif (
            subject == "host.cmd.volume"
            and type(body.get("delta")) is int
            and abs(body["delta"]) <= 72
        ):
            delta = body["delta"]
            args = [self.wpctl, "set-volume"]
            if delta >= 0:
                args += ["-l", "1.0"]
            args += [
                "@DEFAULT_AUDIO_SINK@",
                f"{abs(delta)}%{'+' if delta >= 0 else '-'}",
            ]
        else:
            raise ValueError("invalid command")
        process = await asyncio.create_subprocess_exec(*args)
        try:
            await asyncio.wait_for(process.wait(), 3)
        except BaseException:
            if process.returncode is None:
                process.kill()
            await process.wait()
            raise
        return {"accepted": process.returncode == 0, "returncode": process.returncode}


async def publish(nc, subject, body):
    if not nc.is_connected:
        raise ConnectionError("NATS unavailable")
    await nc.publish(subject, json.dumps(body).encode())
    await nc.flush(timeout=1)


async def relay(nc, mosquitto, host, port):
    process = await asyncio.create_subprocess_exec(
        mosquitto,
        "-h",
        host,
        "-p",
        str(port),
        "-t",
        TOPIC,
        "-R",
        stdout=asyncio.subprocess.PIPE,
        limit=8192,
    )
    try:
        while True:
            line = await process.stdout.readline()
            if not line:
                raise ConnectionError("MQTT relay exited")
            try:
                event = gesture(decode(line))
            except (ValueError, TypeError):
                print("cube relay: rejected payload", flush=True)
                continue
            event["ts"] = time.time()
            await publish(nc, f"cube.evt.{DEVICE}.{event['action']}", event)
    finally:
        if process.returncode is None:
            process.terminate()
        try:
            await asyncio.wait_for(process.wait(), 2)
        except TimeoutError:
            process.kill()
            await process.wait()


async def serve(
    url,
    mode,
    handy="handy",
    wpctl="wpctl",
    mosquitto="mosquitto_sub",
    host="haze",
    port=1883,
    notify_send="notify-send",
    deny_agents=(),
):
    disconnected = asyncio.Event()

    async def disconnect():
        disconnected.set()

    nc = await nats.connect(
        url,
        allow_reconnect=False,
        pending_size=0,
        connect_timeout=2,
        ping_interval=0.5,
        max_outstanding_pings=2,
        disconnected_cb=disconnect,
        closed_cb=disconnect,
    )
    queue = asyncio.Queue(maxsize=64)
    handler = (
        Controller(lambda s, b: request(nc, s, b), deny_agents)
        if mode == "controller"
        else HostExecutor(handy, wpctl, notify_send)
    )

    async def report(result, subject):
        await publish(
            nc,
            "cube.evt.controller.result"
            if mode == "controller"
            else "host.evt.execution",
            {"subject": subject, **result},
        )

    async def receive(msg):
        try:
            queue.put_nowait(msg)
        except asyncio.QueueFull:
            result = {"accepted": False, "reason": "busy"}
            await report(result, msg.subject)
            if msg.reply:
                await msg.respond(json.dumps(result).encode())

    async def work():
        if mode == "relay":
            await relay(nc, mosquitto, host, port)
            return
        subjects = (
            [f"cube.evt.{DEVICE}.*", "agent.evt.*.settled"]
            if mode == "controller"
            else ["host.cmd.handy", "host.cmd.volume", "host.cmd.notify"]
        )
        for subject in subjects:
            await nc.subscribe(
                subject, cb=receive, pending_msgs_limit=64, pending_bytes_limit=262144
            )
        await nc.flush()
        while True:
            msg = await queue.get()
            try:
                result = await handler.handle(
                    msg.subject,
                    decode(
                        msg.data, 8192 if msg.subject.startswith("agent.") else 4096
                    ),
                )
            except (
                ValueError,
                RecursionError,
                TypeError,
                OSError,
                RuntimeError,
                TimeoutError,
                nats.errors.Error,
            ) as error:
                print(f"cube {mode}: {type(error).__name__}: {error}", flush=True)
                result = {"accepted": False, "reason": type(error).__name__}
            await report(result, msg.subject)
            if msg.reply:
                await msg.respond(json.dumps(result).encode())

    async def watch_connection():
        while nc.is_connected and not disconnected.is_set():
            await asyncio.sleep(0.1)

    worker = asyncio.create_task(work())
    outage = asyncio.create_task(watch_connection())
    try:
        done, _ = await asyncio.wait(
            (worker, outage), return_when=asyncio.FIRST_COMPLETED
        )
        if worker in done:
            await worker
        raise ConnectionError("NATS disconnected; cube control stopped")
    finally:
        worker.cancel()
        outage.cancel()
        await asyncio.gather(worker, outage, return_exceptions=True)
        await nc.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("controller", "executor", "relay"))
    parser.add_argument("--url", required=True)
    parser.add_argument("--handy", default="handy")
    parser.add_argument("--wpctl", default="wpctl")
    parser.add_argument("--notify-send", default="notify-send")
    parser.add_argument("--mosquitto", default="mosquitto_sub")
    parser.add_argument("--mqtt-host", default="haze")
    parser.add_argument("--mqtt-port", type=int, default=1883)
    parser.add_argument("--deny-agent", action="append", default=[])
    args = parser.parse_args()
    asyncio.run(
        serve(
            args.url,
            args.mode,
            args.handy,
            args.wpctl,
            args.mosquitto,
            args.mqtt_host,
            args.mqtt_port,
            args.notify_send,
            args.deny_agent,
        )
    )


if __name__ == "__main__":
    main()
