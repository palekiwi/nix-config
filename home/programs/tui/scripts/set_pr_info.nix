{ pkgs, ... }:

pkgs.writeShellScriptBin "set_pr_info" ''
  DEST_FILE=.git/pr-info

  pr_info=$(${pkgs.gh}/bin/gh pr view --json number,baseRefName 2>/dev/null)

  if [ -n "$pr_info" ] && [ "$pr_info" != "null" ]; then
    GH_PR_NUMBER=$(echo "$pr_info" | ${pkgs.jq}/bin/jq -r '.number')
    GIT_BASE=$(echo "$pr_info" | ${pkgs.jq}/bin/jq -r '.baseRefName')

    echo "GH_PR_NUMBER=$GH_PR_NUMBER" > "$DEST_FILE"
    echo "GIT_BASE=$GIT_BASE" >> "$DEST_FILE"

    # Check if base branch has new commits
    ${pkgs.git}/bin/git fetch origin "$GIT_BASE" --quiet

    # Get the merge base (common ancestor)
    merge_base=$(${pkgs.git}/bin/git merge-base HEAD origin/"$GIT_BASE")

    # Check if origin/base is ahead of the merge base
    if [ "$(${pkgs.git}/bin/git rev-parse origin/"$GIT_BASE")" != "$merge_base" ]; then
      echo "GIT_BASE_AHEAD=true" >> "$DEST_FILE"
       printf "\033[33mBase branch '%s' has new commits\033[0m\n" "$GIT_BASE"
    fi

     printf "\033[32mUpdated PR info: #%s (base: %s)\033[0m\n" "$GH_PR_NUMBER" "$GIT_BASE"
  else
    rm -f .git/pr-info
     printf "\033[32mCleared PR info (not on a PR branch)\033[0m\n"
  fi
''
