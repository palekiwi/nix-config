import base64
import json
import os
import sys
import time

from mitmproxy import http

SECRETS_DIR = os.environ["AGENT_PROXY_SECRETS_DIR"]

with open(os.environ["AGENT_PROXY_RULES"]) as _fh:
    RULES = json.load(_fh)

for _rule in RULES:
    _rule["hosts"] = set(_rule["hosts"])
    try:
        with open(os.path.join(SECRETS_DIR, _rule["name"])) as _fh:
            _rule["secret"] = _fh.read().strip()
    except FileNotFoundError:
        _rule["secret"] = ""


def _log(event: dict) -> None:
    event["ts"] = round(time.time(), 3)
    sys.stdout.write(json.dumps(event) + "\n")
    sys.stdout.flush()


def _swap_authorization(value: str, rule: dict) -> tuple[str, str | None]:
    placeholder, secret = rule["placeholder"], rule["secret"]
    scheme, _, cred = value.partition(" ")
    if scheme.lower() in ("bearer", "token") and cred == placeholder:
        return "ok", f"{scheme} {secret}"
    decoded = ""
    if scheme.lower() == "basic":
        try:
            decoded = base64.b64decode(cred, validate=True).decode()
        except ValueError:
            decoded = ""
        user, sep, password = decoded.partition(":")
        if sep and password == placeholder:
            swapped = f"{user}:{secret}".encode()
            return "ok", f"{scheme} {base64.b64encode(swapped).decode()}"
    if placeholder in value or placeholder in decoded:
        return "malformed", None
    return "none", None


def _target(flow: http.HTTPFlow) -> str:
    return flow.request.host.lower().rstrip(".")


def _authority_consistent(flow: http.HTTPFlow, host: str) -> bool:
    if flow.request.scheme != "https" or flow.request.port != 443:
        return False
    header = (flow.request.host_header or "").lower().rstrip(".")
    if header not in (host, f"{host}:443"):
        return False
    sni = (flow.client_conn.sni or "").lower().rstrip(".")
    return sni == host


def _deny(flow: http.HTTPFlow, rule: str, where: str, reason: str) -> None:
    _log({"event": "placeholder_blocked", "rule": rule,
          "host": _target(flow), "where": where, "reason": reason})
    flow.metadata["agent_proxy_blocked"] = True
    flow.response = http.Response.make(
        403, b"placeholder not allowed\n", {"content-type": "text/plain"})


def _placeholder_outside_authorization(flow: http.HTTPFlow) -> tuple | None:
    for rule in RULES:
        marker = rule["placeholder"]
        for name, value in flow.request.headers.items(multi=True):
            if name.lower() != "authorization" and marker in value:
                return rule["name"], f"header:{name.lower()}"
        if marker in flow.request.url:
            return rule["name"], "url"
    return None


def http_connect(flow: http.HTTPFlow) -> None:
    _log({"event": "connect", "client": flow.client_conn.peername[0],
          "host": flow.request.host, "port": flow.request.port})


def requestheaders(flow: http.HTTPFlow) -> None:
    if flow.response is not None:
        return
    host = _target(flow)
    found = _placeholder_outside_authorization(flow)
    if found:
        _deny(flow, found[0], found[1], "outside_authorization")
        return
    values = flow.request.headers.get_all("authorization")
    if not values:
        return
    if len(values) > 1:
        for rule in RULES:
            if any(rule["placeholder"] in v for v in values):
                _deny(flow, rule["name"], "header:authorization", "multiple")
                return
        return
    value = values[0]
    for rule in RULES:
        status, swapped = _swap_authorization(value, rule)
        if status == "none":
            continue
        if status == "malformed":
            _deny(flow, rule["name"], "header:authorization", "malformed")
            return
        if host not in rule["hosts"]:
            _deny(flow, rule["name"], "header:authorization", "host")
            return
        if not _authority_consistent(flow, host):
            _deny(flow, rule["name"], "header:authorization", "authority")
            return
        if not rule["secret"]:
            _deny(flow, rule["name"], "header:authorization", "no_secret")
            return
        flow.request.headers["authorization"] = swapped
        flow.request.headers.pop("accept-encoding", None)
        flow.metadata["agent_proxy_rule"] = rule["name"]
        flow.metadata["agent_proxy_redact"] = _redactions(rule, swapped)
        return


def _redactions(rule: dict, header: str) -> list[bytes]:
    values = [rule["secret"], header.partition(" ")[2]]
    return [v.encode() for v in values if v]


def _redact(data: bytes, secrets: list[bytes]) -> bytes:
    for secret in secrets:
        data = data.replace(secret, b"[redacted]")
    return data


def _redacting_stream(secrets: list[bytes]):
    keep = max(len(s) for s in secrets) - 1
    tail = b""

    def stream(chunk: bytes) -> bytes:
        nonlocal tail
        if not chunk:
            out, tail = _redact(tail, secrets), b""
            return out
        data = _redact(tail + chunk, secrets)
        tail = data[-keep:] if keep > 0 else b""
        return data[:len(data) - len(tail)]

    return stream


def responseheaders(flow: http.HTTPFlow) -> None:
    secrets = flow.metadata.get("agent_proxy_redact")
    if not secrets:
        return
    flow.response.headers.fields = tuple(
        (name, _redact(value, secrets))
        for name, value in flow.response.headers.fields)
    flow.response.stream = _redacting_stream(secrets)


def response(flow: http.HTTPFlow) -> None:
    _log({"event": "response", "client": flow.client_conn.peername[0],
          "method": flow.request.method, "host": _target(flow),
          "path": flow.request.path.split("?", 1)[0],
          "status": flow.response.status_code,
          "injected": flow.metadata.get("agent_proxy_rule"),
          "origin": "proxy" if flow.metadata.get("agent_proxy_blocked")
          else "upstream"})
