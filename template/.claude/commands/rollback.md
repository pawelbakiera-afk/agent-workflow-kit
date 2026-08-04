---
description: Cofnij produkcję na poprzednie wydanie
argument-hint: [identyfikator wydania, opcjonalnie]
---

<!--
  SZKIELET — do wypełnienia przy instalacji kitu.
  Gotowe wersje per architektura: `recipes/<architektura>/rollback.md` w kicie.
  Uniwersalne jest tylko jedno i jest nienegocjowalne: NAJPIERW ratujesz produkcję,
  POTEM naprawiasz repo. Zmienia się wyłącznie mechanizm powrotu.
-->

Cofasz produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 4.

Kolejność jest nienegocjowalna: **najpierw ratujesz produkcję, potem naprawiasz repo.**

1. **Wybierz wydanie.** Jeśli podano argument ($ARGUMENTS) — użyj go. Jeśli nie:
   ```
   {{FILL:LIST_RELEASES_CMD}}
   ```
   Weź to bezpośrednio poprzedzające aktualnie obsługujące ruch. Pokaż listę i wybór w jednym zdaniu.

2. **Przywróć poprzednie wydanie:**
   ```
   {{FILL:ROLLBACK_CMD}}
   ```
   {{FILL:ROLLBACK_COST — czy to wymaga builda i ile trwa. Np. „żaden build się nie wykonuje, ~30 s"
   albo „wymaga ponownego builda, ~5 min — powiedz to userowi, zanim zaczniesz".}}

3. **Potwierdź**, że ruch faktycznie idzie na wskazane wydanie, i przypomnij o `Ctrl+Shift+R`.

4. **Dopiero teraz kod:** ustal SHA na `{{FILL:MAIN_BRANCH}}`, które wywołało problem, i zaproponuj `git revert <sha>`
   przez normalny `/ship` (branch → PR → CI → merge). Nie commituj na chronionym branchu — hook to zablokuje, i słusznie.

Nie próbuj „naprawiać w locie" na produkcji. Rollback jest ścieżką awaryjną i **nigdy** nie jest blokowany
przez hooki — upewnij się przy instalacji, że komenda rollbacku pasuje do `$DeployAllowPattern` w guardzie,
a nie do `$DeployPattern`.
