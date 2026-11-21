import html
import json
import math
import re
import unicodedata
import urllib.request

SOURCES = ("interactive", "headless")


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


def agent_of(body):
    return label(body.get("agent"))


def status_of(body):
    status = []
    if body.get("aborted") is True:
        status.append("aborted")
    if (
        body.get("errored") is True
        or body.get("error")
        or body.get("state") == "error"
        or body.get("stopReason") == "error"
    ):
        status.append("error")
    return status


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
    status = ", ".join(status_of(body)) or "idle"
    if "agent" in body:
        source = "headless"
        name = agent_of(body) or label(sid)
        parts = [f"── {status}"]
    else:
        source = "interactive"
        name = (
            label(body.get("tmux_window"))
            or label(body.get("session_name"))
            or last_segment(body.get("context"))
            or label(body.get("context_title"))
            or label(sid)
        )
        tmux_session = label(body.get("tmux_session"))
        parts = [
            label(body.get("session_description")),
            f"── {status} · {tmux_session}" if tmux_session else f"── {status}",
        ]
    return {
        "summary": name[:100],
        "body": "\n".join(filter(None, parts))[:256],
        "source": source,
    }


def valid(summary, text):
    return (
        isinstance(summary, str)
        and label(summary, 100) != ""
        and len(summary) <= 100
        and isinstance(text, str)
        and len(text) <= 256
    )


def notify_argv(executable, body, icons=None):
    summary = body.get("summary")
    text = body.get("body")
    source = body.get("source")
    if not valid(summary, text) or source not in (None, *SOURCES):
        raise ValueError("invalid notification")
    icon = (icons or {}).get(source)
    return [
        executable,
        "--app-name=Agent controller",
        "--urgency=normal",
        "--expire-time=8000",
        *([f"--icon={icon}"] if icon else []),
        "--",
        html.escape(label(summary, 100)),
        html.escape(lines(text, 256)),
    ]


def gotify_message(body):
    title = body.get("title")
    message = body.get("message")
    priority = body.get("priority")
    if (
        not valid(title, message)
        or type(priority) is not int
        or not 0 <= priority <= 10
    ):
        raise ValueError("invalid gotify message")
    return {
        "title": label(title, 100),
        "message": lines(message, 256),
        "priority": priority,
    }


def gotify_token(path):
    with open(path, encoding="utf-8") as file:
        text = file.read(4096)
    token = next((line.strip() for line in text.splitlines() if line.strip()), "")
    if token.startswith("GOTIFY_TOKEN="):
        token = token.split("=", 1)[1].strip().strip("'\"")
    if not re.fullmatch(r"[A-Za-z0-9._~-]{1,256}", token):
        raise ValueError("invalid gotify token file")
    return token


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def post_gotify(url, token_file, message, timeout=3):
    request = urllib.request.Request(
        url.rstrip("/") + "/message",
        data=json.dumps(message).encode(),
        headers={
            "Content-Type": "application/json",
            "X-Gotify-Key": gotify_token(token_file),
        },
        method="POST",
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)
    with opener.open(request, timeout=timeout) as response:
        return response.status
