import json
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, Mock

import clipboard_nats


class ClipboardTests(unittest.IsolatedAsyncioTestCase):
    def client(self, state, accepted=True):
        nc = SimpleNamespace(request=AsyncMock())
        nc.request.side_effect = [
            SimpleNamespace(data=json.dumps(state).encode()),
            *[SimpleNamespace(data=json.dumps({"accepted": accepted}).encode()) for _ in range(10)],
        ]
        return nc

    async def test_active_speech_stops_without_reading_clipboard(self):
        nc = self.client({"active": True})
        read = Mock(side_effect=AssertionError("must not read"))
        await clipboard_nats.toggle(nc, read)
        self.assertEqual(nc.request.call_args.args[0], "speech.intent.stop")
        read.assert_not_called()

    async def test_chunks_are_contiguous_and_final(self):
        nc = self.client({"active": False})
        await clipboard_nats.toggle(nc, lambda: "abcdefgh", 3)
        calls = nc.request.call_args_list[1:]
        bodies = [json.loads(call.args[1]) for call in calls]
        self.assertEqual([b["text"] for b in bodies], ["abc", "def", "gh"])
        self.assertEqual([b["seq"] for b in bodies], [0, 1, 2])
        self.assertEqual([b["final"] for b in bodies], [False, False, True])
        self.assertEqual(len({b["utt"] for b in bodies}), 1)
        self.assertTrue(all(b["origin"] == "clipboard" for b in bodies))

    async def test_empty_clipboard_is_idle(self):
        nc = self.client({"active": False})
        await clipboard_nats.toggle(nc, lambda: "  ")
        self.assertEqual(nc.request.await_count, 1)

    async def test_rejected_request_fails_without_retry(self):
        nc = self.client({"active": False}, False)
        with self.assertRaises(ValueError):
            await clipboard_nats.toggle(nc, lambda: "hello")
        self.assertEqual(nc.request.await_count, 2)

    async def test_timeout_does_not_fall_back_to_local_audio(self):
        nc = self.client({})
        nc.request.side_effect = TimeoutError()
        with self.assertRaises(TimeoutError):
            await clipboard_nats.toggle(nc, Mock())
