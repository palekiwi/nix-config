# VM GitHub collection service

`vm/agent/home/github-service.nix` defines the collector as a home-manager
user service in `homeConfigurations."pl@casm"`. It runs only while `pl` has a
session (no linger). User units cannot order against the system
`agent-nats-leaf` unit; transient disconnections must be handled by the
collector, and the unit restarts on failure. No host collector is enabled.

## Package and configuration contract

The default package is
`inputs.cue-platform.packages.x86_64-linux.cue-github`. It must provide
`bin/cue-github`, including its Node runtime and JavaScript dependencies.
The service adds `gh` to PATH.
It invokes exactly:

```
cue-github --config /home/pl/.config/cue/github.toml
```

Nix generates this TOML schema:

```toml
repositories = ["spabreaks/spabreaks"]
poll_seconds = 120
nats_url = "nats://127.0.0.1:4222"
```

These three keys match the in-progress cue-platform parser inspected during
implementation. The collector must read but never rewrite the config and
stay in the foreground. State is selected with the explicit environment
`XDG_STATE_HOME=/home/pl/.local/state`; the collector appends
`cue/github/snapshots.sqlite`. The state root follows home-manager's `xdg.stateHome`; the
writable sandbox path is `cue/github` under it. Migrations, reconnect logic and collection behavior belong to the
package. No CLI flags beyond `--config` are assumed.

The package and executable are both named `cue-github`, matching the
standalone cue-platform output. Keep `poll_seconds` within 15-1800 to respect
the parser's default cooldown and maximum backoff.

The config is a home-manager `xdg.configFile` symlink to immutable store
content; changes trigger a service restart through `X-Restart-Triggers`. An
activation step creates the state directories with mode 0700, and the service uses umask 0077. Its sandbox makes the home directory
read-only except the collector state directory. Nix is the sole config owner.
Do not put real credentials in the module or generated TOML.

## Network and credentials

The VM explicitly passes the existing upper/lowercase proxy and no-proxy
variables, Node CA configuration, and the system CA bundle to this service.
It selects the spabreaks placeholder credential through `GH_TOKEN`, rather
than inheriting the generic GitHub placeholder from the login environment.
The host egress proxy performs credential substitution. Unrelated model/API
credentials are not inherited. No live GitHub access is part of the check.

The host NATS hub explicitly exports from AGENT and imports into HOST:

- `github.api.v1.*` as a singleton request/reply **service**, allowing replies
  back to the HOST requester's inbox.
- `github.evt.v1.*` as a pub/sub **stream** export for advisory notifications.
  This is not a JetStream storage stream and adds no persisted event log.

GitHub traffic is not nested under `agent.>`; neither future API versions nor
additional subject segments are exported. VM-local clients use the same leaf
account directly. Existing leaf credentials and host network guards remain
unchanged.

## Validation and deployment boundary

Run from this worktree:

```
nix develop --command nix build .#checks.x86_64-linux.github-service --no-link
```

The check evaluates the real home-manager unit and generated TOML, without
executing the collector. It tests the rendered user unit, the absence of a
system unit in the VM and on the host, private state configuration, explicit
environment, and real NATS account
request/reply and event routing with out-of-scope subjects rejected.
It does not execute a collector or claim the pinned input exports it.

The enabled VM deliberately references the real package without a fallback.
Until a separately authorized input update makes that package available,
normal VM toplevel evaluation may fail at the missing package attribute.
No flake input changes or deployment are included here. Once package/config
alignment and input availability are confirmed, the operator must build and
activate the VM, then verify startup, private SQLite creation, proxy/CA GitHub
access, 120-second polling and HOST-to-VM snapshot/refresh round trips through
the actual leaf connection.
