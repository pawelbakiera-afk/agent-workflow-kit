---
description: Wypuść main na produkcję (preflight, deploy Cloud Run, tag, raport)
---

<!-- Recipe: Cloud Run. Podmień <SERWIS>, <REGION>, <PROJEKT> i ścieżkę do dokumentacji deployu. -->

Wypuszczasz **`main`** na produkcję. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md)
sekcja 3, komendy: [`docs/DEPLOYMENT.md`](../../docs/DEPLOYMENT.md).

`gcloud run deploy --source .` pakuje **katalog z dysku**, nie commit — dlatego preflight nie jest formalnością.

1. **Preflight (wszystkie cztery, po kolei):**
   - `git checkout main` + `git pull`
   - `git status --porcelain` → musi być **pusto** (także brak nowych, nieśledzonych plików)
   - `git rev-parse HEAD` == `git rev-parse origin/main`
   - bramki jakości (`<BUILD_GATE>`, `<TEST_GATE>`) → zielone

   Którykolwiek warunek niespełniony → **przerwij** i powiedz, co naprawić. Hook `guard` zablokuje deploy niezależnie od ciebie.

2. **Sprawdź kolizję:** `gcloud run revisions list --service <SERWIS> --region <REGION> --project <PROJEKT> --limit 1`.
   Jeśli najnowsza rewizja ma mniej niż ~5 minut — druga osoba prawdopodobnie właśnie deployuje. Zgłoś to i zaczekaj, nie deployuj równolegle.

3. **Deploy** — dokładnie komendą z `DEPLOYMENT.md` (na Windowsie `gcloud` zwykle nie jest na PATH; użyj pełnej ścieżki do `gcloud.cmd`). Sukces = pojawia się **nowy** numer rewizji `<SERWIS>-000NN`.

4. **Tag** tego, co poszło na live (dzisiejsza data, `<n>` = kolejny deploy dnia):
   ```
   git tag -a "deploy/<YYYY-MM-DD>-<n>" -m "rev <SERWIS>-000NN"
   git push origin --tags
   ```

5. **Raport:** numer rewizji, tag, SHA na `main` + przypomnienie o `Ctrl+Shift+R` (prod potrafi serwować stary bundle z cache'u).

Jeśli deploy padnie w trakcie builda — na produkcji **nadal działa stara rewizja**, ruch nie został przekierowany. Powiedz to wprost, żeby nikt nie panikował.
