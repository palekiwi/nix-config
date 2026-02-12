{ pkgs, ... }:

let
  orange = "\\033[33m";
  green = "\\033[32m";
  reset = "\\033[0m";
in
pkgs.writeShellScriptBin "set_pr_info" ''
  # TODO: rewrite in nushell
  DEST_DIR="."
  FILE_PR_NUMBER="$DEST_DIR/.gh_pr_number"
  FILE_GH_PR_BASE="$DEST_DIR/.gh_pr_base"
  FILE_GH_PR_BASE_AHEAD="$DEST_DIR/.gh_pr_base_ahead"

  pr_info=$(${pkgs.gh}/bin/gh pr view --json number,baseRefName 2>/dev/null)

  if [ -n "$pr_info" ] && [ "$pr_info" != "null" ]; then
    GH_PR_NUMBER=$(echo "$pr_info" | ${pkgs.jq}/bin/jq -r '.number')
    GH_PR_BASE=$(echo "$pr_info" | ${pkgs.jq}/bin/jq -r '.baseRefName')

    echo "$GH_PR_NUMBER" > "$FILE_PR_NUMBER"
    echo "$GH_PR_BASE" > "$FILE_GH_PR_BASE"

    # Check if base branch has new commits
    ${pkgs.git}/bin/git fetch origin "$GH_PR_BASE" --quiet

    # Get the merge base (common ancestor)
    merge_base=$(${pkgs.git}/bin/git merge-base HEAD origin/"$GH_PR_BASE")

    # Check if origin/base is ahead of the merge base
    if [ "$(${pkgs.git}/bin/git rev-parse origin/"$GH_PR_BASE")" != "$merge_base" ]; then
      echo "true" > "$FILE_GH_PR_BASE_AHEAD"
        echo -e "${orange}Base branch '$GH_PR_BASE' has new commits${reset}"
    else
      rm -f "$FILE_GH_PR_BASE_AHEAD"
    fi
      echo -e "${green}Updated PR info: #$GH_PR_NUMBER (base: $GH_PR_BASE)${reset}"
  else
    rm -f "$FILE_PR_NUMBER" "$FILE_GH_PR_BASE" "$FILE_GH_PR_BASE_AHEAD"
      echo -e "${green}Cleared PR info (not on a PR branch)${reset}"
  fi
''
