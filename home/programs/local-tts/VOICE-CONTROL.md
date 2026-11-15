# Guarded voice controller: partial prototype

Not ready to replace Handy's keyboard shortcut. No deployment or physical
host QA has been performed. Cube integration is not implemented.

## Observation blocker

The configured Handy revision is `14cfed8aca5d557e0d14f596846bc5bd3fc4b50f`
(`home/flake.nix`). In that source, `src-tauri/src/overlay.rs` creates a
window titled `Recording`, then `show_overlay_state` reuses it for
`recording`, `streaming`, `transcribing`, and `processing`. Its phase is an
internal Tauri `show-overlay` event. Recording readiness is another internal
`recording-ready` event. Hiding is delayed by 300 ms. Overlay style can also
be None. Neither window existence nor visibility proves microphone state.
The Awesome rule in `home/config/awesome/rules.lua` only positions it.
No recording observer or Awesome event publisher is installed here.

The adapter therefore answers `dictation.query.state` with
`{observed: "unknown", reason: "observer_unavailable"}` and rejects toggle
commands with `{accepted: false, reason: "observer_unavailable"}`. Cancel
runs the real Handy `--cancel` CLI with a three-second timeout; successful
CLI exit is not reported as observed recording stop. There are deliberately
no synthetic started/stopped events or optimistic toggle boolean.

## Implemented controller contract

- Core NATS requests only, no JetStream acknowledgements/replay, no HTTP or
  fake-keystroke fallback. CONTROL's `no_ack` setting is irrelevant to core
  request/reply acknowledgements.
- Serialized bounded input queue. Every toggle or cancel requests speech
  stop, waits for acceptance, requests hold, waits for acceptance, and only
  then commands the adapter. Failure before the adapter prevents execution.
- Each process owns a fresh hold ID with a 15-second TTL. Adapter state is
  queried at startup, after accepted commands, and every two seconds.
- An authoritative `started` response stops playback and renews that ID;
  `stopped` releases only that ID. Unknown never renews or releases. An
  unconfirmed request or dead controller leaves at most a bounded hold.
- The current adapter cannot supply authoritative started/stopped responses;
  controller renewal/release paths are tested using a simulated executor.
- Loss of NATS exits the process; systemd retries with a new connection and
  reconciles, without replaying commands. A speech bridge restart loses
  holds; a future working observer allows the next poll to reacquire one.
- Only one controller and one adapter should run per account. These are
  live subscribers, not competing-worker queue subscriptions.

## Optional development activation

Do not enable this expecting usable dictation. In the host Home Manager
configuration, `programs.local-tts.voiceControl.enable = true` creates
`voice-controller.service` and `handy-adapter.service`. It requires Handy
and a configured NATS speech bridge. The default is false; pale is unchanged.
After an operator-selected Home Manager rebuild, inspect:

```
systemctl --user status voice-controller handy-adapter
journalctl --user -u voice-controller -u handy-adapter
voice-control toggle --url nats://127.0.0.1:4222
```

Toggle must fail explicitly with `observer_unavailable`, after stopping
speech and setting a bounded hold. `voice-control cancel --url ...` uses
the same stop/hold path and invokes Handy's cancel. Check that hold expires
within 15 seconds, NATS shutdown terminates the services, reconnection
starts fresh processes, and no command is replayed. Do not run experimental
commands during important dictation. Disabling the option removes the units.

## Shortcut migration is intentionally blocked

No key bindings or Handy settings are changed. Existing Pause and
XF86AudioPrev/legacy cube fake-Pause routing remain legacy, uncoordinated
paths, not part of this controller. Do not add a second Pause binding.
No supported declarative runtime shortcut-disable mechanism has been
established; do not overwrite Handy's mutable settings store speculatively.

Before activation as the normal dictation path:

1. Supply a verified external recording-state interface (including startup,
   reconnect, cancellation and process-death state). A Handy change exposing
   its internal phase is preferable to inferring it from window geometry.
2. Establish and test how to disable every native transcription shortcut,
   including post-process transcription. Confirm Handy releases its grabs.
   Exact GUI/store migration instructions remain blocked, not guessed here.
3. Replace Pause and XF86AudioPrev with
   `voice-control toggle --url nats://127.0.0.1:4222`, restart sxhkd, and
   verify only one request per physical key press. No xdotool in the new
   path. Leave legacy cube gestures disabled until their relay is migrated.
4. Physically QA dictation over speech, repeated toggles, cancel, crashes,
   hold renewal beyond 15 seconds, restart/reconnect, and outage rejection.

Steps 6 and 7 of the voice plan remain incomplete; this is the tested
controller/guard foundation, not a working observed Handy integration.
