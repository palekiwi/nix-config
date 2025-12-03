const AGENTS_DIR = ".agents"

export def main [] {
    "Agents module for managing content and files"
}

export def store [filename: string] {
    # Save input content to .agents directory structure
    # Usage: some-command | agents store <filename>
    
    let content = $in
    
    # Get current git branch and commit
    let branch = (do { git branch --show-current } | complete)
    if $branch.exit_code != 0 {
        error make { msg: "Not in a git repository" }
    }
    let branch_name = $branch.stdout | str trim
    
    let commit = (do { git rev-parse HEAD } | complete)
    if $commit.exit_code != 0 {
        error make { msg: "Cannot get current commit" }
    }
    let commit_hash = $commit.stdout | str trim | str substring 0..7
    
    # Create directory structure
    let base_dir = $"($AGENTS_DIR)/($branch_name)"
    let commit_dir = $"($base_dir)/($commit_hash)"
    let latest_dir = $"($base_dir)/latest"
    
    # Ensure directories exist
    mkdir $commit_dir
    mkdir $latest_dir
    
    # Save content to commit-specific location
    let commit_file = $"($commit_dir)/($filename)"
    $content | save $commit_file
    
    # Create symlink in latest directory
    let latest_file = $"($latest_dir)/($filename)"
    
    # Remove existing symlink if it exists
    if ($latest_file | path exists) {
        rm $latest_file
    }
    
    # Create relative symlink
    ln -s $"../($commit_hash)/($filename)" $latest_file
    
    print $"Content saved to: ($commit_file)"
    print $"Symlink created at: ($latest_file)"
    
    $commit_file
}
