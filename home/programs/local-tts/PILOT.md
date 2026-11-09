# Host-only prebuilt CUDA / FP32 Kokoro pilot

Experimental, opt-in, not a GPU deployment or speedup claim. No configuration
activation, flake/lock changes, runtime source build, daemon or CPU default
change. Do not run archive fetches or preparation in the VM; the script
rejects the VM role and requires `/dev/nvidiactl` even for fetch/prepare.
`--help` and unit tests do not require a GPU.

Operator verified RTX 4060 Laptop GPU, 8188 MiB VRAM, 5667 MiB free, driver
595.71.05. That establishes hardware, not runtime compatibility or speed.
All real release linking, dependency loading, GPU generation, profiling,
playback, VRAM and cancellation checks below remain **host QA pending**.
VM validation covers formatting, tests and compilation against the existing
1.12.38 headers/API only, not the downloaded GPU release.

## Evidence and pins

`pilot-assets.json` pins URLs, byte counts and SHA-256 from GitHub/PyPI
metadata. Fetch verifies both size and digest before extraction, including
cached archives. Metadata hashes have not been independently checked by
large downloads in the VM. Changing upstream release assets fails closed.

- sherpa 1.12.38 CUDA 12.x / cuDNN 9.x Linux x64 release: 200913104 bytes.
- Kokoro English v0.19 FP32: 319625534 bytes, `model.onnx`, not the CPU
  `model.int8.onnx`. Total: 520538638 bytes (496.4 MiB).
- No Python inference package is needed; Python is orchestration only.
  The pilot compiles only a tiny adapter, not sherpa/ORT/CUDA.

Version-pinned upstream evidence:

- [Release workflow](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.38/.github/workflows/linux-gpu.yaml)
  builds shared APIs in manylinux_2_28, copies `bin`, `lib`, `include`, uses
  patched prebuilt ORT 1.24.4 for this named CUDA release. It does not copy
  a CUDA toolkit/cuDNN installation into the release.
- [ORT selection](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.38/cmake/onnxruntime-linux-x86_64-gpu.cmake)
  specifies CUDA 12 / cuDNN 9.
- [Session implementation](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.38/sherpa-onnx/csrc/session.cc)
  supports `cuda:CONFIG` / `cpu:CONFIG`, `ProfilingFilePrefix` and verbose
  node placement. Missing CUDA registration can silently fall back to CPU.
- [v0.19 voice generator](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.38/scripts/kokoro/v0.19/generate_voices_bin.py)
  explicitly maps 11 voices, `af_bella` to ID 1. The pilot additionally
  requires exact `voices.bin` and `tokens.txt` hashes matching the selected
  CPU bundle, and checks the runtime reports 11 speakers. If these differ,
  **stop and inspect the archive/mapping**, do not bypass the check or assume
  Bella based on another Kokoro model's numbering.

The adapter reuses the existing callback pipe writer, generation settings
and C++ API. It calls back in WAV mode too, for first-PCM instrumentation.
The existing Python lifecycle manager runs the engine/player in disposable
process groups. CPU `speak`, Home Manager and package defaults are unchanged.

## Dependency/download gate

Nix supplies only Python, compiler, patchelf, binutils, PipeWire, glibc,
libstdc++ and zlib. `pilot-shell.nix` uses the existing root lock and has
**no CUDA derivations**. It does not install or activate anything. The Nix
compiler links the adapter; patchelf sets its Nix loader. A wrapper invokes
that loader with explicit release/driver/CUDA library directories. The
sherpa archive is not patched in place. This avoids `/lib64` interpreter
assumptions and avoids globally exporting a foreign `LD_LIBRARY_PATH`.

Host driver libraries come from `/run/opengl-driver/lib` (not NVIDIA wheel
stub libraries). CUDA provider preflight dlopens `libcuda.so.1` and
`libonnxruntime_providers_cuda.so` in a fresh process with the same search
path. Missing shared objects stop before generation. This discovers actual
ELF dependencies, including transitive ones, after download; archive layout
and complete dependency closure are not claimed verified from metadata.

If already present, supply compatible host library directories with repeated
`--cuda-lib-dir /nix/store/.../lib`. Do not build a CUDA Nix package just to
obtain these. Useful initial search against existing installed closures:

