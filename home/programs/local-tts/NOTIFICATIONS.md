# Live agent idle desktop prototype

Pale's existing cubeControl option now starts one `agent-controller`
process for cube rules and notifications. The separate cube relay and
fixed host executor remain. Guarded voice-controller and handy-adapter
stay disabled. No Handy shortcuts, speech padding or cube mappings change.

The controller subscribes to core NATS `agent.evt.*.settled`, not a
JetStream consumer. Every valid live settled event requests one desktop
notification. There are no duration, pipeline, aggregation or success
filters. There is no Gotify, registry query, history/read state, retry
queue or replay after restart. Events while disconnected are lost; NATS
outages terminate the processes for systemd restart, without fallback.

`Agent became idle` never claims task success. An aborted event explicitly
says `aborted`; an error field/state explicitly says `error reported`,
without exposing error text. Current cue-platform SessionTracker emits
only v, ts, sid, host, kind, seq and aborted on settled. It does not attach
the prior error state, cwd, session name or context, so normal identity is
session ID and host, and prior errors cannot be inferred. Optional session
name and context/cwd are supported when present; no lookup blocks delivery.

Identity labels are flattened, stripped of controls and bounded to 80
characters each. The executor bounds summary/body to 100/256 characters,
escapes markup, and calls a fixed Nix-store notify-send executable with
separate argv and `--`. No shell or caller-selected executable/options.
Event JSON is limited to 8 KiB; other cube/host messages remain 4 KiB.
Existing 64-message queues, two-second host command expiry and three-second
subprocess timeout remain. Overload, executor failure and unavailable
notification daemon are visible failures, not silently retried. No text
from agent prompts, tools or assistant messages is included.

## Transport and desktop environment

The pale hub's HOST account imports AGENT `agent.>`; the VM leaf attaches
to AGENT and exports that subject family. Core settled subscriptions at
`nats://127.0.0.1:4222` therefore see live VM events without JetStream APIs,
KV access or domain remapping. Domain `pale` applies to stored AGENT_EVENTS
and registry access, not this execution path. No import changes required.
The local integration test exercises live filtering/execution and restart
without replay; actual VM-to-host leaf delivery still needs host QA.

The controller only decides and sends `host.cmd.notify {summary, body,
id, ts}`. Existing `cube-host-executor`, already part of the user's
graphical-session target, performs the desktop action. This is simpler
than a new notification service and preserves the policy/action boundary.
It uses the user manager's session D-Bus environment, not a VM environment.
HOST publishers remain trusted to invoke fixed actions in this prototype;
this is not a new arbitrary-command capability or a per-publisher ACL.

## Host fetch and activation (operator only)

From the host worktree already on feat/agent-nats:

```sh
cd /home/pl/nix-config/worktrees/feat/agent-nats
git fetch vm
git status --short --branch
git log --oneline --left-right HEAD...vm/feat/agent-nats
git merge-base --is-ancestor HEAD vm/feat/agent-nats
git merge --ff-only vm/feat/agent-nats
```

Stop for dirty state, divergence or host-only commits. Do not reset work.
From a terminal inside pale's actual graphical session:

```sh
systemctl --user disable --now cube-controller.service
systemctl --user stop cube-remote.service
systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS
home-manager switch --flake './home#pl@pale'
systemctl --user daemon-reload
systemctl --user restart cube-host-executor agent-controller cube-relay
systemctl --user is-active cube-host-executor agent-controller cube-relay
systemctl --user is-active cube-controller cube-remote voice-controller handy-adapter
systemctl --user cat agent-controller cube-host-executor
```

Absent legacy units can report not-found on disable/stop. The last
is-active check must report inactive/not-found for all four units. The new
controller conflicts with cube-controller as a second migration guard.
No NixOS rebuild, NATS restart, VM rebuild or pi reload is needed if the
previous NATS transport is already active. Keep replacements stopped if
activation fails before restoring old units. Integration into the host
integration branch is a separate operator decision.

## QA (real desktop side effects)

```sh
nats --server nats://127.0.0.1:4222 sub 'host.evt.execution'
journalctl --user -f -u agent-controller -u cube-host-executor
```

In another host terminal:

```sh
nats --server nats://127.0.0.1:4222 pub agent.evt.notification_qa.settled \
  '{"v":1,"ts":0,"sid":"notification_qa","host":"pale-qa","kind":"settled","seq":1,"aborted":false}'
nats --server nats://127.0.0.1:4222 pub agent.evt.notification_qa.settled \
  '{"v":1,"ts":0,"sid":"notification_qa","host":"pale-qa","kind":"settled","seq":2,"aborted":true,"error":true}'
```

Expect one idle notification per publish; second says aborted/error reported,
never succeeded/completed. No event timestamp filter is applied: these
are live publishes, not stored messages. Publish the same command from
the VM using its existing local NATS URL to verify the leaf/HOST import.
Also observe an actual pi idle transition. An `end` or `turn_end` subject
must not notify. Stop agent-controller, publish settled, restart it:
no notification should appear until a new live publish. Recheck cube tap,
flip90, rotations and shake using CUBE-CONTROL.md, native Handy shortcuts,
and absence of duplicate actions. Desktop daemon/D-Bus access, real leaf
connectivity, physical cube and notification rendering require operator QA.

## Verification

The package check runs all local-tts Python tests, including real loopback
NATS/MQTT brokers, fixed argv/failed executor tests, malformed/oversized
payload rejection, wording, cube mappings and restart/no-replay tests.
Home Manager service evaluation checks the new controller exists, conflicts
with the removed old unit, and leaves guarded units absent. No deployment
or physical acceptance is implied by those checks.
