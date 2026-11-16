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
independent and can overlap. The desktop clipboard toggle below owns a
separate invocation. No notification integration, clipboard watcher or Pi
extension; the agent VM speaks through the speech bridge below.

`--output PATH` writes mono 24 kHz signed 16-bit PCM WAV and atomically
replaces PATH only after success, preserving an existing file on failure or
cancellation. Parent directories must exist. Temporary files are removed;
audio files are generated without playback. Successful requests are quiet.
`--verbose` shows engine diagnostics and total time including playback.
Text is passed through an anonymous stdin file, not child arguments; use
stdin/file/clipboard to keep it out of the CLI's own argument list as well.
Errors/verbose diagnostics may contain content; do not treat this as a
secret-input facility.

## Unified NATS clipboard toggle on pale

With `bridge.enable` and `bridge.natsUrl` set (as on pale), **Ctrl+Pause**
queries `speech.query.state`. Active speech from any source is stopped via
`speech.intent.stop`; otherwise clipboard text is cleaned and published in
contiguous `speech.intent.say` chunks with a fresh utterance ID. Each chunk
awaits acceptance. A runtime lock serializes local key presses. There is no
separate clipboard-speech user unit on pale, and no audio fallback on NATS
failure. Errors go to sxhkd stderr. Empty clipboard is a no-op. Very large
input may fill the bridge queue: rejection is visible and Ctrl+Pause can
stop the partial utterance. Query/stop is not atomic against other sources.

Activate both NixOS (firewall) and Home Manager (bridge, package, bindings):

```sh
sudo nixos-rebuild switch --flake .#pale
home-manager switch --flake './home#pl@pale'
systemctl --user restart speech-bridge.service sxhkd.service
```

From a clean host feature checkout, first `git fetch vm`, compare
`HEAD...vm/feat/agent-nats` for divergence, then fast-forward only when safe.
Do not reset host work or deploy from the guest.

Host QA: start clipboard speech, stop before/during audio, let it finish and
start again; try empty clipboard, NATS down, active holds, and rapid presses.
Confirm clipboard replaces/stops agent speech, and direct HTTP emergency
stop works with NATS down. Verify Ctrl+Shift+Pause is delivered physically
and neither shortcut triggers Handy. Manual recovery:
`systemctl --user restart speech-bridge.service`.

## Legacy standalone clipboard toggle (without NATS bridge)

sxhkd binds **Ctrl+Pause** to `clipboard-speech-toggle` when
`programs.local-tts.enable` is true. The command resolves through the desktop
PATH to the Home Manager-installed toggle, as it did in Awesome. Awesome
no longer grabs this shortcut. First press starts `speak --clipboard`; the
next stops only `clipboard-speech.service`.
No Super key is needed on the controller. Plain Pause is not bound here
and remains available to Handy. No other configured Ctrl+Pause binding
was found in this checkout; Handy's runtime shortcut configuration is not
managed here, so modifier collision still requires a host test.

The user service is not enabled at login. A per-user runtime lock serializes
state checks and synchronous starts/stops, including rapid repeated
presses. Natural completion is idle; failed requests can restart immediately
without systemd start throttling. Stop targets the service cgroup, including
HTTP generation and playback children even in separate process sessions.
The resident GPU server, direct `speak` calls and Pi-owned playback are not
stopped. A disconnected server may finish its current inference chunk.
Display variables present in sxhkd's environment are imported into the
user manager before starting, for clipboard access. Errors are available via
`journalctl --user -u clipboard-speech.service`; toggle control errors also
go to sxhkd's stderr (`journalctl --user -u sxhkd.service`).

### Host activation and controller QA

Fetch the VM branch on the host, inspect clean status and compare history
before advancing the existing host feature checkout. Stop for divergence
or host-only changes; never reset them away:

```sh
git fetch vm
git status --short --branch
git log --oneline --left-right HEAD...vm/feat/local-tts
git merge --ff-only vm/feat/local-tts
```

Run the merge in the host checkout already on `feat/local-tts`, not blindly
in the integration checkout. Integration into `feat/agent-microvm` is a
separate operator-controlled merge. From the updated feature checkout:

```sh
sudo nixos-rebuild switch --flake .#pale
home-manager switch --flake './home#pl@pale'
systemctl --user daemon-reload
awesome-client 'awesome.restart()'
systemctl --user restart sxhkd.service
```

