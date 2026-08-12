# INSTALL — instrukcja dla agenta wpinającego kit w nowy projekt

> **Czytasz to, bo człowiek powiedział „zainstaluj kit z agent-workflow-kit".**
> Wykonaj całą procedurę samodzielnie. Pytaj **tylko** o rzeczy z kroku 2 — reszty
> nie zgaduj, tylko wyczytaj z repo. Na końcu (krok 10) obowiązkowy raport.

**Człowiek, który to zamawia, najczęściej nie jest programistą.** Nie oddawaj mu listy komend
do wpisania i nie zostawiaj „TODO: uzupełnij". Albo coś wypełniasz sam z repo, albo pytasz
konkretnym pytaniem z propozycją odpowiedzi.

---

## Krok 0. Zasady tej instalacji

1. **Nie nadpisuj cicho.** Jeśli w docelowym repo istnieje już `.claude/settings.json`,
   `docs/AGENT-WORKFLOW.md` albo `.github/workflows/ci.yml` — przeczytaj je, scal świadomie
   i powiedz w raporcie, co zmieniłeś. Nigdy nie kasuj istniejących hooków innych osób.
2. **Idempotentność.** Druga instalacja na tym samym repo nie może niczego zdublować.
3. **Zero fałszywych sukcesów.** „Skopiowane" ≠ „działa". Guard uznajesz za działający
   **wyłącznie** po zielonym wyniku jego testów (krok 8).
4. **Instalację publikujesz normalnym flow, który właśnie wprowadzasz** — branch → PR → merge.
   Nie commituj kitu bezpośrednio na chroniony branch (nawet jeśli jeszcze nic tego nie broni).

---

## Krok 1. Recon — wyczytaj z repo, nie pytaj

Zbierz to sam (Glob/Grep/Read, `git`, `gh`):

| Co ustalasz | Gdzie szukać |
|---|---|
| `REPO_SLUG`, `REPO_URL` | `git remote -v`, `gh repo view --json nameWithOwner` |
| `MAIN_BRANCH` | `git symbolic-ref refs/remotes/origin/HEAD` albo `gh repo view --json defaultBranchRef` |
| `INITIALS_RULE`, `EMAIL_DOMAIN` | `git log --format='%ae' -20 \| sort -u` — wzorzec adresów zespołu |
| stack + katalogi aplikacji | `package.json`, `requirements*.txt`, `pyproject.toml`, `go.mod`, `*.csproj`, `Gemfile` |
| `BUILD_GATE` / `TEST_GATE` | skrypty w `package.json`, obecność `pytest.ini`/`tests/`, istniejący workflow CI, `CLAUDE.md`/`README.md` |
| architektura deployu | `Dockerfile`, `docker-compose*.yml`, `vercel.json`, `.github/workflows/*deploy*`, `cloudbuild.yaml`, `app.yaml`, `fly.toml`, `Procfile`, `netlify.toml` |
| czy CI już istnieje | `.github/workflows/` |
| ile osób pracuje | `git shortlog -sne --all \| head` |

Z architektury deployu wybierz **recipe**: `recipes/cloud-run`, `recipes/vercel`,
`recipes/docker-vps`, `recipes/no-deploy`. Jeśli żaden nie pasuje (Fly.io, Heroku, App Engine,
Kubernetes, mobile store…) → wybierz najbliższy strukturalnie i napisz własny wariant
komend według `ADAPT.md` §4. **Nie udawaj, że pasuje** — deploy to jedyne miejsce w tym kicie,
gdzie zła wartość jest groźna, a nie tylko brzydka.

---

## Krok 2. Zapytaj człowieka — tylko o to, czego nie da się wyczytać

