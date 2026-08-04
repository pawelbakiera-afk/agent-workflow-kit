#!/usr/bin/env bash
#
# PreToolUse hook guard (macOS / Linux) -- twin of guard.ps1, same contract:
# docs/AGENT-WORKFLOW.md. Keep the two in sync; guard.tests.sh mirrors guard.tests.ps1.
#
# Blocks:
#   1. commit / merge / rebase / push DIRECTLY on the main branch
#   2. push --force anywhere
#   3. a deploy command run from a dirty tree / not from main / when main != origin/main
#
# ALWAYS FAIL-OPEN: anything unexpected (no JSON parser, no git, unreadable input)
# means allow. A broken guard must not block all work.
#
# ASCII-ONLY, like guard.ps1 -- keeps both files diffable and avoids locale surprises.
#
# REGEX DIALECT WARNING: bash uses POSIX ERE, which has no \S \s \b and no lookaheads.
# The patterns below are ERE translations of the .NET patterns in guard.ps1:
#   \S -> [^[:space:]]   \s -> [[:space:]]   (?![\w-]) -> ([[:space:]]|$)
# When you fill DEPLOY_PATTERN here, write ERE -- not the .NET regex from guard.ps1.
#
# After ANY edit run: bash .claude/hooks/guard.tests.sh

# ============================ CONFIG -- set during install =====================
MAIN_BRANCH='main'

# ERE matched against the HEAD of each command segment to recognise a DEPLOY command.
# Empty ('') disables the deploy preflight -- correct when deploys run from CI.
# {{FILL:DEPLOY_GUARD_PATTERN_ERE}}
DEPLOY_PATTERN=''

# ERE for commands that must never be blocked even though they look deploy-ish
# (typically the emergency rollback path). Checked before DEPLOY_PATTERN.
# {{FILL:DEPLOY_ALLOW_PATTERN_ERE}}
DEPLOY_ALLOW_PATTERN=''

CONTRACT_DOC='docs/AGENT-WORKFLOW.md'
# ==============================================================================

allow() { exit 0; }

