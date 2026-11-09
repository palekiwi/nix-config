# Manual packaged GPU acceptance on pale

Host-only preparation, not an accepted GPU backend. `speak` stays incremental
CPU Kokoro; this document does not install a TTS service or change its callers.
Do not run the image pull, GPU tests or system activation in the agent VM.
Use Bash for the commands below. No custom CUDA runtime or source build.

## Pin and runtime boundary

- Image: `ghcr.io/remsky/kokoro-fastapi-gpu:v0.10.0`, Linux amd64 / cu126.
- Immutable amd64 manifest:
  `sha256:797cb80c83b3c17bd03845a09cf131430a3fb95ca06cb55c2fbd12b54abce065`.
- Registry config identifies source revision
  `f2a5270d2ccd9590bc87e2393c774814f23fe7a1`, CUDA base 12.6.3.
  These commands were checked against that revision, not newer upstream master.
- Compressed layers total about 4.31 GiB. Allow substantial additional space
  for unpacking and Docker storage; the download does not include that space.
  Pull only on the host when ready for that cost. Do not build the image.
- Expected host: RTX 4060 Laptop GPU, 8188 MiB, driver 595.71.05. Confirm
  running hardware, driver and free VRAM before use. Driver compatibility
  and successful CUDA work still require the host test below.
- This image uses PyTorch Kokoro V1, not the CPU sherpa v0.19 int8 model.
  `af_bella` is a named voice, not sherpa speaker index 1. Same voice name
  does not make quality, precision or timing comparisons model-equivalent.

Pinned nixpkgs enables native Docker CDI via
`hardware.nvidia-container-toolkit.enable`. Its oneshot
`nvidia-container-toolkit-cdi-generator` produces
`/run/cdi/nvidia-container-toolkit.json`, is required by Docker and reruns
on NVIDIA udev events. It sets Docker `features.cdi = true` automatically.
Docker 29 consumes this via `--device nvidia.com/gpu=all`. Do not use
`--gpus all`, `--runtime=nvidia`, `nvidia-ctk runtime configure`, or the
deprecated `virtualisation.docker.enableNvidia` for this configuration.
There is no NVIDIA default-runtime change and no TTS autostart; the only
new system unit is the NixOS-provided CDI generator.

## 1. Fetch and activate on the host

From the host, not the VM:

```sh
cd /home/pl/nix-config
git fetch vm
cd worktrees/feat/local-tts
git status --short
git log --left-right --oneline HEAD...vm/feat/local-tts
git merge-base --is-ancestor HEAD vm/feat/local-tts
```

Proceed only if the working tree is clean and the ancestry command succeeds.
Stop on divergence or host-only work; never reset it away. If the feature
worktree is absent, stop and arrange it rather than changing another branch.

```sh
git merge --ff-only vm/feat/local-tts
nix eval --raw .#nixosConfigurations.pale.config.system.build.toplevel.drvPath
sudo nixos-rebuild switch --flake .#pale
```

Run the rebuild from this **root feature checkout**, not `home/`. It applies
this branch's full pale system configuration, including existing branch
changes; review those before activation. It may restart Docker and affect
existing containers. It does not activate standalone Home Manager or change
`speak`. If the rebuild changes the NVIDIA kernel driver, reboot before GPU
QA so loaded driver and userspace libraries match. Do not continue after
failed activation.

Read-only checks after activation (do not hand-edit daemon.json or CDI):

```sh
nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version --format=csv
docker version
systemctl status nvidia-container-toolkit-cdi-generator.service --no-pager
journalctl -b -u nvidia-container-toolkit-cdi-generator.service --no-pager
cat /run/cdi/nvidia-container-toolkit.json
cat /etc/docker/daemon.json
docker info
```

Require a successful CDI generator, an `nvidia.com/gpu` spec with an `all`
device, Docker server 29 with CDI enabled, and the expected driver/device.
`docker info` should expose CDI devices; do not treat version alone as proof.
Stop and retain diagnostics if a check fails. Do not bypass CDI with privileged
mode, driver mounts or an ad-hoc runtime wrapper. If Docker permissions fail,
use the existing host Docker access workflow; do not chmod its socket.

## 2. Pull once and verify GPU access

In the host terminal:

```sh
IMAGE=ghcr.io/remsky/kokoro-fastapi-gpu@sha256:797cb80c83b3c17bd03845a09cf131430a3fb95ca06cb55c2fbd12b54abce065
df -h /var/lib/docker
docker system df
docker pull --platform linux/amd64 "$IMAGE"
docker image inspect "$IMAGE" --format '{{.Os}}/{{.Architecture}} {{index .Config.Labels "org.opencontainers.image.revision"}}'
docker run --rm --platform linux/amd64 --device nvidia.com/gpu=all \
  -e NVIDIA_VISIBLE_DEVICES=void --entrypoint nvidia-smi "$IMAGE"
docker run --rm --platform linux/amd64 --device nvidia.com/gpu=all \
  -e NVIDIA_VISIBLE_DEVICES=void --entrypoint python "$IMAGE" -c \
  'import torch; assert torch.cuda.is_available(), "CUDA unavailable"; print(torch.__version__, torch.version.cuda, torch.cuda.get_device_name(0)); x = torch.ones((256, 256), device="cuda"); y = x @ x; torch.cuda.synchronize(); assert y[0, 0].item() == 256; print("CUDA kernel test passed")'
```

