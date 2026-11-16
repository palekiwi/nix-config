# Live agent idle notifications (desktop and Gotify)

Pale's existing cubeControl option now starts one `agent-controller`
process for cube rules and notifications. The separate cube relay and
fixed host executor remain. Guarded voice-controller and handy-adapter
stay disabled. No Handy shortcuts, speech padding or cube mappings change.

The controller subscribes to core NATS `agent.evt.*.settled`, not a
JetStream consumer. Every valid live settled event requests one desktop
notification, except settled events from deny-listed service agents (see
below). Interactive sessions (events without an `agent` field) also
push to Gotify when enabled (see "Gotify channel"). There are no
duration, pipeline, aggregation or success filters. There is no
registry query, history/read state, retry queue or replay after
restart. Events while disconnected are lost; NATS outages terminate
the processes for systemd restart, without fallback.

## Settled event fields

cue-platform's SessionTracker (schema v1, additive) puts these on
settled; every field after `aborted` is omitted when unknown:

- `v`, `ts`, `sid`, `host`, `kind`, `seq`: envelope.
- `aborted`: the busy period was aborted.
- `errored`: the session was in error state when it settled.
- `context`: canonical cue context address (`org/repo/slug`).
- `context_title`: `title` (else `description`) of that context's
  `context.md` in the cue store.
- `session_name`, `cwd`: pi session name and working directory.
- `session_description`: latest `session-description` entry written by
  `/describe`, refreshed when the session settles.
- `tmux_window`, `tmux_session`: `#{window_name}` and `#{session_name}`
  of the pane, read with `tmux display-message` when the session settles.
  Only an interactive pi owning its tty inside tmux reports them;
  headless runs, which inherit `TMUX_PANE` from their parent, do not.
- `run_id`, `agent`: cue-agent run id and agent name when the session is
  a headless agent run (`agent` comes from `CUE_AGENT_NAME`, set by
  cue-platform on every cue-agent task and by cue-supervisor on every
  supervisor run).
- `turn_ms`: milliseconds since the input that began the busy period.
- `tools`: tool calls completed in the busy period.

No assistant, prompt, tool or error text is ever carried or shown.

## Layout

The status prefix is the state the settled event reports: `[idle]`,
or `[aborted]`, `[error]` or `[aborted, error]`. `idle` never claims
task success. Error is shown for `errored: true` and, for older events,
an `error` field, `state: error` or `stopReason: error`, without
exposing error text. Headless runs use the same prefix; no run outcome
(succeeded, failed, timed out) is published on NATS.

Interactive sessions (no `agent` field):

- Summary `[<status>]: <tmux window>`. The window name is `tmux_window`,
  the name the C-f window picker shows. Without it (pi outside tmux, older
  events) the label falls back to `session_name`, the context slug (last
  segment of `context`), `context_title`, then `sid`.
- Body, one line each, only when present: the session description from
  `/describe`, then the tmux session name as a footer prefixed with
  `── `. No blank line separates them; without a tmux session there is
  no footer.

Example: summary `[idle]: notifications`, body

```
Simplify agent notifications
── palekiwi
```

Headless agent runs (`agent` field present, any value):

- Summary `[<status>]: <agent>`, falling back to `sid` when `agent` is
  empty.
- Body: empty. A task label would go here, but no settled event carries
  one: cue-agent and the supervisor do not pass task labels to the run.

Desktop and Gotify use the same summary and body. The working
directory, context address, host, turn duration and tool counts are not
displayed.

Older events with only the envelope and `aborted` still notify, as
`[idle]: <sid>` with an empty body. No lookup blocks delivery.

For QA, set or edit `/describe` in a running pi session inside tmux and
let it settle. Both desktop and phone should show `[idle]: <window>`
with the window name the picker shows (rename the window by hand to
check it follows), then the description and the `── <tmux session>`
footer.
A delegated run shows `[idle]: <agent>` on the desktop only.

## Service agent deny list

`programs.local-tts.cubeControl.notifyDenyAgents` (default
`[ "summarizer" "compactor" ]`) is passed to agent-controller as
repeated `--deny-agent <name>`. A valid settled event whose `agent` is
listed is dropped: the controller prints `agent controller: dropped
settled from agent <name>` to the journal and reports
`{"accepted": true, "reason": "denied agent"}` on
`cube.evt.controller.result`; it is not an error. Events without an
`agent` field always notify. Malformed events are rejected before the
deny check, as before. Filtering is controller policy; pi always
publishes.

## Gotify channel

Gotify is a second channel, independent of the desktop one. Routing for
a valid settled event:

- `agent` is deny-listed: dropped, neither channel.
- `agent` field present (any value, including empty; delegate and other
  cue-agent runs): desktop only.
- no `agent` field (interactive pi session): desktop and Gotify.

