---
description: Odpal lokalnie to, co odbije CI — zanim pójdzie PR
---

Lokalne lustro `.github/workflows/ci.yml`. CI jest **jedyną** bramką przed mergem (nikt nikogo
nie zatwierdza), więc każdy czerwony check to stracona runda push → czekanie → fix → push.

**Wykonaj samodzielnie, bez pytania o zgodę na poszczególne kroki.** Nie naprawiaj nic po
drodze — najpierw zbierz pełny obraz, dopiero raport mówi, co jest do zrobienia.

1. **Zakres.** `git status --porcelain` i `git diff --name-only {{FILL:MAIN_BRANCH}}...HEAD`.
   Kroki dotyczące nietkniętej warstwy **pomiń i zapisz to w raporcie** (nie jako „PASS", tylko
   „pominięte — diff nie tyka `{{FILL:...}}`").
2. **Build:** `{{FILL:BUILD_GATE — komenda; „brak" jeśli projekt nie ma builda}}`.
3. **Testy:** `{{FILL:TEST_GATE — komenda; „brak" jeśli nie ma testów}}`. Podaj liczbę testów —
   jeśli dopisałeś testy w tym PR-ze, sprawdź, czy licznik faktycznie urósł.
4. **Lint**, jeśli projekt go ma: `{{FILL:LINT_GATE — komenda; „brak" jeśli nie ma lintu}}`.
   Rozróżnij errory (bramkują) od warningów (nie bramkują), jeśli narzędzie to rozdziela.
5. **Hooki** (gdy diff tyka `.claude/hooks/`): odpal testy guarda i session-start —
   Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/<plik>.tests.ps1`;
   macOS/Linux: `bash .claude/hooks/<plik>.tests.sh`. Oczekiwany ogon: `FAILURES: 0`. Hook, który
   cicho pada, wygląda dokładnie jak hook, który działa.
6. **Raport.** Zwięzła tabela + werdykt:

   ```
   build   PASS
   testy   PASS (42)
   lint    PASS (0 errorów)
   hooki   pominięte — diff nie tyka .claude/hooks/
   ```

   Werdykt „gotowe do `/ship`" tylko wtedy, gdy **każdy uruchomiony** krok jest PASS. Krok,
   który sam się wywalił (brak zależności, brak środowiska), raportuj jako BŁĄD NARZĘDZIA,
   nie jako PASS.

Ta komenda niczego nie commituje ani nie pushuje — to krok **przed** `/ship`, nie zamiast niego.