Require revision `f2a5270d2ccd9590bc87e2393c774814f23fe7a1`, linux/amd64,
CUDA availability and a successful synchronized CUDA operation. The `void`
environment override avoids legacy NVIDIA_VISIBLE_DEVICES injection; native
CDI explicitly supplies devices and driver libraries. No host CUDA toolkit
is needed. Stop on missing devices, libraries, incompatible driver or OOM.
This verifies Torch in the image, not yet the running TTS process.

## 3. Run manually in the foreground

Keep this terminal attached. No `-d`, restart policy, host network, volume,
PipeWire socket or privileged access. Port 8880 must be unused. Docker
publishes **only 127.0.0.1**, not all LAN interfaces; the app listens on
0.0.0.0 only inside its container. Local processes can still access the API.

```sh
docker run --rm --name kokoro-gpu-qa --platform linux/amd64 \
  --device nvidia.com/gpu=all -e NVIDIA_VISIBLE_DEVICES=void \
  -p 127.0.0.1:8880:8880 \
  -e USE_GPU=true -e DEVICE_TYPE=cuda -e DEFAULT_VOICE=af_bella \
  -e DOWNLOAD_MODEL=false -e ENABLE_WEB_PLAYER=false -e CORS_ENABLED=false \
  "$IMAGE"
```

The release image bakes the model and voices; `DOWNLOAD_MODEL=false` skips
the entrypoint model downloader. No model cache volume hides image content.
If baked assets are missing, stop rather than downloading around the pin.
`DEVICE=gpu` from the image is **not** the backend selector; Settings reads
`DEVICE_TYPE`. Forcing `cuda` makes model `.cuda()` fail on unavailable CUDA
rather than accepting the default CPU autodetection fallback.

## 4. Readiness, backend evidence and streaming

In a second host terminal:

```sh
curl --fail --silent --show-error --retry 60 --retry-delay 2 \
  --retry-connrefused --retry-max-time 180 --max-time 5 \
  http://127.0.0.1:8880/health
docker port kokoro-gpu-qa
docker inspect kokoro-gpu-qa --format '{{json .HostConfig.RestartPolicy}} {{json .HostConfig.PortBindings}}'
docker logs --tail 200 kokoro-gpu-qa
curl --fail --silent --show-error http://127.0.0.1:8880/v1/audio/voices
```

Require `/health` returning `{"status":"healthy"}`, Bella in the voice list,
localhost-only publication and restart policy `no`. Startup lifespan warms
the model before HTTP readiness. Require the **backend** log
`Loading Kokoro model on cuda`, successful warmup and no initialization,
CUDA or CPU-fallback errors. Do not accept only `Initializing Kokoro V1 on
cuda`, `Model warmed up on cuda`, `/health` or `/dev/model`: at this revision
the manager labels CUDA from USE_GPU while the backend independently uses
Settings.get_device(). `/dev/model` is disabled by default and is not needed.
Forcing DEVICE_TYPE plus actual backend load/warmup and generation are the
acceptance evidence; GPU memory allocation alone is not kernel proof.

Streaming playback, raw **signed 16-bit little-endian**, mono 24 kHz (not
the CPU adapter's float32). No WAV header and no complete-file staging:

```sh
set -o pipefail
curl --fail --silent --show-error --no-buffer --max-time 180 \
  http://127.0.0.1:8880/v1/audio/speech \
  -H 'Content-Type: application/json' \
  --data-binary '{"model":"kokoro","voice":"af_bella","input":"Hello. Bella is speaking locally. This final sentence checks streaming playback before the whole request is finished.","response_format":"pcm","stream":true,"speed":1}' \
  | pw-play --raw --format=s16 --rate=24000 --channels=1 -
```

Run `nvidia-smi -l 1` in another terminal during a longer request and inspect
server logs afterward. Record CUDA errors, GPU utilization/VRAM, audible
startup, inter-sentence gaps and quality, first-after-idle versus repeat
requests and competing GPU load. Text processing remains CPU work. This is
chunk streaming, not token streaming or an all-GPU claim. `curl --fail`
rejects HTTP errors before piping error bodies to the player; errors after
stream headers can still leave partial audio, so require successful pipeline
exit **and** clean server logs. Ctrl+C cancels this client/player pipeline;
verify server observes the disconnect and a subsequent request works. It
intentionally does not terminate the separately running container.

Host sound, gaps, cancellation, VRAM and real TTS GPU success remain pending
until the operator reports them. Do not infer speedup from VM checks or
compare this model as identical to CPU v0.19. Do not change `speak` or create
an automatic service until host acceptance and a separate integration decision.

## 5. Stop and recover

Ctrl+C in the foreground container terminal, or from the second terminal:

```sh
docker stop --time 10 kokoro-gpu-qa
docker ps -a --filter name=kokoro-gpu-qa
```

`--rm` removes the container after it stops. If a failed run leaves a stopped
container, inspect its logs first, then remove only that named container:

```sh
docker rm kokoro-gpu-qa
```

No broad Docker prune, image deletion, Nix-store removal or host cache cleanup.
The pinned image remains cached for another manual run. Existing `speak`
(or `nix run .#local-tts -- 'CPU recovery works independently.'` from this
checkout) remains the explicit CPU fallback. Stopping the test does not undo
CDI host support; it leaves no TTS autostart or backend switch to reverse.
