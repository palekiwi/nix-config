# Agent workflow: nix-config

## Branches and integration

- `master` is the stable line.
- `feat/agent-microvm` is the designated long-lived host/VM integration
  branch. The operator rebuilds the host and agent VM from this branch.
- Before creating a worktree, run `git worktree list` to check existing
  checkouts. Do feature work in `./worktrees/<branch>`, relative to the
  repository root. Normally branch from `feat/agent-microvm` in this repo.
- Integrate ready changes by merge. Never rebase or force-push the
  integration branch. Branch changes, integration and deployment require
  authorization; this policy does not itself authorize those actions.
- Validate the relevant configuration and tests before integration. Use
  the repository devshell (`nix develop`) for project tools; evaluate/build
  the affected NixOS or Home Manager configuration as appropriate. Keep
  documentation-only validation scoped to documentation.
- Inspect status and diffs before editing or committing. Preserve unrelated
  changes and stage only the intended files.
- Do not repoint flake inputs to temporary feature branches without the
  operator's approval.

## Host and guest handoff

- Host and guest checkouts are independent, not shared. Never assume their
  branch tips or working trees match.
- The guest never pushes. Commit locally and report the branch and commit;
  the operator runs `git fetch vm` on the host, whose `vm` remote points
  at the guest checkout.
- Before advancing a host branch, check its working tree and compare its
  history with the fetched guest branch for divergence and host-only
  commits. Fast-forward only when ancestry permits; otherwise stop and
  agree on reconciliation with the operator. Never reset away host work.
- Never retire or delete a branch/worktree without explicit approval and
  checking for unique commits on both host and guest. Guest-only evidence
  cannot establish that a host branch is safe to retire.
