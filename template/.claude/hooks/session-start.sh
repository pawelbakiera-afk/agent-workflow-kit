#!/usr/bin/env bash
#
# SessionStart tree probe (macOS / Linux) -- twin of session-start.ps1, same purpose and same
# contract: docs/AGENT-WORKFLOW.md. Guard (guard.sh) BLOCKS; this one only LOOKS: it fetches
# origin and reports the state of the working tree into the agent's context before the first
# edit of a session (a branch whose PR already got squash-merged, the protected branch held by
# a leftover worktree, a parallel session mid-edit with uncommitted files -- each costs a round
# of guessing if discovered late; this costs about a second at session start).
#
# It reports, it never blocks: SessionStart cannot deny anything, and any unexpected condition
# (no git, not a repo, a broken git call) means no output at all. A silent probe must never stop
# a session from starting.
#
# HOOK_SKIP_NETWORK=1 skips 'git fetch' and 'gh', which is how the test file gets a
# deterministic, offline run.
#
# Needs python3 to emit well-formed JSON (falls back to jq); with neither, it stays silent --
# same fail-open contract as guard.sh.
#
# After ANY edit run: bash .claude/hooks/session-start.tests.sh

# ============================ CONFIG -- set during install =====================
# Keep these two in sync with guard.sh -- same branch, same contract document.
MAIN_BRANCH='main'
CONTRACT_DOC='docs/AGENT-WORKFLOW.md'
# ==============================================================================

# The payload is not needed, but the pipe must be drained or the caller can block.
cat >/dev/null 2>&1

emit_json() {
  # $1 = context text (already newline-joined). Silent (no output) if neither parser exists --
  # consistent fail-open with the rest of the kit.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
ctx = sys.stdin.read()
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))
' <<<"$1"
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
  fi
}

command -v git >/dev/null 2>&1 || exit 0

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
[ -n "$here" ] || exit 0
[ -e "$here/.git" ] || exit 0

