# ============================================================================
# Context Detection Functions
# ============================================================================

# Check if in git repository
def is-git-repo [] {
    (do -i { git rev-parse --git-dir } | complete | get exit_code) == 0
}

# Get JIRA project namespace (e.g., "SB")
def get-project-namespace [] {
    if ($env.JIRA_PROJECT? != null) {
        $env.JIRA_PROJECT
    } else {
        error make {
            msg: "JIRA_PROJECT environment variable not set"
            help: "Load .envrc with direnv or set JIRA_PROJECT manually"
        }
    }
}

# Get issue number from branch name using existing spabreaks script
def get-issue-number [] {
    if not (is-git-repo) {
        error make {
            msg: "Not in a git repository"
            help: "Use --issue <number> or --project <namespace>.<issue> to specify manually"
        }
    }

    try {
        # Reuse existing spabreaks_jira_ticket_from_branch
        # It returns format "SB-1234", we need to extract "1234"
        let ticket = (spabreaks_jira_ticket_from_branch)
        let parts = ($ticket | parse "{prefix}-{issue}")
        if ($parts | length) > 0 {
            $parts.0.issue
        } else {
            error make {
                msg: $"Could not extract issue number from ticket: ($ticket)"
            }
        }
    } catch {
        let branch = (git branch --show-current)
        error make {
            msg: $"No issue number found in branch name '($branch)'"
            help: "Use --issue <number> to specify manually, or ensure branch follows pattern: sb-1234-name or 1234-name"
        }
    }
}

# Get repository name
def get-repo-name [] {
    if not (is-git-repo) {
        error make {
            msg: "Not in a git repository"
            help: "Repository name cannot be auto-detected outside git repositories"
        }
    }

    git rev-parse --show-toplevel | path basename
}

# Get current branch name
def get-branch-name [] {
    if not (is-git-repo) {
        error make {
            msg: "Not in a git repository"
            help: "Branch name cannot be auto-detected outside git repositories"
        }
    }

    git branch --show-current
}

# Get PR number from .git/GH_PR_NUMBER or gh CLI
def get-pr-number [] {
    # Try .git/GH_PR_NUMBER first (set by git hooks)
    if (".git/GH_PR_NUMBER" | path exists) {
        open .git/GH_PR_NUMBER | str trim
    } else {
        # Fallback to gh CLI
        try {
            let pr_info = (gh pr view --json number | from json)
            $pr_info.number | into string
        } catch {
            null
        }
    }
}

# ============================================================================
# URL Construction Functions
# ============================================================================

# Construct JIRA URL
def build-jira-url [namespace: string, issue: string] {
    if ($env.JIRA_URL? == null) {
        error make {
            msg: "JIRA_URL environment variable not set"
            help: "Load .envrc with direnv or set JIRA_URL manually"
        }
    }
    $"($env.JIRA_URL)/browse/($namespace)-($issue)"
}

# Construct PR URL from PR number
def build-pr-url [pr_number: string] {
    let origin = (git remote get-url origin | str trim)

    # Parse GitHub URL (handles both SSH and HTTPS)
    let repo_path = ($origin
        | str replace 'git@github.com:' ''
        | str replace 'https://github.com/' ''
        | str replace '.git' '')

    $"https://github.com/($repo_path)/pull/($pr_number)"
}

# ============================================================================
# Taskwarrior Binary Helper
# ============================================================================

# Helper to invoke the correct taskwarrior binary
# Uses absolute path to avoid conflicts with go-task in devshells
def call-task [...args: string] {
    run-external ~/.nix-profile/bin/task ...$args
}

# Get task data by ID and extract UDAs
def get-task-data [task_id: string] {
    let task_json = (call-task $task_id "export" | from json)

    if ($task_json | is-empty) {
        error make {
            msg: $"Task ($task_id) not found"
        }
    }

    $task_json.0
}

# ============================================================================
# Context Detection (Main)
# ============================================================================

