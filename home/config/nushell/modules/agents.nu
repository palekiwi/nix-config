const AGENTS_DIR = ".agents"

export def main [] {
    "Agents module for managing content and files"
}

export def add [filename: string, --clipboard(-c), --empty(-e)] {
    # Save input content to .agents directory structure
    # Usage: some-command | agents add <filename>
    #        agents add <filename> --clipboard (-c)
    #        agents add <filename> --empty (-e)

    # Validate flag combinations
    if $empty and ($clipboard or not ($in | is-empty)) {
        error make { msg: "Cannot use --empty flag with piped input or --clipboard" }
    }

    let content = if $empty {
        ""
    } else if $clipboard {
        # TODO: Check if xclip is available

        # Read clipboard content
        let clipboard_content = (do { xclip -selection clipboard -o } | complete)
        if $clipboard_content.exit_code != 0 {
            error make { msg: "Failed to read clipboard content" }
        }

        # Check if clipboard is empty
        if ($clipboard_content.stdout | str trim | is-empty) {
            error make { msg: "Clipboard is empty" }
        }

        $clipboard_content.stdout
    } else {
        $in
    }

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
    let commit_hash = $commit.stdout | str trim | str substring 0..6

    # Create directory structure
    let base_dir = $"($AGENTS_DIR)/($branch_name)"
    let commit_dir = $"($base_dir)/($commit_hash)"
    let latest_dir = $"($base_dir)/latest"

    # Ensure directories exist
    mkdir $commit_dir
    mkdir $latest_dir

    # Save content to commit-specific location
    let commit_file = $"($commit_dir)/($filename)"
    $content | save -f $commit_file

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
