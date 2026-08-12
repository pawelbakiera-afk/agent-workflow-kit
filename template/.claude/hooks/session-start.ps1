<#
  SessionStart tree probe (Windows / PowerShell) -- companion to guard.ps1. Guard BLOCKS;
  this one only LOOKS: it fetches origin and reports the state of the working tree into the
  agent's context before the first edit of a session.

  Why it exists: once more than one agent works this repo autonomously, nothing tells a fresh
  session what happened while it was away -- a branch whose PR already got squash-merged, the
  protected branch held by a leftover worktree, a parallel session mid-edit with uncommitted
  files. Each of those costs a round of guessing if discovered late; this costs about a second
  at session start.

  It reports, it never blocks: SessionStart cannot deny anything, and an unexpected error means
  exit 0 with no output. A silent probe must never stop a session from starting.

  Network work (git fetch, gh) is skipped when HOOK_SKIP_NETWORK=1, which is how the test file
  gets a deterministic, offline run.

  Worktree paths come from Get-ChildItem, NOT from 'git worktree list': a repo path containing
  a non-ASCII character makes git print it c-quoted (e.g. 'Pawe\305\202Bakiera'), which no
  Test-Path can resolve. The directory listing gives usable paths, and 'git -C <dir>' then
  names the branch.

  ASCII-ONLY BY DESIGN, same reason as guard.ps1: Windows PowerShell 5.1 reads `-File` scripts
  using the system ANSI codepage, so one UTF-8 byte would silently break parsing -- and a broken
  probe looks exactly like a quiet repo. Messages are in English on purpose: the agent reads
  them and relays to the user in the team's language.

  After ANY edit run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/session-start.tests.ps1
#>

$ErrorActionPreference = 'Stop'

# ============================ CONFIG -- set during install =====================
# Keep these two in sync with guard.ps1 -- same branch, same contract document.
$MainBranch = 'main'
$ContractDoc = 'docs/AGENT-WORKFLOW.md'
# ==============================================================================

function Emit([string[]]$lines) {
    if (-not $lines -or $lines.Count -le 1) { exit 0 }
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = ($lines -join "`n")
        }
    }
    Write-Output ($payload | ConvertTo-Json -Depth 5 -Compress)
    exit 0
}

