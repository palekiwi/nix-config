#!/usr/bin/env bash
# Global git hook dispatcher for the agent VM (core.hooksPath).
#
# Installed under every client hook name. Runs the global actions for the
# hook, then chains to the repository's own hook in
# $(git rev-parse --git-common-dir)/hooks/<name> and exits with its status.
# Global actions never fail the git operation.

hook=$(basename "$0")
marker="# nix-config managed"

stdin_file=
case "$hook" in
    post-rewrite | pre-push)
        stdin_file=$(mktemp)
        cat >"$stdin_file"
        ;;
esac
cleanup() { [ -n "$stdin_file" ] && rm -f "$stdin_file"; }
trap cleanup EXIT

pr_sync() {
    command -v git-pr-sync >/dev/null 2>&1 && git-pr-sync
}

publish() {
    [ -n "${GIT_ACTIVITY_DISABLE:-}" ] && return 0

    local branch head rewrites=null commit=null
    branch=$(git symbolic-ref -q --short HEAD 2>/dev/null)
    head=$(git rev-parse -q --verify HEAD 2>/dev/null)

    if [ -n "$head" ]; then
        commit=$(git log -1 --format='%H%x00%P%x00%an%x00%ae%x00%at%x00%s' "$head" 2>/dev/null |
            jq -Rc 'split("\u0000") | {sha: .[0], parents: (.[1] | split(" ") | map(select(. != ""))),
                author: .[2], email: .[3], author_ts: (.[4] | tonumber? // null), subject: .[5]}')
        [ -n "$commit" ] || commit=null
    fi

    if [ "$hook" = post-rewrite ] && [ -n "$stdin_file" ]; then
        rewrites=$(jq -Rsc 'split("\n") | map(select(. != "") | split(" ") | {old: .[0], new: .[1]})' "$stdin_file")
    fi

    local id payload
    id=$(cat /proc/sys/kernel/random/uuid)
    payload=$(jq -nc \
        --arg id "$id" \
        --arg hook "$hook" \
        --argjson args "$(jq -nc '$ARGS.positional' --args -- "$@")" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" \
        --arg host "$(cat /proc/sys/kernel/hostname)" \
        --arg origin "$(git config --get remote.origin.url 2>/dev/null)" \
        --arg common_dir "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
        --arg worktree "$(git rev-parse --show-toplevel 2>/dev/null)" \
        --arg branch "$branch" \
        --arg head "$head" \
        --argjson commit "$commit" \
        --argjson rewrites "$rewrites" \
        --arg cue_context_branch "$([ -n "$branch" ] && git config --get "branch.$branch.cue-context" 2>/dev/null)" \
        --arg reflog_action "${GIT_REFLOG_ACTION:-}" \
        --arg pi_session "${PI_SESSION_ID:-}" \
        --arg pi_model "${PI_MODEL:-}" \
        --arg cue_context "${CUE_CONTEXT:-}" \
        --arg tmux_pane "${TMUX_PANE:-}" \
        'def nz: if . == "" then null else . end;
         {v: 1, id: $id, hook: $hook, args: $args, ts: $ts, host: $host,
          repo: {origin: ($origin | nz), common_dir: $common_dir},
          worktree: $worktree, branch: ($branch | nz), head: ($head | nz),
          commit: $commit, rewrites: $rewrites,
          reflog_action: ($reflog_action | nz),
          actor: {pi_session: ($pi_session | nz), pi_model: ($pi_model | nz),
                  cue_context: ($cue_context | nz),
                  cue_context_branch: ($cue_context_branch | nz),
                  tmux_pane: ($tmux_pane | nz)}}
         | del(..|nulls)')

    (
        timeout 3 nats --server "$GIT_ACTIVITY_NATS_URL" pub -H "Nats-Msg-Id:$id" \
            "git.evt.v1.$hook" "$payload"
    ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
    return 0
}

case "$hook" in
    post-commit) publish "$@" ;;
    post-checkout)
        [ "$3" = "1" ] && pr_sync
        publish "$@"
        ;;
    post-merge | post-rewrite)
        pr_sync
        publish "$@"
        ;;
esac

local_hook="$(git rev-parse --git-common-dir 2>/dev/null)/hooks/$hook"
if [ -f "$local_hook" ] && [ -x "$local_hook" ] && ! grep -qF "$marker" "$local_hook"; then
    if [ -n "$stdin_file" ]; then
        "$local_hook" "$@" <"$stdin_file"
    else
        "$local_hook" "$@"
    fi
    exit $?
fi

exit 0
