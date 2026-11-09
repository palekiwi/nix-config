# Foreground local speech

`speak` uses CPU Kokoro Bella (`af_bella`, speaker ID 1) and starts `pw-play`
with incremental audio from sherpa-onnx callbacks. It loads the model once
per invocation. Playback can begin after the first sentence batch, while
later batches are still being generated; it no longer waits for the whole
paragraph. This is sentence-batch delivery, not token-level streaming.

No services, GUI, keybindings, clipboard watcher, replacement behavior, or
stop command. Concurrent invocations are independent and can overlap;
Ctrl+C stops only the invocation in that terminal. CPU remains the default;
no GPU deployment or speedup claim is made. The abandoned custom CUDA pilot
has been removed; GPU investigation evidence is retained in coordination
memory, not shipped as runtime tooling. A provider flag alone is not a
supported GPU path. The separate [manual packaged GPU test](CONTAINER.md)
starts with pale host activation, then a pinned localhost-only container;
it does not change `speak` or install a TTS service.

## Run without rebuilding or installing

From the root of this feature checkout on the desktop:

```sh
nix run .#local-tts -- 'Hello from Bella. This is incremental playback.'
printf '%s\n' '# A heading' 'Read this response.' | nix run .#local-tts
nix run .#local-tts -- --file response.md
nix run .#local-tts -- --clipboard
nix run .#local-tts -- --output narration.wav --file response.md
nix run .#local-tts -- --verbose 'Show engine diagnostics.'
```

These commands build/download the package on demand but do not activate a
Home Manager generation or alter the running system. For repeated use
without `nix run` startup overhead:

```sh
nix build .#local-tts
./result/bin/speak 'Hello from Bella.'
printf 'Read this. Then read this.\n' | ./result/bin/speak
./result/bin/speak --file response.md
./result/bin/speak --clipboard
```

Use `--` before positional text starting with a dash. Choose one explicit
source: positional words (joined with spaces), `--file PATH` (UTF-8), or
`--clipboard`. With no explicit source, read stdin to EOF. Explicit sources
take precedence over piped stdin; conflicting explicit sources are errors.
Empty input is an error. No input is truncated or summarized by this tool.

`--clipboard` reads once, using `wl-paste` when `WAYLAND_DISPLAY` is set,
otherwise `xclip -selection clipboard -out` when `DISPLAY` is set. Clipboard
errors are reported, not silently replaced with another source. The desktop
session must provide access to its clipboard and PipeWire. VM verification
cannot establish host listening acceptance.

## Incremental playback and limits

A compiled `speak-engine` adapter uses the existing packaged sherpa-onnx
C++ API, one model creation and one `Generate` call. Kokoro's frontend splits
text into sentence batches; the engine calls back with each batch before
synthesizing the next. The callback writes mono 24 kHz float32 PCM to a
blocking OS pipe consumed by `pw-play --raw`. No extra Python audio queue,
per-sentence process, runtime download, or resident inference is involved.

The pipe has bounded capacity and applies backpressure: if playback stops
draining, the callback blocks before more synthesis can proceed. The
current generated batch and PipeWire's own buffers also occupy memory.
Importantly, sherpa's API **still accumulates the full result internally**;
this is bounded playback transport, not constant-memory generation for
arbitrarily long requests. Input and phonemization also remain whole-request.

First audio still requires model initialization, frontend processing and
one batch of CPU synthesis. A long unpunctuated sentence can delay it.
If CPU synthesis cannot keep up with playback, there may be gaps between
batches. Short requests may finish synthesis before the player emits sound.
No controlled host latency or seamless-playback claim is made.

`--output PATH` generates a complete mono 16-bit PCM WAV instead of starting
playback. It overwrites PATH only after successful generation and does not
create parent directories. Temporary input/output and diagnostics use the
system temporary directory. Text goes to the adapter through an anonymous
temporary file on stdin, not command arguments; `--file`/stdin/clipboard
avoid exposing content in the CLI's own argument list too. Positional text
is necessarily visible in `speak`'s arguments.

Successful requests are quiet by default. On child failure, the last 8 KiB
of captured diagnostics are shown along with the failed command/status.
`--verbose` forwards live engine diagnostics and reports total request time
(including playback when enabled). Engine errors or verbose logs may contain
input text; this is not a secret-input facility.

## Cancellation

Press Ctrl+C during generation or playback to cancel both children and their
process-group descendants. SIGTERM during child execution has the same
behavior. Termination escalates to SIGKILL after a shared 0.5-second grace
period; direct children are reaped and temporary files removed. This also
handles a callback blocked on the playback pipe and an engine that has
finished while playback is still draining. A child failure stops its peer.
Exit status is 130 for cancellation, 1 for operational failure, 2 for usage
errors. A failed/cancelled generation does not copy an output WAV.

