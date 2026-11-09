# Foreground local speech

`speak` generates a complete WAV with CPU Kokoro Bella (`af_bella`, speaker
ID 1), then plays it with `pw-play`. It is **not streaming**: the entire
request must finish generation before sound starts. No services, GUI,
keybindings, clipboard watcher, replacement behavior, or stop command.
Concurrent invocations are independent and can overlap; Ctrl+C stops only
the invocation in that terminal.

## Run without rebuilding or installing

From the root of this feature checkout on the desktop:

```sh
nix run .#local-tts -- 'Hello from Bella.'
printf '%s\n' '# A heading' 'Read this response.' | nix run .#local-tts
nix run .#local-tts -- --file response.md
nix run .#local-tts -- --clipboard
nix run .#local-tts -- --output narration.wav --file response.md
```

These commands build/download the package on demand but do not activate a
Home Manager generation or alter the running system. For repeated use
without `nix run` startup overhead:

```sh
nix build .#local-tts
./result/bin/speak 'Hello from Bella.'
printf 'Read this.\n' | ./result/bin/speak
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
session must provide access to its clipboard and PipeWire. The VM alone
cannot establish host playback acceptance.

Press Ctrl+C during generation or playback to cancel. Children run in a
separate process group: termination escalates to SIGKILL after at most a
0.5-second direct-child grace period; the direct child is reaped and temporary
WAVs removed. SIGTERM during child execution uses the same cleanup. Exit
status is 130 for cancellation, 1 for operational failure, 2 for usage errors.
Processes that deliberately detach from the group are not supported; the
packaged engine and player do not do that. SIGKILL of `speak` itself cannot
run cleanup.

`--output PATH` saves the generated WAV instead of starting playback,
overwrites PATH only after successful generation, and does not create parent
directories. Playback and generation are separate functions, leaving a
small boundary for future engine changes. Temporary WAVs use the system
temporary directory. Input is passed to the local engine as an argument;
very long requests can hit the OS argument-size limit and fail explicitly.
Use smaller input files in that case. Text is visible in process arguments
and sherpa-onnx diagnostic output; do not treat this as a secret-input tool.

## Conservative cleanup

Default cleanup removes heading, unordered-list, blockquote and inline-code
markers, and simple code-fence delimiter/language lines. Code body text is
retained unchanged. Markdown links/images retain both label/alt text and
destination. Unknown syntax (including emphasis, tables, HTML and numbered
lists) is retained, rather than risking content omission. There is no LLM,
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
asset fails hash verification. There is no runtime download or dependency on
an audition directory. The flake's nixpkgs lock pins the runtime and player;
the root flake currently supplies sherpa-onnx 1.12.38 and ONNX Runtime 1.24.4.
A separately pinned Home Manager flake can resolve a different runtime;
validate it when updating that lock.

Wrapper defaults use absolute store paths. For engine development/tests,
`SPEAK_MODEL`, `SPEAK_ENGINE`, `SPEAK_PLAYER`, `SPEAK_WL_PASTE`, and
`SPEAK_XCLIP` can override them. Values are single paths, not shell command
strings. `SPEAK_ENGINE` must accept the current sherpa-onnx arguments; another
engine requires changing only the generation adapter, not input/playback.
Defaults are CPU, four threads, speaker 1, length scale 1, max sentences per
batch 1, silence scale 0.2. Each request starts a fresh engine process.

## Validation

From the repository root, using the project devshell:

```sh
nix develop --command nix build .#local-tts --no-link
nix develop --command nix shell --inputs-from . nixpkgs#python3 nixpkgs#ruff \
  --command bash -c 'ruff format --check home/programs/local-tts/*.py &&
    ruff check --select E4,E7,E9,F,I home/programs/local-tts/*.py &&
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

The package runs Python tests during its sandboxed build. Lifecycle tests
use fake generation/player subprocesses, including a SIGTERM-ignoring child
and a descendant, and interrupt both stages with SIGINT and SIGTERM. The
isolated Home Manager evaluation checks opt-in/disabled package presence,
activation evaluation, and absence of user services; it does not evaluate
the full desktop profile with its separate/private flake inputs. The full
`pl@pale` activation derivation was also evaluated successfully without
activation or lockfile updates; its runtime is likewise sherpa-onnx 1.12.38.

VM observations (not controlled cold/warm benchmarks or host latency):

- Short 6-word sample: 2.91 seconds whole-file generation, 2.18 seconds audio.
- Existing 84-word audition text: 28.27 seconds generation, 34.91 seconds audio.
- Both outputs validated as mono, 24 kHz, 16-bit PCM with nonzero samples.

Timing includes engine startup, phonemization, synthesis and WAV writing,
but excludes Nix startup/downloads and PipeWire startup. Earlier audition
used a different runtime; these observations do not establish why timings
differ. Host first-sound latency, quality, real clipboard retrieval, output
routing and Ctrl+C during audible playback still require operator acceptance.
GUI, keybindings, daemon/resident engine, automatic clipboard watching,
background replacement, stop command and GPU comparison are deferred.
