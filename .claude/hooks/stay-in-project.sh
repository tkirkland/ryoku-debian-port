#!/usr/bin/env bash
# PreToolUse guard: this project never edits anything outside itself.
#
# Other repos are REFERENCE: read them, cite them, copy the parts this
# project needs into this project. Never change them from here.
#
# Edit/Write/NotebookEdit: the target path must resolve under the project
# root or Claude's scratchpad. Bash: a command that names another repo under
# ~/src AND carries a write-shaped token is refused. Read-only looks at other
# repos (grep, cat, git log, diff ...) stay allowed.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Edit|Write|NotebookEdit)
    f="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
    [[ -z "$f" ]] && exit 0
    # realpath -m: resolve symlinks, tolerate a not-yet-existing file
    rp="$(realpath -m -- "$f")"
    case "$rp" in
      "$root"/*|/tmp/claude-*) exit 0 ;;
    esac
    deny "stay-in-project: $f is outside $root. Other repos are reference only: read them and copy what this project needs INTO this project. Never edit them from here."
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
    # Any ~/src/<repo> path that is not this project.
    others="$(grep -oE '(/home/me|~)/src/[A-Za-z0-9._-]+' <<<"$cmd" | sed -E 's#^~#/home/me#' | sort -u | grep -vxF "$root" || true)"
    [[ -z "$others" ]] && exit 0
    if grep -qE '(^|[;&|(] *)(git +(-C +\S+ +)?(add|am|apply|branch|checkout|cherry-pick|clean|commit|merge|mv|pull|push|rebase|reset|restore|revert|rm|stash|switch|tag|worktree)|cp|mv|rm|rmdir|mkdir|touch|ln|chmod|chown|tee|truncate|install|dd|rsync|patch|sed +-i|perl +-[a-z]*i|npx|prettier|make|dpkg|apt(-get)?)\b|>>?[^&]' <<<"$cmd"; then
      deny "stay-in-project: command touches another repo ($(tr '\n' ' ' <<<"$others")) with a write-shaped operation. Other repos are reference only: read them and copy what this project needs INTO this project. Never change them from here."
    fi
    ;;
esac
exit 0
