---
title: Add devShell to home/flake.nix
status: open
priority: normal
---
# Task: Add devShell to home/flake.nix

## Acceptance Criteria
| Criteria | Status |
| :--- | :--- |
| `devShells.x86_64-linux.default` is added to `home/flake.nix` | [ ] |
| The shell includes `luajit`, `lua-language-server`, `nixd`, and `nixfmt-rfc-style` | [ ] |
| `nix develop` successfully starts in `home/` | [ ] |

## Plan
1. Read `home/flake.nix` to confirm insertion point.
2. Update `home/flake.nix` with the `devShells` output.
3. Verify the shell by running `nix develop --command lua -v`.
4. Commit the change.
