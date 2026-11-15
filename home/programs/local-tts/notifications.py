import html
import math
import re
import unicodedata

SUMMARY = re.compile(r".+ idle( \((aborted|error|aborted, error)\))?", re.S)


def label(value, limit=80):
    if not isinstance(value, str):
        return ""
    text = " ".join(
        "".join(
            c if not unicodedata.category(c).startswith("C") else " " for c in value
        ).split()
    )
    return text[:limit]


def lines(value, limit=256):
    if not isinstance(value, str):
        return ""
    return "\n".join(filter(None, (label(line, limit) for line in value.split("\n"))))[
        :limit
    ]


def duration(ms):
    if type(ms) not in (int, float) or not math.isfinite(ms) or ms < 0:
        return ""
    seconds = int(ms // 1000)
    hours, rest = divmod(seconds, 3600)
    minutes, seconds = divmod(rest, 60)
    if hours:
        return f"{hours}h{minutes:02d}m"
    if minutes:
        return f"{minutes}m{seconds:02d}s"
    return f"{seconds}s"


def last_segment(value):
    return label(value).rstrip("/").rsplit("/", 1)[-1].strip()


def home_short(path):
    return re.sub(r"^(/home/[^/]+|/root)(?=/|$)", "~", label(path))


def agent_of(body):
    return label(body.get("agent"))


def notification(subject, body):
    sid = body.get("sid")
    if (
        body.get("v") != 1
        or body.get("kind") != "settled"
        or not isinstance(sid, str)
        or not sid
        or len(sid) > 512
        or subject != f"agent.evt.{re.sub(r'[^A-Za-z0-9_=-]', '_', sid)}.settled"
        or not isinstance(body.get("host"), str)
        or type(body.get("aborted")) is not bool
    ):
        raise ValueError("invalid settled event")
    status = []
    if body["aborted"]:
        status.append("aborted")
    if (
        body.get("errored") is True
        or body.get("error")
        or body.get("state") == "error"
        or body.get("stopReason") == "error"
    ):
        status.append("error")
    suffix = " idle" + (f" ({', '.join(status)})" if status else "")
    name = (
        label(body.get("context_title"))
        or last_segment(body.get("context"))
        or label(body.get("session_name"))
        or last_segment(body.get("cwd"))
        or label(sid)
    )
    summary = name[: 100 - len(suffix)] + suffix
    tools = body.get("tools")
    work = [duration(body.get("turn_ms"))]
    if work[0]:
        work[0] = f"turn {work[0]}"
    if type(tools) is int and tools >= 0:
        work.append(f"{tools} tool{'' if tools == 1 else 's'}")
    agent = agent_of(body)
    parts = [
        label(body.get("context")),
        home_short(body.get("cwd")),
        f"agent {agent}" if agent else "",
        ", ".join(filter(None, work)),
        label(body["host"]),
    ]
    return {"summary": summary, "body": "\n".join(filter(None, parts))[:256]}


def notify_argv(executable, body):
    summary = body.get("summary")
    text = body.get("body")
    if (
        not isinstance(summary, str)
        or not SUMMARY.fullmatch(summary)
        or len(summary) > 100
        or not isinstance(text, str)
        or len(text) > 256
    ):
        raise ValueError("invalid notification")
    return [
        executable,
        "--app-name=Agent controller",
        "--urgency=normal",
        "--expire-time=8000",
        "--",
        html.escape(label(summary, 100)),
        html.escape(lines(text, 256)),
    ]
