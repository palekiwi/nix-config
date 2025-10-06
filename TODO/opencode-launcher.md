---
priority: medium
status: done
---

Create a wrapper script that launches opencode, something like `opencode-run`.

The script does the following:
- sets flags: `--hostname 0.0.0.0 --port 80`
- determines which wrapped opencode executable to run depending on the type of the project:
  * opencode-rust
  * opencode-ruby
  * opencode
