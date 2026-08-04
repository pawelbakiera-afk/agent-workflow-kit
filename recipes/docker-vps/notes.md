# Recipe: Docker Compose na własnym serwerze (VPS / on-prem)

Deploy = zbuduj obraz → wypchnij do registry → na serwerze `pull` + `up -d`. Najbardziej
„ręczna" z architektur, więc najłatwiej tu wypuścić coś, czego nie ma w gicie.

**Warunek wstępny, bez którego rollback nie istnieje: taguj obrazy SHA commita**, nie tylko
`latest`. `latest` znaczy „nie wiem, co tam jest" i zamienia rollback w ponowny build.

```
docker build -t <registry>/<app>:$(git rev-parse --short HEAD) -t <registry>/<app>:latest .
```

## Guard — wzorce

Zawężone **celowo** do komend produkcyjnych: lokalny `docker build` do testów nie powinien
lecieć w blokadę, bo to zwykła praca na branchu. Blokujemy `push` obrazu i `compose up`
z plikiem produkcyjnym.

`.claude/hooks/guard.ps1` (regex .NET):

```powershell
$DeployPattern      = '^(&\s*)?\S*docker(\.exe)?"?\s+(push\b|compose\s+[^\r\n]*(-f|--file)\s+\S*prod[^\r\n]*\bup\b)'
$DeployAllowPattern = '^(&\s*)?\S*docker(\.exe)?"?\s+(ps|logs|images|inspect)\b'
```

`.claude/hooks/guard.sh` (POSIX ERE):

```bash
DEPLOY_PATTERN='^(&[[:space:]]*)?[^[:space:]]*docker(\.exe)?"?[[:space:]]+(push([[:space:]]|$)|compose[[:space:]][^\n]*(-f|--file)[[:space:]]+[^[:space:]]*prod[^\n]*[[:space:]]up([[:space:]]|$))'
DEPLOY_ALLOW_PATTERN='^(&[[:space:]]*)?[^[:space:]]*docker(\.exe)?"?[[:space:]]+(ps|logs|images|inspect)([[:space:]]|$)'
```

**Jeśli deployujecie przez `ssh serwer 'cd /srv/app && docker compose pull && docker compose up -d'`**
— dopisz do wzorca człon na `ssh`, np. `|^(&\s*)?ssh\s+[^\r\n]*docker` (.NET) oraz odpowiednik ERE.
Guard dopasowuje **początek segmentu**, a cała komenda `ssh …` jest jednym segmentem, więc
wzorzec musi zaczynać się od `ssh`, nie od `docker`.

Przypadki testowe (`guard.tests.ps1`):

```powershell
$deployCases = @(
    @{ cmd = 'docker push registry.example.com/app:abc123';                     expect = 'BLOCK' },
    @{ cmd = 'docker compose -f docker-compose.prod.yml up -d';                  expect = 'BLOCK' },
    # lokalna praca na branchu nie może być blokowana
    @{ cmd = 'docker compose -f docker-compose.dev.yml up';                      expect = 'ALLOW' },
    @{ cmd = 'docker ps';                                                        expect = 'ALLOW' }
)
```

## Wypełnienia komend

| Placeholder | Wartość |
|---|---|
| `DEPLOY_CMD` | `docker build -t <reg>/<app>:<sha> .` → `docker push <reg>/<app>:<sha>` → `ssh <serwer> "cd /srv/<app> && IMAGE_TAG=<sha> docker compose up -d"` |
| `LIST_RELEASES_CMD` | `ssh <serwer> "docker ps --format '{{.Image}} {{.RunningFor}}'"` — pokazuje, jaki tag faktycznie chodzi i od kiedy |
| `ROLLBACK_CMD` | `ssh <serwer> "cd /srv/<app> && IMAGE_TAG=<poprzedni-sha> docker compose up -d"` |
| `DEPLOY_SUCCESS_SIGNAL` | kontener chodzi na **nowym** tagu (sprawdź `docker ps`) i healthcheck jest zielony |
| `TAG_BODY` | `image <reg>/<app>:<sha>` |
| `ROLLBACK_COST` | bez builda, jeśli poprzedni obraz jest w registry — kilkanaście sekund; **z** buildem to kilka minut, powiedz to userowi |
| `PARTIAL_FAILURE_NOTE` | jeśli padnie build albo push, produkcja się nie zmienia; jeśli padnie `up -d`, kontener może być **zatrzymany** — sprawdź `docker ps` przed raportem, nie zakładaj |

## Czego nie zapomnieć

- **Migracje bazy** to najczęstsza przyczyna „rollback nie pomógł". Jeśli deploy odpala
  migracje, dopisz do `/rollback` jawnie, czy schemat jest wstecz kompatybilny — a jeśli nie
  wiadomo, każ agentowi zapytać człowieka **zanim** cofnie kod.
- **Sekrety na serwerze** (`.env` na VPS-ie) nie są w gicie — jak w Vercelu, rollback ich nie cofa.
- **Healthcheck po deployu** wpisz do komendy `/deploy` jako krok, nie jako dobrą praktykę:
  `curl -fsS https://<host>/health`. Bez tego „sukces" znaczy tylko „docker nie krzyknął".
- **Dostęp SSH per maszyna** — wpisz do `/setup` (klucz, `~/.ssh/config`, host jump).
