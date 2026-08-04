---
description: Zacznij nowe zadanie na świeżym branchu (sync main + branch)
argument-hint: <krótki opis zadania>
---

Zaczynasz nowe zadanie: **$ARGUMENTS**

Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 2.1. Wykonaj bez dopytywania:

1. Jeśli w drzewie są niezacommitowane zmiany — **nie kasuj ich**; przejdą na nowy branch razem z tobą. Wspomnij o nich w podsumowaniu.
2. `git checkout {{FILL:MAIN_BRANCH}}` i `git pull` (jeśli już jesteś na branchu roboczym z niezakończoną pracą — zatrzymaj się i powiedz o tym, zamiast przełączać).
3. Ustal inicjały z `git config user.email` ({{FILL:INITIALS_RULE — np. „wzorzec imie.nazwisko@firma.com → in"}}).
4. Wyznacz typ zmiany (`feat` / `fix` / `docs` / `chore` / `polish`) i krótki slug z opisu zadania.
5. `git checkout -b <inicjały>/<typ>/<slug>`.
6. Zaraportuj jednym zdaniem: nazwa brancha, od jakiego SHA `{{FILL:MAIN_BRANCH}}` startujesz, czy przeniosły się jakieś zmiany.

Potem wracaj do normalnej pracy nad zadaniem według `CLAUDE.md`.
