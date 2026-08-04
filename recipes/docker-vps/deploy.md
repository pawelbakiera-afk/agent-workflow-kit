---
description: Wypuść main na produkcję (preflight, build+push obrazu, up -d, healthcheck, tag)
---

<!-- Recipe: Docker Compose na VPS. Podmień <REG>, <APP>, <SERWER>, <HOST>. -->

Wypuszczasz **`main`** na produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 3.

`docker build .` bierze **katalog z dysku**, nie commit — dlatego preflight nie jest formalnością.

1. **Preflight (wszystkie, po kolei):**
   - `git checkout main` + `git pull`
   - `git status --porcelain` → **pusto** (także brak nieśledzonych plików)
   - `git rev-parse HEAD` == `git rev-parse origin/main`
   - bramki jakości (`<BUILD_GATE>`, `<TEST_GATE>`) → zielone

   Którykolwiek warunek niespełniony → **przerwij**. Hook `guard` zablokuje deploy niezależnie od ciebie.

2. **Ustal tag:** `SHA=$(git rev-parse --short HEAD)`. **Nigdy nie deployuj samego `latest`** — bez taga per commit nie ma do czego wrócić.

3. **Sprawdź kolizję:** `ssh <SERWER> "docker ps --format '{{.Image}} {{.RunningFor}}'"`. Jeśli obecny kontener wstał <5 minut temu, ktoś prawdopodobnie właśnie deployuje. Zaczekaj.

4. **Build + push + up:**
   ```
   docker build -t <REG>/<APP>:$SHA -t <REG>/<APP>:latest .
   docker push <REG>/<APP>:$SHA
   ssh <SERWER> "cd /srv/<APP> && IMAGE_TAG=$SHA docker compose up -d"
   ```

5. **Healthcheck — to krok, nie dobra praktyka:** `curl -fsS https://<HOST>/health`. Dodatkowo `ssh <SERWER> "docker ps"` — kontener musi chodzić na **nowym** tagu. Bez tego „sukces" znaczy tylko „docker nie krzyknął".

6. **Migracje bazy:** jeśli deploy je odpala, powiedz w raporcie **wprost**, czy poszły i czy schemat jest wstecz kompatybilny. Od tego zależy, czy `/rollback` w ogóle uratuje sytuację.

7. **Tag w gicie:**
   ```
   git tag -a "deploy/<YYYY-MM-DD>-<n>" -m "image <REG>/<APP>:$SHA"
   git push origin --tags
   ```

8. **Raport:** tag obrazu, wynik healthchecku, SHA na `main`, status migracji.

Jeśli padnie build albo push — produkcja się nie zmieniła. Jeśli padnie `up -d` — kontener może być **zatrzymany**; sprawdź `docker ps` i powiedz, jaki jest faktyczny stan, nie zakładaj.
