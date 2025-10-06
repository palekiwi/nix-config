{ pkgs, ... }:

pkgs.writeShellScriptBin "opencode-run" ''
  # Project type detection logic
  if [ -f "Cargo.toml" ]; then
    OPENCODE_BIN="${pkgs.opencode-rust}/bin/opencode-rust"
  elif [ -f "Gemfile" ] || [ -f ".ruby-version" ]; then
    OPENCODE_BIN="${pkgs.opencode-ruby}/bin/opencode-ruby"
  else
    OPENCODE_BIN="${pkgs.opencode}/bin/opencode"
  fi

  # Execute with standard server flags
  exec "$OPENCODE_BIN" --hostname 0.0.0.0 --port 80 "$@"
''
