# Pipe-test for guard.ps1. Run it after ANY change to the guard, and once per machine
# during /setup -- a guard that silently fails open looks exactly like a guard that works.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.tests.ps1
#
# Expected tail: "FAILURES: 0".
#
# Cases live in this FILE, never in the shell command -- otherwise the live hook inspects
# the test command itself and blocks the test run.
# ASCII-ONLY, same reason as guard.ps1 (see its header).

$guard = Join-Path $PSScriptRoot 'guard.ps1'
if (-not (Test-Path $guard)) { Write-Output "guard.ps1 not found next to this script"; exit 1 }

# Read the protected branch name out of the guard itself, so renaming it in one place
# cannot leave these tests asserting against a branch nobody protects.
$mainLine = (Get-Content $guard) | Where-Object { $_ -match "MainBranch\s*=\s*'([^']+)'" } | Select-Object -First 1
$mainName = if ($mainLine -match "MainBranch\s*=\s*'([^']+)'") { $Matches[1] } else { 'main' }

# ---- universal cases: true for every project ---------------------------------
# 'BRANCH' = blocked only while HEAD is the main branch; allowed on a feature branch.
$cases = @(
    @{ cmd = 'git commit -m "x"';                                                             expect = 'BRANCH' },
    @{ cmd = 'git push';                                                                      expect = 'BRANCH' },
    @{ cmd = 'git push origin --tags';                                                        expect = 'ALLOW' },
    @{ cmd = 'git push --force origin feat/x';                                                expect = 'BLOCK' },
    @{ cmd = 'git push -f origin feat/x';                                                     expect = 'BLOCK' },
    @{ cmd = 'git push --force-with-lease origin feat/x';                                     expect = 'BLOCK' },
    # a mention inside an argument is not an invocation
    @{ cmd = 'gh pr create --body "reminder: git push and the deploy come later"';             expect = 'ALLOW' },
    @{ cmd = 'npm run build';                                                                 expect = 'ALLOW' },
    @{ cmd = 'git status';                                                                    expect = 'ALLOW' },
    # '-F' (commit message file) must not read as '-f' (force push)
    @{ cmd = "git add x`ngit commit -q -F msg.txt`ngit push -q origin pb/x/y";                expect = 'BRANCH' },
    # a one-liner that leaves main first cannot land a commit on main
    @{ cmd = "git checkout -b pb/x/y`ngit commit -q --file m.txt`ngit push -u origin pb/x/y"; expect = 'ALLOW' },
    @{ cmd = "git switch -c pb/x/y`ngit commit -m z";                                         expect = 'ALLOW' },
    @{ cmd = "git checkout -q -b pb/x/y`ngit commit -q -m z";                                 expect = 'ALLOW' },
    @{ cmd = "git switch --create pb/x/y`ngit commit -m z";                                   expect = 'ALLOW' },
    # negative control: plain checkout of an existing branch does NOT count as leaving main
    @{ cmd = "git checkout $mainName`ngit commit -m z";                                       expect = 'BRANCH' },
    # read-only plumbing whose name merely starts with a blocked verb
    @{ cmd = "git merge-base --is-ancestor feat/x $mainName";                                 expect = 'ALLOW' },
    @{ cmd = "git branch --merged $mainName";                                                 expect = 'ALLOW' },
    # ...but the real thing is still blocked on main
    @{ cmd = 'git merge feat/x';                                                              expect = 'BRANCH' },
    @{ cmd = "git rebase origin/$mainName";                                                   expect = 'BRANCH' },
    # global flags between 'git' and the verb are still a real invocation
    @{ cmd = 'git -c user.name=T -c user.email=t@t.pl commit -m z';                            expect = 'BRANCH' },
    @{ cmd = 'git -C . commit -m z';                                                          expect = 'BRANCH' },
    # ...but a command aimed at ANOTHER repo is none of this guard's business, otherwise the
    # agent could not work in a scratch/sibling repo while this project sits on main
    @{ cmd = 'git -C ../__not_a_repo__ commit -m z';                                          expect = 'ALLOW' },
    @{ cmd = 'git -C ../__not_a_repo__ push --force origin x';                                expect = 'ALLOW' }
)

# ---- deploy cases: project-specific, fill together with $DeployPattern -------
# Add one BLOCK case per real deploy command (it is blocked whenever the tree is dirty or
# HEAD != origin/main -- see below) and one ALLOW case for the rollback path.
# Leave the array empty for projects that deploy from CI ($DeployPattern = '').
# Ready-made sets per architecture: recipes/*/notes.md in the kit.
# {{FILL:DEPLOY_TEST_CASES}}
$deployCases = @()

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
$onMain = ($branch -eq $mainName)

# A deploy case can only be expected to BLOCK when this checkout actually violates the
# preflight; on a clean protected branch synced with origin the guard rightly allows the
# deploy, so those cases are skipped instead of reported as failures.
$dirty = & git status --porcelain
if (-not $dirty -and $onMain) { $cleanMain = $true } else { $cleanMain = $false }
foreach ($c in $deployCases) {
    if ($c.expect -eq 'BLOCK' -and $cleanMain) { $c.expect = 'SKIP-clean-tree' }
    $cases += $c
}
Write-Output ("branch: {0}  protected: {1}  (BRANCH cases expect {2})" -f $branch, $mainName, $(if ($onMain) { 'BLOCK' } else { 'ALLOW' }))
Write-Output ""

$fails = 0
foreach ($case in $cases) {
    $expected = $case.expect
    if ($expected -eq 'BRANCH') { $expected = if ($onMain) { 'BLOCK' } else { 'ALLOW' } }
    if ($expected -eq 'SKIP-clean-tree') {
        Write-Output ("skip expect=n/a          <- {0}" -f $case.cmd)
        continue
    }

    $json = @{ tool_name = 'PowerShell'; tool_input = @{ command = $case.cmd } } | ConvertTo-Json -Compress
    $out = $json | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guard
    $got = if ($out) { 'BLOCK' } else { 'ALLOW' }

    if ($got -ne $expected) { $fails++; $mark = 'FAIL' } else { $mark = 'ok  ' }
    $oneLine = ($case.cmd -replace "`r?`n", ' ; ')
    Write-Output ("{0} expect={1} got={2}  <- {3}" -f $mark, $expected, $got, $oneLine)
}

Write-Output ""
Write-Output "FAILURES: $fails"
if ($fails -gt 0) { exit 1 }
