import argparse
import json
import re
import sys
import time
import unicodedata

AGENT = re.compile(r"[a-z0-9-]{1,32}")
INBOX_TOPIC = re.compile(r"host/agent/([a-z0-9-]{1,32})/inbox")
HEX = re.compile(rb"(?:[0-9a-f]{2})*")
BANNED_CATEGORIES = {"Cc", "Cf", "Cs", "Co", "Cn", "Zl", "Zp"}

SPEECH_TEXT_MAX = 280
SPEECH_BYTES_MAX = 2048
INBOX_TEXT_MAX = 2000
INBOX_BYTES_MAX = 12288


class Reject(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def _no_duplicates(pairs):
    keys = [k for k, _ in pairs]
    if len(set(keys)) != len(keys):
        raise Reject("duplicate_key")
    return dict(pairs)


def _no_constants(_):
    raise Reject("json")


def decode_hex(data):
    if not HEX.fullmatch(data):
        raise Reject("framing")
    return bytes.fromhex(data.decode("ascii"))


def parse_object(raw, byte_cap):
    if len(raw) > byte_cap:
        raise Reject("size")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise Reject("utf8")
    try:
        obj = json.loads(
            text,
            object_pairs_hook=_no_duplicates,
            parse_constant=_no_constants,
        )
    except (ValueError, RecursionError):
        raise Reject("json")
    if not isinstance(obj, dict):
        raise Reject("json")
    return obj


def check_version(obj):
    v = obj.get("v")
    if type(v) is not int or v != 1:
        raise Reject("version")


def check_text(value, limit):
    if not isinstance(value, str):
        raise Reject("text_type")
    if not 1 <= len(value) <= limit or not value.strip():
        raise Reject("text_length")
    for ch in value:
        if unicodedata.category(ch) in BANNED_CATEGORIES:
            raise Reject("text_chars")
    return value


def validate_speech(raw):
    obj = parse_object(raw, SPEECH_BYTES_MAX)
    check_version(obj)
    if set(obj) != {"v", "agent", "text"}:
        raise Reject("keys")
    agent = obj["agent"]
    if not isinstance(agent, str) or not AGENT.fullmatch(agent):
        raise Reject("agent")
    return {"agent": agent, "text": check_text(obj["text"], SPEECH_TEXT_MAX)}


def validate_inbox(raw, topic, allowed):
    match = INBOX_TOPIC.fullmatch(topic)
    if not match:
        raise Reject("topic")
    agent = match.group(1)
    if agent not in allowed:
        raise Reject("agent")
    obj = parse_object(raw, INBOX_BYTES_MAX)
    check_version(obj)
    if set(obj) != {"v", "text"}:
        raise Reject("keys")
    return {"agent": agent, "text": check_text(obj["text"], INBOX_TEXT_MAX)}


class Limiter:
    def __init__(self, interval, clock):
        self.interval = interval
        self.clock = clock
        self.next = None

    def allow(self):
        now = self.clock()
        if self.next is None or now >= self.next:
            self.next = now + self.interval
            return True
        return False


class Processor:
    def __init__(
        self,
        mode,
        out,
        allowed=(),
        accept_interval=0.0,
        reject_log_interval=0.0,
        clock=time.monotonic,
    ):
        self.mode = mode
        self.out = out
        self.allowed = frozenset(allowed)
        self.accepts = Limiter(accept_interval, clock)
        self.reject_logs = Limiter(reject_log_interval, clock)
        self.accepted = 0
        self.rejected = 0
        self.suppressed = 0

    def validate(self, line):
        line = line.rstrip(b"\n")
        if len(line) > 2 * 16384 + 256:
            raise Reject("size")
        if self.mode == "speech":
            return validate_speech(decode_hex(line))
        payload, sep, topic = line.partition(b" ")
        if not sep:
            raise Reject("framing")
        try:
            topic = topic.decode("utf-8")
        except UnicodeDecodeError:
            raise Reject("topic")
        return validate_inbox(decode_hex(payload), topic, self.allowed)

    def handle(self, line):
        try:
            record = self.validate(line)
        except Reject as e:
            self.reject(e.reason, len(line))
            return
        if not self.accepts.allow():
            self.reject("rate_limited", len(line))
            return
        self.accepted += 1
        self.emit({"event": "accepted", **record})

    def reject(self, reason, size):
        self.rejected += 1
        if not self.reject_logs.allow():
            self.suppressed += 1
            return
        record = {
            "event": "rejected",
            "reason": reason,
            "line_bytes": size,
            "rejected_total": self.rejected,
        }
        if self.suppressed:
            record["suppressed"] = self.suppressed
            self.suppressed = 0
        self.emit(record)

    def emit(self, record):
        self.out.write(json.dumps(record, ensure_ascii=True, sort_keys=True) + "\n")
        self.out.flush()


def main(argv=None):
    parser = argparse.ArgumentParser(prog="agent-mqtt-validate")
    parser.add_argument("mode", choices=["speech", "inbox"])
    parser.add_argument("--agent", action="append", default=[])
    parser.add_argument("--accept-interval", type=float, default=0.0)
    parser.add_argument("--reject-log-interval", type=float, default=10.0)
    args = parser.parse_args(argv)
    processor = Processor(
        args.mode,
        sys.stdout,
        allowed=args.agent,
        accept_interval=args.accept_interval,
        reject_log_interval=args.reject_log_interval,
    )
    for line in sys.stdin.buffer:
        processor.handle(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