function Norm([string]$p) {
    if (-not $p) { return '' }
    return ($p -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
}

# Branch of a working tree, or $null when the directory is not a checkout.
function Get-Branch([string]$dir) {
    try {
        $b = (& git -C $dir rev-parse --abbrev-ref HEAD)
        if ($LASTEXITCODE -ne 0) { return $null }
        return $b.Trim()
    } catch { return $null }
}

try {
    # The payload is not needed, but the pipe must be drained or the caller can block.
    try { [Console]::In.ReadToEnd() | Out-Null } catch { }

    $here = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (-not (Test-Path -LiteralPath (Join-Path $here '.git'))) { exit 0 }

    # A session may start inside a worktree. The ROOT tree is the one holding .claude/worktrees,
    # and it is the tree both /start and /ship reach for -- so report on it either way.
    $root = $here
    if ($here -match '^(?<root>.+)[\\/]\.claude[\\/]worktrees[\\/][^\\/]+$') { $root = $matches['root'] }

    $skipNet = ($env:HOOK_SKIP_NETWORK -eq '1')
    if (-not $skipNet) { try { & git -C $here fetch origin --quiet } catch { } }

    $lines = @("TREE STATE (.claude/hooks/session-start.ps1) -- read before the first edit. Relay anything relevant to the user in plain language; never hand them git commands to type if the team's contract has the agent operate git.")

    # ---- 1. where HEAD is, and how far it drifted -----------------------------
    $branch = Get-Branch $here
    if (-not $branch) { exit 0 }
    $head = (& git -C $here rev-parse --short HEAD).Trim()
    $where = if ((Norm $here) -ne (Norm $root)) { " (session started in worktree '" + (Split-Path $here -Leaf) + "')" } else { '' }

    $behind = 0
    $sync = "no origin/$MainBranch ref -- cannot tell how stale this is"
    if (& git -C $here rev-parse --verify --quiet "origin/$MainBranch") {
        $ahead  = [int]((& git -C $here rev-list --count "origin/$MainBranch..HEAD").Trim())
        $behind = [int]((& git -C $here rev-list --count "HEAD..origin/$MainBranch").Trim())
        if ($ahead -eq 0 -and $behind -eq 0) { $sync = "in sync with origin/$MainBranch" }
        else { $sync = "ahead $ahead / behind $behind vs origin/$MainBranch" }
    }
    $lines += "- HEAD: $branch @ $head, $sync$where"

    # ---- 2. uncommitted work -- possibly NOT ours -----------------------------
    $dirty = & git -C $here status --porcelain
    if ($dirty) {
        $count = ($dirty | Measure-Object -Line).Lines
        $names = (($dirty | ForEach-Object { ($_ -replace '^.{2,3}\s+', '') } | Select-Object -First 6) -join ', ')
        $lines += "- uncommitted here: $count file(s) -- $names. Do NOT assume they are yours: a parallel session may be mid-task. Never run a blanket 'git add' and never switch this tree's branch before checking ($ContractDoc, section on parallel sessions)."
    } else {
        $lines += '- uncommitted here: none'
    }

    # ---- 3. other worktrees, and who holds the protected branch ---------------
    # Directory listing, not 'git worktree list' -- see header.
    $holdsMain = $null
    $others = @()
    $stale = @()
    $wtDir = Join-Path $root '.claude\worktrees'
    if (Test-Path -LiteralPath $wtDir) {
        foreach ($d in (Get-ChildItem -LiteralPath $wtDir -Directory -ErrorAction SilentlyContinue)) {
            # A real worktree holds a '.git' FILE pointing at the common dir. Without this check
            # 'git -C <dir>' walks UP into the parent repo (.claude/worktrees lives inside it) and
            # answers for the ROOT tree, so a leftover empty directory would report itself as a
            # dirty worktree on the protected branch -- and the warning below would fire on a lie.
            if (-not (Test-Path -LiteralPath (Join-Path $d.FullName '.git'))) {
                $stale += $d.Name
                continue
            }
            $b = Get-Branch $d.FullName
            if (-not $b) { continue }
            if ($b -eq $MainBranch) { $holdsMain = $d.Name }
            if ((Norm $d.FullName) -eq (Norm $here)) { continue }
            $wtDirty = & git -C $d.FullName status --porcelain
            $state = if ($wtDirty) { "" + ($wtDirty | Measure-Object -Line).Lines + " uncommitted" } else { 'clean' }
            $others += ("{0} [{1}, {2}]" -f $d.Name, $b, $state)
        }
    }
    if ($others.Count -gt 0) { $lines += ('- other worktrees: ' + ($others -join '; ') + '. A dirty one means another session is working there -- leave it alone.') }
    if ($stale.Count -gt 0) { $lines += ('- leftover dirs under .claude/worktrees (no .git, not a worktree): ' + ($stale -join ', ') + '. Nothing git-tracked lives there; check the contents, then delete.') }
    if ($holdsMain) {
        $lines += "- WARNING: '$MainBranch' is checked out in worktree '$holdsMain', so checking out $MainBranch in the root tree fails with 'already used by worktree'. If that worktree is a leftover, remove it before /start or the last step of /ship."
    }

    # ---- 4. open PRs (drafts included -- a draft is often waiting on purpose) --
    if (-not $skipNet) {
        $gh = $null
        foreach ($cand in @("$env:LOCALAPPDATA\Programs\gh\bin\gh.exe", "$env:ProgramFiles\GitHub CLI\gh.exe")) {
            if ($cand -and (Test-Path -LiteralPath $cand)) { $gh = $cand; break }
        }
        if (-not $gh) {
            $found = Get-Command gh.exe -ErrorAction SilentlyContinue
            if ($found) { $gh = $found.Source }
        }
        if ($gh) {
            try {
                Push-Location -LiteralPath $here
                try {
                    $raw = & $gh pr list --state open --limit 10 --json number,title,isDraft,headRefName
                } finally { Pop-Location }
                if ($raw) {
                    $prs = $raw | ConvertFrom-Json
                    if ($prs -and $prs.Count -gt 0) {
                        $desc = @()
                        foreach ($pr in $prs) {
                            $title = [string]$pr.title
                            if ($title.Length -gt 55) { $title = $title.Substring(0, 55) + '...' }
                            $flag = if ($pr.isDraft) { ' DRAFT' } else { '' }
                            $desc += ("#{0}{1} {2} [{3}]" -f $pr.number, $flag, $title, $pr.headRefName)
                        }
                        $lines += ('- open PRs: ' + ($desc -join '; ') + '. A DRAFT is usually parked on purpose (waiting on a decision) -- do not push it toward merge unasked.')
                    } else {
                        $lines += '- open PRs: none'
                    }
                }
            } catch { }
        }
    }

    # ---- 5. the one action that follows from the above -------------------------
    if ($branch -eq $MainBranch) {
        $lines += "- ACTION: a new task starts with /start (pull + fresh branch). Committing here is blocked by guard.ps1."
    } elseif ($behind -gt 3) {
        $lines += "- ACTION: this branch is $behind commits behind $MainBranch. If more code is going in, merge 'origin/$MainBranch' into it FIRST (git merge, never rebase -- the guard blocks force push), so a conflict or a renamed helper surfaces now instead of at the CI gate."
    }

    Emit $lines
}
catch {
    # fail-open -- see header
    exit 0
}