# Detect all context information
def detect-context [
    --issue: string         # Manual issue number override
    --project: string       # Manual project override (format: "sb.1234" or "sb:1234")
    --branch: string        # Manual branch override
] {
    # Project detection
    let proj = if ($project != null) {
        # Manual override: parse "sb.1234" or "sb:1234"
        let normalized = ($project | str replace ':' '.')
        let parts = ($normalized | split row '.')

        if ($parts | length) != 2 {
            error make {
                msg: $"Invalid project format: ($project)"
                help: "Use format: namespace.issue (e.g., sb.1234) or namespace:issue (e.g., sb:1234)"
            }
        }

        {
            namespace: $parts.0,
            issue: $parts.1,
            project_path: $normalized
        }
    } else {
        # Auto-detect
        let namespace = (get-project-namespace)
        let issue_num = if ($issue != null) {
            $issue
        } else {
            (get-issue-number)
        }
        {
            namespace: $namespace,
            issue: $issue_num,
            project_path: $"($namespace).($issue_num)"
        }
    }

    # Repo detection
    let repo = (get-repo-name)

    # Branch detection
    let branch = if ($branch != null) {
        $branch
    } else {
        (get-branch-name)
    }

    # JIRA URL
    let jira_url = (build-jira-url $proj.namespace $proj.issue)

    # PR detection (optional - don't fail if not found)
    let pr_info = try {
        let pr_num = (get-pr-number)
        if ($pr_num != null) {
            {
                number: $pr_num,
                url: (build-pr-url $pr_num)
            }
        } else {
            null
        }
    } catch {
        null
    }

    {
        project: $proj,
        repo: $repo,
        branch: $branch,
        jira_url: $jira_url,
        pr: $pr_info
    }
}

# ============================================================================
# Task Command Building
# ============================================================================

# Build task command arguments from context
def build-task-args [context: record, task_args: list] {
    mut args = []

    # Add project
    $args = ($args | append $"project:($context.project.project_path)")

    # Add JIRA ticket ID (e.g., SB-9570)
    $args = ($args | append $"jira:($context.project.namespace)-($context.project.issue)")

    # Add repo
    $args = ($args | append $"repo:($context.repo)")

    # Add branch
    $args = ($args | append $"branch:($context.branch)")

    # Add PR number if available
    if ($context.pr != null) {
        $args = ($args | append $"pr:($context.pr.number)")
    }

    # Add task description and other args passed through
    $args = ($args | append $task_args)

    $args
}

# ============================================================================
# Main Exported Commands
# ============================================================================

# Add a task with automatic context detection
#
# Automatically detects JIRA ticket, repository, branch, and PR info
# from the current git context and adds them as UDAs to the task.
export def "add" [
    ...task_args: string        # Task description and additional taskwarrior arguments
    --issue (-i): string        # Manual issue number override
    --project (-p): string      # Manual project override (format: "sb.1234" or "sb:1234")
    --branch (-b): string       # Manual branch override
    --dry-run (-d)              # Show command without executing
    --verbose (-v)              # Show detected context
] {
    # Detect context
    let context = (detect-context --issue $issue --project $project --branch $branch)

    if $verbose {
        print $"(ansi green_bold)Detected context:(ansi reset)"
        print $"  Project: (ansi cyan)($context.project.project_path)(ansi reset)"
        print $"  JIRA URL: (ansi blue)($context.jira_url)(ansi reset)"
        print $"  Repository: (ansi yellow)($context.repo)(ansi reset)"
        print $"  Branch: (ansi yellow)($context.branch)(ansi reset)"
        if ($context.pr != null) {
            print $"  PR: (ansi magenta)#($context.pr.number)(ansi reset) - ($context.pr.url)"
        }
        print ""
    }

    # Build task arguments
    let task_cmd_args = (build-task-args $context $task_args)

    if $dry_run {
        print $"(ansi yellow_bold)Would execute:(ansi reset)"
        print $"  task add ($task_cmd_args | str join ' ')"
    } else {
        if $verbose {
            print $"(ansi blue_bold)Executing:(ansi reset) task add ($task_cmd_args | str join ' ')"
            print ""
        }
        call-task "add" ...$task_cmd_args
    }
}