# Emit the same JSON verdict as guard.ps1. (Exit code 2 would also block, but only the
# first stderr line reaches the model -- JSON carries the full multi-line explanation.)
deny() {
  local reason="$1"
  reason=${reason//\\/\\\\}
  reason=${reason//\"/\\\"}
  reason=${reason//$'\n'/\\n}
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

# Match a real invocation, not a mention: split the command on statement separators and
# test each segment from its HEAD only, so 'gh pr create --body "...git push..."' passes.
# Prints the matching segment (empty if none).
find_segment() {
  local command="$1" pattern="$2" line
  [ -z "$pattern" ] && return 0
  # tr pads SET2 with its last char, so ; | & all become newlines ('&&' -> two newlines,
  # the empty one is harmless). An '&' inside an argument may cut a segment short, which
  # can only ever cause a missed match -- i.e. fail-open, never a false block.
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    if [[ $line =~ $pattern ]]; then
      printf '%s' "$line"
      return 0
    fi
  done <<EOF
$(printf '%s' "$command" | tr ';|&' '\n')
EOF
  return 0
}

test_head() { [ -n "$(find_segment "$1" "$2")" ]; }

# 'git -C <path> commit' operates on ANOTHER repository. This guard protects the repo it
# lives in, so a command aimed at a different checkout must pass -- otherwise the agent
# could not touch any other repo while this project sits on the protected branch.
# Returns 0 (true) when the segment targets a foreign repo. Unresolvable path -> foreign,
# i.e. fail-open, consistent with the rest of the guard.
is_foreign_repo() {
  local segment="$1" path there here
  path="$(printf '%s' "$segment" | sed -nE 's/.*[[:space:]]-C[[:space:]]+"([^"]+)".*/\1/p')"
  [ -z "$path" ] && path="$(printf '%s' "$segment" | sed -nE "s/.*[[:space:]]-C[[:space:]]+'([^']+)'.*/\1/p")"
  [ -z "$path" ] && path="$(printf '%s' "$segment" | sed -nE 's/.*[[:space:]]-C[[:space:]]+([^[:space:]]+).*/\1/p')"
  [ -z "$path" ] && return 1
  there="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$there" ] || return 0
  here="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$here" ] || return 1
  [ "$there" != "$here" ]
}

raw="$(cat)"
[ -z "$raw" ] && allow

# JSON parsing: jq first, python3 second, otherwise fail open. If neither exists the
# guard is inert -- guard.tests.sh will report failures, which is how /setup catches it.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$raw" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$raw" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("command","") or "", end="")
except Exception:
    pass' 2>/dev/null)"
else
  allow
fi
[ -z "$cmd" ] && allow

command -v git >/dev/null 2>&1 || allow

# Repo root = two levels above this script, resolved from the script path (works in a worktree).
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
[ -n "$repo" ] || allow
[ -e "$repo/.git" ] || allow

branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)" || allow
[ -n "$branch" ] || allow

# '((-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]+)*' lets global flags sit between 'git' and
# the verb: 'git -C /path push' and 'git -c user.name=x commit' are real invocations.
GIT_HEAD_RE='^(&[[:space:]]*)?[^[:space:]]*git(\.exe)?"?[[:space:]]+((-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]+)*'

# ---- 1. deploy preflight -----------------------------------------------------
if [ -n "$DEPLOY_ALLOW_PATTERN" ] && test_head "$cmd" "$DEPLOY_ALLOW_PATTERN"; then allow; fi

if [ -n "$DEPLOY_PATTERN" ] && test_head "$cmd" "$DEPLOY_PATTERN"; then
  problems=''
  add_problem() { problems="${problems}  - $1"$'\n'; }

  if [ "$branch" != "$MAIN_BRANCH" ]; then
    add_problem "you are on branch '$branch', but ONLY $MAIN_BRANCH may be deployed (only $MAIN_BRANCH contains everyone's work)"
  fi

  dirty="$(git -C "$repo" status --porcelain 2>/dev/null)"
  if [ -n "$dirty" ]; then
    n="$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')"
    add_problem "working tree is dirty ($n files) -- the deploy uploads the DIRECTORY, so live would get changes that exist in no commit"
  fi

  git -C "$repo" fetch origin "$MAIN_BRANCH" --quiet >/dev/null 2>&1
  local_sha="$(git -C "$repo" rev-parse HEAD 2>/dev/null)"
  remote_sha="$(git -C "$repo" rev-parse "origin/$MAIN_BRANCH" 2>/dev/null)"
  if [ -n "$local_sha" ] && [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]; then
    ahead="$(git -C "$repo" rev-list --count "origin/$MAIN_BRANCH..HEAD" 2>/dev/null)"
    behind="$(git -C "$repo" rev-list --count "HEAD..origin/$MAIN_BRANCH" 2>/dev/null)"
    add_problem "local $MAIN_BRANCH diverged from origin/$MAIN_BRANCH (ahead: $ahead, behind: $behind) -- run 'git pull', or ship your work through a PR first"
  fi

  if [ -n "$problems" ]; then
    deny "DEPLOY BLOCKED by .claude/hooks/guard.sh:
${problems}
Fix the above and retry. Deploy contract: $CONTRACT_DOC."
  fi
  allow
fi

# ---- 2. push --force ---------------------------------------------------------
push_segment="$(find_segment "$cmd" "${GIT_HEAD_RE}push([[:space:]]|\$)")"
if [ -n "$push_segment" ] && is_foreign_repo "$push_segment"; then push_segment=''; fi

# Scoped to the push segment only: 'git commit -F msg.txt' on another line must not read
# as a force flag. Bash [[ =~ ]] is case-sensitive, so -F stays distinct from -f.
if [ -n "$push_segment" ] && [[ $push_segment =~ (--force(-with-lease)?([[:space:]]|$)|(^|[[:space:]])-f([[:space:]]|$)) ]]; then
  deny "FORCE PUSH BLOCKED: with more than one person a force push destroys someone else's work. Repair history with a new commit or 'git revert', never by overwriting."
fi

# ---- 3. working directly on the main branch ----------------------------------
# The hook runs BEFORE the command: a one-liner that creates a branch and then commits
# still reports HEAD as main, but the commit cannot land on main -- so treat it as fine.
if test_head "$cmd" "${GIT_HEAD_RE}(checkout|switch)[[:space:]].*(-b|-c|--create)([[:space:]]|\$)"; then
  branch='(new branch)'
fi

write_segment="$(find_segment "$cmd" "${GIT_HEAD_RE}(commit|merge|rebase)([[:space:]]|\$)")"
if [ -n "$write_segment" ] && is_foreign_repo "$write_segment"; then write_segment=''; fi

if [ "$branch" = "$MAIN_BRANCH" ] && [ -n "$write_segment" ]; then
  deny "YOU ARE ON $MAIN_BRANCH : commit/merge/rebase on $MAIN_BRANCH is blocked. Create a branch ('git checkout -b <initials>/<type>/<slug>'), commit there, then open a PR -- see $CONTRACT_DOC. Note: uncommitted file changes follow you to the new branch, switching loses nothing."
fi

if [ "$branch" = "$MAIN_BRANCH" ] && [ -n "$push_segment" ]; then
  # release tags may be pushed from main -- they are what records what is live
  if ! [[ $cmd =~ (--tags|refs/tags|[[:space:]]tag[[:space:]]) ]]; then
    deny "PUSH FROM $MAIN_BRANCH BLOCKED: $MAIN_BRANCH only advances through a merged PR. Create a branch and open a PR ($CONTRACT_DOC). The single exception is pushing a release tag."
  fi
fi

allow
