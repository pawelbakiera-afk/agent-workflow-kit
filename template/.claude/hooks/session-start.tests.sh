#!/usr/bin/env bash
# Pipe-test for session-start.sh -- mirror of session-start.tests.ps1. Run after ANY change to
# the hook, and once per machine during /setup: a probe that silently fails open looks exactly
# like a quiet repo.
#
#   bash .claude/hooks/session-start.tests.sh
#
# Expected tail: "FAILURES: 0".
# The run is offline: HOOK_SKIP_NETWORK=1 skips 'git fetch' and 'gh'.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook="$here/session-start.sh"
[ -f "$hook" ] || { echo "session-start.sh not found next to this script"; exit 1; }

if ! command -v python3 >/dev/null 2>&1 && ! command -v jq >/dev/null 2>&1; then
  echo "NEITHER python3 NOR jq FOUND -- session-start.sh cannot emit JSON and will stay silent."
  echo "Install one of them and re-run."
  echo "FAILURES: 1"
  exit 1
fi

fails=0
check() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" = 1 ]; then
    printf 'ok   %s\n' "$name"
  else
    fails=$((fails + 1))
    printf 'FAIL %s -- %s\n' "$name" "$detail"
  fi
}

export HOOK_SKIP_NETWORK=1

payload='{"session_id":"test","source":"startup","cwd":"'"$here"'"}'
out="$(printf '%s' "$payload" | bash "$hook")"
code=$?

[ "$code" = 0 ] && check 1 'exit code is 0' '' || check 0 'exit code is 0' "got $code"
[ -n "$out" ] && check 1 'produced output' '' || check 0 'produced output' 'no output -- the hook failed open on a healthy checkout'

if [ -n "$out" ] && command -v python3 >/dev/null 2>&1; then
  event="$(printf '%s' "$out" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["hookEventName"])
except Exception:
    print("")' 2>/dev/null)"
  [ "$event" = 'SessionStart' ] && check 1 'hookEventName is SessionStart' '' || check 0 'hookEventName is SessionStart' "got '$event'"

  ctx="$(printf '%s' "$out" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception:
    print("")' 2>/dev/null)"

  if printf '%s\n' "$ctx" | grep -Eq '^- HEAD: [^ ]+ @ [0-9a-f]{7}'; then h=1; else h=0; fi
  check "$h" 'reports HEAD' 'no HEAD line'

  if printf '%s\n' "$ctx" | grep -Eq '^- uncommitted here: '; then u=1; else u=0; fi
  check "$u" 'reports uncommitted state' 'no uncommitted line'

  if printf '%s\n' "$ctx" | grep -Eq 'never switch this tree|uncommitted here: none'; then w=1; else w=0; fi
  check "$w" 'warns about shared trees' 'neither the warning nor the clean state was reported'

  lc="$(printf '%s' "$out" | wc -l | tr -d ' ')"
  [ "$lc" -le 1 ] && check 1 'single-line payload' '' || check 0 'single-line payload' "output spans $lc lines"
fi

# Regression: .claude/worktrees lives INSIDE the repo, so 'git -C <leftover dir>' walks up and
# answers for the ROOT tree unless a directory without '.git' is explicitly excluded. Without
# that check an abandoned directory reports itself as a dirty worktree on the protected branch.
probe_root="$(cd "$here/../.." && pwd)"
case "$probe_root" in
  */.claude/worktrees/*)
    probe_root="$(printf '%s' "$probe_root" | sed -E 's#(.*)/\.claude/worktrees/[^/]+$#\1#')"
    ;;
esac
probe="$probe_root/.claude/worktrees/_selftest_leftover"
mkdir -p "$probe"
probe_out="$(printf '%s' "$payload" | bash "$hook")"
rmdir "$probe" 2>/dev/null
probe_ctx=''
if [ -n "$probe_out" ] && command -v python3 >/dev/null 2>&1; then
  probe_ctx="$(printf '%s' "$probe_out" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception:
    print("")' 2>/dev/null)"
fi
if printf '%s' "$probe_ctx" | grep -q 'leftover dirs.*_selftest_leftover'; then l1=1; else l1=0; fi
check "$l1" 'leftover dir listed as leftover' 'a non-worktree directory was not reported as leftover'
if printf '%s' "$probe_ctx" | grep -q 'other worktrees:.*_selftest_leftover'; then l2=0; else l2=1; fi
check "$l2" 'leftover dir not called worktree' 'a directory without .git was reported as a worktree'

# Empty stdin must not crash: an unexpected shape means silence, never an error.
printf '' | bash "$hook" >/dev/null 2>&1
check 1 'empty stdin does not crash' ''

echo
echo "FAILURES: $fails"
[ "$fails" -gt 0 ] && exit 1
exit 0