Processes deliberately detaching from their process groups are unsupported;
the packaged engine and player do not do that. SIGKILL of `speak` itself
cannot run cleanup.

## Conservative cleanup

Default cleanup removes heading, unordered-list, blockquote and inline-code
markers, and simple code-fence delimiter/language lines. Code body text is
retained unchanged. Markdown links/images retain both label/alt text and
destination. Unknown syntax (including emphasis, tables, HTML and numbered
lists) is retained rather than risking content omission. There is no LLM,
rewriting or semantic filtering. Use `--raw` to bypass all cleanup. English
model pronunciation of code, paths and other languages is not guaranteed;
content retention does not prove intelligibility.

## Home Manager

Import `home/programs/local-tts` and set:

```nix
programs.local-tts.enable = true;
```

The module defaults to disabled and only adds a package. The desktop
`home/users/pl/pale.nix` explicitly imports and enables it. Other profiles
are unchanged. Apply only through the operator's normal Home Manager
workflow after reviewing/integrating this branch; no activation is needed
for the commands above.

## Reproducibility and engine boundary

`package.nix` fetches the upstream `k2-fsa/sherpa-onnx` `tts-models` release
asset `kokoro-int8-en-v0_19.tar.bz2` with fixed SHA-256:

```text
sha256-yfDdOTYVgFsLqwUMNAg01eaE5zKuyRwOhgzTDpgsCL0=
```

The bundle includes its Apache-2.0 license and espeak data. A changed release
asset fails hash verification. There is no audition-directory dependency.
The flake's nixpkgs lock pins the runtime/player; it currently supplies
sherpa-onnx 1.12.38 and ONNX Runtime 1.24.4. The adapter links its existing
shared C/C++ libraries; no sherpa rebuild or Python binding is needed. A
separately pinned Home Manager flake may resolve a different runtime;
validate it when updating that lock.

Wrapper defaults use absolute store paths. For development/tests,
`SPEAK_MODEL`, `SPEAK_ENGINE`, `SPEAK_PLAYER`, `SPEAK_WL_PASTE`, and
`SPEAK_XCLIP` can override them. Values are single paths, not shell commands.
`SPEAK_ENGINE` now follows the adapter protocol, **not** the former sherpa
CLI flags: arguments are `MODEL OUTPUT-OR-DASH VERBOSE-0-OR-1`, UTF-8 text is
read from stdin, `-` outputs raw float32 PCM, otherwise it writes a WAV.
`SPEAK_PLAYER` must accept `pw-play`'s raw PCM arguments. The adapter checks
the model is 24 kHz before streaming. Defaults remain CPU, four threads,
speaker 1, length/speed 1, one sentence batch, silence scale 0.2.

## Validation

From the repository root, using the project devshell:

```sh
nix develop --command nix build .#local-tts --no-link
nix develop --command nix shell --inputs-from . nixpkgs#python3 nixpkgs#ruff \
  nixpkgs#clang-tools --command bash -c '
    ruff format --check home/programs/local-tts/*.py &&
    ruff check --select E4,E7,E9,F,I home/programs/local-tts/*.py &&
    clang-format --dry-run --Werror home/programs/local-tts/engine.cc &&
    cd home/programs/local-tts && python3 -m unittest -v'
nix develop --command nixfmt --check home/programs/local-tts/*.nix
nix develop --command nix eval --json --impure --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./home/programs/local-tts/test-config.nix {
    pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
    home-manager = f.inputs.home-manager;
  }'
nix develop --command nix eval --raw \
  './home#homeConfigurations."pl@pale".activationPackage.drvPath' \
  --no-write-lock-file
nix develop --command nix run .#local-tts -- \
  --output /tmp/bella-smoke.wav 'Hello. Bella is speaking locally.'
```

The package runs Python tests in its sandboxed build and compiles the
adapter with warnings as errors. Deterministic fake processes verify audio
receipt before synthesis completion, bounded-pipe backpressure, quiet
success/useful failure, complete output mode, and SIGINT/SIGTERM cleanup of
both pipeline process groups and descendants during generation/playback.

VM callback smoke with an 18-word, three-sentence request: first PCM arrived
in 1.49 s while the engine was still running; completion took 6.34 s for
7.76 s of audio. Complete WAV mode took 6.26 s and produced nonzero mono
24 kHz, 16-bit PCM. These are uncontrolled VM observations, **not audible
first-sound measurements**, cold/warm benchmarks, or comparisons against
the earlier 84-word whole-file sample. Host playback/clipboard/Ctrl+C were
confirmed for the original whole-file CLI; incremental sound, routing,
startup latency, gaps and interruption require fresh operator verification.
GUI, keybindings, daemon/resident engine, automatic clipboard watching,
background replacement and stop command remain deferred. GPU runtime and
host acceptance remain separate from this working CPU implementation.
