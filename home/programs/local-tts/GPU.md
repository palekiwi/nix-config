# GPU feasibility investigation

Investigated against `fb878f80b136e542ad6a86b2022460d7cdd27bfe` and its
unchanged root flake lock. No GPU backend is implemented. CPU is still the
only supported runtime; no activation or lock update is needed.

## Findings

- Pale imports `hosts/pale/nvidia.nix`: proprietary stable NVIDIA driver,
  PRIME sync, NVIDIA PCI address `1:0:0`. Its evaluated driver version is
  595.71.05. `hosts/pale/ollama.nix` selects `ollama-cuda`, but this does not
  make other packages CUDA-enabled. The RTX 4060 / 8 GB identification is
  operator-provided, not established by the configuration. Confirm the
  actual device, running driver and available VRAM with `nvidia-smi`.
- The guest has neither `/dev/nvidia*` nor `/dev/dri`. GPU inference and
  host audio cannot be validated here.
- Pinned nixpkgs supplies sherpa-onnx 1.12.38 and ONNX Runtime 1.24.4.
  Both have `cudaSupport` arguments, defaulting to false in this package
  set. Setting sherpa's argument alone does **not** change its ONNX Runtime
  dependency. ONNX Runtime also needs an explicit `cudaPackages` argument.
- Sherpa's `sherpa-onnx/csrc/session.cc`, CUDA provider branch, checks
  `Ort::GetAvailableProviders()`. If CUDA is absent it logs a warning and
  falls back to CPU. Our successful requests normally hide diagnostics.
  Merely exposing `provider = "cuda"` would therefore be misleading.
- Available/registered CUDA does not prove that model nodes run on GPU.
  ONNX Runtime can partition a graph between CUDA and CPU. Provider
  initialization must fail loudly when requested CUDA is unavailable;
  a benchmark must also inspect actual node placement/profiling.

## Current int8 model is a poor CUDA comparison

The existing 134,186,977-byte `model.int8.onnx` contains 5,564 top-level
nodes, including 88 `ConvInteger`, 96 `DynamicQuantizeLinear`, six
`com.microsoft::DynamicQuantizeLSTM` and 83 `MatMulInteger` nodes. These
counts come from parsing the packaged ONNX protobuf, not filename inference;
control-flow subgraphs and runtime graph optimizations are not counted.

The version-matched ONNX Runtime kernel matrix has **no CUDA kernel** for
`ConvInteger`, `DynamicQuantizeLinear` or `DynamicQuantizeLSTM`.
CUDA `MatMulInteger` supports int8 inputs only. Consequently this graph
cannot be assumed to execute entirely on CUDA; substantial CPU execution
and transfer overhead are risks. No speedup is established by this static
inspection. Even FP32 may retain CPU-only operations and needs profiling.

Sources:

- <https://github.com/microsoft/onnxruntime/blob/v1.24.4/docs/OperatorKernels.md>
- <https://onnxruntime.ai/docs/execution-providers/CUDA-ExecutionProvider.html>
- Pinned nixpkgs `pkgs/by-name/{sh/sherpa-onnx,on/onnxruntime}/package.nix`.
- Packaged sherpa source `sherpa-onnx/csrc/session.cc`.

## Packaging cost and stopping point

The following **evaluation/dry-run only** command uses the existing lock;
no CUDA build or NVIDIA archive download was started:

```sh
nix develop --command nix build --dry-run --no-link --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    p = import f.inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    ort = p.onnxruntime.override {
      cudaSupport = true;
      cudaPackages = p.cudaPackages;
    };
  in p.sherpa-onnx.override {
    cudaSupport = true;
    onnxruntime = ort;
  }'
```

On the guest with its configured caches, this requires 27 derivations,
including source builds of ONNX Runtime and sherpa, NCCL and CUDA library
repackaging. It lists 89 cached paths: 254.5 MiB download / 3.7 GiB unpacked.
Those totals **exclude uncached fixed-output downloads and build space**.
The uncached cuDNN archive alone is 959,541,460 bytes (915.1 MiB, verified
with an HTTP HEAD request). More disk space is needed for extracted CUDA
libraries and compilation. No reliable build-time or peak-space estimate
was measured. ONNX Runtime requires the `big-parallel` system feature and
its GPU build disables unit tests; a successful build is not GPU QA.

