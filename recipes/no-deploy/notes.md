# Recipe: brak lokalnego deployu

Trzy sytuacje, w których `/deploy` i `/rollback` **nie powinny istnieć w takiej formie**.
Wybierz swoją i nie zostawiaj martwych komend — komenda, która nic nie robi albo robi coś
innego niż mówi, jest gorsza niż jej brak.

## A. Deploy odpala CI po mergu (GitHub Actions → chmura)

```powershell
$DeployPattern = ''      # nie ma lokalnej komendy deployu, nie ma czego pilnować
```

Co zrobić:

1. **Usuń `.claude/commands/deploy.md` i `rollback.md`** — albo, lepiej, zamień je na komendy,
   które robią to, co ma sens w tym modelu:
   - `/deploy` → *„pokaż status ostatniego workflow deployowego i co jest na live"*
     (`gh run list --workflow deploy.yml --limit 5`, `gh run watch <id>`)
   - `/rollback` → *„cofnij przez `git revert` + PR, albo re-run poprzedniego udanego deployu"*
     (`gh run rerun <id>` na starszym, zielonym runie — jeśli wasz workflow to umożliwia).
2. W sekcji 1 kontraktu napisz **wprost**: `/ship` = deploy. To najważniejsze zdanie w tym
   modelu — inaczej ktoś scali „na później" i po dwóch minutach będzie to na produkcji.
3. Sekcje 3 i 4 kontraktu przepisz na: „co dokładnie robi workflow deployowy, jak sprawdzić
   jego status, ile trwa, jak wygląda awaryjne cofnięcie".
4. **Ochrona nie znika, przenosi się**: skoro merge = produkcja, required checks stają się
   jedyną bramką. Nie zostawiaj CI, które tylko lintuje.

## B. Biblioteka / paczka (npm, PyPI, NuGet) — „deploy" to publikacja wersji

```powershell
$DeployPattern      = '^(&\s*)?\S*(npm|pnpm|yarn)(\.cmd)?"?\s+publish\b'
$DeployAllowPattern = ''
```

ERE:

```bash
DEPLOY_PATTERN='^(&[[:space:]]*)?[^[:space:]]*(npm|pnpm|yarn)(\.cmd)?"?[[:space:]]+publish([[:space:]]|$)'
```

Preflight jest tu **jeszcze ważniejszy** niż w aplikacji webowej: `npm publish` pakuje katalog
z dysku, a opublikowanej wersji **nie da się cofnąć** (unpublish jest ograniczony i psuje
zależności innych). Zamiast `/rollback` masz tylko `/deploy` nowej, wyższej wersji z fixem —
napisz to w kontrakcie wprost, bo to zmienia sposób myślenia o ryzyku.

W `/deploy` dodaj kroki, których nie ma w wariancie webowym: bump wersji w osobnym PR-ze
(wersja musi być w gicie **przed** publikacją), tag = wersja (`v1.4.2`), changelog.

## C. Projekt wewnętrzny bez produkcji (skrypty, analizy, prototyp)

```powershell
$DeployPattern = ''
```

Usuń `/deploy` i `/rollback`, usuń sekcje 3–4 kontraktu, zostaw sekcje 0–2 i 5–8. Kit ma wtedy
nadal sens: chroni `main`, wymusza PR + CI i daje dwóm agentom wspólne zasady pracy.
To najczęstszy przypadek przy starcie nowego repo — i najlepszy moment, żeby wpiąć kit,
zanim ktoś zdąży wypracować własne nawyki.
