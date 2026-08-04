---
description: Cofnij produkcję na poprzednią rewizję Cloud Run (~30 s, bez builda)
argument-hint: [nazwa rewizji, opcjonalnie]
---

<!-- Recipe: Cloud Run. Podmień <SERWIS>, <REGION>, <PROJEKT>. -->

Cofasz produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 4.

Kolejność jest nienegocjowalna: **najpierw ratujesz produkcję, potem naprawiasz repo.**

Na Windowsie `gcloud` zwykle nie jest na PATH — użyj pełnej ścieżki do `gcloud.cmd`.

1. **Wybierz rewizję.** Jeśli podano argument ($ARGUMENTS) — użyj jej. Jeśli nie:
   ```
   gcloud run revisions list --service <SERWIS> --region <REGION> --project <PROJEKT> --limit 5
   ```
   Weź tę bezpośrednio poprzedzającą aktualnie obsługującą ruch. Pokaż listę i wybór w jednym zdaniu.

2. **Przekieruj ruch** (żaden build się nie wykonuje, więc jest to szybkie i bezpieczne):
   ```
   gcloud run services update-traffic <SERWIS> --region <REGION> --project <PROJEKT> --to-revisions <rewizja>=100
   ```

3. **Potwierdź**, że ruch faktycznie idzie na wskazaną rewizję, i przypomnij o `Ctrl+Shift+R`.

4. **Dopiero teraz kod:** ustal SHA na `main`, które wywołało problem, i zaproponuj `git revert <sha>`
   przez normalny `/ship` (branch → PR → CI → merge). Nie commituj na `main` — hook to zablokuje, i słusznie.

Nie próbuj „naprawiać w locie" na produkcji. Rollback ruchu jest ścieżką awaryjną i nigdy nie jest blokowany przez hooki.
