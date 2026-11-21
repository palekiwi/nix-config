import argparse
import asyncio
import http.client
import json
import math
import os
import time
import uuid

import nats
from notifications import (
    agent_of,
    gotify_message,
    notification,
    notify_argv,
    post_gotify,
    status_of,
)
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
    def __init__(self, call, deny_agents=(), gotify=None):
        super().__init__(call)
        self.deny_agents = frozenset(deny_agents)
        self.gotify = gotify

    async def deliver(self, subject, payload):
        payload.update(ts=time.time(), id=str(uuid.uuid4()))
        try:
            result = await self.call(subject, payload)
        except (
            ValueError,
            TypeError,
            OSError,
            RuntimeError,
            TimeoutError,
            nats.errors.Error,
        ) as error:
            return f"{subject} {type(error).__name__}"
        return None if result.get("accepted") is True else f"{subject} rejected"

    async def handle(self, subject, body):
        if subject.startswith("agent."):
            payload = notification(subject, body)
            agent = agent_of(body)
            if agent and agent in self.deny_agents:
                print(
                    f"agent controller: dropped settled from agent {agent}", flush=True
                )
                return {"accepted": True, "reason": "denied agent"}
            commands = [("host.cmd.notify", payload)]
            if self.gotify and "agent" not in body:
                priority, alert_priority = self.gotify
                commands.append(
                    (
                        "host.cmd.gotify",
                        {
                            "title": payload["summary"],
                            "message": payload["body"],
                            "priority": alert_priority if status_of(body) else priority,
                        },
                    )
                )
            failures = [
                failure
                for failure in [await self.deliver(*command) for command in commands]
                if failure
            ]
            if failures:
                raise RuntimeError("; ".join(failures))
            return {
                "accepted": True,
                "channels": [name.rsplit(".", 1)[1] for name, _ in commands],
            }
        return await super().handle(subject, body)


async def play_blip(kind):
    directory = os.environ.get("SPEAK_BLIP_DIR")
    player = os.environ.get("SPEAK_PLAYER")
    if not directory or not player:
        return
    args = [player, f"--volume={os.environ.get('SPEAK_BLIP_VOLUME', '0.6')}"]
    target = os.environ.get("SPEAK_TARGET", "")
    if target:
        args.append(f"--target={target}")
    args.append(os.path.join(directory, f"{kind}.wav"))
    try:
        process = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await asyncio.wait_for(process.wait(), 2)
    except (OSError, TimeoutError):
        pass


class HostExecutor:
    def __init__(
        self,
        handy,
        wpctl,
        notify_send="notify-send",
        gotify_url=None,
        gotify_token_file=None,
        notify_icons=None,
    ):
        self.handy = handy
        self.wpctl = wpctl
        self.notify_send = notify_send
        self.notify_icons = notify_icons or {}
        self.gotify_url = gotify_url
        self.gotify_token_file = gotify_token_file

    async def handle(self, subject, body):
        fresh(body)
        if subject == "host.cmd.gotify" and self.gotify_url:
            message = gotify_message(body)
            status = await asyncio.wait_for(
                asyncio.to_thread(
                    post_gotify, self.gotify_url, self.gotify_token_file, message, 3
                ),
                3,
            )
            return {"accepted": True, "status": status}
        if subject == "host.cmd.notify":
            args = notify_argv(self.notify_send, body, self.notify_icons)
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
        if subject == "host.cmd.handy":
            kind = (
                "error"
                if process.returncode != 0
                else ("cancel" if body["action"] == "cancel" else "start")
            )
            await play_blip(kind)
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
    gotify=None,
    gotify_url=None,
    gotify_token_file=None,
    notify_icons=None,
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
        Controller(lambda s, b: request(nc, s, b), deny_agents, gotify)
        if mode == "controller"
        else HostExecutor(
            handy, wpctl, notify_send, gotify_url, gotify_token_file, notify_icons
        )
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
            + (["host.cmd.gotify"] if gotify_url else [])
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
                http.client.HTTPException,
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
    parser.add_argument("--notify-icon-interactive")
    parser.add_argument("--notify-icon-headless")
    parser.add_argument("--mosquitto", default="mosquitto_sub")
    parser.add_argument("--mqtt-host", default="haze")
    parser.add_argument("--mqtt-port", type=int, default=1883)
    parser.add_argument("--deny-agent", action="append", default=[])
    parser.add_argument("--gotify", action="store_true")
    parser.add_argument("--gotify-priority", type=int, default=5)
    parser.add_argument("--gotify-alert-priority", type=int, default=7)
    parser.add_argument("--gotify-url")
    parser.add_argument("--gotify-token-file", default="/run/secrets/gotify/token")
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
            (
                (args.gotify_priority, args.gotify_alert_priority)
                if args.gotify
                else None
            ),
            args.gotify_url,
            args.gotify_token_file,
            {
                source: path
                for source, path in (
                    ("interactive", args.notify_icon_interactive),
                    ("headless", args.notify_icon_headless),
                )
                if path
            },
        )
    )


if __name__ == "__main__":
    main()
