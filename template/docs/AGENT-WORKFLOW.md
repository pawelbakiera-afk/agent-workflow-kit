# Agent workflow — jak pracujemy w kilka osób

Repo prowadzi **{{FILL:TEAM_SIZE — np. „dwie osoby"}}, każda przez agenta** (Claude Code). Nikt tu nie pisze
komend gita ręcznie i nikt nie czeka na czyjąś zgodę. Ten plik jest kontraktem: **sekcja 1 dla
ludzi, sekcje 2–8 dla agenta** (wykonuj bez dopytywania).

Repozytorium jest jedno: **`{{FILL:REPO_SLUG}}`** = zdalny `origin`. Nie ma forków,
nie ma drugiego remote'a, nie ma „mojej kopii".

---

## 0. Pięć zasad kardynalnych

1. **Jedno repo, jeden `origin`** — `{{FILL:REPO_SLUG}}`. Praca nigdy nie ląduje w prywatnym forku.
2. **Zero akceptacji, zero review.** Każdy scala własne PR-y sam. Bramką jest **CI, nie człowiek**.
3. **`{{FILL:MAIN_BRANCH}}` jest zawsze deployowalny.** Wchodzi się na niego wyłącznie zmergowanym PR-em z zielonym CI.
4. **Na live idzie tylko `{{FILL:MAIN_BRANCH}}`, z czystego drzewa, zsynchronizowany z `origin/{{FILL:MAIN_BRANCH}}`.**
5. **Nigdy `push --force`.** Historię naprawia się nowym commitem albo `git revert`.

Zasady 3–5 nie są prośbą — pilnuje ich hook (sekcja 6), który zablokuje komendę i wyjaśni dlaczego.

---

## 1. Dla ludzi — pięć komend i tyle

| Chcesz…                          | Wpisz                    |
|----------------------------------|--------------------------|
| zacząć nowe zadanie              | `/start <krótki opis>`   |
| sprawdzić przed publikacją       | `/verify`                |
| opublikować gotową pracę         | `/ship`                  |
| wypuścić na produkcję            | `/deploy`                |
| cofnąć produkcję po wpadce       | `/rollback`              |

Nic więcej nie musisz pamiętać. Agent nie pyta o pozwolenie na żaden krok w środku tych
komend — sam robi branch, commit, push, PR, czeka na CI, scala i sprząta. `/verify` jest
opcjonalne dla ciebie — `/ship` i tak odpali te same bramki przed publikacją — ale jeśli chcesz
zobaczyć wynik przed commitem, poproś o `/verify`.

**Co widzisz po `/ship`:** link do PR-a, wynik CI, potwierdzenie merge'a. **Po `/deploy`:**
{{FILL:DEPLOY_REPORT — co user zobaczy, np. „numer nowej rewizji i tag, który mówi, co siedzi na live"}}.

Jedna rzecz, o której warto wiedzieć: **`/ship` nie wypuszcza na produkcję.** Publikuje do
repo. Produkcja to osobna, świadoma decyzja — `/deploy`.

---

## 2. Kontrakt dla agenta — cykl życia zmiany

### 2.0 Triage — tryb pracy wybiera AGENT, nie człowiek

Ludzie prowadzący to repo pracują wyłącznie przez agenta i **nie mają obowiązku wiedzieć**,
kiedy poprosić o worktree, subagenta czy świeżą sesję. To twoja robota: rozpoznaj przed pierwszą
edycją, zdecyduj sam, zamelduj jednym zdaniem. **Nie pytaj o zgodę na tryb** — user może
nadpisać, ale nie musi wybierać.

**Krok 1 — zbadaj drzewo (zawsze, przed pierwszą edycją).** Jeśli w repo jest hook
`session-start` (sekcja 6) — jego raport na starcie sesji już zrobił to za ciebie. Jeśli nie:

```
git status --porcelain=v1 --branch    # gdzie jestem i czy jest brudno
git worktree list                     # czy ktoś już siedzi obok
```

| Co widzisz | Tryb |
|---|---|
| `{{FILL:MAIN_BRANCH}}`, czysto | zwykły branch (2.1) |
| `{{FILL:MAIN_BRANCH}}` + zmiany, które **sam** zrobiłeś w tej sesji | branch teraz; zmiany idą z tobą, nic nie ginie |
| **branch roboczy, którego nie utworzyłeś w tej sesji**, albo niezacommitowane zmiany nie twojego autorstwa | **worktree** — `git worktree add .claude/worktrees/<slug> -b <inicjały>/<typ>/<slug> origin/{{FILL:MAIN_BRANCH}}`. Nigdy `checkout`: przełączenie wyrywa drzewo drugiej sesji w połowie pracy |
| user prosi „zrób to w tle / drugi agent / przy okazji", a poprzednie zadanie jeszcze żyje | **worktree** |

**Krok 2 — policz niezależne tematy.** Temat = jeden przyszły PR: własny obszar, własne
uzasadnienie w commicie, sensowny do cofnięcia osobno.

| Tematów | Jak pracujesz | PR-y |
|---|---|---|
| 1 | jeden agent, jeden branch, bez ceremonii | 1 |
| 2–3 | jeden agent, tematy **po kolei** (branch → PR → merge → następny) | 1 na temat |
| 4+ albo wklejona lista zgłoszeń | najpierw **recon read-only** (subagenty, po jednym na rozłączny obszar), potem **plan na dysk**, potem temat po temacie | 1 na temat |

Nigdy nie łącz kilku tematów w jeden PR „żeby było szybciej" — jeden odrzucony punkt blokuje
wtedy wszystkie pozostałe, a `git revert` przestaje być narzędziem chirurgicznym.

**Krok 3 — plan na dysk, gdy tematów jest 4+** (np. `docs/tasks/<data>-<slug>.md`, idzie do repo
razem z pracą): punkt → plik/moduł, grupowanie w PR-y, **dosłowne** decyzje usera, stan każdego
punktu. Aktualizuj po każdym merge'u. Plan trzymany tylko w kontekście sesji ginie, jeśli sesja
się przerywa — bez niego długa sesja z wieloma PR-ami nie da się bezpiecznie oddać dalej.

**Krok 4 — handoff, gdy padnie którykolwiek próg** (nie czekaj, aż user zapyta):

- zmergowałeś **drugi** PR w tej sesji,
- zaczynasz **trzeci** temat,
- odpalił się ostrzegacz rozmiaru kontekstu, albo sesja idzie już długo,
- przed tobą recon zupełnie nowego obszaru (świeży kontekst jest tańszy niż doczytywanie).

Wtedy: **domknij bieżący temat** (merge — handoff w połowie zadania jest gorszy niż jego brak),
zaktualizuj plan, oddaj handoff i powiedz wprost: „resztę zrobimy w świeżej sesji, wklej to".

**Subagenty:**

- **TAK** — recon i audyt read-only (jeden na rozłączny obszar), samodzielna diagnostyka
  („skąd błąd 500 na tym endpoincie"), zbieranie liczb do rekonsyliacji. Subagent oddaje
  **konkluzję**, nie kod.
- **NIE** — równoległe edycje w jednym drzewie (punkty z jednej listy prawie zawsze zbiegają
  się na wspólnych plikach), decyzje biznesowe, zmiany w plikach z sekcji 2.4 (kolidujące/wrażliwe).
- Subagent z **własnym worktree** — tylko gdy zadania są w rozłącznych plikach i user jawnie
  chce równolegle.

**Meldunek — obowiązkowy, jedno zdanie, bez żargonu.** Dobrze: „Widzę 7 zgłoszeń — grupuję w
3 paczki, robię po kolei, po drugiej zaproponuję świeżą sesję". Źle: „odpalam worktree i fan-out
subagentów".

### 2.1 Start zadania (`/start`, albo automatycznie przy pierwszej edycji plików)

```
git checkout {{FILL:MAIN_BRANCH}}
git pull                        # origin to jedyne źródło prawdy
git checkout -b <inicjaly>/<typ>/<slug>
```

- Inicjały bierz z `git config user.email` ({{FILL:INITIALS_RULE}}). Widać wtedy od razu, czyj to warsztat.
- `<typ>`: `feat` · `fix` · `docs` · `chore` · `polish`.
- Jeden branch = jedna zmiana. Żyje maksymalnie 2–3 dni.
- **Nigdy nie zaczynaj pracy na chronionym branchu.** Jeśli edycje już powstały — zrób branch
  teraz; niezacommitowane zmiany przechodzą razem z tobą, nic nie ginie.

### 2.2 Praca

Normalnie, według `CLAUDE.md`. Commituj małymi, tematycznymi krokami, nie jednym grubym
commitem — dzięki temu da się cofnąć jedną decyzję bez ruszania dwunastu innych.

### 2.3 Publikacja (`/ship`)

Kolejność jest obowiązkowa, bez skrótów:

1. **Bramki lokalne muszą być zielone** — dokładnie te, które sprawdza CI:
   `{{FILL:BUILD_GATE}}` oraz `{{FILL:TEST_GATE}}`. Czerwone → napraw, nie idź dalej.
2. Commit + `git push -u origin <branch>`.
3. `gh pr create --base {{FILL:MAIN_BRANCH}} --title "<tytuł>" --body "<opis>"` — **tytuł podawaj jawnie**,
   w konwencji commitów. Samo `--fill` przy więcej niż jednym commicie wstawia jako tytuł
   nazwę brancha i po squashu taki śmieć zostaje w historii na zawsze.
4. **Czekaj na CI:** `gh pr checks <nr> --watch --required --interval 15`. Flaga `--required`
   jest istotna: run CI bywa rejestrowany nawet ~90 s po utworzeniu PR-a, a `--watch` śledzi
   tylko checki widoczne na starcie — bez niej komenda zwróci „zielone" po samym firmowym
   skanie sekretów, a merge i tak odbije się od polityki brancha. Czerwone → napraw i wypchnij
   poprawkę, CI puści się od nowa.
5. **Scal sam:** `gh pr merge --squash --delete-branch`. Squash = jeden commit za jedną zmianę,
   czyli `git revert <sha>` cofa całość jednym ruchem. Merge odbity, bo branch jest za
   chronionym branchem? → `gh pr update-branch`, poczekaj na ponowne CI, scal.
6. `git checkout {{FILL:MAIN_BRANCH}}; git pull` — zostaw lokalne repo zsynchronizowane.
7. Zaraportuj: link do PR-a, SHA po merge'u, co dalej (deploy albo nie).

**Nie pytaj drugiej osoby o zgodę i nie oznaczaj jej jako reviewera.** Taka jest umowa.

### 2.4 Pliki, które kolidują między nami

{{FILL:HOTSPOT_FILES — wypełnij przy instalacji: pliki, które w TYM projekcie realnie kolidują,
i reguła dla każdego. Wzorce, które sprawdziły się w praktyce:

- **dziennik / changelog** (np. `docs/WORKLOG.md`) — wpisy dodawaj **na samą górę**, z datą i
  inicjałami; przy konflikcie zachowaj **oba** wpisy (nikt nie kasuje cudzego). Docelowo warto
  rozbić na plik per wpis (`docs/worklog/<data>-<inicjały>-<temat>.md`) — wtedy konflikt przestaje istnieć.
- **dwie kopie tego samego korpusu / configu** — jeśli projekt trzyma zduplikowane dane
  (np. dokumentacja + runtime snapshot), zmiana jednej strony **musi** iść w tym samym commicie
  co druga. Git nie zgłosi tu konfliktu, tylko cicho zostawi rozjazd.
- **pliki dzielone przez wszystkich** (wspólne helpery, warstwa API, komponenty UI, routing) —
  skoro nie ma review, ochroną jest **rozmiar i tempo**: osobny mały PR, zmergowany od razu,
  nie trzymany dzień. Im dłużej taki branch żyje, tym pewniejszy konflikt.
- **pliki wrażliwe bezpieczeństwem** (autoryzacja, widoczność danych, walidacja wejścia) —
  wypisz je tu z jednozdaniowym „co się stanie, jak to zepsujesz". Błąd w takim pliku to nie
  brzydki widok, a cudze dane u niewłaściwej osoby.}}

---

## 3. Deploy na live (`/deploy`)

{{FILL:DEPLOY_SECTION — pełny opis dla tej architektury. Gotowe wersje: `recipes/<architektura>/notes.md`
w kicie. Musi zawierać:
1. **czym jest produkcja** (jeden serwis? staging? kilka środowisk?),
2. **dlaczego preflight jest konieczny** (czy deploy pakuje katalog z dysku, czy commit z gita),
3. **preflight**: na chronionym branchu · czyste drzewo · HEAD == origin · zielone bramki,
4. **wykrywanie kolizji dwóch deployów** (jak sprawdzić, czy druga osoba właśnie nie deployuje),
5. **tagowanie tego, co poszło na live**,
6. **co jest prawdą, gdy deploy padnie w połowie**.}}

---

## 4. Rollback (`/rollback`)

{{FILL:ROLLBACK_SECTION — jak wrócić do poprzedniego wydania w tej architekturze, ile to trwa
i czy wymaga builda. Uniwersalna jest tylko kolejność: **najpierw ratujesz produkcję, potem
naprawiasz repo** (`git revert <sha>` na branchu → PR → merge). Rollback nigdy nie jest
blokowany przez hooki — to ścieżka awaryjna.}}

---

## 5. Jak się nie zderzyć z drugim agentem

- **Jeden obszar (moduł / ekran / router) = jedna osoba na raz.** Podział po obszarach, nie po plikach.
- **Krótkie branche.** Konflikt rośnie liniowo z czasem życia brancha, nie z liczbą zmian.
- **`git pull` przed startem zadania i po każdym mergu.** Praca na nieaktualnym chronionym
  branchu to najczęstsza przyczyna konfliktu, jaki dało się uniknąć darmowo.
- **Worktrees** tylko przy naprawdę rozłącznych, długich zadaniach — dla <20 plików koszt
  (osobne środowisko, ponowna instalacja zależności) przewyższa zysk. Zasoby jednorazowe na
  maszynę (serwery dev, przeglądarka do testów) i tak się nie zrównoleglą.
- **Jedno drzewo robocze = jedna sesja agenta.** Druga równoległa sesja (także własna: „zrób
  to obok / w tle") dostaje `git worktree add .claude/worktrees/<slug>`. `git checkout` w
  drzewie, w którym siedzi inna sesja, wyrywa jej pracę w połowie — rozpoznanie tej sytuacji
  jest w 2.0 (krok 1) i obowiązuje **przed pierwszą edycją**.
- **Sprzątaj po sobie:** po zmergowaniu `git worktree remove .claude/worktrees/<slug>`.
  Porzucone worktrees mylą przy `git worktree list` i przy raporcie hooka `session-start`.

---

## 6. Co jest zablokowane technicznie (hook `guard`)

`.claude/settings.json` rejestruje `PreToolUse` → `.claude/hooks/guard.ps1` (Windows) lub
`.claude/hooks/guard.sh` (macOS/Linux), który blokuje komendę i tłumaczy powód:

| Blokada | Dlaczego |
|---|---|
| `git commit` / `merge` / `rebase` na chronionym branchu | praca idzie przez branch + PR |
| `git push` z chronionego brancha (poza pushem tagu) | branch rośnie tylko przez zmergowany PR |
| `git push --force` gdziekolwiek | force push kasuje pracę drugiej osoby |
| komenda deployu przy brudnym drzewie / nie z chronionego brancha / gdy lokalny ≠ `origin` | deploy pakuje katalog, nie commit |

Cztery właściwości, o których trzeba wiedzieć przy modyfikacji:

- **Fail-open.** Każdy nieprzewidziany błąd = przepuść. Zepsuty guard nie może zablokować
  całej pracy; on łapie pomyłki, nie jest bramką bezpieczeństwa.
- **Rozpoznaje wywołanie, nie wzmiankę.** Dopasowanie idzie po *początku* segmentu komendy,
  więc `gh pr create --body "...git push..."` przechodzi.
- **Oba pliki muszą zostać czystym ASCII.** Windows PowerShell 5.1 czyta skrypty `-File` w
  kodowaniu ANSI, więc bajt `0x94` z pauzy `—` zamienia się w cudzysłów i **cicho** rozwala
  parsowanie → hook przepuszcza wszystko. Dlatego komunikaty guarda są po angielsku i bez
  znaków diakrytycznych.
- **Dwa dialekty regexu.** `guard.ps1` używa regexu .NET, `guard.sh` — POSIX ERE (bez `\s`,
  `\b`, lookaheadów). Zmieniasz wzorzec w jednym → przetłumacz na drugi, inaczej ochrona
  rozjedzie się między systemami.

Hooki wczytują się przy starcie sesji. Po zmianie `settings.json` otwórz raz `/hooks` albo
zrestartuj Claude Code.

### Drugi hook: `session-start` — mówi, w co wchodzisz

`SessionStart` → `.claude/hooks/session-start.ps1` (Windows) lub `session-start.sh`
(macOS/Linux). **Niczego nie blokuje** (SessionStart nie umie): robi `git fetch origin` i
wrzuca do kontekstu agenta stan drzewa, zanim ten zdąży cokolwiek tknąć — HEAD i rozjazd
względem `origin/{{FILL:MAIN_BRANCH}}`, niezacommitowane pliki *w tym* drzewie, pozostałe
worktrees z informacją, które są brudne, katalogi-resztki po skasowanych worktrees oraz otwarte
PR-y (drafty oznaczone). Na koniec dokleja jedną akcję, jeśli jakaś wynika: „jesteś na
`{{FILL:MAIN_BRANCH}}` → `/start`" albo „branch jest N commitów za `{{FILL:MAIN_BRANCH}}` →
wciągnij go" (patrz 2.2).

Rozwiązuje to samo, co triage w 2.0 robi ręcznie: bez tego raportu sesja dowiaduje się o
zmergowanym PR-ze, cudzym worktree albo równoległej sesji tylko wtedy, gdy któraś z tych
rzeczy już namiesza. Trzy właściwości jak przy guardzie: **fail-open** (błąd = brak wypisu, nie
blokada startu sesji), **czyste ASCII** w wariancie `.ps1` (ten sam powód co guard.ps1), i
**testy w pliku** (`session-start.tests.ps1` / `.tests.sh`, oczekiwany ogon `FAILURES: 0`).
Sieć wyłącza zmienna `HOOK_SKIP_NETWORK=1` (pomija `fetch` i `gh`) — testy dostają wynik
deterministyczny i nie czekają na sieć.

Worktree'y wykrywa listą katalogów (`Get-ChildItem` / `for d in .../*/`), nie przez
`git worktree list` — repo w ścieżce ze znakiem spoza ASCII sprawia, że git wypisuje ją
c-quoted i żadne `Test-Path`/`[ -d ]` jej nie rozwiąże. Katalog bez `.git` **nie jest**
worktree'em (leży wewnątrz repo, więc `git -C <katalog>` wspina się do drzewa nadrzędnego i
odpowiada za drzewo GŁÓWNE) — bez tego rozróżnienia porzucony katalog wygląda jak cudzy,
brudny worktree na chronionym branchu.

### Co z `.claude/` jest wspólne, a co prywatne

Hooki i komendy **muszą** być w repo — inaczej na drugiej maszynie po prostu nie istnieją, a to
dokładnie ta cicha awaria, której mają zapobiegać. Podział warstw:

| Ścieżka | Zawartość | W repo? |
|---|---|---|
| `.claude/settings.json` | rejestracja hooków (ścieżka przez `${CLAUDE_PROJECT_DIR}`, bez danych osobowych) | **tak** — kontrakt zespołu |
| `.claude/hooks/`, `.claude/commands/` | guard + session-start + ich testy, komendy `/start`…`/setup` | **tak** |
| `.claude/settings.local.json` | osobiste nadpisania (permissions, env, model) | **nie** — gitignored |
| `.claude/worktrees/` | izolowane checkouty agenta | **nie** — gitignored |
| `~/.claude/` | konto, tokeny, transkrypty, pamięć agenta | **nigdy** — poza repo |

> Świadomy kompromis: commitowany hook to **kod wykonywany na maszynie drugiej osoby** przy
> każdym wywołaniu narzędzia. Dlatego guard niczego nie modyfikuje (czyta string komendy
> i zwraca werdykt), jest fail-open, ma testy, a każda jego zmiana przechodzi przez PR, który
> wszyscy widzą. Każdy może go też podejrzeć przez `/hooks`.

### Druga warstwa: ochrona chronionego brancha po stronie GitHuba

Hook działa lokalnie i tylko tam, gdzie ma czym się uruchomić. Niezależnie od niego serwer egzekwuje:

| Ustawienie | Wartość |
|---|---|
| PR wymagany przed mergem | tak |
| wymagane approvale | **0** — nikt nikogo nie zatwierdza |
| wymagane checki | {{FILL:CI_CHECK_NAMES — nazwy jobów CI, np. `frontend` + `backend`}} |
| branch musi być aktualny względem chronionego | tak (`strict`) |
| reguły obowiązują adminów | tak — inaczej byłyby bezzębne, jeśli wszyscy są adminami |
| force push / usunięcie chronionego brancha | zablokowane |
| historia liniowa, tylko squash merge | tak |

---

## 7. Weryfikacja i onboarding

**Test obu hooków po każdej ich zmianie** (oczekiwany ogon `FAILURES: 0` w każdym) — przypadki
siedzą w pliku, nie w komendzie shella, bo inaczej guard zablokowałby sam test:

```
# Windows
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/session-start.tests.ps1
# macOS / Linux  (wymaga jq albo python3 — bez nich hook cicho przepuszcza/milczy)
bash .claude/hooks/guard.tests.sh
bash .claude/hooks/session-start.tests.sh
```

**Przed `/ship`: `/verify`.** Jedna komenda odpalająca lokalnie te same bramki, które sprawdzi
CI: `{{FILL:BUILD_GATE}}` · `{{FILL:TEST_GATE}}`, plus testy hooków, jeśli diff ich dotyka.
Odpal ją lokalnie *przed* `/ship`, nie po — czerwony check na PR-ze to stracona runda
push → czekanie → fix → push, skoro nikt nikogo nie zatwierdza.

### Onboarding nowej maszyny

**Jedna komenda: `/setup`.** Idempotentna, uruchamiana ręcznie przez człowieka — sprawdza
remote, scope'y `gh` (w tym `workflow`), działanie hooków, zależności, narzędzia deployu,
i naprawia to, czego brakuje.

Czego **nie** trzeba instalować: **hooków**. `.claude/settings.json` i `.claude/hooks/` są
w repo, więc świeży klon już je ma, a Claude Code wczytuje ustawienia projektu przy starcie
sesji. `/setup` tylko sprawdza, czy naprawdę działają — hook, który po cichu przepuszcza
wszystko, wygląda identycznie jak hook, który działa.

Czego `/setup` nie załatwi (wymaga człowieka i przeglądarki):

| Krok | Dlaczego |
|---|---|
| `gh auth login` / `gh auth refresh -s workflow` | device flow — kod trzeba wkleić w przeglądarce |
| logowanie do chmury / narzędzia deployu | jw. |
| {{FILL:MANUAL_ONBOARDING — sekrety lokalne, klucze, role/uprawnienia w chmurze: kto je nadaje}} |

---

## 8. Sesje z listą zgłoszeń QA (3+ punktów naraz)

Typowa sesja: user wkleja numerowaną listę uwag z klikania aplikacji. **Zanim ruszysz kod**,
napisz w jednym akapicie: mapę punkt → plik/endpoint, co grupujesz, co zlecasz obok, jak
weryfikujesz. Reguły, które się sprawdziły:

- **Recon przez `grep`/agenta-eksploratora, nie przez czytanie całych plików.** Do fixa
  w 550-liniowym pliku potrzebujesz 4 miejsc, nie całego pliku. Czytaj w całości tylko to,
  co faktycznie przepisujesz. Listę punktów wrzuć na listę zadań — przy 13 uwagach łatwo zgubić jedną.
- **Grupuj po plikach, nie po numerach uwag.** Punkty dzielące ten sam komponent rób w jednym
  przejściu — inaczej wracasz do tego samego pliku trzy razy.
- **Subagenty: TAK na równoległy recon read-only** („znajdź gdzie jest X, oddaj konkluzję")
  **i na samodzielną diagnostykę** (np. „skąd błąd 500 na tym endpoincie"). **NIE na równoległe
  edycje** — punkty z listy QA prawie zawsze nakładają się na współdzielonych plikach, a każdy
  agent czyta ten sam kontekst od zera (fan-out mnoży tokeny, nie dzieli ich).
- **Weryfikuj najtaniej jak można.** Kolejność: porównanie liczb z API (reconciliation typu
  „suma z filtrem == suma bez filtra"), potem asercja na DOM zwracająca liczbę/tekst,
  a screenshot **tylko gdy oceniasz wygląd**. Screenshot to najdroższy token w sesji —
  5 celowanych bije 17 potwierdzających.
- **Nie „upraszczaj" działającego mechanizmu w trakcie fixa.** Zmiana ma być chirurgiczna;
  jeśli chcesz uprościć, sprawdź założenie osobno.
- **Commity tematyczne, nie jeden gruby.** Żeby dało się cofnąć jedną decyzję bez ruszania
  dwunastu innych — i żeby jeden odrzucony punkt nie blokował merge'a pozostałych.
