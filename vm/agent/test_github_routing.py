import asyncio

import nats
from nats.errors import NoRespondersError


async def connect(**kwargs):
    for _ in range(100):
        try:
            return await nats.connect(
                "nats://127.0.0.1:14222", connect_timeout=0.1, **kwargs
            )
        except OSError:
            await asyncio.sleep(0.05)
    raise AssertionError("NATS did not start")


async def main():
    host = await connect()
    agent = await connect(user="github-test-agent", password="github-test-only")
    try:
        requests = []

        async def respond(message):
            requests.append(message.subject)
            if message.reply:
                await message.respond(b'{"revision":1}')

        await agent.subscribe("github.api.>", cb=respond)
        await agent.flush()
        for subject in ("github.api.v1.snapshot", "github.api.v1.refresh"):
            reply = await host.request(subject, b"{}", timeout=2)
            assert reply.data == b'{"revision":1}'
        assert requests == ["github.api.v1.snapshot", "github.api.v1.refresh"]
        for subject in ("github.api.v2.snapshot", "github.api.v1.private.extra"):
            try:
                await host.request(subject, b"{}", timeout=0.2)
            except NoRespondersError:
                pass
            else:
                raise AssertionError(f"Unexpected service export: {subject}")

        observed = []

        async def observe(message):
            observed.append(message.subject)

        await host.subscribe("github.>", cb=observe)
        await host.flush()
        for subject in (
            "github.evt.v2.changed",
            "github.evt.v1.private.extra",
            "github.private.changed",
            "github.api.v1.snapshot",
            "github.evt.v1.changed",
        ):
            await agent.publish(subject, b"event")
        await agent.flush()
        for _ in range(100):
            if "github.evt.v1.changed" in observed:
                break
            await asyncio.sleep(0.01)
        assert observed == ["github.evt.v1.changed"], observed
    finally:
        await agent.close()
        await host.close()


asyncio.run(main())