For a qualifying event the controller publishes `host.cmd.notify
{summary, body, id, ts}` and then `host.cmd.gotify {title, message,
priority, id, ts}`; title and message are the same summary and body.
Priority is `priority` (default 5) for a normal idle and `alertPriority`
(default 7) when the event is aborted or errored. Each command is sent
even if the other fails; any failed or rejected command makes the
controller report `accepted: false` with `reason: RuntimeError` on
`cube.evt.controller.result` and print e.g. `cube controller:
RuntimeError: host.cmd.gotify rejected` to the journal.

`cube-host-executor` performs the push: a fixed POST of JSON `{title,
message, priority}` to `<url>/message`, with the application token in
the `X-Gotify-Key` header (never in the URL, never logged). It uses the
Python standard library (urllib), no proxy, no redirects, a three-second
timeout and no retries. The token is read from the token file at send
time, so a missing, unreadable or malformed token file is a per-message
failure (`FileNotFoundError`, `PermissionError`, `ValueError`), not a
crash. The file may hold the bare token or a `GOTIFY_TOKEN=<token>`
line. HTTP errors, timeouts and unreachable servers are reported like
every other executor failure: a `cube executor: <Error>: <message>`
journal line and `host.evt.execution {subject: "host.cmd.gotify",
accepted: false, reason}`. Success reports `accepted: true, status`. The
executor validates the command the same way as `host.cmd.notify`
(summary pattern, 100/256 bounds, priority an integer 0-10), strips
control characters, and keeps message line breaks; no markup escaping is
applied since Gotify renders plain text. The controller never sees the
token. The executor only subscribes to `host.cmd.gotify` when Gotify is
enabled.

Options under `programs.local-tts.cubeControl.gotify`:

- `enable` (default false; pale sets it in `home/users/pl/pale.nix`):
  passes `--gotify --gotify-priority <n> --gotify-alert-priority <n>` to
  agent-controller and `--gotify-url <url> --gotify-token-file <path>`
  to cube-host-executor.
- `url` (default `http://haze:8780`): Gotify base URL, the same server
  acuity on pale posts to.
- `tokenFile` (default `/run/secrets/gotify/token`): the existing sops
  secret `gotify/token`, owned by `pl` on pale. No new secret.
- `priority` (default 5) and `alertPriority` (default 7), 0-10.

## Bounds and execution

Identity labels are flattened, stripped of controls and bounded to 80
characters each; the summary label is shortened further so the summary
stays within 100 characters. The executor bounds summary/body to
100/256 characters, keeps body line breaks but strips every other
control character per line, escapes markup, and calls a fixed Nix-store
notify-send executable with separate argv and `--`. No shell or caller-selected executable/options.
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
id, ts}` and, for Gotify, `host.cmd.gotify {title, message, priority, id,
ts}`. Existing `cube-host-executor`, already part of the user's
graphical-session target, performs the desktop action. This is simpler
than a new notification service and preserves the policy/action boundary.
It uses the user manager's session D-Bus environment, not a VM environment,
and reaches haze:8780 directly from pale.
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
previous NATS transport is already active. Gotify needs no new secret:
`/run/secrets/gotify/token` is already deployed on pale; check it with
`test -r /run/secrets/gotify/token && echo readable` (never print it).
The `systemctl --user cat` output must show `--gotify ...` on
agent-controller and `--gotify-url http://haze:8780 --gotify-token-file
/run/secrets/gotify/token` on cube-host-executor. Keep replacements
stopped if activation fails before restoring old units. Integration into the host
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

Expect one idle notification per publish: `[idle]: notification_qa` with
an empty body, then `[aborted, error]: notification_qa`; never
succeeded/completed.

v2 fields and the deny list:

```sh
nats --server nats://127.0.0.1:4222 pub agent.evt.notification_qa.settled \
  '{"v":1,"ts":0,"sid":"notification_qa","host":"pale-qa","kind":"settled","seq":3,"aborted":false,"errored":false,"context":"palekiwi/palekiwi/controller-design","context_title":"Controller design QA","cwd":"/home/pl/code/palekiwi/palekiwi","agent":"builder","turn_ms":192400,"tools":14}'
nats --server nats://127.0.0.1:4222 pub agent.evt.notification_qa.settled \
  '{"v":1,"ts":0,"sid":"notification_qa","host":"pale-qa","kind":"settled","seq":4,"aborted":false,"agent":"summarizer","context_title":"Should not show"}'
nats --server nats://127.0.0.1:4222 pub agent.evt.notification_qa.settled \
  '{"v":1,"ts":0,"sid":"notification_qa","host":"pale-qa","kind":"settled","seq":5,"aborted":false,"session_name":"named","session_description":"Notification layout QA","tmux_window":"notifications","tmux_session":"palekiwi","cwd":"/home/pl/code/palekiwi/palekiwi"}'
