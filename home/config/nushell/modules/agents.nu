const AGENTS_DIR = ".agents"

export def main [] {
    "Agents module for managing content and files"
}

# Helper function to get git information
def get-git-info [] {
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

    {
        branch_name: $branch_name,
        commit_hash: $commit_hash
    }
}

# Helper function to ensure directories exist
def ensure-directories [branch_name: string, commit_hash: string] {
    let base_dir = $"($AGENTS_DIR)/($branch_name)"
    let commit_dir = $"($base_dir)/($commit_hash)"
    let latest_dir = $"($base_dir)/latest"

    # Ensure directories exist
    mkdir $commit_dir
    mkdir $latest_dir

    {
        base_dir: $base_dir,
        commit_dir: $commit_dir,
        latest_dir: $latest_dir
    }
}

# Helper function to save file and create symlink
def save-file-and-create-symlink [
    content: string,
    filename: string,
    commit_dir: string,
    latest_dir: string,
    commit_hash: string,
    force: bool
] {
    # Save content to commit-specific location
    let commit_file = $"($commit_dir)/($filename)"

    # Check if file exists and force is not set
    if ($commit_file | path exists) and (not $force) {
        error make { msg: $"File ($filename) already exists. Use --force (-f) to overwrite." }
    }

    # Save with force flag if needed
    if $force {
        $content | save -f $commit_file
    } else {
        $content | save $commit_file
    }

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

# Helper function to handle clone content
def handle-clone-content [filename: string, branch_name: string] {
    let latest_file = $"($AGENTS_DIR)/($branch_name)/latest/($filename)"
    if not ($latest_file | path exists) {
        error make { msg: $"File ($filename) does not exist in latest" }
    }

    # Read content from latest file
    open $latest_file
}

# Helper function to handle clipboard content
def handle-clipboard-content [] {
    # TODO: Check if xclip is available
    let clipboard_content = (do { xclip -selection clipboard -o } | complete)
    if $clipboard_content.exit_code != 0 {
        error make { msg: "Failed to read clipboard content" }
    }

    # Check if clipboard is empty
    if ($clipboard_content.stdout | str trim | is-empty) {
        error make { msg: "Clipboard is empty" }
    }

    $clipboard_content.stdout
}

export def add [
    filename: string,
    --clipboard(-C),
    --empty(-e),
    --clone(-c),
    --force(-f),
    --open(-o)
] {
    # Save input content to .agents directory structure
    # Usage: some-command | agents add <filename>
    #        agents add <filename> --clipboard (-C)
    #        agents add <filename> --empty (-e)
    #        agents add <filename> --clone (-c)
    #        agents add <filename> --force (-f)  # Force overwrite existing files
    #        agents add <filename> --open (-o)   # Create file and open in editor

    # Capture pipeline input immediately before any conditional logic
    let piped_input = $in

    # Validate flag combinations and input
    if ($empty and ($clipboard or not ($piped_input | is-empty))) or ($clone and ($empty or $clipboard or not ($piped_input | is-empty))) {
        error make { msg: "Invalid flag combination" }
    }

    # Check if we have content when no flags are provided
    if (not $empty) and (not $clone) and (not $clipboard) and (not $open) and ($piped_input | is-empty) {
        error make {
            msg: "No input provided. Use: --empty, --clipboard, --clone, --open, or pipe content"
        }
    }

    # Get git info once
    let git_info = get-git-info

    # Determine content based on flags
    let content = if $empty {
        ""
    } else if $clone {
        handle-clone-content $filename $git_info.branch_name
    } else if $clipboard {
        handle-clipboard-content
    } else if $open {
        ""
    } else {
        $piped_input
    }

    # Ensure directories exist
    let dirs = (ensure-directories $git_info.branch_name $git_info.commit_hash)

    # Save file and create symlink
    let saved_file = (save-file-and-create-symlink $content $filename $dirs.commit_dir $dirs.latest_dir $git_info.commit_hash $force)

    # Open in editor if --open flag is used
    if $open {
        # Get the editor from environment, default to nvim
        let editor = ($env.EDITOR? | default "nvim")
        ^$editor $saved_file
    }
}
