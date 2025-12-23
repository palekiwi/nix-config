use agents.nu

export def main [pr: int] {
    # TODO: Create a way to automate PR reviews given a PR number on a separate copy of the repo.
    # For simpilicity assume we know where the repo is already checked out.
    # Required steps:
    # - read the PR number
    # - find out the base branch
    # - make sure the base branch is present locally and up to date
    # - checkout the PR branch
    # - run a dummy review command (to be replaced later)
    #
    # Considerations:
    # We may want to run reviews on multiple branches in parallel. What would be the checkout strategy?
    # Assume the repo may be rather large and takes too much time to fully clone from upstream every time.
    # Should we use git worktrees? What about making sure the branches are always up to date?

    let pr_info = (do { gh pr view $pr --json number,baseRefName,headRefName,title } | complete)

    if $pr_info.exit_code != 0 {
        print $"Error: Could not find PR: ($pr)"
        exit 1
    }

    let pr_data = $pr_info.stdout | from json
    let base_ref_name = $pr_data.baseRefName
    let head_ref_name = $pr_data.headRefName

    git fetch origin $base_ref_name
    git branch -f $base_ref_name origin/($base_ref_name)

    gh pr checkout $pr

    git diff $"($base_ref_name)...HEAD" | agents add -f diff.patch

    opencode run --command sb:deep-review
}