The NixOS rebuild is only needed if the earlier resident GPU system changes
have not been activated; this binding move needs only Home Manager. Awesome
restart briefly reorganizes/restarts the WM, not applications. Reload it first
to release the old grab, then restart sxhkd to acquire Ctrl+Pause (even if
Home Manager already restarted sxhkd during activation). Do not enable the
clipboard service; it starts only on demand.

Pending human acceptance on the host, with the actual controller:

- Copy a long passage; Ctrl+Pause starts speech, second press stops it.
- Stop before first audio and during audio, then immediately start again.
- Let speech finish; next press starts a new clipboard read. Empty clipboard
  or server failure must return to retryable idle; test recovery.
- Try rapid distinct presses. Each press toggles in serialized order; there
  is no queue of utterances or key-repeat debouncing.
- Run independent/Pi speech concurrently; stopping clipboard speech must
  leave it playing. Stopping Pi must likewise leave clipboard speech alone.
- Verify plain Pause still starts/stops Handy dictation. Verify Ctrl+Pause
  never triggers Handy and plain Pause never triggers clipboard speech.
  Check both physical keyboard and controller key/modifier delivery.
  If Handy treats Pause without respecting modifiers, resolve its shortcut
  configuration before accepting the binding; VM checks cannot prove this.

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
the default is `"cpu"`. Only pale opts in to HTTP. Enabling the module also
installs the clipboard toggle and its on-demand user service. System and
standalone Home Manager must be activated separately.

Development overrides: `SPEAK_BACKEND` (`cpu`/`http`, overridden by
`--backend`), `SPEAK_URL` (default
`http://127.0.0.1:8880/v1/audio/speech`, HTTP without credentials),
`SPEAK_MODEL`, `SPEAK_ENGINE`, `SPEAK_PLAYER`, `SPEAK_WL_PASTE`, `SPEAK_XCLIP`.
Executable overrides are single paths, not shell commands. The CPU adapter
protocol is `MODEL OUTPUT-OR-DASH VERBOSE-0-OR-1` with UTF-8 stdin, raw f32
on `-`, WAV otherwise. Player overrides must accept `pw-play`'s raw options.
HTTP does not use proxy environment variables or follow redirects.

## Speech bridge

`programs.local-tts.bridge.enable` runs `speech-bridge.service`, a user
service started with the login session (`default.target`, after PipeWire,
restarted on failure). It listens on `10.77.0.1:8881` with `IP_FREEBIND`, so
it starts before the agent VM's tap device exists and survives VM restarts.
Address and port live once in `bridge-endpoint.nix`, read by both the user
service and the NixOS `agent-speech-guard` firewall chain, which accepts the
port from `10.77.0.2` on `vm-agent`, and from host-local loopback traffic
whose source and destination are `10.77.0.1`. Everything else, including
LAN traffic, is dropped. This deliberately trusts host-local clients for
all bridge HTTP endpoints; it does not expose a new listening address.

**Ctrl+Shift+Pause** runs `speech-emergency-stop`, a direct HTTP `/stop`
with proxies disabled and a two-second timeout, independent of NATS. No
conflicting configured binding was found; physical key delivery and Handy
modifier handling still need host QA. Second-tier recovery is manually
`systemctl --user restart speech-bridge.service`; this loses in-memory
holds and retired IDs, so do not use it as an automatic fallback.

```sh
curl -X POST -d '{"text": "Hello from the VM."}' http://10.77.0.1:8881/say
curl -X POST http://10.77.0.1:8881/stop
curl http://10.77.0.1:8881/health
```

- `POST /say` takes `{"text": ...}` up to `maxChars` (default 1000) in a
  body of at most 8 KiB. The sentence is queued before the 202 reply; 400
  for bad JSON or empty text, 413 for oversized input, 503 when the queue
  (`maxQueue`, default 64) or the request slots are full.
- `POST /stop` kills playback, clears the queue and cancels synthesis by
  shutting down the Kokoro socket. 204, idempotent, served even when /say
  is saturated.
- `GET /health` returns queue length and whether a sentence is in progress.

Each sentence streams from the resident Kokoro server into its own `pw-play`
with the same stream properties and gain as `speak`; short gaps between
sentences are expected. Speed (`bridge.speed`) is never a caller choice.
HTTP `/say` always uses the default voice (`bridge.voice`); NATS utterances
may select another (see below). Kokoro failures drop
the sentence and are logged without its text in
`journalctl --user -u speech-bridge.service`.

### Diagnosing clipped opening words