# List tasks with smart filtering
#
# Shows tasks for the current context by default.
# Use --all to see all tasks, --issue <number> to filter by specific issue,
# --project to filter by project namespace, or --repo to filter by repository.
# Flags can be combined.
export def "list" [
    ...args: string             # Additional taskwarrior filter arguments
    --all (-a)                  # Show all tasks (no filtering)
    --issue (-i): string        # Show tasks for specific issue number (e.g., "1234")
    --project (-p)              # Show tasks for current project namespace
    --repo (-r)                 # Show tasks for current repository
] {
    if $all {
        # Pass through to task with list report (clean view without URLs)
        call-task "list" ...$args
    } else if $issue != null {
        # Show tasks for specific issue number
        let namespace = (get-project-namespace)
        let project_path = $"($namespace).($issue)"
        call-task "list" $"project:($project_path)" ...$args
    } else {
        # Build filter arguments based on flags
        mut filters = []
        
        if $project {
            # Add project namespace filter
            let namespace = (get-project-namespace)
            $filters = ($filters | append $"project:($namespace)")
        }
        
        if $repo {
            # Add repo filter
            let repo_name = (get-repo-name)
            $filters = ($filters | append $"repo:($repo_name)")
        }
        
        if ($filters | is-empty) {
            # Default: try to detect issue from context
            try {
                let context = (detect-context)
                $filters = ($filters | append $"project:($context.project.project_path)")
            } catch {
                print "no issue, use --project flag to see all tasks in current project"
                return
            }
        }
        
        call-task "list" ...$filters ...$args
    }
}

# Pass through to taskwarrior for advanced usage
#
# Directly invoke taskwarrior with any command without context detection.
# Useful for advanced taskwarrior operations not covered by wrapper commands.
export def "raw" [...args: string] {
    call-task ...$args
}

# Mark task as done
export def "done" [...args: string] {
    call-task "done" ...$args
}

# Start a task (mark as active)
export def "start" [...args: string] {
    call-task "start" ...$args
}

# Stop a task (mark as inactive)
export def "stop" [...args: string] {
    call-task "stop" ...$args
}

# Delete a task
export def "delete" [...args: string] {
    call-task "delete" ...$args
}

# Modify a task's attributes
export def "modify" [...args: string] {
    call-task "modify" ...$args
}

# Checkout PR associated with a task
#
# Uses the GitHub CLI to checkout the pull request referenced by the task's PR UDA.
# Validates that you're in the correct repository before checking out.
export def "checkout" [
    task_id: string             # Task ID to checkout PR for
    --verbose (-v)              # Show validation steps
] {
    # Get task data
    let task = (get-task-data $task_id)

    # Extract repo UDA
    let task_repo = try {
        $task.repo
    } catch {
        null
    }

    if ($task_repo == null) {
        error make {
            msg: $"Task ($task_id) does not have a repo UDA"
            help: "This task may not have been created with 'tw add'"
        }
    }

    # Extract PR UDA
    let task_pr = try {
        $task.pr
    } catch {
        null
    }

    if ($task_pr == null) {
        error make {
            msg: $"Task ($task_id) does not have a PR associated with it"
            help: "Make sure the task has a PR before trying to check it out"
        }
    }

    # Verify we're in correct repository
    let current_repo = (get-repo-name)

    if $verbose {
        print $"(ansi blue)Validating repository...(ansi reset)"
        print $"  Current: (ansi yellow)($current_repo)(ansi reset)"
        print $"  Expected: (ansi yellow)($task_repo)(ansi reset)"
    }

    if $current_repo != $task_repo {
        error make {
            msg: $"Repository mismatch! Current: ($current_repo), Expected: ($task_repo)"
            help: $"Please switch to the '($task_repo)' repository before checking out this PR"
        }
    }

    if $verbose {
        print $"(ansi green)✓ Repository matches!(ansi reset)"
        print $"(ansi blue)Checking out PR #($task_pr)...(ansi reset)"
    }

    # Checkout the PR using gh CLI
    gh pr checkout $task_pr
}

# Default command - show help or list tasks
#
# Without arguments, lists tasks. Passes through to taskwarrior for
# any other commands not handled by the wrapper.
export def main [
    ...args: string  # Taskwarrior commands or filters
] {
    if ($args | is-empty) {
        # Default to list when called without args
        do { list }
    } else {
        # Pass through to task if called with args
        call-task ...$args
    }
}
