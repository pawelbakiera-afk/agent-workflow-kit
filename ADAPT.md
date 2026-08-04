# ADAPT — co jest uniwersalne, co podmieniasz i gdzie

Referencja dla agenta w trakcie instalacji (`INSTALL.md`) oraz później, gdy w projekcie
zmienia się architektura deployu. Cztery sekcje: co jest niezmienne · tabela placeholderów ·
jak napisać własny recipe · jak zaktualizować kit w działającym repo.

---

## 1. Co jest uniwersalne, a co projektowe

| Plik | Zmienia się przy nowym projekcie? |
|---|---|
| `guard.ps1` / `guard.sh` — logika git (main, force push, rozpoznawanie wywołań) | **nie** — tylko blok CONFIG na górze |
| `guard.ps1` / `guard.sh` — sekcja deploy | tylko wzorce w CONFIG |
| `guard.tests.*` — przypadki gitowe | **nie** |
| `guard.tests.*` — przypadki deployowe | tak, z recipe |
| `commands/start.md` | prawie nie (branch, inicjały) |
| `commands/ship.md` | bramki jakości + slug repo |
| `commands/setup.md` | zależności, narzędzia deployu, sekrety |
| `commands/deploy.md`, `rollback.md` | **całkowicie** — bierz z recipe |
| `docs/AGENT-WORKFLOW.md` sekcje 0–2, 5–8 | prawie nie |
| `docs/AGENT-WORKFLOW.md` sekcje 3–4 | **całkowicie** — deploy/rollback |
| `ci.yml` | szablon per stack |
| ochrona brancha na GitHubie | tylko nazwy checków |

Wniosek praktyczny: **90% kitu jest niezmienne, a całe ryzyko siedzi w deployu.** Tam skup
uwagę — resztę przepisz mechanicznie.

---

## 2. Tabela placeholderów

Wszystkie mają postać `{{FILL:NAZWA — podpowiedź}}`. Po instalacji `grep -rn "{{FILL"` musi
zwracać pustkę (INSTALL.md krok 5).

| Placeholder | Skąd wziąć wartość | Występuje w |
|---|---|---|
| `MAIN_BRANCH` | `gh repo view --json defaultBranchRef` | guard (CONFIG), wszystkie komendy, kontrakt, ci.yml |
| `REPO_SLUG` | `gh repo view --json nameWithOwner` | ship, setup, kontrakt |
| `REPO_URL` | `git remote get-url origin` | setup |
| `TEAM_SIZE` | pytanie/`git shortlog -sne` | kontrakt |
| `INITIALS_RULE` | wzorzec adresów w `git log` | start, kontrakt |
| `EMAIL_DOMAIN` | jw. | setup |
| `BUILD_GATE` | skrypty `package.json` / istniejące CI | ship, setup, deploy, kontrakt |
| `TEST_GATE` | `pytest.ini`, `tests/`, skrypty | ship, setup, deploy, kontrakt |
| `CI_CHECK_NAMES` | nazwy jobów w `ci.yml` | kontrakt, ochrona brancha |
| `DEPS_SETUP` | menedżery pakietów w repo | setup |
| `LOCAL_SECRETS` | `.env.example`, README | setup |
| `DEPLOY_TOOLING` | recipe | setup |
| `HOTSPOT_FILES` | `git log --format= --name-only -300 \| sort \| uniq -c \| sort -rn \| head -20` | kontrakt §2.4 |
| `MANUAL_ONBOARDING` | recipe + realia dostępów | kontrakt §7 |
| `DEPLOY_GUARD_PATTERN` (.NET) | recipe | guard.ps1 |
| `DEPLOY_GUARD_PATTERN_ERE` | recipe | guard.sh |
| `DEPLOY_ALLOW_PATTERN(_ERE)` | recipe (ścieżka rollbacku!) | guard.ps1 / guard.sh |
| `DEPLOY_TEST_CASES(_SH)` | recipe | guard.tests.* |
| `DEPLOY_CMD`, `LIST_RELEASES_CMD`, `ROLLBACK_CMD` | recipe | deploy, rollback |
| `DEPLOY_SUCCESS_SIGNAL`, `TAG_BODY`, `ROLLBACK_COST`, `PARTIAL_FAILURE_NOTE` | recipe | deploy, rollback |
| `DEPLOY_SECTION`, `ROLLBACK_SECTION`, `DEPLOY_REPORT`, `DEPLOY_RISK`, `DEPLOY_QUESTION`, `DEPLOY_DOC_REF` | recipe | kontrakt §3–4, ship, deploy |
| `APP_DIR` / `FRONTEND_DIR` / `BACKEND_DIR`, `NODE_VERSION`, `PYTHON_VERSION`, `APP_ENTRY_MODULE` | struktura repo, wersje z produkcji | ci-templates |

---

## 3. Trzy pułapki, które kosztowały najwięcej czasu

1. **ASCII w plikach guarda.** Windows PowerShell 5.1 czyta skrypty `-File` w kodowaniu ANSI:
   bajt `0x94` (część pauzy `—`) dekoduje się jako cudzysłów i **cicho** rozwala parsowanie.
   Skutek: hook przepuszcza wszystko i wygląda dokładnie jak działający. Dlatego komunikaty
   guarda są po angielsku i bez znaków diakrytycznych — a testy uruchamiasz po **każdej** edycji.
2. **Dwa dialekty regexu.** `guard.ps1` = regex .NET (`\s`, `\b`, lookaheady OK).
   `guard.sh` = POSIX ERE (**nic z tego nie działa**; zamiast `(?![\w-])` używa się
   `([[:space:]]|$)`). Wzorzec wklejony z jednego do drugiego nie dopasuje niczego —
   i znowu: cicha utrata ochrony, nie błąd.
