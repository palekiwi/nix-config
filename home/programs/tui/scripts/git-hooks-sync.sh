#!/usr/bin/env bash
# Sync nix-config git template hooks into existing repositories.
#
# git init copies template entries verbatim. Repositories created while the
# templates were home.file symlinks carry .git/hooks symlinks instead of
# real files - dangling after store GC and never resolving inside cast
# containers. This script installs the template hooks as real files; re-run
# it after any template hook edit to refresh managed copies.
#
# A hook is replaced only when it is a symlink or carries the managed
# marker; hooks owned by other tooling are never touched.
#
# Usage: git-hooks-sync [root...]    (default: ~/code ~/nix-config)

set -euo pipefail

templates="${HOME}/nix-config/home/config/git/templates/hooks"
marker="# nix-config managed"
hooks=(post-checkout post-merge)

roots=("$@")
[ ${#roots[@]} -gt 0 ] || roots=("$HOME/code" "$HOME/nix-config")

changed=0
skipped=0
readonly_skipped=0

sync_repo() {
    local gitdir=$1
    local repo did hook
    repo=$(dirname "$gitdir")
    did=0

    if ! mkdir -p "$gitdir/hooks" 2>/dev/null || [ ! -w "$gitdir/hooks" ]; then
        echo "skip (read-only): $repo"
        readonly_skipped=$((readonly_skipped + 1))
        return 0
    fi

    for hook in "${hooks[@]}"; do
        local src="$templates/$hook" dst="$gitdir/hooks/$hook"
        [ -f "$src" ] || continue
        mkdir -p "$gitdir/hooks"

        if [ -L "$dst" ] || [ ! -e "$dst" ]; then
            install -m 755 "$src" "$dst"
            did=1
        elif [ -f "$dst" ] && grep -qF "$marker" "$dst"; then
            if ! cmp -s "$src" "$dst"; then
                install -m 755 "$src" "$dst"
                did=1
            fi
        else
            skipped=$((skipped + 1))
        fi
    done

    if [ $did -eq 1 ]; then
        echo "synced: $repo"
        changed=$((changed + 1))
    fi
    return 0
}

for root in "${roots[@]}"; do
    [ -d "$root" ] || continue
    while IFS= read -r -d '' gitdir; do
        sync_repo "$gitdir"
    done < <(find "$root" -type d -name .git -prune -print0)
done

echo "repos changed: $changed, foreign hooks skipped: $skipped, read-only repos skipped: $readonly_skipped"
