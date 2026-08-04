#!/usr/bin/env bash
# Pipe-test for guard.sh -- mirror of guard.tests.ps1. Run after ANY change to the guard
# and once per machine during /setup: a guard that silently fails open (no jq, no python3,
# a broken regex) looks exactly like a guard that works.
#
#   bash .claude/hooks/guard.tests.sh
#
# Expected tail: "FAILURES: 0".
# Cases live in this FILE, never in the shell command -- otherwise the live hook inspects
# the test command itself and blocks the test run.
# ASCII-ONLY, same reason as guard.sh.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
guard="$here/guard.sh"
[ -f "$guard" ] || { echo "guard.sh not found next to this script"; exit 1; }

if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "NEITHER jq NOR python3 FOUND -- guard.sh cannot parse hook input and will allow"
  echo "everything. Install one of them (macOS: brew install jq) and re-run."
  echo "FAILURES: 1"
  exit 1
fi

main_name="$(sed -n "s/^MAIN_BRANCH='\([^']*\)'.*/\1/p" "$guard" | head -1)"
[ -n "$main_name" ] || main_name='main'

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [ "$branch" = "$main_name" ]; then on_main=1; else on_main=0; fi
if [ "$on_main" = 1 ]; then branch_expect='BLOCK'; else branch_expect='ALLOW'; fi
echo "branch: $branch  protected: $main_name  (BRANCH cases expect $branch_expect)"
echo

# One case per line: EXPECT<TAB>COMMAND. Newlines inside a command are written as \n and
# unescaped below, so a multi-statement command stays on one line here.
# EXPECT is ALLOW | BLOCK | BRANCH (BRANCH = BLOCK only while HEAD is the protected branch).
cases="$(cat <<CASES
BRANCH	git commit -m "x"
BRANCH	git push
ALLOW	git push origin --tags
BLOCK	git push --force origin feat/x
BLOCK	git push -f origin feat/x
BLOCK	git push --force-with-lease origin feat/x
ALLOW	gh pr create --body "reminder: git push and the deploy come later"
ALLOW	npm run build
ALLOW	git status
BRANCH	git add x\ngit commit -q -F msg.txt\ngit push -q origin pb/x/y
ALLOW	git checkout -b pb/x/y\ngit commit -q --file m.txt\ngit push -u origin pb/x/y
ALLOW	git switch -c pb/x/y\ngit commit -m z
ALLOW	git checkout -q -b pb/x/y\ngit commit -q -m z
ALLOW	git switch --create pb/x/y\ngit commit -m z
BRANCH	git checkout $main_name\ngit commit -m z
ALLOW	git merge-base --is-ancestor feat/x $main_name
ALLOW	git branch --merged $main_name
BRANCH	git merge feat/x
BRANCH	git rebase origin/$main_name
BRANCH	git -c user.name=T -c user.email=t@t.pl commit -m z
BRANCH	git -C . commit -m z
ALLOW	git -C ../__not_a_repo__ commit -m z
ALLOW	git -C ../__not_a_repo__ push --force origin x
CASES
)"

# ---- deploy cases: project-specific, fill together with DEPLOY_PATTERN -------
# Same TAB-separated format. Leave empty for projects that deploy from CI.
# Ready-made sets per architecture: recipes/*/notes.md in the kit.
# {{FILL:DEPLOY_TEST_CASES_SH}}
deploy_cases=''

# A deploy case can only be expected to BLOCK when this checkout actually violates the
# preflight; on a clean protected branch synced with origin the guard rightly allows it.
if [ -z "$(git status --porcelain 2>/dev/null)" ] && [ "$on_main" = 1 ]; then
  clean_main=1
else
  clean_main=0
fi

fails=0
run_case() {
  local expect="$1" cmd="$2"
  [ -z "$expect" ] && return 0
  if [ "$expect" = 'BRANCH' ]; then expect="$branch_expect"; fi
  if [ "$expect" = 'BLOCK' ] && [ "$3" = 'deploy' ] && [ "$clean_main" = 1 ]; then
    printf 'skip expect=n/a          <- %s\n' "$cmd"
    return 0
  fi

  # Real newlines for the guard's segment splitting; JSON-escape them for the payload.
  local real json out got mark
  real="$(printf '%b' "$cmd")"
  json="$(printf '%s' "$real" | python_json 2>/dev/null)"
  out="$(printf '%s' "$json" | bash "$guard")"
  if [ -n "$out" ]; then got='BLOCK'; else got='ALLOW'; fi
  if [ "$got" != "$expect" ]; then fails=$((fails+1)); mark='FAIL'; else mark='ok  '; fi
  printf '%s expect=%s got=%s  <- %s\n' "$mark" "$expect" "$got" "$cmd"
}

# Build the hook payload with a real JSON encoder -- hand-rolled quoting breaks on the
# quotes and backslashes that several cases deliberately contain.
python_json() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys,json;print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.stdin.read()}}))'
  else
    jq -Rs '{tool_name:"Bash",tool_input:{command:.}}'
  fi
}

while IFS=$'\t' read -r expect cmd; do
  [ -z "$cmd" ] && continue
  run_case "$expect" "$cmd" 'core'
done <<< "$cases"

if [ -n "$deploy_cases" ]; then
  while IFS=$'\t' read -r expect cmd; do
    [ -z "$cmd" ] && continue
    run_case "$expect" "$cmd" 'deploy'
  done <<< "$deploy_cases"
fi

echo
echo "FAILURES: $fails"
[ "$fails" -gt 0 ] && exit 1
exit 0
