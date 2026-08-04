<#
  PreToolUse hook guard (Windows / PowerShell) -- contract: docs/AGENT-WORKFLOW.md

  Reads the hook JSON from stdin and blocks three classes of mistake that no verbal
  agreement catches once two autonomous agents share one repo:

    1. commit / merge / rebase / push DIRECTLY on the main branch -> work goes via branch + PR
    2. push --force anywhere                                      -> a shared main is never overwritten
    3. a deploy command run from a dirty tree / not from main / when main != origin/main
       (deploys that upload the WORKING DIRECTORY -- 'gcloud run deploy --source .',
        'vercel --prod', 'docker build .', rsync -- can push code that exists in no
        commit, or miss the other person's work)

  Always FAIL-OPEN: any unexpected error means exit 0 (allow). A broken guard must not
  block all work; its job is catching slips, not being a security boundary.

  ASCII-ONLY BY DESIGN. Windows PowerShell 5.1 reads '-File' scripts using the system
  ANSI codepage, so a UTF-8 byte such as 0x94 (part of an em dash) is decoded as a double
  quote and silently breaks parsing -- which would make every hook call fail open.
  Keep this file 7-bit ASCII. Messages are English on purpose: the agent reads them and
  relays them to the user in the language of the conversation.

  After ANY edit run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.tests.ps1
#>

# 'Continue', NOT 'Stop', and this is load-bearing. In Windows PowerShell 5.1 a native
# command's stderr (git writing "'origin' does not appear to be a git repository", or any
# network error while offline) is wrapped in an ErrorRecord; with 'Stop' that becomes a
# terminating error, the catch-all at the bottom fires, and the guard fails OPEN -- i.e.
# a deploy from a diverged tree sails through exactly when the network is flaky.
# Every git call below is checked via $LASTEXITCODE or an empty result instead.
$ErrorActionPreference = 'Continue'

# ============================ CONFIG -- set during install =====================
# Name of the protected branch (whatever this project calls it: main / master / trunk).
$MainBranch = 'main'

# Regex matched against the HEAD of each command segment to recognise a DEPLOY command.
# Empty string ('') disables the deploy preflight entirely -- correct for projects that
# deploy from CI (push to main triggers the pipeline), because then there is no local
# deploy command to guard.
# Ready-made values per architecture: see recipes/*/notes.md in the kit, or ADAPT.md.
# {{FILL:DEPLOY_GUARD_PATTERN}}
$DeployPattern = ''

# Regex for commands that must NEVER be blocked even though they look deploy-ish --
# typically the emergency rollback path (traffic switch, previous-release promote).
# Checked before $DeployPattern.
# {{FILL:DEPLOY_ALLOW_PATTERN}}
$DeployAllowPattern = ''

# Where the human-readable contract lives (quoted in every denial message).
$ContractDoc = 'docs/AGENT-WORKFLOW.md'
# ==============================================================================

function Allow { exit 0 }

# Match a real invocation, not a mention. The command is split on statement separators
# and each segment is tested from its HEAD only, so 'gh pr create --body "...git push..."'
# is not mistaken for an actual push. Returns the matching segment so flag checks can be
# scoped to it -- a multi-line command may commit AND push, and a flag on one line must
# never be read as a flag on the other.
function Find-Segment([string]$command, [string]$pattern) {
    if ([string]::IsNullOrEmpty($pattern)) { return $null }
    foreach ($segment in ($command -split '(\r?\n|;|&&|\|\||\|)')) {
        $trimmed = $segment.Trim()
        if ($trimmed -match $pattern) { return $trimmed }
    }
    return $null
}

function Test-Head([string]$command, [string]$pattern) {
    return $null -ne (Find-Segment $command $pattern)
}

# 'git -C <path> commit' operates on ANOTHER repository. This guard protects the repo it
# lives in, so a command aimed at a different checkout (a scratch repo, a sibling project,
# a test fixture) must pass -- otherwise the agent cannot touch any other repo at all
# while this project happens to sit on the protected branch.
# Unresolvable path (a shell variable, a typo) -> treated as foreign, i.e. fail-open.
function Test-ForeignRepo([string]$segment, [string]$repo) {
    # -cnotmatch (case-SENSITIVE): '-C' is a path, '-c' is a config override. PowerShell's
    # -match ignores case, so 'git -c user.name=T commit' was read as a foreign path
    # ('user.name=T'), which then failed to resolve and let the commit through.
    if ($segment -cnotmatch '\s-C\s+("([^"]+)"|''([^'']+)''|(\S+))') { return $false }
    $path = @($Matches[2], $Matches[3], $Matches[4] | Where-Object { $_ })[0]
    if (-not $path) { return $false }

    $there = (& git -C $path rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $there) { return $true }
    $here = (& git -C $repo rev-parse --show-toplevel 2>$null)
    if (-not $here) { return $false }
    return ($there.Trim() -ne $here.Trim())
}

function Deny([string]$reason) {
    $payload = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reason
        }
    }
    Write-Output ($payload | ConvertTo-Json -Depth 5 -Compress)
    exit 0
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { Allow }

    $cmd = ($raw | ConvertFrom-Json).tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { Allow }

    # Repo root = two levels above this script (.claude/hooks/guard.ps1). Resolved from
    # the script path, not from cwd, so it also works inside a git worktree.
    $repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (-not (Test-Path (Join-Path $repo '.git'))) { Allow }

    $branch = (& git -C $repo rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { Allow }
    $branch = $branch.Trim()

    # ---- 1. deploy preflight --------------------------------------------------
    if ($DeployAllowPattern -and (Test-Head $cmd $DeployAllowPattern)) { Allow }

    if ($DeployPattern -and (Test-Head $cmd $DeployPattern)) {
        $problems = @()

        if ($branch -ne $MainBranch) {
            $problems += "you are on branch '$branch', but ONLY $MainBranch may be deployed (only $MainBranch contains everyone's work)"
        }

        $dirty = & git -C $repo status --porcelain
        if ($dirty) {
            $n = ($dirty | Measure-Object -Line).Lines
            $problems += "working tree is dirty ($n files) -- the deploy uploads the DIRECTORY, so live would get changes that exist in no commit"
        }

        # No origin / offline / auth prompt -> skip the comparison, but keep enforcing the
        # branch and dirty-tree rules. try{}catch{} because a native stderr write must never
        # take the whole guard down (see the header note on $ErrorActionPreference).
        try { & git -C $repo fetch origin $MainBranch --quiet 2>$null | Out-Null } catch { }
        $localSha  = (& git -C $repo rev-parse HEAD 2>$null)
        $remoteSha = (& git -C $repo rev-parse "origin/$MainBranch" 2>$null)
        if ($localSha -and $remoteSha -and ($localSha.Trim() -ne $remoteSha.Trim())) {
            $ahead  = (& git -C $repo rev-list --count "origin/$MainBranch..HEAD" 2>$null)
            $behind = (& git -C $repo rev-list --count "HEAD..origin/$MainBranch" 2>$null)
            $problems += "local $MainBranch diverged from origin/$MainBranch (ahead: $ahead, behind: $behind) -- run 'git pull', or ship your work through a PR first"
        }

        if ($problems.Count -gt 0) {
            $list = ($problems | ForEach-Object { "  - $_" }) -join "`n"
            Deny "DEPLOY BLOCKED by .claude/hooks/guard.ps1:`n$list`n`nFix the above and retry. Deploy contract: $ContractDoc."
        }
        Allow
    }

    # ---- 2. push --force ------------------------------------------------------
    # '((-C|-c)\s+\S+\s+)*' lets global flags sit between 'git' and the verb:
    # 'git -C /path push', 'git -c user.name=x commit' are real invocations and were
    # slipping through a pattern that demanded the verb immediately after 'git'.
    $gitHead = '^(&\s*)?\S*git(\.exe)?"?\s+((-C|-c)\s+\S+\s+)*'

    $pushSegment = Find-Segment $cmd ($gitHead + 'push\b')
    $isPush = ($null -ne $pushSegment) -and -not (Test-ForeignRepo $pushSegment $repo)

    # -cmatch (case-SENSITIVE) and scoped to the push segment only: PowerShell's -match
    # ignores case, so 'git commit -F msg.txt' on another line read as a force flag.
    if ($isPush -and ($pushSegment -cmatch '(--force(-with-lease)?\b|(\s|^)-f(\s|$))')) {
        Deny "FORCE PUSH BLOCKED: with more than one person a force push destroys someone else's work. Repair history with a new commit or 'git revert', never by overwriting."
    }

    # ---- 3. working directly on the main branch -------------------------------
    # The hook runs BEFORE the command, so a one-liner that creates a branch and then
    # commits still reports HEAD as main. If the command itself leaves main first, the
    # commit cannot land on main -- treat those rules as satisfied.
    # flags may sit anywhere before the branch-creating one: 'git checkout -q -b x',
    # 'git switch --create x', 'git checkout -b x' all count
    $leavesMain = Test-Head $cmd ($gitHead + '(checkout|switch)\s+[^\r\n]*(-b|-c|--create)\b')
    if ($leavesMain) { $branch = '(new branch)' }

    # (?![\w-]) instead of \b: '\b' still matches inside 'merge-base', which is a READ-ONLY
    # plumbing command and must not be blocked. Same for commit-tree / rebase--*.
    $writeSegment = Find-Segment $cmd ($gitHead + '(commit|merge|rebase)(?![\w-])')
    if ($writeSegment -and (Test-ForeignRepo $writeSegment $repo)) { $writeSegment = $null }

    if ($branch -eq $MainBranch -and $writeSegment) {
        Deny "YOU ARE ON $MainBranch : commit/merge/rebase on $MainBranch is blocked. Create a branch ('git checkout -b <initials>/<type>/<slug>'), commit there, then open a PR -- see $ContractDoc. Note: uncommitted file changes follow you to the new branch, switching loses nothing."
    }

    if ($branch -eq $MainBranch -and $isPush) {
        # release tags may be pushed from main -- they are what records what is live
        if ($cmd -notmatch '(--tags|refs/tags|\stag\s)') {
            Deny "PUSH FROM $MainBranch BLOCKED: $MainBranch only advances through a merged PR. Create a branch and open a PR ($ContractDoc). The single exception is pushing a release tag."
        }
    }

    Allow
}
catch {
    # fail-open -- see header
    exit 0
}
