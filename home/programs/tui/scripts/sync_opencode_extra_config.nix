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

    # Sync AGENTS.md file if flag is set
    if $sync_agents {
      let agents_file = ($config_dir | path join "AGENTS.md")
      if ($agents_file | path exists) {
        print $"Copying ($agents_file) to AGENTS.md"
        ^cp $agents_file "AGENTS.md"
      }
    }
  }
''
