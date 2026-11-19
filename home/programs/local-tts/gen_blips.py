import math
import os
import struct
import sys
import wave

RATE = 44100
LEAD_SILENCE = 0.3


def silence(dur):
    return bytearray(int(RATE * dur) * 2)


def tone(freqs, dur, amp):
    frames = bytearray()
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        env = min(1.0, i / (RATE * 0.005), (n - i) / (RATE * 0.02))
        sample = sum(math.sin(2 * math.pi * f * t) for f in freqs)
        frames += struct.pack("<h", int(amp * env * sample / len(freqs) * 32767))
    return frames


def blips():
    return {
        "start": silence(LEAD_SILENCE)
        + tone([660], 0.09, 0.8)
        + tone([880], 0.12, 0.8),
        "cancel": silence(LEAD_SILENCE)
        + tone([520], 0.12, 0.8)
        + tone([392], 0.12, 0.8),
        "error": silence(LEAD_SILENCE) + tone([180, 181], 0.18, 0.9),
    }


def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    for name, frames in blips().items():
        with wave.open(os.path.join(outdir, f"{name}.wav"), "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(bytes(frames))


if __name__ == "__main__":
    main(sys.argv[1])
