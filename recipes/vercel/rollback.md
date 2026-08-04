---
description: Cofnij produkcję na poprzedni deployment Vercela (bez builda)
argument-hint: [id lub URL deploymentu, opcjonalnie]
---

<!-- Recipe: Vercel. -->

Cofasz produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 4.

Kolejność jest nienegocjowalna: **najpierw ratujesz produkcję, potem naprawiasz repo.**

1. **Wybierz deployment.** Jeśli podano argument ($ARGUMENTS) — użyj go. Jeśli nie:
   ```
   vercel ls <projekt>
   ```
   Weź ostatni **udany** deployment produkcyjny poprzedzający obecny. Pokaż listę i wybór w jednym zdaniu.

2. **Przywróć go** (nic się nie buduje — Vercel przełącza alias na gotowy artefakt):
   ```
   vercel rollback <deployment-id-lub-url>
   ```
   Jeśli `rollback` nie jest dostępny w waszym planie/wersji CLI, użyj `vercel promote <deployment-id>`.

3. **Potwierdź**, że produkcyjny URL serwuje przywróconą wersję, i przypomnij o `Ctrl+Shift+R`.

4. **Uwaga na zmienne środowiskowe:** rollback cofa **kod**, nie zmienne w Vercelu. Jeśli awarię
   spowodowała zmiana `env`, cofnij ją osobno (`vercel env`) i powiedz o tym userowi.

5. **Dopiero teraz kod:** ustal SHA na `main`, które wywołało problem, i zaproponuj `git revert <sha>`
   przez normalny `/ship`. Nie commituj na `main` — hook to zablokuje, i słusznie.