Zadaj **jedną** turę pytań, z propozycją odpowiedzi (nie otwarte „jak chcesz?"):

1. **System zespołu** — wszyscy na Windowsie / wszyscy na macOS-Linuksie / mieszanie?
   (decyduje, który `settings.*.json` staje się `settings.json`; przy mieszance uprzedź
   o widocznej, nieblokującej notce „hook error" na maszynie bez drugiego launchera).
2. **Model pracy** — potwierdź wprost: *„PR obowiązkowy, ale zero review i zero approvali,
   każdy scala swoje sam; bramką jest CI"*. Jeśli człowiek chce review — powiedz, że kit
   nadal ma sens, ale zmieniasz `required_approving_review_count` na 1 i wywalasz
   z dokumentów zdania „nie oznaczaj nikogo jako reviewera".
3. **Deploy** — jeśli po kroku 1 nie masz pewności: czy produkcja wychodzi z lokalnej komendy
   (kto wpisuje), czy sama z CI po mergu? Podaj, co znalazłeś, i poproś o potwierdzenie.
4. **Czego nie wiesz o bramkach** — jeśli repo nie ma testów ani builda, powiedz to i zapytaj,
   co ma sprawdzać CI. Nie instaluj zielonego CI, który nic nie robi (patrz `ci-templates/minimal.yml`).

---

## Krok 3. Skopiuj pliki

Z kitu do docelowego repo:

```
template/.claude/hooks/guard.ps1               -> .claude/hooks/guard.ps1
template/.claude/hooks/guard.tests.ps1         -> .claude/hooks/guard.tests.ps1
template/.claude/hooks/guard.sh                -> .claude/hooks/guard.sh
template/.claude/hooks/guard.tests.sh          -> .claude/hooks/guard.tests.sh
template/.claude/hooks/session-start.ps1       -> .claude/hooks/session-start.ps1
template/.claude/hooks/session-start.tests.ps1 -> .claude/hooks/session-start.tests.ps1
template/.claude/hooks/session-start.sh        -> .claude/hooks/session-start.sh
template/.claude/hooks/session-start.tests.sh  -> .claude/hooks/session-start.tests.sh
template/.claude/commands/start.md             -> .claude/commands/start.md
template/.claude/commands/verify.md            -> .claude/commands/verify.md
template/.claude/commands/ship.md              -> .claude/commands/ship.md
template/.claude/commands/setup.md             -> .claude/commands/setup.md
template/docs/AGENT-WORKFLOW.md                -> docs/AGENT-WORKFLOW.md
```

Kopiuj **oba** warianty (`.ps1` i `.sh`) niezależnie od systemu instalującego — tylko jeden z
nich zostanie wpięty w `settings.json` (krok 4), ale drugi ma czekać gotowy, gdyby zespół
zatrudnił kogoś na innym systemie.

Deploy i rollback — **z recipe, nie z template**, jeśli recipe je ma:

```
recipes/<wybrany>/deploy.md    -> .claude/commands/deploy.md
recipes/<wybrany>/rollback.md  -> .claude/commands/rollback.md
```

Jeśli wybrany recipe ich nie ma (`no-deploy`) — zastosuj jego instrukcję (usuń komendy albo
zamień na wariant statusowy). Jeśli piszesz własny wariant — startuj ze szkieletów
`template/.claude/commands/deploy.md` i `rollback.md`.

Ustaw bit wykonywalności na skryptach shellowych, jeśli system to obsługuje:
`git update-index --chmod=+x .claude/hooks/guard.sh .claude/hooks/guard.tests.sh`.

Dopisz do `.gitignore` (jeśli ich tam nie ma):

```
.claude/settings.local.json
.claude/worktrees/
```

---

## Krok 4. Wybierz `settings.json`

Skopiuj **jeden** wariant jako `.claude/settings.json`:

| Zespół | Plik |
|---|---|
| tylko Windows | `template/.claude/settings.windows.json` |
| tylko macOS/Linux | `template/.claude/settings.unix.json` |
| mieszany | `template/.claude/settings.cross.json` |

Jeśli w repo **już jest** `.claude/settings.json` — nie podmieniaj go, tylko **dodaj** wpis
`PreToolUse` do istniejącej struktury, zachowując to, co tam było.

Zmień `statusMessage` na język zespołu, jeśli inny niż angielski.

---

## Krok 5. Wypełnij placeholdery

Wszystkie miejsca do wypełnienia mają postać `{{FILL:NAZWA — podpowiedź}}`. Pełna tabela
z opisem, skąd brać wartość → `ADAPT.md` §2. Kolejność, która się nie zaplącze:

1. **Guard** (`.claude/hooks/guard.ps1` i `guard.sh`): `MainBranch`, `DeployPattern`,
   `DeployAllowPattern`, `ContractDoc`. Wzorce **przepisz z `recipes/<wybrany>/notes.md`** —
   są tam podane osobno dla .NET (`.ps1`) i osobno dla POSIX ERE (`.sh`).
   ⚠️ **Nie kopiuj wzorca .NET do `.sh`** — ERE nie zna `\s`, `\b` ani lookaheadów; taki
   wzorzec nie dopasuje niczego i guard cicho przestanie pilnować deployu.
2. **Testy guarda**: wklej `$deployCases` / `deploy_cases` z tego samego recipe.
   Projekt bez lokalnego deployu → zostaw puste (i `DeployPattern = ''`).
2b. **`session-start.ps1` i `session-start.sh`**: te same `MainBranch` / `ContractDoc` co
   w guardzie — wypełnij razem, żeby oba hooki zgadzały się co do nazwy chronionego brancha
   i miejsca kontraktu.
3. **Komendy** `.claude/commands/*.md`: `MAIN_BRANCH`, `REPO_SLUG`, `BUILD_GATE`, `TEST_GATE`,
   `LINT_GATE`, `INITIALS_RULE`, `DEPS_SETUP`, `DEPLOY_TOOLING`, `LOCAL_SECRETS`, `DEPLOY_QUESTION`.
   `LINT_GATE` (tylko w `verify.md`) → „brak", jeśli projekt nie ma osobnego lintera.
4. **Kontrakt** `docs/AGENT-WORKFLOW.md`: dodatkowo `TEAM_SIZE`, `CI_CHECK_NAMES`,
   `HOTSPOT_FILES`, `DEPLOY_SECTION`, `ROLLBACK_SECTION`, `MANUAL_ONBOARDING`.
   Sekcje 3–4 (deploy/rollback) napisz **treścią z recipe**, nie ogólnikami.
   `HOTSPOT_FILES` wypełnij realnymi plikami tego repo (najczęściej edytowane wspólne
   moduły: `git log --format= --name-only -300 | sort | uniq -c | sort -rn | head -20`).
5. **Weryfikacja mechaniczna — obowiązkowa:**
   ```
   grep -rn "{{FILL" .claude docs .github
   ```
   **Musi nie zwrócić nic.** Jeśli któryś placeholder jest w tym projekcie bez sensu,
   usuń całe zdanie/sekcję, a nie sam znacznik — dokument ma się czytać naturalnie.

---

## Krok 6. CI

Wybierz szablon z `ci-templates/` (`node.yml`, `python.yml`, `node-python.yml`, `minimal.yml`),
skopiuj jako `.github/workflows/ci.yml`, wypełnij `{{FILL:…}}`.

- **Nazwy jobów są kontraktem** — trafiają do required status checks (krok 7) i do
  `CI_CHECK_NAMES` w dokumentacji. Zmienisz je później → musisz zaktualizować ochronę brancha,
  inaczej merge zablokuje się na checku, który nigdy nie wystartuje.
- CI musi uruchamiać **te same** komendy, co bramki w `/ship`. Rozjazd tu znaczy, że agent
  dowiaduje się o błędzie z PR-a zamiast z konsoli.
- Push zmieniający cokolwiek w `.github/workflows/` wymaga scope'a `workflow` w `gh`
  (`gh auth refresh -s workflow -h github.com`) — sprawdź to teraz, nie po odbitym pushu.

---

## Krok 7. Ochrona brancha po stronie GitHuba

**Kolejność ma znaczenie:** najpierw wypuść instalację PR-em (krok 8), żeby CI raz przeleciało
i nazwy checków były pewne, **potem** ustaw ochronę. Odwrotnie zablokujesz sobie własny PR.

```
gh api -X PUT repos/{owner}/{repo}/branches/{main}/protection --input protection.json
```

`protection.json` (podmień `contexts` na nazwy jobów z kroku 6):

```json
{
  "required_status_checks": { "strict": true, "contexts": ["frontend", "backend"] },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

Do tego ustawienia repo (squash-only + auto-sprzątanie branchy):

```
gh api -X PATCH repos/{owner}/{repo} -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false -F delete_branch_on_merge=true
```

**`enforce_admins: true` jest istotne** — jeśli wszyscy w zespole są adminami, bez tego reguły
są bezzębne.

**Jeśli API odpowie 403/404:** ochrona branchy nie jest dostępna na tym planie (typowo:
prywatne repo na darmowym koncie osobistym). **Nie udawaj, że się udało.** Zaraportuj wprost:
zostaje ochrona lokalna (hook) + zasady z sekcji 0 kontraktu, a `main` da się nadpisać ręcznie.
Opcje dla człowieka: repo w organizacji, plan Pro/Team, albo repo publiczne.

---

## Krok 8. Weryfikacja — bez tego instalacja się nie liczy

1. **Testy obu hooków** (na tym systemie, na którym pracujesz):
   - Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.tests.ps1`
     i analogicznie `session-start.tests.ps1`
   - macOS/Linux: `bash .claude/hooks/guard.tests.sh` i `bash .claude/hooks/session-start.tests.sh`

   Wymagany ogon: **`FAILURES: 0`** w każdym z nich. Typowe przyczyny czerwonego:
   - znak spoza ASCII w `guard.ps1` (PowerShell 5.1 czyta `-File` w ANSI → cicha awaria parsowania),
   - brak `jq` **i** `python3` na Unixie (guard nie ma czym sparsować wejścia → fail-open),
   - wzorzec .NET wklejony do `.sh` (krok 5, pułapka 1),
   - `$ErrorActionPreference` zmieniony na `'Stop'` w `guard.ps1` → stderr gita wywala cały
     guard w fail-open (`ADAPT.md` §3 pułapka 4).

   Jeśli wypełniłeś sekcję deployową, odpal testy **także w checkoutcie bez remote'a `origin`**
   (albo offline) — przypadki deployowe muszą wtedy nadal blokować. Ta ścieżka jest jedynym
   sposobem, żeby wyłapać fail-open na `git fetch`.
2. **Sanity na żywo:** po zarejestrowaniu hooków nowa sesja Claude Code musi realnie blokować
   `git commit` na chronionym branchu, **i** musi dostać na starcie raport `session-start`
   (widoczny w `<system-reminder>` na początku transkryptu). Hooki wczytują się przy starcie
   sesji — jeśli instalujesz w trwającej sesji, powiedz człowiekowi, żeby raz otworzył `/hooks`
   albo zrestartował Claude Code. **Nie raportuj żadnego z hooków jako aktywnego, dopóki to
   się nie stanie.**
3. **Pierwszy PR = test całego flow.** Wypuść instalację dokładnie tak, jak opisuje `/ship`:
   branch → commit → push → `gh pr create` → `gh pr checks --watch --required` →
   `gh pr merge --squash --delete-branch`. Jeśli ten PR nie przejdzie, kit jest źle
   zainstalowany — nie „naprawiaj" go pchając na chroniony branch.
4. **Testy guarda odpal jeszcze raz na branchu roboczym** — przypadki deployowe `BLOCK`
   są pomijane na czystym, zsynchronizowanym chronionym branchu (bo tam guard słusznie przepuszcza).

---

## Krok 9. Wpięcie w `CLAUDE.md` docelowego repo

Kit działa tylko wtedy, gdy agent w tym repo o nim wie. Dopisz do `CLAUDE.md`:

- do mapy dokumentów: `**Praca zespołowa: branch → PR → merge → deploy (+ hooki blokujące)** → docs/AGENT-WORKFLOW.md`;
- do sekcji reguł twardych, zwięźle: nigdy nie pracuj na chronionym branchu; cykl
  `<inicjały>/<typ>/<slug>` → commit → push → `gh pr create` → `gh pr checks --watch --required`
  → `gh pr merge --squash --delete-branch`; deploy wyłącznie z chronionego brancha, z czystego
  drzewa; komendy `/start`, `/ship`, `/deploy`, `/rollback`, `/setup` (ta ostatnia **tylko** na
  wyraźne polecenie człowieka).

Jeśli `CLAUDE.md` nie istnieje — utwórz minimalny, z mapą dokumentów i tą sekcją.

---

## Krok 10. Raport (obowiązkowy)

Tabela: pozycja → `OK` / `pominięte (dlaczego)` / `wymaga człowieka (co dokładnie)`, dla:
pliki skopiowane · wariant `settings.json` · placeholdery (`grep {{FILL` = 0) · recipe deployu ·
CI (nazwy jobów) · ochrona brancha (albo dlaczego niedostępna) · testy guarda (`FAILURES: n`) ·
testy session-start (`FAILURES: n`) · pierwszy PR (link, wynik CI, merge) · wpis w `CLAUDE.md`.

Na końcu **jawnie**: czego nie dokończyłeś i co człowiek musi zrobić w przeglądarce
(`gh auth login`, logowanie do chmury, sekrety lokalne, uprawnienia do deployu, plan GitHuba).
Jedno zdanie na koniec: co się teraz zmienia w codziennej pracy (pięć komend z sekcji 1
kontraktu, w tym opcjonalny `/verify`) i że hooki zablokują pracę na chronionym branchu / będą
raportować stan drzewa na starcie sesji — to nie awaria, to kontrakt.
