# Recipe: Google Cloud Run (`gcloud run deploy --source .`)

Architektura, z której ten kit wyrósł: jeden serwis Cloud Run, bez staginga, build po stronie
Cloud Build (bez lokalnego Dockera), ruch przełączany na nową rewizję.

**Dlaczego preflight jest tu krytyczny:** `gcloud run deploy --source .` pakuje **katalog
z dysku**, nie commit z gita. Bez dyscypliny na produkcję trafia kod, którego nie ma w żadnym
commicie — albo wersja bez zmian drugiej osoby.

## 1. Guard — wzorce do wklejenia

`.claude/hooks/guard.ps1` (regex .NET):

```powershell
$DeployPattern      = '^(&\s*)?\S+\s+(\S+\s+)?run\s+deploy\b'
$DeployAllowPattern = ''
```

Wzorzec łapie `gcloud run deploy …`, `gcloud beta run deploy …` oraz `& $gc beta run deploy …`
(pełna ścieżka do `gcloud.cmd` w zmiennej — na Windowsie `gcloud` często nie jest na PATH).

`.claude/hooks/guard.sh` (POSIX ERE — **inny dialekt, nie kopiuj wersji .NET**):

```bash
DEPLOY_PATTERN='^(&[[:space:]]*)?[^[:space:]]+[[:space:]]+([^[:space:]]+[[:space:]]+)?run[[:space:]]+deploy([[:space:]]|$)'
DEPLOY_ALLOW_PATTERN=''
```

`DeployAllowPattern` pusty, bo rollback (`run services update-traffic`) nie zawiera
`run deploy` i nie wpada w blokadę. Jeśli kiedykolwiek zmienisz `$DeployPattern` na luźniejszy
(np. samo `run\s`), **musisz** wpisać rollback do allow-pattern — inaczej zablokujesz ścieżkę awaryjną.

## 2. Guard — przypadki testowe

`guard.tests.ps1`:

```powershell
$deployCases = @(
    @{ cmd = 'gcloud run deploy my-service --source .';                                    expect = 'BLOCK' },
    @{ cmd = '& $gc beta run deploy my-service --source . --region europe-west1';          expect = 'BLOCK' },
    # rollback jest ścieżką awaryjną i nigdy nie może być blokowany
    @{ cmd = '& $gc run services update-traffic my-service --to-revisions rev-42=100';     expect = 'ALLOW' }
)
```

`guard.tests.sh` (format `EXPECT<TAB>KOMENDA`):

```bash
deploy_cases="$(cat <<CASES
BLOCK	gcloud run deploy my-service --source .
ALLOW	gcloud run services update-traffic my-service --to-revisions rev-42=100
CASES
)"
```

> Przypadki `BLOCK` są automatycznie pomijane, gdy testy odpalasz na czystym, zsynchronizowanym
> chronionym branchu — wtedy guard **słusznie** przepuszcza deploy. Żeby zobaczyć je zielone,
> odpal testy na branchu roboczym.

## 3. Wypełnienia dla `/deploy` i `/rollback`

Gotowe pliki leżą obok: [`deploy.md`](deploy.md) i [`rollback.md`](rollback.md) — skopiuj je
do `.claude/commands/` **zamiast** szkieletów z `template/` i podmień tylko nazwy serwisu/regionu/projektu.

| Placeholder | Wartość dla Cloud Run |
|---|---|
| `DEPLOY_CMD` | `gcloud run deploy <serwis> --source . --region <region> --project <projekt>` (+ flagi z `DEPLOYMENT.md`) |
| `LIST_RELEASES_CMD` | `gcloud run revisions list --service <serwis> --region <region> --project <projekt> --limit 5` |
| `ROLLBACK_CMD` | `gcloud run services update-traffic <serwis> --region <region> --project <projekt> --to-revisions <rewizja>=100` |
| `DEPLOY_SUCCESS_SIGNAL` | pojawia się **nowy** numer rewizji `<serwis>-000NN` |
| `TAG_BODY` | `rev <serwis>-000NN` |
| `ROLLBACK_COST` | żaden build się nie wykonuje, ~30 s |
| `PARTIAL_FAILURE_NOTE` | jeśli deploy padnie w trakcie builda, na produkcji **nadal działa stara rewizja** — ruch nie został przekierowany |

## 4. Czego nie zapomnieć w tej architekturze

- **Uprawnienia do deployu to nie to samo co dostęp do aplikacji.** Do samego oglądania
  wystarcza `roles/iap.httpsResourceAccessor`; do `/deploy` potrzeba `roles/run.developer`,
  `roles/cloudbuild.builds.editor`, `roles/artifactregistry.writer`,
  `roles/storage.objectCreator` + `roles/iam.serviceAccountUser` na runtime SA. Łatwo
  przeoczyć, że ktoś „ma dostęp", a mimo to nie zdeployuje. Wpisz to do sekcji 7 kontraktu.
- **`.gcloudignore`, nie `.dockerignore`** rządzi tym, co ląduje w uploadzie. Trzymaj oba
  w zgodzie, jeśli wykluczasz sekrety albo prototypy.
- **Kolizja dwóch deployów:** sprawdź `revisions list --limit 1` przed startem. Jeśli
  najnowsza rewizja ma <5 minut, ktoś prawdopodobnie właśnie deployuje — dwa równoległe
  deploye kończą się tym, że wygrywa ten, który skończy później, i może wypchnąć starszy kod.
- **Cache przeglądarki:** po deployu przypomnij o `Ctrl+Shift+R`.
