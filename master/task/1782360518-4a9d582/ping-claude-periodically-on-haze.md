---
status: complete
title: Ping claude periodically on haze
priority: normal
---

On my haze host (`/home/pl/nix-config/hosts/haze/default.nix`),
I want to set up a timer that executes a command starting
at a particular time in the morning (6am) and repeating after an
interval of 5hrs 5 minutes since the last occurence.

Specifications:

- user: `pl`
- command: `nix run github:palekiwi-labs/cast#cast -- run opencode run "hi" --model "anthropic/claude-haiku-4-5"`
- env:
  - `CAST_VOLUMES_NAMESPACE="cast"`
  - `CAST_AGENT_VERSIONS__OPENCODE="1.17.11"`
- directory: `/home/pl/code/test`
