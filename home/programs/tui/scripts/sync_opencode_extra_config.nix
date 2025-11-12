{ pkgs, ... }:

pkgs.writers.writeNuBin "sync_opencode_extra_config" ''
  def main [config_dir: string, --sync-agents] {
    let subdir = ".opencode"

    # Sync .opencode directory
    if ($config_dir | path join $subdir | path exists) {
      print $"Syncing opencode extra config from ($config_dir)/($subdir)..."
      mkdir .opencode
      ^rsync -av --delete $"($config_dir)/($subdir)/" ".opencode/"
    } else {
      print $"Warning: Config directory '($config_dir)/($subdir)' does not exist"
    }

    # Sync opencode.json
    if ($config_dir | path join "opencode.json" | path exists) {
      print "Syncing opencode.json from ($config_dir)/opencode.json..."
      ^cp $"($config_dir)/opencode.json" "./"
    }

    # Sync AGENTS.md files if flag is set
    if $sync_agents {
      print "Syncing AGENTS.md files from ($config_dir)..."
      let agent_files = (${pkgs.fd}/bin/fd "AGENTS.md" $config_dir -t f | lines)

      for agent_file in $agent_files {
        let relative_path = ($agent_file | path relative-to $config_dir)
        let target_dir = ($relative_path | path dirname)

        if ($target_dir != "." and ($target_dir | path exists)) {
          print $"Copying ($agent_file) to ($relative_path)" # TODO: this is broken
          ^cp $agent_file $relative_path
        } else if ($target_dir == ".") {
          print $"Copying ($agent_file) to AGENTS.md"
          ^cp $agent_file "AGENTS.md"
        } else {
          print $"Skipping ($agent_file) - target directory ($target_dir) does not exist"
        }
      }
    }
  }
''
