# Pipe-test for session-start.ps1. Run it after ANY change to the hook, and once per machine
# during /setup -- a probe that silently fails open looks exactly like a quiet repo.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/session-start.tests.ps1
#
# Expected tail: "FAILURES: 0".
#
# The run is offline: HOOK_SKIP_NETWORK=1 skips 'git fetch' and 'gh', so the result depends
# only on the local checkout and the test never waits on the network.
# ASCII-ONLY, same reason as the hook itself (see its header).

$hook = Join-Path $PSScriptRoot 'session-start.ps1'
if (-not (Test-Path $hook)) { Write-Output 'session-start.ps1 not found next to this script'; exit 1 }

$fails = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) { Write-Output ("ok   {0}" -f $name) }
    else { $script:fails++; Write-Output ("FAIL {0} -- {1}" -f $name, $detail) }
}

$env:HOOK_SKIP_NETWORK = '1'

# The real payload Claude Code sends on SessionStart, plus the empty-stdin edge case.
$payload = @{ session_id = 'test'; source = 'startup'; cwd = (Get-Location).Path } | ConvertTo-Json -Compress
$out = $payload | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
$code = $LASTEXITCODE

Check 'exit code is 0' ($code -eq 0) "got $code"
Check 'produced output' ([bool]$out) 'no output -- the hook failed open on a healthy checkout'

$parsed = $null
if ($out) {
    try { $parsed = ($out -join '') | ConvertFrom-Json } catch { }
}
Check 'output is valid JSON' ($null -ne $parsed) 'ConvertFrom-Json rejected the payload'

if ($parsed) {
    Check 'hookEventName is SessionStart' ($parsed.hookSpecificOutput.hookEventName -eq 'SessionStart') ("got '" + $parsed.hookSpecificOutput.hookEventName + "'")
    $ctx = [string]$parsed.hookSpecificOutput.additionalContext
    Check 'reports HEAD'              ($ctx -match '(?m)^- HEAD: \S+ @ [0-9a-f]{7}') 'no HEAD line'
    Check 'reports uncommitted state' ($ctx -match '(?m)^- uncommitted here: ') 'no uncommitted line'
    Check 'warns about shared trees'  ($ctx -match 'never switch this tree|uncommitted here: none') 'neither the warning nor the clean state was reported'
    # A single JSON object on one line: Claude Code parses hook stdout as one payload.
    Check 'single-line payload' (($out -join "`n").Trim() -notmatch "`n") 'output spans multiple lines'
}

# Regression, found the first time an installed hook ran for real: .claude/worktrees lives
# INSIDE the repo, so 'git -C <leftover dir>' walks up and answers for the root tree. An
# abandoned directory (leftover node_modules, nothing git-tracked) therefore reported itself
# as a dirty worktree on the protected branch, and the 'main is held elsewhere' warning fired
# on a lie. A directory without '.git' must be listed as leftover, never as a worktree.
$probeRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ($probeRoot -match '^(?<root>.+)[\\/]\.claude[\\/]worktrees[\\/][^\\/]+$') { $probeRoot = $matches['root'] }
$probe = Join-Path $probeRoot '.claude\worktrees\_selftest_leftover'
try {
    New-Item -ItemType Directory -Path $probe -Force | Out-Null
    $probeOut = $payload | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
    $probeCtx = ''
    if ($probeOut) { $probeCtx = [string](($probeOut -join '') | ConvertFrom-Json).hookSpecificOutput.additionalContext }
    Check 'leftover dir listed as leftover'   ($probeCtx -match 'leftover dirs[^\r\n]*_selftest_leftover') 'a non-worktree directory was not reported as leftover'
    Check 'leftover dir not called worktree'  ($probeCtx -notmatch 'other worktrees:[^\r\n]*_selftest_leftover') 'a directory without .git was reported as a worktree'
    Check 'leftover dir raises no main claim' ($probeCtx -notmatch "'main' is checked out in worktree '_selftest_leftover'") 'the main-is-held warning fired on a leftover directory'
} finally {
    if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Recurse -Force -Confirm:$false }
}

# Empty stdin must not throw: an unexpected shape means exit 0, never a crash.
$empty = '' | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
Check 'empty stdin still exits 0' ($LASTEXITCODE -eq 0) "got $LASTEXITCODE"

# Every hook in this directory must stay 7-bit ASCII: PS 5.1 reads -File scripts with the system
# ANSI codepage, so one UTF-8 byte (an em dash, a non-ASCII letter) breaks parsing and the hook
# then fails open on every call -- invisibly.
foreach ($ps1 in (Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1')) {
    $bytes = [System.IO.File]::ReadAllBytes($ps1.FullName)
    $bad = 0
    foreach ($b in $bytes) { if ($b -gt 127) { $bad++ } }
    Check ("7-bit ASCII: " + $ps1.Name) ($bad -eq 0) "$bad non-ASCII byte(s)"
}

Write-Output ''
Write-Output "FAILURES: $fails"
if ($fails -gt 0) { exit 1 }
