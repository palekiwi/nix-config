#!/usr/bin/env zsh

DEST_FILE=.git/pr-info
ORANGE='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'

pr_info=$(gh pr view --json number,baseRefName 2>/dev/null)

if [ -n "$pr_info" ] && [ "$pr_info" != "null" ]; then
    GH_PR_NUMBER=$(echo "$pr_info" | jq -r '.number')
    GIT_BASE=$(echo "$pr_info" | jq -r '.baseRefName')

    echo "GH_PR_NUMBER=$GH_PR_NUMBER" > $DEST_FILE
    echo "GIT_BASE=$GIT_BASE" >> $DEST_FILE

    # Check if base branch has new commits
    git fetch origin $GIT_BASE --quiet

    # Get the merge base (common ancestor)
    merge_base=$(git merge-base HEAD origin/$GIT_BASE)

    # Check if origin/base is ahead of the merge base
    if [ "$(git rev-parse origin/$GIT_BASE)" != "$merge_base" ]; then
        echo "GIT_BASE_AHEAD=true" >> $DEST_FILE
        echo -e "${ORANGE}Base branch '$GIT_BASE' has new commits${RESET}"
    fi

    echo "${GREEN}Updated PR info: #$GH_PR_NUMBER (base: $GIT_BASE)${RESET}"
else
    rm -f .git/pr-info
    echo "${GREEN}Cleared PR info (not on a PR branch)${RESET}"
fi