NATS replacement cancels the prior owner, but does not trim the new text.
The bridge still opens a player lazily on the first PCM bytes, once per
sentence, just as before NATS. `speech.evt.started` means process creation,
not that PipeWire or Bluetooth is ready to render sound. The foreground
`speak` pipeline instead starts its player before synthesis. Faster warm
synthesis can expose a sink wake-up delay; this is a host hypothesis, not
something VM tests can establish.

On pale, compare cold playback after the earbuds have idled with immediate
replays and with a wired/default sink. Observe intent text and lifecycle
while replaying the reported message (these subjects contain spoken text):

```sh
nats --server nats://127.0.0.1:4222 sub 'speech.>'
wpctl status -n
journalctl --user -u speech-bridge.service --since '5 minutes ago'
speak --output /tmp/speech-opening.wav \
  'Pi speech now uses NATS. The opening words must survive.'
pw-play --target=bluez_output.58_FC_C6_CE_92_70.1 /tmp/speech-opening.wav
```

Verify seq 0 contains the opening words, and look for rejected/stopped
utterances. Listen to the saved WAV on a warmed or wired sink: if its
opening is missing there too, investigate synthesis rather than transport.
Optionally record the sink monitor during a cold replay and listen back
warm; intact monitor audio with missing physical sound narrows the loss to
the output path, though it does not measure the earbuds themselves:

```sh
pw-record --target=bluez_output.58_FC_C6_CE_92_70.1 \
  --properties='{ stream.capture.sink = true }' /tmp/speech-monitor.wav
```

The opt-in `programs.local-tts.bridge.leadingSilenceMs` (default 0, range
0–2000) prepends mono s16 24 kHz zero samples before the first audio of an
utterance. Try 350, then compare 0/350/700 ms after equal idle periods. It
is not a sleep: silence traverses the actual player and sink. It is not
repeated for subsequent chunks, does not alter generated WAVs or direct
`speak`, and remains cancellable through the existing bounded pipe. A
replacement utterance gets its own padding. It cannot guarantee readiness
or address devices that mute again between sentence players.

After fetching and safely fast-forwarding `feat/agent-nats` on the host,
set that option in `home/users/pl/pale.nix`, then run from the checkout:

```sh
home-manager switch --flake './home#pl@pale'
systemctl --user restart speech-bridge.service
systemctl --user cat speech-bridge.service
```

Confirm `--leading-silence-ms 350` in ExecStart. No NixOS rebuild, NATS
restart, VM rebuild or Pi reload is needed for this bridge-only option.
Test cold first playback, immediate replay, multi-chunk continuity, stop
before/during audio, rapid replacement and clipboard/agent replacement.
Report the smallest effective padding and any remaining clipping; physical
acceptance is still pending. These changes do not enable padding on pale
automatically.

## Cube NATS migration

See [CUBE-CONTROL.md](CUBE-CONTROL.md) for the pale-only cube relay,
controller and mechanical host executor, safe replacement of cube-remote,
activation commands, observation, simulations and pending physical QA.
Handy state tracking remains deferred; native shortcuts stay unchanged.

The same `agent-controller` now handles live agent idle notifications.
See [NOTIFICATIONS.md](NOTIFICATIONS.md) for protocol, migration, desktop
session environment, host fetch/activation and simulated settled-event QA.

## NATS voice prototype

Pale enables `bridge.natsUrl = "nats://127.0.0.1:4222"`. Other profiles
leave it null. HTTP stays available during initial connection failure and
reconnection. The bridge uses live core subscriptions, not JetStream
consumers. Commands are never replayed. Lifecycle events are best effort
and not buffered during outages; CONTROL is observation, not execution.
The CONTROL stream sets `no_ack = true`: its broad observation subjects
must not send JetStream publish acknowledgments to core request inboxes.
Only the bridge replies to speech queries, intents and commands. Publishers
must not use JetStream publish acknowledgment APIs for CONTROL subjects.

After activating a changed hub configuration, reconcile an existing CONTROL
stream with `sudo systemctl restart nats-control-stream.service`. The unit
edits the stream in place, preserving recorded observations; no stream
deletion or bridge restart is needed. Verify with:

```sh
nats --server nats://127.0.0.1:4222 stream info CONTROL --json | jq '.config.no_ack'
nats --server nats://127.0.0.1:4222 req speech.query.state '{}' --timeout 2s
```

