import argparse
import collections
import hashlib
import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
import zipfile
from pathlib import Path

import speak

HERE = Path(__file__).resolve().parent
RUNTIME = "sherpa-onnx-v1.12.38-cuda-12.x-cudnn-9.x-linux-x64-gpu"


def host_only():
    role = Path("/etc/palekiwi/machine-role")
    if (role.exists() and role.read_text().strip() == "vm") or not Path(
        "/dev/nvidiactl"
    ).exists():
        raise ValueError(
            "host-only pilot requires /dev/nvidiactl; no VM downloads/builds"
        )
    if platform.machine() != "x86_64":
        raise ValueError("pilot requires x86_64 Linux")


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def fetch(root, nvidia):
    assets = json.loads((HERE / "pilot-assets.json").read_text())
    chosen = [a for a in assets if a["group"] == "base" or nvidia]
    print(f"Selected archive bytes: {sum(a['size'] for a in chosen)}", flush=True)
    downloads = root / "downloads"
    downloads.mkdir(parents=True, exist_ok=True)
    for asset in chosen:
        archive = downloads / asset["name"]
        if not archive.exists():
            partial = archive.with_suffix(archive.suffix + ".partial")
            with urllib.request.urlopen(asset["url"], timeout=60) as response:
                with partial.open("wb") as target:
                    shutil.copyfileobj(response, target)
            if (
                partial.stat().st_size != asset["size"]
                or digest(partial) != asset["sha256"]
            ):
                partial.unlink()
                raise ValueError(f"download hash/size mismatch: {archive.name}")
            partial.rename(archive)
        if (
            archive.stat().st_size != asset["size"]
            or digest(archive) != asset["sha256"]
        ):
            raise ValueError(f"cached hash/size mismatch: {archive}")
        if asset["group"] == "base":
            with tarfile.open(archive) as bundle:
                bundle.extractall(root, filter="data")
        else:
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(root / "cuda")
        print(f"Verified/extracted {archive.name}", flush=True)


def verify_voice(model, cpu_model):
    for name in ("voices.bin", "tokens.txt"):
        if digest(model / name) != digest(cpu_model / name):
            raise ValueError(
                f"{name} differs from selected CPU model; verify Bella mapping"
            )


def profile_counts(paths):
    counts = collections.Counter()
    for path in paths:
        for event in json.loads(path.read_text()):
            provider = event.get("args", {}).get("provider")
            if event.get("cat") == "Node" and provider:
                counts[provider] += 1
    return dict(counts)


def check_profiles(paths, provider):
    counts = profile_counts(paths)
    if not counts:
        raise ValueError("no node profile evidence; backend is unverified")
    if provider == "cuda" and not counts.get("CUDAExecutionProvider"):
        raise ValueError(f"CUDA fallback/no CUDA node execution: {counts}")
    return counts


def prepare(root):
    runtime = root / RUNTIME
    if not (runtime / "include/sherpa-onnx/c-api/cxx-api.h").is_file():
        raise ValueError("release headers missing; inspect archive before proceeding")
    target = root / "pilot-engine"
    subprocess.run(
        [
            "c++",
            "-std=c++17",
            "-Wall",
            "-Wextra",
            "-Werror",
            str(HERE / "pilot-engine.cc"),
            "-I" + str(runtime / "include"),
            "-L" + str(runtime / "lib"),
            "-lsherpa-onnx-cxx-api",
            "-lsherpa-onnx-c-api",
            "-Wl,--allow-shlib-undefined",
            "-o",
            str(target),
        ],
        check=True,
    )
    subprocess.run(
        [
            "patchelf",
            "--set-interpreter",
            os.environ["LOCAL_TTS_PILOT_LOADER"],
            str(target),
        ],
        check=True,
    )


def run(args, root):
    model = root / "kokoro-en-v0_19"
    verify_voice(model, args.cpu_model.resolve())
    libraries = [root / RUNTIME / "lib", Path("/run/opengl-driver/lib")]
    libraries.extend(sorted((root / "cuda/nvidia").glob("*/lib")))
    libraries.extend(p.resolve() for p in args.cuda_lib_dir)
    libpath = (
        ":".join(map(str, libraries)) + ":" + os.environ["LOCAL_TTS_PILOT_SYSTEM_LIBS"]
    )
    os.environ["LD_LIBRARY_PATH"] = libpath
    if args.provider == "cuda":
        subprocess.run(
            [
                sys.executable,
                "-c",
                "import ctypes; "
                "ctypes.CDLL('libcuda.so.1'); "
                "ctypes.CDLL('libonnxruntime_providers_cuda.so')",
            ],
            check=True,
        )
    report = args.report.resolve()
    report.mkdir(parents=True, exist_ok=False)
    subprocess.run(
        ["nvidia-smi"], stdout=(report / "nvidia-smi.txt").open("w"), check=True
    )
    config = report / "provider.config"
    config.write_text(f"LogSeverityLevel=0\nProfilingFilePrefix={report / 'ort'}\n")
    os.environ["LOCAL_TTS_PILOT_PROVIDER"] = f"{args.provider}:{config}"
    wrapper = report / "engine"
    wrapper.write_text(
        "#!/bin/sh\nexec "
        + shlex.quote(os.environ["LOCAL_TTS_PILOT_LOADER"])
        + " --library-path "
        + shlex.quote(libpath)
        + " "
        + shlex.quote(str(root / "pilot-engine"))
        + ' "$@"\n'
    )
    wrapper.chmod(0o700)
    os.environ["SPEAK_ENGINE"] = str(wrapper)
    os.environ["SPEAK_MODEL"] = str(model)
    text = args.file.read_text(encoding="utf-8")
    started = time.monotonic()
    candidate = report / "candidate.wav" if args.output else None
    speak.synthesize(text, candidate, verbose=True)
    elapsed = time.monotonic() - started
    counts = check_profiles(sorted(report.glob("ort*.json")), args.provider)
    if args.output:
        shutil.copyfile(candidate, args.output.resolve())
    result = {
        "provider_requested": args.provider,
        "node_events_by_provider": counts,
        "request_seconds": elapsed,
        "playback": args.output is None,
        "text_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "runtime": RUNTIME,
        "model": "kokoro-en-v0_19/model.onnx",
        "voice": "af_bella",
        "sid": 1,
        "threads": 4,
    }
    (report / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser(
        description="Host-only experimental CUDA/FP32 Kokoro"
    )
    parser.add_argument("--root", type=Path, required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    download = sub.add_parser("fetch")
    download.add_argument("--include-nvidia-1_59GB", action="store_true")
    sub.add_parser("prepare")
    execute = sub.add_parser("run")
    execute.add_argument("--cpu-model", type=Path, required=True)
    execute.add_argument("--cuda-lib-dir", type=Path, action="append", default=[])
    execute.add_argument("--provider", choices=("cpu", "cuda"), default="cuda")
    execute.add_argument("--file", type=Path, required=True)
    execute.add_argument("--output", type=Path)
    execute.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    try:
        host_only()
        root = args.root.expanduser().resolve()
        if args.command == "fetch":
            fetch(root, args.include_nvidia_1_59GB)
        elif args.command == "prepare":
            prepare(root)
        else:
            run(args, root)
        return 0
    except (KeyboardInterrupt, speak.Cancelled):
        return 130
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"pilot: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
