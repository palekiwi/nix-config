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
# Context Detection (Main)
# ============================================================================

# Detect all context information
def detect-context [
    --issue: string         # Manual issue number override
    --project: string       # Manual project override (format: "sb.1234" or "sb:1234")
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

    # Add JIRA URL
    $args = ($args | append $"jira_url:($context.jira_url)")

    # Add repo
    $args = ($args | append $"repo:($context.repo)")

    # Add PR info if available
    if ($context.pr != null) {
        $args = ($args | append $"pr:($context.pr.number)")
        $args = ($args | append $"pr_url:($context.pr.url)")
    }

    # Add task description and other args passed through
    $args = ($args | append $task_args)

    $args
}

# ============================================================================
# Main Exported Commands
# ============================================================================

# Add a task with automatic context detection
export def "add" [
    ...task_args: string        # Task description and additional taskwarrior arguments
    --issue (-i): string        # Manual issue number override
    --project (-p): string      # Manual project override (format: "sb.1234" or "sb:1234")
    --dry-run (-d)              # Show command without executing
    --verbose (-v)              # Show detected context
] {
    # Detect context
    let context = (detect-context --issue $issue --project $project)

    if $verbose {
        print $"(ansi green_bold)Detected context:(ansi reset)"
        print $"  Project: (ansi cyan)($context.project.project_path)(ansi reset)"
        print $"  JIRA URL: (ansi blue)($context.jira_url)(ansi reset)"
        print $"  Repository: (ansi yellow)($context.repo)(ansi reset)"
        if ($context.pr != null) {
            print $"  PR: (ansi magenta)#($context.pr.number)(ansi reset) - ($context.pr.url)"
        }
        print ""
    }

    # Build task arguments
    let task_cmd_args = (build-task-args $context $task_args)

    if $dry_run {
        print $"(ansi yellow_bold)Would execute:(ansi reset)"
        print $"  task add (ansi dim)($task_cmd_args | str join ' ')(ansi reset)"
    } else {
        if $verbose {
            print $"(ansi blue_bold)Executing:(ansi reset) task add ($task_cmd_args | str join ' ')"
            print ""
        }
        run-external "task" "add" ...$task_cmd_args
    }
}

# List tasks with smart filtering
export def "list" [
    ...args: string             # Additional taskwarrior filter arguments
    --all (-a)                  # Show all tasks (no filtering)
    --project (-p)              # Show all tasks in project namespace
    --repo (-r)                 # Show tasks for current repo
] {
    if $all {
        # Pass through to task
        run-external "task" ...$args
    } else if $project {
        # Show all tasks in namespace (e.g., project:sb)
        let namespace = (get-project-namespace)
        run-external "task" $"project:($namespace)" ...$args
    } else if $repo {
        # Show tasks for current repo
        let repo = (get-repo-name)
        run-external "task" $"repo:($repo)" ...$args
    } else {
        # Default: show tasks for current issue
        let context = (detect-context)
        run-external "task" $"project:($context.project.project_path)" ...$args
    }
}

# Pass through to taskwarrior for advanced usage
export def "raw" [...args: string] {
    run-external "task" ...$args
}

# Convenience exports for common operations (pass through to task)
export def "done" [...args: string] {
    run-external "task" "done" ...$args
}

export def "start" [...args: string] {
    run-external "task" "start" ...$args
}

export def "stop" [...args: string] {
    run-external "task" "stop" ...$args
}

export def "delete" [...args: string] {
    run-external "task" "delete" ...$args
}

export def "modify" [...args: string] {
    run-external "task" "modify" ...$args
}

# Default command - show help or list tasks
export def main [...args: string] {
    if ($args | is-empty) {
        print $"(ansi cyan_bold)Taskwarrior Context-Aware Wrapper(ansi reset)\n"
        print "Available commands:"
        print $"  (ansi green)tw add(ansi reset) <description>       - Add task with auto-detected context"
        print $"  (ansi green)tw list(ansi reset)                   - List tasks for current issue"
        print $"  (ansi green)tw done(ansi reset) <id>              - Mark task as done"
        print $"  (ansi green)tw start(ansi reset) <id>             - Start task"
        print $"  (ansi green)tw stop(ansi reset) <id>              - Stop task"
        print $"  (ansi green)tw modify(ansi reset) <id> <mods>     - Modify task"
        print $"  (ansi green)tw raw(ansi reset) <command>          - Pass through to task"
        print ""
        print "Flags:"
        print "  --verbose, -v            - Show detected context"
        print "  --dry-run, -d            - Preview without executing"
        print "  --issue, -i <num>        - Manual issue override"
        print "  --project, -p <proj>     - Manual project override (e.g., sb.1234)"
        print ""
        print $"For more info: (ansi blue)tw add --help(ansi reset)"
    } else {
        # Pass through to task if called with args
        run-external "task" ...$args
    }
}
