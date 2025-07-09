#!/usr/bin/env zsh

save_pr_info() {
    local DEST_FILE=.git/pr-info

    pr_info=$(gh pr view --json number,baseRefName 2>/dev/null)

    if [ -n "$pr_info" ] && [ "$pr_info" != "null" ]; then
        GH_PR_NUMBER=$(echo "$pr_info" | jq -r '.number')
        GIT_BASE=$(echo "$pr_info" | jq -r '.baseRefName')

        echo "GH_PR_NUMBER=$GH_PR_NUMBER" > $DEST_FILE
        echo "GIT_BASE=$GIT_BASE" >> $DEST_FILE

        echo "✓ Updated PR info: #$GH_PR_NUMBER (base: $GIT_BASE)"
    else
        rm -f .git/pr-info
        echo "✓ Cleared PR info (not on a PR branch)"
    fi
}
