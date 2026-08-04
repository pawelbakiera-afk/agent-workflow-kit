---
description: Wypuść chroniony branch na produkcję (preflight, deploy, tag, raport)
---

<!--
  SZKIELET — do wypełnienia przy instalacji kitu.
  Gotowe, kompletne wersje tej komendy per architektura leżą w kicie: `recipes/<architektura>/deploy.md`
  (cloud-run · vercel · docker-vps · no-deploy). Jeśli twoja architektura tam nie występuje,
  napisz własną wersję trzymając strukturę poniżej — preflight i tag są uniwersalne,
  zmienia się tylko komenda deployu i sposób identyfikacji „co jest na live".
-->

Wypuszczasz **`{{FILL:MAIN_BRANCH}}`** na produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md)
sekcja 3{{FILL:DEPLOY_DOC_REF — np. „, komendy: docs/DEPLOYMENT.md"}}.

{{FILL:DEPLOY_RISK — jednym zdaniem, dlaczego preflight nie jest formalnością w tej architekturze.
Np. dla `gcloud run deploy --source .` / `vercel --prod` / `docker build .`: „pakuje katalog z dysku, nie commit".
Dla deployu z CI: usuń całą tę komendę i zamiast niej opisz, że deploy odpala się sam po merge'u.}}

1. **Preflight (wszystkie po kolei):**
   - `git checkout {{FILL:MAIN_BRANCH}}` + `git pull`
   - `git status --porcelain` → musi być **pusto** (także brak nowych, nieśledzonych plików)
   - `git rev-parse HEAD` == `git rev-parse origin/{{FILL:MAIN_BRANCH}}`
   - bramki jakości: `{{FILL:BUILD_GATE}}` (+ `{{FILL:TEST_GATE}}`) → zielone

   Którykolwiek warunek niespełniony → **przerwij** i powiedz, co naprawić. Hook `guard` zablokuje deploy niezależnie od ciebie.

2. **Sprawdź kolizję z drugą osobą:** `{{FILL:LIST_RELEASES_CMD — komenda pokazująca ostatnie wydanie/rewizję z czasem}}`.
   Jeśli ostatnie wydanie ma mniej niż ~5 minut — ktoś prawdopodobnie właśnie deployuje. Zgłoś to i zaczekaj, nie deployuj równolegle.

3. **Deploy:** `{{FILL:DEPLOY_CMD}}`. Sukces = `{{FILL:DEPLOY_SUCCESS_SIGNAL — np. „pojawia się nowy numer rewizji"}}`.

4. **Tag** tego, co poszło na live (bez tego po dwóch tygodniach nikt nie odpowie na pytanie „co dokładnie siedzi na produkcji"):
   ```
   git tag -a "deploy/<YYYY-MM-DD>-<n>" -m "{{FILL:TAG_BODY — np. „rev <numer rewizji>"}}"
   git push origin --tags
   ```

5. **Raport:** {{FILL:REPORT_FIELDS — np. „numer rewizji, tag, SHA na chronionym branchu"}} + przypomnienie o `Ctrl+Shift+R`, jeśli produkt jest webowy (prod potrafi serwować stary bundle z cache'u).

{{FILL:PARTIAL_FAILURE_NOTE — co jest prawdą, gdy deploy padnie w połowie. Np. dla Cloud Run:
„jeśli deploy padnie w trakcie builda, na produkcji nadal działa stara rewizja, ruch nie został przekierowany".
Powiedz to wprost w raporcie, żeby nikt nie panikował.}}