```sh
find /run/current-system/sw /run/opengl-driver/lib -name 'libcuda.so*'
nix-store -qR /run/current-system | grep -E 'cudnn|cublas|cufft|curand|cuda.*runtime|nvjitlink'
```

The optional pinned NVIDIA wheel library set is **1589294900 additional
bytes (1515.7 MiB)**, bringing archives to 2109833538 bytes (2012.1 MiB).
Allow several further GiB for extracted files, particularly cuDNN/cuBLAS,
and retained archives. These are NVIDIA redistributable binary libraries,
not source builds. Review the NVIDIA wheel license files before use.
The pinned candidate ABI set is CUDA runtime 12.8.90, cuBLAS 12.8.4.1,
cuDNN 9.8.0.87, cuFFT 11.3.3.83, cuRAND 10.3.9.90, nvJitLink 12.8.93.
Expected SONAME majors: cudart 12, cublas/cublasLt 12, cudnn 9, cufft 11,
curand 10, nvJitLink 12. Major-version compatibility is supported by the
upstream CUDA/cuDNN requirements; this exact candidate set still needs
host initialization and profiling validation. No TensorRT or nvcc needed.

**The roughly 500 MiB-plus approval is not treated as automatic approval
for another 1.59 GB.** Default fetch downloads only sherpa/model. Reuse
existing libraries first, or separately approve the explicit optional
command below. Failure due to unavailable libraries is a host dependency
gate, not permission for a source build. No large archives were downloaded
while preparing this tooling.

## Host fetch and setup

On the host, first fetch the guest commit without discarding host changes:

```sh
cd /home/pl/nix-config
git fetch vm
cd worktrees/feat/local-tts
git status --short
git log --left-right --oneline HEAD...vm/feat/local-tts
```

Only if clean and HEAD is an ancestor of `vm/feat/local-tts`:

```sh
git merge --ff-only vm/feat/local-tts
```

Stop on divergence; never reset host-only work. From that feature checkout,
enter the isolated shell (may download ordinary cached compiler/tools):

```sh
nix develop --impure --expr 'import ./home/programs/local-tts/pilot-shell.nix {}'
```

All following commands run **inside that host shell**, in the repo root:

```sh
set -o pipefail
P=home/programs/local-tts
ROOT="$HOME/.cache/local-tts-cuda-v1.12.38"
python3 "$P/pilot.py" --root "$ROOT" fetch
python3 "$P/pilot.py" --root "$ROOT" prepare
nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version --format=csv
```

If, and only if, the additional 1.59 GB has been approved:

```sh
python3 "$P/pilot.py" --root "$ROOT" fetch --include-nvidia-1_59GB
```

Fetch is repeatable and re-verifies cached archives (no network for existing
valid archives). Preparation requires the release headers and links against
its actual shared libraries. If layout/API/linking fails, stop and save the
error rather than build sherpa/ORT. Inspect dependencies if needed:

```sh
RUNTIME=sherpa-onnx-v1.12.38-cuda-12.x-cudnn-9.x-linux-x64-gpu
readelf -d "$ROOT/$RUNTIME/lib/libonnxruntime_providers_cuda.so"
```

## Same-text/Bella generation, placement and playback

Resolve the current CPU model without activation (normally already cached):

```sh
CPU_MODEL=$(nix eval --raw .#local-tts.model.outPath)
mkdir -p /tmp/local-tts-pilot
printf '%s %s\n' 'Hello. Bella is speaking locally.' \
  'This final sentence checks incremental CPU generation before the whole request is finished.' \
  > /tmp/local-tts-pilot/text.txt
python3 "$P/pilot.py" --root "$ROOT" run --cpu-model "$CPU_MODEL" \
  --file /tmp/local-tts-pilot/text.txt --report /tmp/local-tts-pilot/cuda-1 \
  --output /tmp/local-tts-pilot/cuda-1.wav 2>&1 | tee /tmp/local-tts-pilot/cuda-1.log
```

