# Cube NATS migration prototype

Pale enables `programs.local-tts.cubeControl.enable`. This is independent
of `voiceControl.enable`, which stays disabled. No recording observer,
dictation query, speech hold, key migration or Handy configuration change
is involved. Native Handy shortcuts remain native; dictation and speech
may interfere. All three services run on pale, never in the agent VM.
The accepted 1000 ms speech startup padding is unchanged.

## Roles and protocol

- `cube-relay.service`: subscribes only to haze:1883 topic
  `zigbee2mqtt/Cube`. `mosquitto_sub` uses its default clean session and
  suppresses retained deliveries (`-R`). Its normal MQTT reconnect remains
  enabled. No persistent session, JetStream execution or outage replay.
- Relay validates bounded JSON, known action and finite rotation angle
  within +/-360 degrees. Left angles must be nonpositive, right angles
  nonnegative. It publishes raw gestures, not commands, as
  `cube.evt.pale_cube.<action>` with `{action, angle?, ts}`. `pale_cube`
  is the stable device token for this single allowlisted physical cube;
  it is a valid single NATS token, not the MQTT topic or arbitrary input.
- `agent-controller.service` (replaces `cube-controller.service`): tap/flip90 -> `speech.cmd.stop {}` globally;
  shake -> `host.cmd.handy {action:"toggle", id, ts}`; rotations ->
  `host.cmd.volume {delta, id, ts}`. Slide/flip180 remain unbound.
- Volume preserves the current pale and feat/cube-remote configuration:
  right increases, left decreases, magnitude `(abs(int(angle)) + 4) // 5`
  percent. Increasing is capped at 1.0; decreasing has no extra cap.
- `cube-host-executor.service`: mechanical allowlist only. Handy toggle
  executes `handy --toggle-transcription`, cancel executes `handy --cancel`.
  Volume executes `wpctl set-volume [-l 1.0] @DEFAULT_AUDIO_SINK@ N%+/-`.
  No shell, keystrokes, focus dependency or invented recording state.
- Executor reports `{accepted, returncode}` over request/reply and on
  `host.evt.execution`. Controller reports `cube.evt.controller.result`.
  Invalid, busy, rejected, unavailable and subprocess failure paths are
  visible in those events or the service journal. CLI success means only
  CLI success, not that Handy was observed recording.

Messages are bounded to 4096 bytes, queues to 64, commands/gestures to a
2-second freshness window, and subprocess execution to 3 seconds. NATS
failure terminates services and systemd retries with fresh core
subscriptions; there is no direct fallback. Controls are unavailable
while disconnected. Observations are best effort during outages. HOST
permissions are trusted in this prototype; arbitrary local publishers can
request allowlisted operations, not arbitrary process execution. CONTROL
currently records cube/speech/dictation, not host subjects; use live
`host.>` observation or journals for executor results.

## Host activation (operator only)

In the host worktree already on feat/agent-nats:

```sh
git fetch vm
git status --short --branch
git log --oneline --left-right HEAD...vm/feat/agent-nats
git merge --ff-only vm/feat/agent-nats
```

Stop for dirty state or divergence; preserve host-only work. From that
updated checkout, first stop the old consumer to avoid overlapping rules:

```sh
systemctl --user stop cube-remote.service
systemctl --user disable --now cube-controller.service
home-manager switch --flake './home#pl@pale'
systemctl --user daemon-reload
systemctl --user restart cube-host-executor agent-controller cube-relay
systemctl --user is-active cube-host-executor agent-controller cube-relay
systemctl --user is-active cube-controller cube-remote voice-controller handy-adapter
```

The last four must be inactive/not-found. A not-found result when stopping
an already absent legacy unit is expected. The new controller conflicts
with the old cube-controller unit as a second duplicate-consumer guard. If activation fails, keep new
services stopped before restoring the previous configuration and old cube
consumer. Do not run both. No NixOS/VM rebuild is needed for this migration
if the earlier NATS hub/speech configuration is already active. Otherwise
activate that configuration separately with
`sudo nixos-rebuild switch --flake .#pale`; do not rebuild the agent VM for
host cube control. Do not enable guarded voice-controller/handy-adapter.

## Observation and simulation on pale

```sh
nats --server nats://127.0.0.1:4222 sub 'cube.>'
nats --server nats://127.0.0.1:4222 sub 'host.>'
nats --server nats://127.0.0.1:4222 sub 'speech.cmd.>'
journalctl --user -f -u cube-relay -u agent-controller -u cube-host-executor
nats --server nats://127.0.0.1:4222 req speech.query.state '{}'
```

Simulation has real side effects on pale. Substitute shake, flip90 or
rotate_left with a negative angle as appropriate:

```sh
nats --server nats://127.0.0.1:4222 pub cube.evt.pale_cube.tap \
  "{\"action\":\"tap\",\"ts\":$(date +%s)}"
mosquitto_pub -h haze -t zigbee2mqtt/Cube \
  -m '{"action":"rotate_right","angle":26.9}'
```

Never retain simulated gestures. Host QA remains pending:

- Shake toggles Handy once with any application focused; native Handy
  shortcuts still work. Do not infer recording from executor success.
- Rotate right/left: verify original direction and 6% step for +/-26.9,
  cap at 100%, actual sink and physical cube angle sign.
- Tap and flip90 stop clipboard/agent speech with focus outside pi.
- Speech state has `held: false`; no guarded dictation services run.
- Restart relay with a retained MQTT gesture: no action. Disconnect/restart
  MQTT and NATS: controls unavailable while disconnected, no stale actions
  after recovery; subsequent fresh gesture works.
- Stop controller: no gesture execution; speech/native Handy shortcuts
  continue independently. Inspect failure events for missing executor.

VM integration tests use temporary loopback MQTT/NATS brokers and fake host
executables. They do not attest physical cube, audio or Handy behavior.