3. **Rozpoznawanie wywołania, nie wzmianki.** Guard dzieli komendę na segmenty i dopasowuje
   od **początku** segmentu, dlatego `gh pr create --body "...git push..."` przechodzi.
   Jeśli poluzujesz wzorzec (np. dopuścisz dopasowanie w środku), zaczniesz blokować własne
   opisy PR-ów. Każda zmiana wzorca → nowy przypadek w testach.

4. **`$ErrorActionPreference` w `guard.ps1` MUSI zostać `'Continue'`.** W Windows PowerShell
   5.1 stderr komendy natywnej jest owijane w `ErrorRecord`; przy `'Stop'` staje się błędem
   przerywającym, łapie go catch-all na dole i guard **fail-open**. Praktyczny skutek: gdy
   `git fetch` cokolwiek wypisze (brak `origin`, brak sieci, prompt o hasło), guard przestaje
   pilnować deployu — dokładnie w momencie, w którym najbardziej powinien. Dlatego każde
   wywołanie gita sprawdzamy przez `$LASTEXITCODE` / puste wyniki, a `fetch` jest w `try{}catch{}`.
   **Test regresyjny:** odpal testy guarda w repo **bez** remote'a `origin` — przypadki deployowe
   muszą nadal blokować (na branchu roboczym). To był realny błąd, znaleziony dopiero tak.
5. **`-C` to ścieżka, `-c` to config.** `-match` w PowerShellu ignoruje wielkość liter, więc
   `git -c user.name=X commit` bywa czytane jako „operacja na innym repo" i przechodzi.
   Rozpoznanie ścieżki idzie przez `-cnotmatch` (case-sensitive) — nie „upraszczaj" tego z powrotem.

Szósta, mniej oczywista: **guard jest fail-open i taki ma zostać.** Nie „napraw" tego na
fail-closed — zepsuty guard zablokowałby wtedy całą pracę zespołu. To narzędzie od łapania
pomyłek, nie bramka bezpieczeństwa; bramką jest GitHub (ochrona brancha).

Świadoma decyzja przy tym: komenda celująca w **inne** repo (`git -C <ścieżka> …`) nie jest
blokowana — także `push --force`. Bez tego agent nie mógłby tknąć żadnego innego checkoutu
(repo testowego, sąsiedniego projektu), gdy ten projekt stoi na chronionym branchu.

---

## 4. Jak napisać własny recipe (architektura nieobsługiwana)

Skopiuj `recipes/cloud-run/` jako wzór i odpowiedz w `notes.md` na sześć pytań:

1. **Czym jest „wydanie"?** (rewizja, deployment, tag obrazu, wersja paczki) — bez tego nie da
   się ani otagować tego, co na live, ani wskazać, do czego wrócić.
2. **Czy deploy pakuje katalog z dysku, czy commit z gita?** Jeśli katalog → preflight
   (czyste drzewo, HEAD == origin) jest **obowiązkowy** i `DeployPattern` musi łapać tę komendę.
   Jeśli deploy leci z CI → `DeployPattern = ''` i zamiast `/deploy` daj komendę statusową.
3. **Jak wygląda rollback i ile trwa?** Czy wymaga builda? Czy poprzedni artefakt jeszcze
   istnieje? Wpisz komendę rollbacku do `DeployAllowPattern`, żeby guard nigdy jej nie zablokował.
4. **Jak sprawdzić kolizję dwóch deployów?** Komenda listująca wydania z czasem.
5. **Co jest prawdą, gdy deploy padnie w połowie?** (stara wersja dalej działa / kontener
   zatrzymany / ruch przełączony częściowo) — agent musi to powiedzieć userowi wprost.
6. **Co rollback kodu NIE cofa?** Zmienne środowiskowe po stronie platformy, migracje bazy,
   opublikowana paczka. To najczęstsze źródło „cofnęliśmy i nie pomogło".

Do tego dwa wzorce regexu (.NET + ERE) i przypadki testowe dla obu wariantów guarda.
Gdy skończysz — dopisz recipe do tabeli w `README.md` i wypchnij do kitu; następny projekt
dostanie to gotowe.

---

## 5. Aktualizacja kitu w działającym repo

Kit nie ma mechanizmu wersjonowania w docelowym repo — celowo, żeby nie udawać, że to menedżer
pakietów. Procedura ręcznej aktualizacji:

1. W kicie zobacz, co się zmieniło (`git log --oneline`, `git diff <poprzedni-tag>..HEAD -- template/`).
2. W docelowym repo zrób branch (`/start aktualizacja kitu`).
3. Przenieś **tylko logikę**, nigdy blok CONFIG i nie nadpisuj wypełnionych placeholderów.
   Praktycznie: `git diff` na plikach guarda, ręczne wklejenie zmian w logice.
4. Uruchom testy guarda (`FAILURES: 0`) i wypuść normalnym `/ship`.

Jeśli zmiana w kicie dotyczy dokumentu (`AGENT-WORKFLOW.md`), przenoś fragmenty, nie cały plik —
w docelowym repo ten dokument jest już dopasowany do projektu i zwykle ma dopiski, których w kicie nie ma.

**W drugą stronę też:** jeśli w projekcie wymyślisz coś, co zadziała (nowy przypadek testowy,
nowa pułapka, lepsze sformułowanie zasady), wypchnij to **do kitu**. Kit żyje z tego, że wraca
do niego doświadczenie z projektów, a nie z tego, że został raz napisany.
