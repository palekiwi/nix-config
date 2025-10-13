{ pkgs, ... }:

# script: sb_pr_merge
# This script merges a PR with `gh` cli checking whether safe conditions for merge are met.
# If they are not, it aborts with a message.
# Conditions:
# - Does the PR create or modify any of the files matching `/db/views/es_*`, e.g. `/db/views/es_packages_v03.sql`
# - If it does, check whether the time is between *:10 and *:30
# - If the time window matches, abort with a message

pkgs.writeShellScriptBin "sb_pr_merge" ''
  set -euo pipefail

  echo "Checking current PR for Elasticsearch view changes..."

  PR_FILES=$(${pkgs.gh}/bin/gh pr view --json files --jq '.files[].path')

  if echo "$PR_FILES" | grep -q '^db/views/es_.*\.sql$'; then
    CURRENT_MINUTE=$(date +%M)

    if [ "$CURRENT_MINUTE" -ge 10 ] && [ "$CURRENT_MINUTE" -le 30 ]; then
      echo "Cannot merge this PR at this time!"
      echo "This PR modifies Elasticsearch views (db/views/es_*.sql)"
      echo "Current time: $(date +%H:%M)"
      echo "Elasticsearch indexing runs between *:10 and *:30"
      echo "Please merge outside this window to avoid conflicts."
      exit 1
    fi

    echo "⚠ Warning: PR modifies Elasticsearch views, but time window is safe"
  fi

  echo "✓ Safe to merge current PR"
  ${pkgs.gh}/bin/gh pr merge --merge
''