The first command must print `true`; the second must return bridge health
(including `active`), not a `stream`/`seq` storage acknowledgment. Without a
bridge responder, requests time out or report no responders rather than
receiving a storage acknowledgment.

- `speech.intent.say`: `{utt, seq, final, text, origin, sid?, voice?}`. IDs are
  nonempty strings up to 128 characters; sequences start at zero and must
  be contiguous. Same-ID chunks append; a different ID atomically stops
  and replaces playback. An empty final chunk finalizes without audio.
  Finalized utterances reject additional chunks. The last 1024 stopped,
  completed or hold-rejected IDs are remembered in memory, not across
  service restarts. Senders must use fresh UUIDs and never retry old speech
  after reconnect. Text uses the HTTP maxChars limit per chunk.
- `voice` is optional. Absent means the configured `bridge.voice`
  (default `af_bella`). Accepted values are exactly `af_bella`, `af_heart`,
  `af_jessica`, `af_sky`, `bf_isabella`, `am_echo` and the configured
  default; the list is fixed in `speech_bridge.py`, not a module option.
  A non-string voice (including `null`) is rejected as `invalid`; any other
  string is rejected with reason `voice`. Such a rejected new utterance
  never replaces or stops current speech. The voice is fixed by seq 0 for
  the whole utterance: every later chunk must resolve to the same voice,
  so either repeat it on each chunk or omit it on all chunks when using
  the default. A mismatched chunk is rejected with reason `voice`, like
  an origin mismatch, and the utterance keeps waiting for a valid chunk.
  Each queued sentence carries its voice into its own Kokoro request.
  Voice availability in the running Kokoro image is not checked by the
  bridge; a missing voice fails synthesis with reason `failed`.
- `speech.intent.stop` and `speech.cmd.stop`: `{}`. Both cancel the owner,
  queued chunks, player and synthesis connection through generation bump.
- `speech.cmd.hold`: `{id, ttl}` with TTL in seconds, greater than zero and
  at most 300. Stops playback immediately. Same-ID renewal extends the
  deadline; different holds coexist. `speech.cmd.release`: `{id}` removes
  only that hold. Expiry is monotonic. HTTP and NATS speech are both
  rejected while any hold remains; rejected speech is never queued.
- `speech.evt.started`, `finished`, `stopped`, `rejected`: carry
  `utt`, `origin`, optional `sid`, and `reason` for stop/rejection.
  Started, finished and stopped also carry the effective `voice`; the
  health `utterance` object does too, for NATS and HTTP owners. Started
  means the player was spawned. Finished means final input and all queued
  audio completed; empty utterances finish without started. Synthesis
  failures terminate NATS utterances with reason `failed`.
- `speech.query.state`: core request/reply returning bridge health with
  `active`, `utterance`, `held`, `queued`, `speaking`. Active includes
  synthesis and waiting for more chunks, not just audible playback.
  Intents/commands also reply `{accepted}` when a reply subject is supplied.

HTTP `/say` retains its sentence queue semantics between HTTP clients.
Switching between HTTP and NATS replaces the prior owner. HTTP callers
have no utterance IDs, so their late requests cannot be tombstoned. Holds
still gate them. Local trusted publishers may issue commands in this
prototype; the AGENT account exports only speech intents, not commands.

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
nix build --no-link .#checks.x86_64-linux.speech-bridge
nix develop --command nix eval --raw \
  './home#homeConfigurations."pl@pale".activationPackage.drvPath' \
  --no-write-lock-file
nix develop --command nix run .#local-tts -- \
  --backend cpu --output /tmp/bella-smoke.wav 'Hello. Bella is speaking locally.'
```

For real user-systemd lifecycle tests (no GPU/audio device required), run
from the same Python tools shell with `SPEAK_TEST_SYSTEMD=1 python3 -m
unittest -v` in `home/programs/local-tts`. These create uniquely named
runtime test services and clean them up; normal package checks skip them.
They verify HTTP disconnect, player termination, unrelated process survival,
natural completion and repeated error recovery. Subprocess controller tests
also cover concurrent presses and control errors.

Fake local HTTP and subprocess tests cover first audio before completion,
backpressure, output success/atomicity/errors, request disconnect and player
cancellation, no silent fallback, and CPU regression. VM checks cannot prove
host sound, GPU execution, startup after reboot or playback routing. The
manual GPU stream was accepted as perceptually instant with no gaps; the
operator also reports the integrated GPU CLI and CPU fallback work on host.
The new desktop toggle and Handy/controller interaction still require the
human acceptance checks above.
