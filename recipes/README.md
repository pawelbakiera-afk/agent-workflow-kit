# recipes — gotowe warianty deployu

Deploy to jedyna część kitu, w której zła wartość jest **groźna**, a nie tylko brzydka.
Dlatego zamiast jednego „uniwersalnego" `/deploy` kit ma kilka kompletnych wariantów.

Każdy recipe zawiera:

- **`notes.md`** — wzorce do guarda (osobno regex .NET dla `guard.ps1`, osobno POSIX ERE dla
  `guard.sh`), przypadki testowe, tabelę wypełnień placeholderów i listę „czego nie zapomnieć",
- **`deploy.md`** / **`rollback.md`** — gotowe komendy do skopiowania do `.claude/commands/`
  (poza `no-deploy`, gdzie chodzi właśnie o to, żeby ich nie było).

| Recipe | Deploy pakuje… | Rollback | Uwaga krytyczna |
|---|---|---|---|
| `cloud-run` | katalog z dysku (`--source .`) | przełączenie ruchu na starszą rewizję, ~30 s, bez builda | uprawnienia do deployu ≠ dostęp do aplikacji |
| `vercel` | katalog (tryb CLI) albo nic (tryb Git integration) | przełączenie aliasu, bez builda | w trybie Git integration **`/ship` = deploy** |
| `docker-vps` | katalog (`docker build .`) | poprzedni tag obrazu — **tylko jeśli tagujesz SHA** | migracje bazy potrafią unieważnić rollback |
| `no-deploy` | — | `git revert` + PR | nie zostawiaj martwych komend `/deploy` |

Nie ma twojej architektury? → `../ADAPT.md` §4 (sześć pytań + wzór). Gdy skończysz, dopisz
recipe tutaj i wypchnij do kitu — następny projekt dostanie to gotowe.
