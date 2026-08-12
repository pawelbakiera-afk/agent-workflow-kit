# agent-workflow-kit

Gotowy sposób pracy dla repozytorium, które prowadzi **kilka osób, każda przez agenta**
(Claude Code), bez wzajemnego zatwierdzania kodu. Wyciągnięty z działającego projektu
(dashboard analityczny na Cloud Run, dwie osoby, zero review) i oczyszczony z jego specyfiki.

## Co dostajesz

| Warstwa | Co robi |
|---|---|
| **Pięć komend** `/start` `/verify` `/ship` `/deploy` `/rollback` | człowiek nie pisze komend gita; agent sam robi branch, testy lokalne, commit, PR, czeka na CI, scala i sprząta |
| **Hook blokujący** (`guard.ps1` + `guard.sh`) | fizycznie nie pozwala commitować na chronionym branchu, zrobić `push --force`, ani zdeployować brudnego drzewa |
| **Hook informacyjny** (`session-start.ps1` + `.sh`) | na starcie każdej sesji melduje agentowi stan drzewa — branch, rozjazd z originem, cudze worktrees, otwarte PR-y — niczego nie blokuje |
| **Kontrakt** `docs/AGENT-WORKFLOW.md` | jedna strona zasad: dla ludzi sekcja 1, dla agenta reszta (w tym triage: kiedy worktree, kiedy subagent, kiedy handoff) |
| **CI** | jedyna bramka przed mergem — skoro nikt nikogo nie zatwierdza, to CI decyduje |
| **Ochrona brancha na GitHubie** | PR obowiązkowy, **0 approvali**, wymagane checki, historia liniowa, reguły obowiązują też adminów |
| **`/setup`** | onboarding nowej maszyny jedną komendą, idempotentnie |

## Jak wpiąć w nowy projekt

Powiedz agentowi w tym projekcie jedno zdanie:

> „Zainstaluj workflow z `<ścieżka-lub-URL>/agent-workflow-kit` — przeczytaj `INSTALL.md` i wykonaj całą procedurę."

Agent sam wyczyta z repo stack, gałąź główną i architekturę deployu, dopyta cię **tylko**
o system operacyjny zespołu i potwierdzenie modelu „zero review", a na koniec pokaże tabelę:
co zrobione, co wymaga ciebie (zwykle: logowanie w przeglądarce).

Nie musisz nic wpisywać ręcznie ani niczego rozumieć z zawartości kitu — ale jeśli chcesz
wiedzieć, co się zmieni w codziennej pracy, przeczytaj sekcję 1 zainstalowanego
`docs/AGENT-WORKFLOW.md`. To jedna tabelka.

## Struktura kitu

```
agent-workflow-kit/
├── README.md          <- ten plik (dla człowieka)
├── INSTALL.md         <- procedura dla agenta-instalatora: recon, kopiowanie, wypełnianie, protection, weryfikacja
├── ADAPT.md           <- co jest uniwersalne, tabela placeholderów, pułapki, jak dopisać własny recipe
├── template/          <- pliki, które lądują w docelowym repo (z placeholderami {{FILL:…}})
│   ├── .claude/       <- settings (3 warianty OS), hooks (guard + session-start + testy), commands (6 komend)
│   └── docs/AGENT-WORKFLOW.md
├── ci-templates/      <- node.yml · python.yml · node-python.yml · minimal.yml
└── recipes/           <- gotowe /deploy + /rollback per architektura
```

## Obsługiwane architektury deployu

| Recipe | Kiedy |
|---|---|
| `recipes/cloud-run` | Google Cloud Run, `gcloud run deploy --source .` (wariant źródłowy, najlepiej przetestowany) |
| `recipes/vercel` | Vercel — osobno tryb Git integration i tryb `vercel --prod` |
| `recipes/docker-vps` | własny serwer, Docker Compose, obraz tagowany SHA |
| `recipes/no-deploy` | deploy z CI po mergu · biblioteka/paczka · projekt bez produkcji |

Inna architektura (Fly.io, Heroku, App Engine, Kubernetes, mobile) → `ADAPT.md` §4: sześć pytań,
na które trzeba odpowiedzieć, i wzór do skopiowania. Cała reszta kitu zostaje bez zmian.

## Co ten kit celowo *nie* robi

- **Nie jest bramką bezpieczeństwa.** Hook jest **fail-open**: każdy nieprzewidziany błąd
  przepuszcza komendę. Łapie pomyłki, nie złośliwość. Twardą bramką jest ochrona brancha na GitHubie.
- **Nie wprowadza review.** Model jest świadomy: PR obowiązkowy, approvali zero, CI decyduje.
  Chcesz review — da się, ale trzeba zmienić dwa miejsca (`INSTALL.md` krok 2 i 7).
- **Nie wersjonuje się w docelowym repo.** Aktualizacja jest ręczna i świadoma (`ADAPT.md` §5) —
  bo pliki w projekcie są dopasowane do projektu i automat by je zdeptał.
