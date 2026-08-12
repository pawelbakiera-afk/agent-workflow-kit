---
description: Opublikuj pracę — build, commit, push, PR, CI, squash-merge, sync
---

Publikujesz zrobioną pracę do `{{FILL:REPO_SLUG}}`. Kontrakt:
[`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 2.3.

**Wykonaj całą sekwencję samodzielnie, bez pytania o zgodę na poszczególne kroki.**
Nie oznaczaj nikogo jako reviewera i nie czekaj na akceptację — każdy scala własne PR-y sam.

1. **Bramki lokalne** (dokładnie te, które sprawdza CI — inaczej dowiesz się o błędzie dopiero
   z PR-a; jeśli już odpaliłeś `/verify` w tej sesji i było zielone, nie odpalaj drugi raz):
   - build: `{{FILL:BUILD_GATE — komenda, np. `npm run build` w `frontend/`; „brak" jeśli projekt nie ma builda}}`
   - testy: `{{FILL:TEST_GATE — komenda, np. `python -m pytest -q` w `backend/`; „brak" jeśli nie ma testów}}`

   Czerwone → napraw i zacznij od nowa; **nie idź dalej**.
2. **Branch:** jeśli jesteś na `{{FILL:MAIN_BRANCH}}`, zrób `git checkout -b <inicjały>/<typ>/<slug>` (inicjały z `git config user.email`). Hook i tak zablokuje commit na chronionym branchu.
3. **Commit(y):** tematyczne, w konwencji repo (`feat(scope): …`, `fix(scope): …`). Kilka obszarów → kilka commitów, nie jeden gruby.
4. **Push:** `git push -u origin <branch>`.
5. **PR:** `gh pr create --base {{FILL:MAIN_BRANCH}} --title "<tytuł>" --body "<opis>"`. **Podawaj tytuł jawnie** — samo `--fill` przy więcej niż jednym commicie wstawia jako tytuł nazwę brancha i taki śmieć zostaje na chronionym branchu po squashu. Tytuł w konwencji commitów; w opisie krótko *co* i *dlaczego*, oraz jak to zweryfikowano.
6. **CI:** `gh pr checks <nr> --watch --required --interval 15`. **Uwaga na wyścig:** run CI potrafi pojawić się nawet ~90 s po utworzeniu PR-a, a `--watch` śledzi tylko checki istniejące w momencie startu — bez `--required` komenda wyjdzie zielona po samym firmowym skanie sekretów, a merge i tak odbije się od polityki brancha. Jeśli zwróci „no required checks", odczekaj kilkanaście sekund i powtórz. Czerwone → napraw, wypchnij poprawkę, poczekaj ponownie.
7. **Merge:** `gh pr merge --squash --delete-branch`. Jeśli GitHub odbije merge, bo branch jest **za** chronionym branchem (ochrona wymaga aktualnego brancha): `gh pr update-branch`, poczekaj ponownie na CI (krok 6), dopiero potem scalaj.
8. **Sync:** `git checkout {{FILL:MAIN_BRANCH}}` + `git pull`.
9. **Raport:** link do PR-a, SHA na `{{FILL:MAIN_BRANCH}}`, wynik CI. {{FILL:DEPLOY_QUESTION — jeśli projekt ma osobny deploy: „Zapytaj jednym zdaniem, czy wypuścić to na live przez `/deploy` — sam tego nie rób."; jeśli deploy jest automatyczny z CI: „Powiedz, że merge do chronionego brancha sam uruchomił deploy i podaj, gdzie sprawdzić jego status."}}

Jeśli którykolwiek krok padnie, zatrzymaj się na nim, powiedz co dokładnie i dlaczego, i nie udawaj, że reszta się udała.
