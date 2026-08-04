---
description: Jednorazowa konfiguracja maszyny do pracy w tym repo (idempotentna, uruchamiana ręcznie)
---

Konfigurujesz **maszynę** do pracy w tym repo. Kontrakt pracy: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md).

**Zasada nadrzędna: najpierw sprawdź, potem działaj — i tylko tam, gdzie czegoś brakuje.**
Ta komenda ma być bezpieczna przy dziesiątym uruchomieniu tak samo jak przy pierwszym.
Nie reinstaluj tego, co już jest; nie nadpisuj konfiguracji, która jest poprawna.

> Uruchamia ją **człowiek**, raz na maszynę (albo po zmianie hooków). Nigdy nie odpalaj jej
> sam z siebie — ani przy starcie sesji, ani po przeczytaniu `CLAUDE.md`.

1. **Remote.** `git remote -v` → `origin` musi wskazywać `{{FILL:REPO_URL}}`. Jakikolwiek inny remote (prywatny fork) → usuń. Ustaw `git branch --set-upstream-to=origin/{{FILL:MAIN_BRANCH}} {{FILL:MAIN_BRANCH}}` oraz `git config pull.rebase true`.

2. **Tożsamość gita.** `git config user.name` i `user.email` muszą być ustawione, a e-mail być firmowy ({{FILL:EMAIL_DOMAIN}}) — z niego biorą się inicjały w nazwach branchy i autorstwo commitów. Globalny e-mail prywatny → ustaw lokalnie w repo (`git config user.email …`), nie ruszaj globalnego.

3. **gh CLI.** Zainstalowane i zalogowane (`gh auth status`)? Scope'y muszą zawierać **`repo` i `workflow`** — bez `workflow` GitHub odrzuci push zmieniający cokolwiek w `.github/workflows/`. Brakuje scope'a → odpal `gh auth refresh -s workflow -h github.com` **w tle**, odczytaj kod device flow z outputu i podaj go użytkownikowi do wklejenia na https://github.com/login/device (user nie wpisuje komend). Na koniec `gh repo set-default {{FILL:REPO_SLUG}}`.

4. **Hooki — NIC nie instaluj.** `.claude/settings.json` i `.claude/hooks/` są w repo, więc świeży klon już je ma, a Claude Code wczytuje ustawienia projektu przy starcie sesji. Twoje zadanie to **weryfikacja, nie instalacja** — uruchom test guarda właściwy dla tego systemu:
   - Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.tests.ps1`
   - macOS / Linux: `bash .claude/hooks/guard.tests.sh`

   Oczekiwany ogon: `FAILURES: 0`. Cokolwiek innego → guard nie chroni. Najczęstsze przyczyny:
   - **Windows:** ktoś wprowadził do `guard.ps1` znak spoza ASCII (patrz nagłówek pliku) — cicha awaria parsowania, hook przepuszcza wszystko.
   - **macOS / Linux:** brak `jq` **i** `python3` — guard nie ma czym sparsować wejścia hooka i fail-open. Zainstaluj jedno z nich (`brew install jq`).
   - Hooki doszły już po starcie tej sesji → powiedz userowi, żeby raz otworzył `/hooks` albo zrestartował Claude Code.

5. **Zależności projektu.** {{FILL:DEPS_SETUP — konkretnie dla tego repo, np. „Jest `backend/.venv`? Nie → utwórz i zainstaluj `requirements-dev.txt`. Jest `frontend/node_modules`? Nie → `npm install`."}}

6. **Bramki jakości.** Uruchom `{{FILL:BUILD_GATE}}` i `{{FILL:TEST_GATE}}` — obie muszą być zielone. Jeśli nie są na świeżym klonie, to nie wina maszyny; zgłoś to jako problem repo.

7. **Narzędzia deployu** (potrzebne tylko do `/deploy`). {{FILL:DEPLOY_TOOLING — np. „gcloud zainstalowany, zalogowany, projekt X" / „vercel CLI + `vercel link`" / „nic — deploy idzie z CI"}}. Logowanie wymaga przeglądarki — jeśli go brakuje, poproś użytkownika, nie próbuj sam.

8. **Sekrety / dostępy lokalne.** {{FILL:LOCAL_SECRETS — np. „klucz SA do BQ + `backend/.env`, procedura w README"; „brak" jeśli projekt nie potrzebuje}}. Sekretów nie da się wygenerować za użytkownika; jeśli ich nie ma, powiedz, od kogo je wziąć.

Na koniec pokaż **tabelę**: pozycja → `OK` / `naprawione` / `wymaga człowieka (co dokładnie)`. Nie raportuj sukcesu tam, gdzie tylko sprawdziłeś obecność pliku — przy hookach i testach liczy się wynik uruchomienia.