Append repeated `--cuda-lib-dir DIR` if reusing host libraries instead of
wheels. Missing CPU model must be realized through the ordinary CPU package,
not a GPU source build. Failure of voice/token identity comparison stops
before inference. Reports must be fresh directories, to avoid stale profile
success. Text is read raw, without Markdown cleanup, for identical inputs.

Successful completion requires nonempty ORT node profile evidence; CUDA
mode additionally requires `CUDAExecutionProvider` **Node** events. A CPU
fallback or absent profile returns failure, not a successful GPU claim.
`result.json` records requested provider and actual per-provider node event
counts (not unique nodes or time percentages). Raw `ort*.json`, config,
wrapper and NVIDIA diagnostic remain in the report. WAV is copied to the
requested output only after backend verification. On failure candidate WAV
may remain in the report; do not call it a validated CUDA result. Verbose
logs may include input text; reports/config/wrapper may include local paths.

For a fairer runtime comparison use the **same FP32 model** with CPU as
well, while separately retaining the existing production int8 baseline:

```sh
python3 "$P/pilot.py" --root "$ROOT" run --provider cpu --cpu-model "$CPU_MODEL" \
  --file /tmp/local-tts-pilot/text.txt --report /tmp/local-tts-pilot/fp32-cpu-1 \
  --output /tmp/local-tts-pilot/fp32-cpu-1.wav 2>&1 | tee /tmp/local-tts-pilot/fp32-cpu-1.log
nix build .#local-tts --out-link result-cpu
./result-cpu/bin/speak --raw --verbose --file /tmp/local-tts-pilot/text.txt \
  --output /tmp/local-tts-pilot/int8-cpu.wav
```

Then test callback playback by omitting `--output`:

```sh
python3 "$P/pilot.py" --root "$ROOT" run --cpu-model "$CPU_MODEL" \
  --file /tmp/local-tts-pilot/text.txt --report /tmp/local-tts-pilot/play-1 \
  2>&1 | tee /tmp/local-tts-pilot/play-1.log
```

Playback is experimental: it may already have emitted audio before post-run
profile verification can reject fallback. Use successful WAV/profile QA
first. No GPU-valid claim is made until the command exits successfully.
Default PipeWire session/routing must be available. Ctrl+C must cancel the
engine/player during initialization, playback and stalled callback writes;
repeat tests on the actual release, including SIGTERM. Reuse of CPU process
management and its tests is not host attestation. Profile-on-cancellation
need not be complete; status 130 does not certify a provider.

`pilot first_pcm_seconds` starts at adapter entry, includes input read,
model load and first batch, but excludes Python/compiler/shell startup.
`generation_seconds` includes model load and full generation; playback mode
also includes pipe backpressure, **not pure inference**. `audio_seconds`
allows RTF = generation/audio seconds in WAV mode. `request_seconds`
includes engine launch, profiler shutdown and playback drain if enabled.
Measure audible first sound separately; first callback is not first sound.
This is sentence-batch streaming, with retained whole-result memory, not
constant-memory or token streaming.

Alternate FP32 CPU/CUDA runs at least three times each with fresh report
names. Record idle-first vs repeated runs, audio duration, first PCM, full
generation, RTF, audible startup, stalls/quality, other GPU load and VRAM.
Profiling/verbose logs add overhead; report that rather than comparing them
as production-equivalent timings. Existing int8 CPU comparison changes
precision as well as provider. No controlled cold-cache claim is implied.
In another terminal sample `nvidia-smi -l 1` during each run. GPU allocation
alone is not evidence of kernel execution. ORT node profiles prove observed
provider execution, not all-GPU execution; CPU shape/control nodes may be
legitimate. Inspect profile durations/placement before attributing speedup;
Nsight Systems/CUPTI tracing is a separate, optional deeper validation if
ORT profiles are absent/ambiguous, not a prerequisite source build here.

## Recovery and removal

Keep `./result-cpu/bin/speak` or the installed `speak` as explicit recovery.
The pilot never changes those wrappers or Home Manager. Exit the isolated
shell to drop its tooling environment. Remove only the chosen cache and QA
report directories when no pilot processes are running. Do not remove Nix
store paths or host driver libraries. Host QA remains open until the
operator supplies evidence; a passed VM syntax/test run is not GPU success.