The selected toolkit is CUDA 12.9 (nvcc 12.9.86), cuDNN 9.22.0.52. Default
CUDA targets are `75;80;86;89;90;100;103;120;121`, not just the RTX 4060's
Ada target 89. Restricting targets or disabling unused Python/websocket/NCCL
features could reduce cost but changes derivations and cache availability.
Do not start this build by simply removing `--dry-run` without approval.

## Options and recommendation

1. **Recommended next experiment: isolated prebuilt CUDA sherpa + FP32
   Kokoro**, keeping the same callback interface and a separate CPU package.
   Upstream [runtime release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.38)
   and [model release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models)
   metadata confirm these assets exist:
   - `sherpa-onnx-v1.12.38-cuda-12.x-cudnn-9.x-linux-x64-gpu.tar.bz2`:
     200,913,104 bytes (191.6 MiB).
   - `kokoro-en-v0_19.tar.bz2`: 319,625,534 bytes (304.8 MiB).
   - Together about 496.4 MiB compressed, before any missing CUDA/cuDNN
     libraries. No assets were downloaded. Archive contents, NixOS ELF
     patching, licensing, library ABI, voices and provider execution remain
     unverified. Pin hashes and inspect dependencies before packaging.
   - FP32 inference is a deliberate model change, not an equivalent int8
     benchmark. Verify that voice index 1 is still Bella, compare the same
     voice/text, and label model/precision differences explicitly.
2. **Source-built CUDA runtime:** the expression above is a reproducible
   starting point if the operator accepts its build/download budget. Still
   prefer a separately pinned FP32 model and a separate opt-in package.
3. **Keep the present CPU implementation:** supported now, with no CUDA
   cost. Sentence stalls remain possible when generation cannot keep up.
   Resident inference or another backend is separate work, not an implicit
   part of this investigation.

A future GPU adapter must validate CUDA registration and initialization,
report the requested and actual backend, and provide profiling evidence
that synthesis kernels use CUDA. Reject a missing GPU/runtime rather than
silently substituting CPU; explicit invocation of the CPU package remains
recovery. CPU-only shape/control operations may be legitimate, so report
mixed placement instead of claiming all-GPU inference. Preserve the single
model load, callback pipe, output mode and process-group cancellation tests.

## Host baseline and eventual comparison

Run from this feature checkout. These commands only build the **CPU**
package; there is intentionally no `local-tts-gpu` target yet:

```sh
nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version \
  --format=csv
nix develop --command nix build .#local-tts --out-link result-cpu
printf '%s %s\n' 'Hello. Bella is speaking locally.' \
  'This final sentence checks incremental CPU generation before the whole request is finished.' \
  > /tmp/local-tts-benchmark.txt
./result-cpu/bin/speak --verbose --file /tmp/local-tts-benchmark.txt
./result-cpu/bin/speak --verbose --file /tmp/local-tts-benchmark.txt
TIMEFORMAT='wall seconds: %R'
time ./result-cpu/bin/speak --raw --file /tmp/local-tts-benchmark.txt \
  --output /tmp/local-tts-cpu.wav
```

Use Bash for `TIMEFORMAT`. Listen for first sound and inter-sentence stalls;
`--verbose` total includes playback, whereas output mode measures complete
WAV generation without playback. Neither gives a measured first-PCM time.
The first run after an idle period and repeated runs should be reported
separately; a fresh process still loads the model each time. Do not claim
controlled cold-cache results without controlling cache state.

Once a validated GPU package exists, repeat the identical workload and
selected Bella voice, alternating CPU/GPU for at least three runs each.
Keep model precision, threads, speed, driver/runtime, other GPU load, WAV
audio duration and total generation time with each result. Compute real-time
factor as generation seconds / audio seconds. Instrument callback delivery
to measure first PCM separately from complete generation; measure audible
first sound separately on the host. Capture ONNX Runtime node placement or
profiling and GPU utilization, not just `nvidia-smi` memory allocation.
Test Ctrl+C during initialization, audible playback and stalled generation,
output WAV completeness, clipboard and unchanged explicit CPU operation.
GPU speed, VRAM use, sound quality and absence of sentence gaps remain open.
