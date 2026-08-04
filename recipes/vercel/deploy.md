---
description: Wypuść main na produkcję (preflight, vercel --prod, tag, raport)
---

<!-- Recipe: Vercel, tryb B (deploy z CLI). W trybie Git integration USUŃ tę komendę. -->

Wypuszczasz **`main`** na produkcję Vercela. Kontrakt: [`docs/AGENT-WORKFLOW.md`](../../docs/AGENT-WORKFLOW.md) sekcja 3.

`vercel --prod` pakuje **katalog z dysku**, nie commit — dlatego preflight nie jest formalnością.

1. **Preflight (wszystkie, po kolei):**
   - `git checkout main` + `git pull`
   - `git status --porcelain` → **pusto** (także brak nieśledzonych plików)
   - `git rev-parse HEAD` == `git rev-parse origin/main`
   - bramki jakości (`<BUILD_GATE>`, `<TEST_GATE>`) → zielone

   Którykolwiek warunek niespełniony → **przerwij**. Hook `guard` zablokuje deploy niezależnie od ciebie.

2. **Sprawdź kolizję:** `vercel ls <projekt>` — jeśli najnowszy deployment produkcyjny ma mniej niż ~5 minut, ktoś prawdopodobnie właśnie deployuje. Zaczekaj.

3. **Deploy:** `vercel --prod`. Sukces = CLI wypisuje **Production URL** i nowy identyfikator deploymentu (`dpl_…`).

4. **Tag** tego, co poszło na live:
   ```
   git tag -a "deploy/<YYYY-MM-DD>-<n>" -m "vercel <dpl_id>"
   git push origin --tags
   ```

5. **Raport:** identyfikator deploymentu, Production URL, tag, SHA na `main` + przypomnienie o `Ctrl+Shift+R`.

Jeśli build padnie — produkcja **się nie zmienia**: alias produkcyjny zostaje na poprzednim deploymencie. Powiedz to wprost.