```

The first shows `[idle]: builder` with an empty body. The second shows no
notification; the journal has `dropped settled from agent summarizer`
and `cube.evt.controller.result` carries `reason: denied agent`. The
third shows `[idle]: notifications` with body lines
`Notification layout QA` and `── palekiwi`, and no directory. From a
real pi session after reloading cue-platform dev: the notification uses
the tmux window name, and a turn summary (summarizer run) or log compaction
(compactor run) produces no notification. No event timestamp filter is applied: these
are live publishes, not stored messages. Publish the same command from
the VM using its existing local NATS URL to verify the leaf/HOST import.
Also observe an actual pi idle transition. An `end` or `turn_end` subject
must not notify. Stop agent-controller, publish settled, restart it:
no notification should appear until a new live publish. Recheck cube tap,
flip90, rotations and shake using CUBE-CONTROL.md, native Handy shortcuts,
and absence of duplicate actions. Desktop daemon/D-Bus access, real leaf
connectivity, physical cube and notification rendering require operator QA.

Gotify channel (desktop and phone):

```sh
nats --server nats://127.0.0.1:4222 pub agent.evt.gotify_qa.settled \
  '{"v":1,"ts":0,"sid":"gotify_qa","host":"pale-qa","kind":"settled","seq":1,"aborted":false,"context_title":"Gotify QA interactive","tools":3}'
nats --server nats://127.0.0.1:4222 pub agent.evt.gotify_qa.settled \
  '{"v":1,"ts":0,"sid":"gotify_qa","host":"pale-qa","kind":"settled","seq":2,"aborted":true,"context_title":"Gotify QA aborted"}'
nats --server nats://127.0.0.1:4222 pub agent.evt.gotify_qa.settled \
  '{"v":1,"ts":0,"sid":"gotify_qa","host":"pale-qa","kind":"settled","seq":3,"aborted":false,"agent":"builder","context_title":"Gotify QA builder"}'
nats --server nats://127.0.0.1:4222 pub agent.evt.gotify_qa.settled \
  '{"v":1,"ts":0,"sid":"gotify_qa","host":"pale-qa","kind":"settled","seq":4,"aborted":false,"agent":"summarizer","context_title":"Gotify QA summarizer"}'
```

Expect:

- seq 1: desktop and phone `[idle]: Gotify QA interactive`, empty body,
  Gotify priority 5; `host.evt.execution` shows
  `host.cmd.notify` and `host.cmd.gotify` accepted (`status: 200`).
- seq 2: desktop and phone `[aborted]: Gotify QA aborted`, priority 7.
- seq 3 (`agent: builder`): desktop only; no `host.cmd.gotify` execution.
- seq 4 (`agent: summarizer`): nothing; `reason: denied agent`.

Failure visibility, desktop unaffected. Temporarily point the token file
at a missing path (or block haze:8780) and restart only the executor:

```sh
unit=$(systemctl --user show -p FragmentPath --value cube-host-executor)
mkdir -p ~/.config/systemd/user/cube-host-executor.service.d
{ echo '[Service]'; echo 'ExecStart='
  grep '^ExecStart=' "$unit" | sed 's|/run/secrets/gotify/token|/run/secrets/gotify/missing|'
} > ~/.config/systemd/user/cube-host-executor.service.d/gotify-qa.conf
systemctl --user cat cube-host-executor | grep gotify-token-file
systemctl --user daemon-reload
systemctl --user restart cube-host-executor
nats --server nats://127.0.0.1:4222 pub agent.evt.gotify_qa.settled \
  '{"v":1,"ts":0,"sid":"gotify_qa","host":"pale-qa","kind":"settled","seq":5,"aborted":false,"context_title":"Gotify QA failure"}'
```

Expect a desktop notification `[idle]: Gotify QA failure`, no phone push,
`host.evt.execution {subject: "host.cmd.gotify", accepted: false, reason:
"FileNotFoundError"}`, journal lines `cube executor: FileNotFoundError:
...` and `cube controller: RuntimeError: host.cmd.gotify rejected`, and
cube-host-executor still active. Blocking the network instead gives
`URLError` or `TimeoutError` within about three seconds (the controller
may report `host.cmd.gotify TimeoutError` first, as its request waits two
seconds). Restore with:

```sh
rm ~/.config/systemd/user/cube-host-executor.service.d/gotify-qa.conf
systemctl --user daemon-reload
systemctl --user restart cube-host-executor
```

## Verification

The package check runs all local-tts Python tests, including real loopback
NATS/MQTT brokers, fixed argv/failed executor tests, malformed/oversized
payload rejection, wording, v2 layout and fallbacks, deny list (unit and
live), Gotify routing (interactive: notify and gotify; agent: notify
only; denied: neither; priorities; independent channel failures), the
executor's POST JSON and `X-Gotify-Key` header against a loopback HTTP
server, HTTP error/unreachable/timeout/missing or malformed token
failures, a live NATS run of both channels with a token-file failure,
cube mappings and restart/no-replay tests. Home Manager service
evaluation checks the new controller exists, conflicts with the removed
old unit, leaves guarded units absent and passes `--deny-agent` for each
configured name, plus the Gotify arguments when
`cubeControl.gotify.enable` is set. No deployment
or physical acceptance is implied by those checks.
