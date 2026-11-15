import argparse
import asyncio
import json
import uuid

import nats


async def request(nc, subject, body):
    if not nc.is_connected:
        raise ConnectionError("NATS is unavailable")
    reply = await nc.request(subject, json.dumps(body).encode(), timeout=2)
    result = json.loads(reply.data)
    if not isinstance(result, dict):
        raise TypeError("invalid acknowledgement")
    return result


class Controller:
    def __init__(self, call, hold_id=None, ttl=15):
        self.call = call
        self.hold_id = hold_id or f"dictation-{uuid.uuid4()}"
        self.ttl = ttl
        self.observed = "unknown"
        self.requested = None

    async def accepted(self, subject, body):
        result = await self.call(subject, body)
        if result.get("accepted") is not True:
            raise RuntimeError(f"command rejected: {subject}")

    async def hold(self):
        await self.accepted("speech.cmd.hold", {"id": self.hold_id, "ttl": self.ttl})

    async def reconcile(self):
        state = await self.call("dictation.query.state", {})
        observed = state.get("observed", "unknown")
        if observed not in ("started", "stopped", "unknown"):
            raise ValueError("invalid dictation observation")
        previous = self.observed
        self.observed = observed
        if observed == "started":
            if previous != "started":
                await self.accepted("speech.cmd.stop", {})
            await self.hold()
            self.requested = None
        elif observed == "stopped":
            await self.accepted("speech.cmd.release", {"id": self.hold_id})
            self.requested = None

    async def handle(self, subject):
        if subject in ("dictation.intent.toggle", "dictation.intent.cancel"):
            await self.accepted("speech.cmd.stop", {})
            await self.hold()
            action = subject.rsplit(".", 1)[1]
            self.requested = action
            result = await self.call(f"dictation.cmd.{action}", {})
            if result.get("accepted") is not True:
                self.requested = None
                return result
            await self.reconcile()
            return {"accepted": True}
        await self.reconcile()
        return {"accepted": True}


class HandyAdapter:
    def __init__(self, executable):
        self.executable = executable

    async def handle(self, subject):
        if subject == "dictation.query.state":
            return {"observed": "unknown", "reason": "observer_unavailable"}
        if subject == "dictation.cmd.toggle":
            return {"accepted": False, "reason": "observer_unavailable"}
        if subject != "dictation.cmd.cancel":
            return {"accepted": False, "reason": "invalid"}
        process = await asyncio.create_subprocess_exec(self.executable, "--cancel")
        try:
            await asyncio.wait_for(process.wait(), timeout=3)
        except BaseException:
            if process.returncode is None:
                process.kill()
            await process.wait()
            raise
        return {"accepted": process.returncode == 0, "observed": "unknown"}


async def serve(url, mode, handy):
    disconnected = asyncio.Event()
    queue = asyncio.Queue(maxsize=64)

    async def disconnect():
        disconnected.set()

    nc = await nats.connect(
        url,
        connect_timeout=2,
        allow_reconnect=False,
        pending_size=0,
        ping_interval=0.5,
        max_outstanding_pings=2,
        disconnected_cb=disconnect,
        closed_cb=disconnect,
    )
    handler = (
        Controller(lambda subject, body: request(nc, subject, body))
        if mode == "controller"
        else HandyAdapter(handy)
    )

    async def receive(msg):
        try:
            queue.put_nowait(msg)
        except asyncio.QueueFull:
            if msg.reply:
                await msg.respond(b'{"accepted":false,"reason":"busy"}')

    subjects = (
        ("dictation.intent.toggle", "dictation.intent.cancel")
        if mode == "controller"
        else ("dictation.cmd.toggle", "dictation.cmd.cancel", "dictation.query.state")
    )
    for subject in subjects:
        await nc.subscribe(subject, cb=receive)
    await nc.flush()

    async def work():
        if mode == "controller":
            await handler.reconcile()
        deadline = asyncio.get_running_loop().time() + 2
        while True:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                if mode == "controller":
                    await handler.reconcile()
                deadline = asyncio.get_running_loop().time() + 2
                continue
            try:
                msg = await asyncio.wait_for(queue.get(), timeout=remaining)
            except TimeoutError:
                continue
            try:
                body = json.loads(msg.data)
                if not isinstance(body, dict) or len(msg.data) > 1024:
                    raise ValueError("invalid message")
                result = await handler.handle(msg.subject)
            except (
                TimeoutError,
                TypeError,
                ValueError,
                OSError,
                RuntimeError,
                nats.errors.Error,
            ) as error:
                print(f"voice {mode}: {type(error).__name__}: {error}", flush=True)
                result = {"accepted": False, "reason": "unavailable"}
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
        raise ConnectionError("NATS disconnected; voice control stopped")
    finally:
        worker.cancel()
        outage.cancel()
        await asyncio.gather(worker, outage, return_exceptions=True)
        await nc.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("controller", "adapter", "toggle", "cancel"))
    parser.add_argument("--url", required=True)
    parser.add_argument("--handy", default="handy")
    args = parser.parse_args()
    if args.mode in ("controller", "adapter"):
        asyncio.run(serve(args.url, args.mode, args.handy))
    else:

        async def send():
            nc = await nats.connect(
                args.url, allow_reconnect=False, pending_size=0, connect_timeout=2
            )
            try:
                result = await request(nc, f"dictation.intent.{args.mode}", {})
                if result.get("accepted") is not True:
                    raise RuntimeError(f"dictation rejected: {result.get('reason')}")
            finally:
                await nc.close()

        asyncio.run(send())


if __name__ == "__main__":
    main()
