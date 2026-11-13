import io
import json
import unittest

from validate import Processor


def speech_line(payload):
    if isinstance(payload, str):
        payload = payload.encode("utf-8")
    return payload.hex().encode("ascii") + b"\n"


def inbox_line(payload, topic="host/agent/pi/inbox"):
    if isinstance(payload, str):
        payload = payload.encode("utf-8")
    return payload.hex().encode("ascii") + b" " + topic.encode("utf-8") + b"\n"


class Clock:
    def __init__(self):
        self.now = 100.0

    def __call__(self):
        return self.now


def run(mode, lines, **kwargs):
    out = io.StringIO()
    processor = Processor(mode, out, **kwargs)
    for line in lines:
        processor.handle(line)
    records = [json.loads(line) for line in out.getvalue().splitlines()]
    return processor, records, out.getvalue()


def reasons(records):
    return [r["reason"] for r in records if r["event"] == "rejected"]


class SpeechTest(unittest.TestCase):
    def test_accepts_valid_request(self):
        payload = json.dumps({"v": 1, "agent": "pi-2", "text": "hello"})
        _, records, _ = run("speech", [speech_line(payload)])
        self.assertEqual(
            records, [{"event": "accepted", "agent": "pi-2", "text": "hello"}]
        )

    def test_rejections(self):
        cases = {
            "framing": b"zz\n",
            "json": speech_line("not json"),
            "utf8": speech_line(b"\xff\xfe"),
            "version": speech_line('{"v":2,"agent":"a","text":"t"}'),
            "keys": speech_line('{"v":1,"agent":"a","text":"t","x":1}'),
            "agent": speech_line('{"v":1,"agent":"A!","text":"t"}'),
            "text_type": speech_line('{"v":1,"agent":"a","text":5}'),
            "text_length": speech_line('{"v":1,"agent":"a","text":""}'),
            "duplicate_key": speech_line('{"v":1,"v":1,"agent":"a","text":"t"}'),
            "size": speech_line('{"v":1,"agent":"a","text":"' + "a" * 3000 + '"}'),
        }
        for reason, line in cases.items():
            with self.subTest(reason=reason):
                _, records, _ = run("speech", [line])
                self.assertEqual(reasons(records), [reason])

    def test_version_must_be_integer(self):
        for v in ["true", "1.0", '"1"', "NaN"]:
            with self.subTest(v=v):
                line = speech_line('{"v":' + v + ',"agent":"a","text":"t"}')
                _, records, _ = run("speech", [line])
                self.assertEqual(len(reasons(records)), 1)

    def test_agent_bounds(self):
        ok = json.dumps({"v": 1, "agent": "a" * 32, "text": "t"})
        long = json.dumps({"v": 1, "agent": "a" * 33, "text": "t"})
        trailing = json.dumps({"v": 1, "agent": "a\n", "text": "t"})
        _, records, _ = run("speech", [speech_line(p) for p in [ok, long, trailing]])
        self.assertEqual(records[0]["event"], "accepted")
        self.assertEqual(reasons(records), ["agent", "agent"])

    def test_text_length_bounds(self):
        ok = json.dumps({"v": 1, "agent": "a", "text": "x" * 280})
        long = json.dumps({"v": 1, "agent": "a", "text": "x" * 281})
        blank = json.dumps({"v": 1, "agent": "a", "text": "   "})
        _, records, _ = run("speech", [speech_line(p) for p in [ok, long, blank]])
        self.assertEqual(records[0]["event"], "accepted")
        self.assertEqual(reasons(records), ["text_length", "text_length"])

    def test_control_and_format_characters_rejected(self):
        for ch in [
            "\x00",
            "\x07",
            "\n",
            "\t",
            "\x1b",
            "\x9b",
            "\u200b",
            "\u200d",
            "\u202e",
            "\u2066",
            "\u2028",
            "\ufeff",
            "\ud800",
            "\ue000",
        ]:
            with self.subTest(ch=hex(ord(ch))):
                payload = json.dumps({"v": 1, "agent": "a", "text": "a" + ch + "b"})
                _, records, _ = run("speech", [speech_line(payload)])
                self.assertEqual(reasons(records), ["text_chars"])

    def test_accepted_record_is_escaped(self):
        text = 'caf\u00e9 <b>"x"</b> \\ $(rm) `id`'
        payload = json.dumps({"v": 1, "agent": "a", "text": text}, ensure_ascii=False)
        _, records, raw = run("speech", [speech_line(payload)])
        self.assertEqual(records[0]["text"], text)
        self.assertTrue(raw.isascii())
        self.assertEqual(raw.count("\n"), 1)
        self.assertIn("caf\\u00e9", raw)

    def test_rejection_never_logs_payload(self):
        marker = "RAWMARKER"
        lines = [
            speech_line(marker),
            speech_line('{"v":2,"agent":"a","text":"' + marker + '"}'),
            speech_line('{"v":1,"agent":"a","text":"' + marker + '\\u202e"}'),
            speech_line('{"v":1,"agent":"a","text":"' + marker * 40 + '"}'),
            speech_line(marker.encode() + b"\xff"),
        ]
        _, records, raw = run("speech", lines)
        self.assertEqual(len(reasons(records)), 5)
        self.assertNotIn(marker, raw)
        self.assertNotIn(marker.encode().hex(), raw)

    def test_rate_limit(self):
        clock = Clock()
        out = io.StringIO()
        processor = Processor("speech", out, accept_interval=3, clock=clock)

        def send(text):
            processor.handle(
                speech_line(json.dumps({"v": 1, "agent": "a", "text": text}))
            )

        send("one")
        send("two")
        clock.now += 1
        send("three")
        clock.now += 2
        send("four")
        records = [json.loads(line) for line in out.getvalue().splitlines()]
        accepted = [r["text"] for r in records if r["event"] == "accepted"]
        self.assertEqual(accepted, ["one", "four"])
        self.assertEqual(reasons(records), ["rate_limited", "rate_limited"])
        self.assertEqual(processor.accepted, 2)
        self.assertEqual(processor.rejected, 2)

    def test_rejection_logs_are_rate_limited(self):
        clock = Clock()
        out = io.StringIO()
        processor = Processor("speech", out, reject_log_interval=10, clock=clock)
        for _ in range(5):
            processor.handle(b"zz\n")
        clock.now += 10
        processor.handle(b"zz\n")
        records = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(len(records), 2)
        self.assertNotIn("suppressed", records[0])
        self.assertEqual(records[1]["suppressed"], 4)
        self.assertEqual(records[1]["rejected_total"], 6)


