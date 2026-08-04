# Recipe: Vercel

Dwa zupełnie różne tryby — **zdecyduj, w którym jesteś, zanim wypełnisz guarda:**

| Tryb | Kto deployuje | Guard |
|---|---|---|
| **A. Git integration** (domyślny) | Vercel sam, po pushu/mergu do gałęzi produkcyjnej | `DeployPattern = ''` — nie ma lokalnej komendy deployu do pilnowania. `/deploy` nie istnieje; usuń tę komendę i napisz w kontrakcie, że merge = deploy. |
| **B. Deploy z CLI** (`vercel --prod`) | człowiek/agent z konsoli | wzorce niżej — CLI **pakuje katalog z dysku**, więc preflight jest konieczny |

W trybie A ochroną produkcji jest wyłącznie CI + branch protection: skoro merge natychmiast
idzie na live, `/ship` **jest** deployem. Napisz to wprost w sekcji 1 kontraktu, inaczej ktoś
zmerguje „na później" i zdziwi się, że jest na produkcji.

## Tryb B — guard

`.claude/hooks/guard.ps1` (regex .NET):

```powershell
$DeployPattern      = '^(&\s*)?\S*vercel(\.cmd|\.exe)?"?\s+([^\r\n]*--prod\b|deploy\b|build\b)'
$DeployAllowPattern = '^(&\s*)?\S*vercel(\.cmd|\.exe)?"?\s+(rollback|promote|ls|list|inspect|logs|env)\b'
```

`.claude/hooks/guard.sh` (POSIX ERE):

```bash
DEPLOY_PATTERN='^(&[[:space:]]*)?[^[:space:]]*vercel(\.cmd|\.exe)?"?[[:space:]]+([^\n]*--prod([[:space:]]|$)|deploy([[:space:]]|$)|build([[:space:]]|$))'
DEPLOY_ALLOW_PATTERN='^(&[[:space:]]*)?[^[:space:]]*vercel(\.cmd|\.exe)?"?[[:space:]]+(rollback|promote|ls|list|inspect|logs|env)([[:space:]]|$)'
```

Przypadki testowe (`guard.tests.ps1`):

```powershell
$deployCases = @(
    @{ cmd = 'vercel --prod';                        expect = 'BLOCK' },
    @{ cmd = 'npx vercel deploy --prod';             expect = 'BLOCK' },
    @{ cmd = 'vercel rollback dpl_abc123';           expect = 'ALLOW' },
    @{ cmd = 'vercel ls';                            expect = 'ALLOW' }
)
```

`guard.tests.sh`:

```bash
deploy_cases="$(cat <<CASES
BLOCK	vercel --prod
ALLOW	vercel rollback dpl_abc123
CASES
)"
```

## Tryb B — wypełnienia komend

| Placeholder | Wartość |
|---|---|
| `DEPLOY_CMD` | `vercel --prod` (albo `vercel deploy --prod --yes`) |
| `LIST_RELEASES_CMD` | `vercel ls <projekt>` — pokazuje deploymenty z czasem i statusem |
| `ROLLBACK_CMD` | `vercel rollback <deployment-url-lub-id>` (alternatywa: `vercel promote <id>`) |
| `DEPLOY_SUCCESS_SIGNAL` | CLI wypisuje **Production URL** i nowy identyfikator deploymentu |
| `TAG_BODY` | `vercel <deployment-id>` |
| `ROLLBACK_COST` | bez builda, kilkanaście sekund — Vercel przełącza alias na starszy, już zbudowany deployment |
| `PARTIAL_FAILURE_NOTE` | nieudany build nie zmienia produkcji: alias produkcyjny zostaje na poprzednim deploymencie |

## Czego nie zapomnieć

- **`vercel link` per maszyna** — bez tego CLI nie wie, do którego projektu deployuje. Wpisz do `/setup`.
- **`.vercelignore`** rządzi tym, co ląduje w uploadzie (analogicznie do `.gcloudignore`).
- **Zmienne środowiskowe żyją w Vercelu, nie w repo.** Zmiana `env` to zmiana produkcji, której
  **nie widać w gicie** — jeśli tak działacie, wpisz do kontraktu regułę: każda zmiana env
  zgłoszona drugiej osobie, bo inaczej rollback kodu nie cofnie configu.
- **Preview deployments per PR** są darmową bramką jakości — warto dopisać do `/ship` krok
  „podaj userowi link do preview", zanim scalisz.
