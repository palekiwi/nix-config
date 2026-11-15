import html
import re
import unicodedata


def label(value, limit=80):
    if not isinstance(value, str):
        return ""
    text = " ".join(
        "".join(
            c if not unicodedata.category(c).startswith("C") else " " for c in value
        ).split()
    )
    return text[:limit]


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
        body.get("error")
        or body.get("state") == "error"
        or body.get("stopReason") == "error"
    ):
        status.append("error reported")
    summary = "Agent became idle"
    if status:
        summary += f" ({', '.join(status)})"
    parts = [label(body.get("session_name")) or label(sid), label(body["host"])]
    project = label(body.get("context")) or label(body.get("cwd"))
    if project:
        parts.append(project)
    return {"summary": summary, "body": " · ".join(p for p in parts if p)}


def notify_argv(executable, body):
    summary = body.get("summary")
    text = body.get("body")
    if (
        not isinstance(summary, str)
        or not summary.startswith("Agent became idle")
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
        html.escape(label(text, 256)),
    ]