class InboxTest(unittest.TestCase):
    def test_accepts_allowlisted_agent(self):
        payload = json.dumps({"v": 1, "text": "hi"})
        _, records, _ = run("inbox", [inbox_line(payload)], allowed=["pi"])
        self.assertEqual(records, [{"event": "accepted", "agent": "pi", "text": "hi"}])

    def test_rejections(self):
        ok = json.dumps({"v": 1, "text": "hi"})
        cases = {
            "agent": inbox_line(ok, "host/agent/other/inbox"),
            "topic": inbox_line(ok, "host/agent/pi/inbox/x"),
            "framing": inbox_line(ok)[:-1].replace(b" ", b"") + b"\n",
            "keys": inbox_line('{"v":1,"text":"t","agent":"pi"}'),
            "version": inbox_line('{"v":0,"text":"t"}'),
            "text_length": inbox_line(json.dumps({"v": 1, "text": "x" * 2001})),
            "text_chars": inbox_line(json.dumps({"v": 1, "text": "a\u202eb"})),
            "size": inbox_line(json.dumps({"v": 1, "text": "x" * 13000})),
        }
        for reason, line in cases.items():
            with self.subTest(reason=reason):
                _, records, _ = run("inbox", [line], allowed=["pi"])
                self.assertEqual(reasons(records), [reason])

    def test_text_limit(self):
        ok = json.dumps({"v": 1, "text": "\u00e9" * 2000}, ensure_ascii=False)
        _, records, raw = run("inbox", [inbox_line(ok)], allowed=["pi"])
        self.assertEqual(records[0]["event"], "accepted")
        self.assertTrue(raw.isascii())

    def test_topic_with_newline_cannot_inject(self):
        payload = json.dumps({"v": 1, "text": "hi"})
        level = "x\n" + payload.encode().hex() + " pi"
        line = inbox_line(payload, "host/agent/" + level + "/inbox")
        _, records, _ = run("inbox", line.splitlines(keepends=True), allowed=["pi"])
        self.assertEqual(reasons(records), ["topic", "topic"])


if __name__ == "__main__":
    unittest.main()
