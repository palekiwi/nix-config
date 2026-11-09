# Resident GPU speech on pale

Pale runs pinned Kokoro-FastAPI through the standard NixOS OCI module:
`docker-kokoro.service`, container name `kokoro`, automatic start on boot,
restart on failure. Normal `systemctl stop/start/restart docker-kokoro`
controls its lifecycle. Stopping a client does not stop the server.

## Deploy on the host

From the host feature worktree, after fetching and fast-forwarding the VM
branch with a clean tree (stop on divergence or host-only changes):

```sh
cd /home/pl/nix-config/worktrees/feat/local-tts
docker ps -a --filter name=kokoro
ss -ltnp 'sport = :8880'
docker image inspect ghcr.io/remsky/kokoro-fastapi-gpu@sha256:797cb80c83b3c17bd03845a09cf131430a3fb95ca06cb55c2fbd12b54abce065 --format '{{.Id}}'
```

The previously tested image should already be cached. The service uses
`--pull never`: a missing image fails visibly, without downloading or building
anything. Do not prune the image/cache. If absent, arrange a host-only pull
of this exact digest; never download the GPU image in the agent VM.

Inspect any manual `kokoro-gpu-qa` container before proceeding. If still
running, stop it explicitly with `docker stop kokoro-gpu-qa`; if a stopped
container remains, remove only it with `docker rm kokoro-gpu-qa`. No automatic
cleanup kills the manual trial. Port 8880 must be free. The name `kokoro`
belongs to NixOS: its normal OCI pre-start removes a prior container with
that name. Inspect/resolve an unrelated namesake before activation.

```sh
sudo nixos-rebuild switch --flake .#pale
home-manager switch --flake './home#pl@pale'
systemctl status docker-kokoro --no-pager
journalctl -b -u docker-kokoro --no-pager -n 60
curl --fail --silent --show-error http://127.0.0.1:8880/health
docker port kokoro
speak 'Hello. Bella is speaking through the resident GPU server.'
```

System and standalone Home Manager activation are separate. Rebuild from the
root checkout, not `home/`; this applies all branch changes and may restart
Docker. Reboot first if the NVIDIA driver changed. HTTP readiness follows
model warmup; an active unit alone is not readiness. Wait for healthy HTTP
and backend `Loading Kokoro model on cuda` plus successful warmup, not merely
manager-reported CUDA. After a failed activation, stop and inspect diagnostics.

## Runtime boundary

- Image digest above is the v0.10.0 Linux amd64 / cu126 manifest, source
  `f2a5270d2ccd9590bc87e2393c774814f23fe7a1`. No latest-tag drift or custom
  CUDA build. Compressed image layers total about 4.31 GiB.
- Native Docker 29 CDI uses `--device=nvidia.com/gpu=all`. The service waits
  for the NixOS NVIDIA CDI generator. No `--gpus all`, privileged mode,
  host driver mounts, legacy runtime or default-runtime override.
- Only `127.0.0.1:8880:8880` is published. No firewall opening, host network,
  PipeWire mount, model volume, VM bridge or authentication. Other local
  processes can use the API. Do not expose it to the LAN.
- `USE_GPU=true`, `DEVICE_TYPE=cuda`, `DEFAULT_VOICE=af_bella`,
  `DOWNLOAD_MODEL=false`, `NVIDIA_VISIBLE_DEVICES=void`,
  `ENABLE_WEB_PLAYER=false`, `CORS_ENABLED=false`. Missing CUDA/assets fail
  rather than silently switching to CPU or downloading models.
- `API_LOG_LEVEL=INFO` suppresses upstream text-bearing debug diagnostics.
  Errors may still contain content; this is not a secret-input facility.
- The server runs PyTorch Kokoro V1; explicit CPU recovery uses sherpa's
  v0.19 int8 model. The Bella name does not make them identical models.

The operator accepted the manual pinned GPU stream as perceptually instant
and gap-free. Declarative boot/restart, the integrated CLI, host cancellation,
output, repeated requests and competing GPU/VRAM load still need host QA.
The client disconnects on Ctrl+C; the upstream server checks disconnects at
chunk boundaries and may finish in-flight inference. It does not summarize;
callers choose and prepare the content.

## Stop or recover

```sh
sudo systemctl stop docker-kokoro
speak --backend cpu 'CPU recovery does not need the HTTP service.'
sudo systemctl start docker-kokoro
```

A stop lasts until explicit start or the next boot. For persistent disable,
set the container's `autoStart = false` and rebuild (it can still be started
manually). Containers are disposable; the pinned Docker image stays cached.
Normal CLI usage and development validation: [README.md](README.md).
