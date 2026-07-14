---
status: open
priority: normal
---
Let tmux show what the active cue scope is.
The active scope can be present in `.cue/HEAD`

cases:
- `.cue/` is absent: do not show anything
- `.cue/HEAD` is absent: print `master`