# A session may start inside a worktree. The ROOT tree is the one holding .claude/worktrees,
# and it is the tree both /start and /ship reach for -- so report on it either way.
root="$here"
case "$here" in
  */.claude/worktrees/*)
    root="$(printf '%s' "$here" | sed -E 's#(.*)/\.claude/worktrees/[^/]+$#\1#')"
    ;;
esac

skip_net=0
[ "$HOOK_SKIP_NETWORK" = '1' ] && skip_net=1
[ "$skip_net" = 0 ] && git -C "$here" fetch origin --quiet >/dev/null 2>&1

branch="$(git -C "$here" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ -n "$branch" ] || exit 0
head_sha="$(git -C "$here" rev-parse --short HEAD 2>/dev/null)"

lines=()
lines+=("TREE STATE (.claude/hooks/session-start.sh) -- read before the first edit. Relay anything relevant to the user in plain language; never hand them git commands to type if the team's contract has the agent operate git.")

# ---- 1. where HEAD is, and how far it drifted -------------------------------
where=''
[ "$here" != "$root" ] && where=" (session started in worktree '$(basename "$here")')"

behind=0
sync="no origin/$MAIN_BRANCH ref -- cannot tell how stale this is"
if git -C "$here" rev-parse --verify --quiet "origin/$MAIN_BRANCH" >/dev/null 2>&1; then
  ahead="$(git -C "$here" rev-list --count "origin/$MAIN_BRANCH..HEAD" 2>/dev/null)"
  behind="$(git -C "$here" rev-list --count "HEAD..origin/$MAIN_BRANCH" 2>/dev/null)"
  [ -n "$ahead" ] || ahead=0
  [ -n "$behind" ] || behind=0
  if [ "$ahead" = 0 ] && [ "$behind" = 0 ]; then
    sync="in sync with origin/$MAIN_BRANCH"
  else
    sync="ahead $ahead / behind $behind vs origin/$MAIN_BRANCH"
  fi
fi
lines+=("- HEAD: $branch @ $head_sha, $sync$where")

# ---- 2. uncommitted work -- possibly NOT ours -------------------------------
dirty="$(git -C "$here" status --porcelain 2>/dev/null)"
if [ -n "$dirty" ]; then
  count="$(printf '%s\n' "$dirty" | grep -c .)"
  names="$(printf '%s\n' "$dirty" | sed -E 's/^.{2,3}[[:space:]]+//' | head -6 | tr '\n' ',' | sed -E 's/,$//; s/,/, /g')"
  lines+=("- uncommitted here: $count file(s) -- $names. Do NOT assume they are yours: a parallel session may be mid-task. Never run a blanket 'git add' and never switch this tree's branch before checking ($CONTRACT_DOC, section on parallel sessions).")
else
  lines+=("- uncommitted here: none")
fi

# ---- 3. other worktrees, and who holds the protected branch ----------------
# A real worktree holds a '.git' FILE pointing at the common dir. Without this check
# 'git -C <dir>' would walk UP into the parent repo (.claude/worktrees lives inside it) and
# answer for the ROOT tree, so a leftover empty directory would report itself as a dirty
# worktree on the protected branch -- and the warning below would fire on a lie.
holds_main=''
others=()
stale=()
wt_dir="$root/.claude/worktrees"
if [ -d "$wt_dir" ]; then
  for d in "$wt_dir"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    name="$(basename "$d")"
    if [ ! -e "$d/.git" ]; then
      stale+=("$name")
      continue
    fi
    b="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -n "$b" ] || continue
    [ "$b" = "$MAIN_BRANCH" ] && holds_main="$name"
    [ "$d" = "$here" ] && continue
    wt_dirty="$(git -C "$d" status --porcelain 2>/dev/null)"
    if [ -n "$wt_dirty" ]; then
      n="$(printf '%s\n' "$wt_dirty" | grep -c .)"
      state="$n uncommitted"
    else
      state='clean'
    fi
    others+=("$name [$b, $state]")
  done
fi
if [ "${#others[@]}" -gt 0 ]; then
  joined="$(printf '%s; ' "${others[@]}")"
  lines+=("- other worktrees: ${joined%; }. A dirty one means another session is working there -- leave it alone.")
fi
if [ "${#stale[@]}" -gt 0 ]; then
  joined="$(printf '%s, ' "${stale[@]}")"
  lines+=("- leftover dirs under .claude/worktrees (no .git, not a worktree): ${joined%, }. Nothing git-tracked lives there; check the contents, then delete.")
fi
if [ -n "$holds_main" ]; then
  lines+=("- WARNING: '$MAIN_BRANCH' is checked out in worktree '$holds_main', so checking out $MAIN_BRANCH in the root tree fails with 'already used by worktree'. If that worktree is a leftover, remove it before /start or the last step of /ship.")
fi

# ---- 4. open PRs (drafts included -- a draft is often waiting on purpose) --
if [ "$skip_net" = 0 ] && command -v gh >/dev/null 2>&1; then
  raw="$(cd "$here" && gh pr list --state open --limit 10 --json number,title,isDraft,headRefName 2>/dev/null)"
  if [ -n "$raw" ] && [ "$raw" != '[]' ] && command -v python3 >/dev/null 2>&1; then
    desc="$(printf '%s' "$raw" | python3 -c '
import sys, json
try:
    prs = json.load(sys.stdin)
except Exception:
    prs = []
out = []
for pr in prs:
    title = pr.get("title") or ""
    if len(title) > 55:
        title = title[:55] + "..."
    flag = " DRAFT" if pr.get("isDraft") else ""
    out.append("#%s%s %s [%s]" % (pr.get("number"), flag, title, pr.get("headRefName")))
print("; ".join(out))
' 2>/dev/null)"
    if [ -n "$desc" ]; then
      lines+=("- open PRs: $desc. A DRAFT is usually parked on purpose (waiting on a decision) -- do not push it toward merge unasked.")
    else
      lines+=("- open PRs: none")
    fi
  elif [ -n "$raw" ]; then
    lines+=("- open PRs: none")
  fi
fi

# ---- 5. the one action that follows from the above --------------------------
if [ "$branch" = "$MAIN_BRANCH" ]; then
  lines+=("- ACTION: a new task starts with /start (pull + fresh branch). Committing here is blocked by guard.sh.")
elif [ "$behind" -gt 3 ] 2>/dev/null; then
  lines+=("- ACTION: this branch is $behind commits behind $MAIN_BRANCH. If more code is going in, merge 'origin/$MAIN_BRANCH' into it FIRST (git merge, never rebase -- the guard blocks force push), so a conflict or a renamed helper surfaces now instead of at the CI gate.")
fi

if [ "${#lines[@]}" -gt 1 ]; then
  context="$(printf '%s\n' "${lines[@]}")"
  emit_json "$context"
fi
exit 0
