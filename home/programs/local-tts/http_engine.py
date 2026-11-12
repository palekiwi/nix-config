import http.client
import json
import os
import sys
import urllib.parse
import wave


def generate(text, output=None, voice="af_bella", speed=1, on_connect=None):
    """Stream Kokoro PCM for text to stdout or output.writeframesraw.

    on_connect, when given, receives the connected socket before the request
    is sent, so a caller can shut it down to cancel a blocked read.
    """
    url = urllib.parse.urlsplit(
        os.environ.get("SPEAK_URL", "http://127.0.0.1:8880/v1/audio/speech")
    )
    if url.scheme != "http" or not url.hostname or url.username or url.password:
        raise ValueError("SPEAK_URL must be an HTTP URL without credentials")
    connection = http.client.HTTPConnection(url.hostname, url.port, timeout=5)
    try:
        connection.connect()
        connection.sock.settimeout(120)
        if on_connect is not None:
            on_connect(connection.sock)
        body = json.dumps(
            {
                "model": "kokoro",
                "voice": voice,
                "input": text,
                "response_format": "pcm",
                "stream": True,
                "speed": speed,
            }
        ).encode("utf-8")
        path = urllib.parse.urlunsplit(("", "", url.path or "/", url.query, ""))
        connection.request("POST", path, body, {"Content-Type": "application/json"})
        with connection.getresponse() as response:
            if response.status != 200:
                raise ValueError(f"speech server returned HTTP {response.status}")
            content_type = response.getheader("Content-Type", "").split(";", 1)[0]
            if content_type not in (
                "audio/pcm",
                "audio/raw",
                "application/octet-stream",
            ):
                raise ValueError("speech server returned an unexpected content type")
            size = 0
            while chunk := response.read1(16384):
                if output is None:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                else:
                    output.writeframesraw(chunk)
                size += len(chunk)
            if not size or size % 2 or response.length not in (None, 0):
                raise ValueError("speech server returned empty or incomplete PCM")
    finally:
        connection.close()


def main():
    try:
        text = sys.stdin.read()
        if sys.argv[1] == "-":
            generate(text)
        else:
            with wave.open(sys.argv[1], "wb") as output:
                output.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
                generate(text, output)
        return 0
    except ValueError as error:
        print(f"speak: {error}", file=sys.stderr)
        return 1
    except (OSError, http.client.HTTPException) as error:
        print(
            f"speak: HTTP speech request failed ({type(error).__name__}); "
            "check server health and logs",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
