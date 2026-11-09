# Foreground local speech

On pale, `speak` streams Bella from the resident localhost GPU server to
PipeWire. Generation is separate from playback: `--output` writes a complete
WAV without starting a player. Other profiles and the standalone flake
package default to CPU. No backend silently falls back to another.

## Normal use

```sh
speak 'Read this response aloud.'
printf '%s\n' '# A heading' 'Read this response.' | speak
speak --file response.md
speak --clipboard
speak --output narration.wav --file response.md
speak --backend cpu 'Explicit CPU recovery.'
speak --backend http 'Explicit resident GPU request.'
```

Choose positional words, `--file PATH` (UTF-8), or `--clipboard`; without an
explicit source, stdin is read to EOF. Positional words are joined with
spaces; use `--` before leading dashes. Explicit sources take precedence
over stdin; conflicting sources and empty input are errors. Clipboard is a
single read from `wl-paste` on Wayland, otherwise `xclip` on X11. A working
desktop clipboard/PipeWire session is required.

Conservative cleanup removes heading, unordered-list, blockquote and
inline-code markers and code-fence delimiters, retaining code bodies. Links
retain labels and destinations; unknown markup is retained. Use `--raw` to
skip cleanup. Nothing is summarized or rewritten by the client. The TTS
frontend normalizes text for pronunciation; code/paths/non-English text may
not be intelligible. Callers own selection and any summary preparation.

Ctrl+C or SIGTERM stops this invocation's request/generator and player,
including process-group descendants; the resident service stays running.
Children get 0.5 seconds before SIGKILL and are reaped. Exit statuses: 130
cancelled, 1 operational failure, 2 usage error. Concurrent invocations are
independent and can overlap. No queue, replacement behavior, GUI, keybindings,
notification integration, clipboard watcher, Pi extension or VM bridge.

`--output PATH` writes mono 24 kHz signed 16-bit PCM WAV and atomically
replaces PATH only after success, preserving an existing file on failure or
cancellation. Parent directories must exist. Temporary files are removed;
audio files are generated without playback. Successful requests are quiet.
`--verbose` shows engine diagnostics and total time including playback.
Text is passed through an anonymous stdin file, not child arguments; use
stdin/file/clipboard to keep it out of the CLI's own argument list as well.
Errors/verbose diagnostics may contain content; do not treat this as a
secret-input facility.

## GPU service and HTTP client

See [CONTAINER.md](CONTAINER.md) for host deployment and service controls.
The pale Home Manager profile sets `programs.local-tts.backend = "http"`.
The client POSTs the full input to `/v1/audio/speech` with `model=kokoro`,
`voice=af_bella`, `response_format=pcm`, `stream=true`, `speed=1`. It streams
raw s16 little-endian mono 24 kHz into a bounded playback pipe as bytes
arrive, without waiting for the whole response. File mode wraps that PCM
in a WAV. HTTP failures and wrong content types are rejected before audio
is forwarded; truncated/empty/odd-sized responses fail. Already played
partial audio cannot be undone, and a server failure after headers may not
always be distinguishable from a cleanly ended short stream.

Connection timeout is 5 seconds; response-header and socket-read inactivity
timeout is 120 seconds, not a total utterance duration limit. Long streams
can continue while making progress. SIGINT/SIGTERM terminate the HTTP worker,
closing its socket even when blocked on a read or playback backpressure.
The server may finish its current inference chunk after disconnect.
Input is whole-request; transport backpressure does not bound server memory.
Client errors do not print server response bodies or supplied text normally.

## CPU recovery and package use

```sh
nix run .#local-tts -- --backend cpu 'CPU speech without activation.'
nix run .#local-tts -- --backend http --file response.md
nix build .#local-tts
./result/bin/speak --backend http 'Use the resident server.'
```

CPU uses a compiled sherpa-onnx callback adapter, one model load per
invocation, four threads, Bella speaker ID 1, speed 1 and one sentence batch.
It sends mono 24 kHz float32 PCM to `pw-play` incrementally. First audio
requires initialization and a batch of synthesis; the operator heard gaps
between CPU sentences. Sherpa still accumulates the complete result
internally. HTTP uses the different PyTorch Kokoro V1 model, not an identical
precision/model comparison.

The CPU model release `kokoro-int8-en-v0_19.tar.bz2` is fixed-hash fetched
in `package.nix` (Apache-2.0, including espeak data). The flake lock pins
sherpa/player dependencies; no Python inference binding or CUDA build.
The package builds only the small C++ adapter and runs Python tests.

The Home Manager module defaults disabled. Enable with
`programs.local-tts.enable = true`, optionally setting `backend = "http"`;
the default is `"cpu"`. Only pale opts in to HTTP, with no user service.
System and standalone Home Manager must be activated separately.

Development overrides: `SPEAK_BACKEND` (`cpu`/`http`, overridden by
`--backend`), `SPEAK_URL` (default
`http://127.0.0.1:8880/v1/audio/speech`, HTTP without credentials),
`SPEAK_MODEL`, `SPEAK_ENGINE`, `SPEAK_PLAYER`, `SPEAK_WL_PASTE`, `SPEAK_XCLIP`.
Executable overrides are single paths, not shell commands. The CPU adapter
protocol is `MODEL OUTPUT-OR-DASH VERBOSE-0-OR-1` with UTF-8 stdin, raw f32
on `-`, WAV otherwise. Player overrides must accept `pw-play`'s raw options.
HTTP does not use proxy environment variables or follow redirects.

## Validation

From the root checkout (no activation, image download or full system build):

```sh
nix develop --command nix build .#local-tts --no-link
nix develop --command nix shell --inputs-from . nixpkgs#python3 nixpkgs#ruff \
  nixpkgs#clang-tools --command bash -c '
    ruff format --check home/programs/local-tts/*.py &&
    ruff check --select E4,E7,E9,F,I home/programs/local-tts/*.py &&
    clang-format --dry-run --Werror home/programs/local-tts/engine.cc &&
    cd home/programs/local-tts && python3 -m unittest -v'
nix develop --command nixfmt --check home/programs/local-tts/*.nix \
  hosts/pale/local-tts.nix hosts/pale/test-local-tts.nix
nix develop --command nix eval --json --impure --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./hosts/pale/test-local-tts.nix { flake = f; }'
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
  --backend cpu --output /tmp/bella-smoke.wav 'Hello. Bella is speaking locally.'
```

Fake local HTTP and subprocess tests cover first audio before completion,
backpressure, output success/atomicity/errors, request disconnect and player
cancellation, no silent fallback, and CPU regression. VM checks cannot prove
host sound, GPU execution, startup after reboot or playback routing. The
manual GPU stream was accepted as perceptually instant with no gaps; the
new declarative service and integrated CLI still require host acceptance.
