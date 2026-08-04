---
description: Cofnij produkcję na poprzedni obraz (bez builda, jeśli tag jest w registry)
argument-hint: [tag obrazu / SHA, opcjonalnie]
---

<!-- Recipe: Docker Compose na VPS. Podmień <REG>, <APP>, <SERWER>, <HOST>. -->

Cofasz produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 4.

Kolejność jest nienegocjowalna: **najpierw ratujesz produkcję, potem naprawiasz repo.**

1. **Sprawdź, czy rollback kodu wystarczy.** Jeśli ostatni deploy odpalał **migracje bazy**
   i nie wiesz, czy schemat jest wstecz kompatybilny — **zapytaj człowieka, zanim cofniesz**.
   Cofnięcie aplikacji pod zmigrowaną bazę potrafi zrobić większą szkodę niż sama awaria.

2. **Wybierz tag.** Jeśli podano argument ($ARGUMENTS) — użyj go. Jeśli nie: weź poprzedni tag
   `deploy/*` z gita (`git tag --sort=-creatordate | head -5`) albo listę obrazów w registry.
   Sprawdź, że obraz **istnieje** (`docker manifest inspect <REG>/<APP>:<sha>`) — inaczej rollback
   zamieni się w build i potrwa minuty, nie sekundy. Powiedz userowi, który wariant zachodzi.

3. **Przywróć:**
   ```
   ssh <SERWER> "cd /srv/<APP> && IMAGE_TAG=<poprzedni-sha> docker compose up -d"
   ```

4. **Potwierdź:** `curl -fsS https://<HOST>/health` + `ssh <SERWER> "docker ps"` (tag musi być ten, o który prosiłeś). Przypomnij o `Ctrl+Shift+R`, jeśli produkt jest webowy.

5. **Dopiero teraz kod:** ustal SHA na `main`, które wywołało problem, i zaproponuj `git revert <sha>`
   przez normalny `/ship`. Nie commituj na `main` — hook to zablokuje, i słusznie.
