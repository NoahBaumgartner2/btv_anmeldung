# Git Workflow

## Branch-Struktur

- `workingbranch` – aktiver Entwicklungs-Branch (hier wird gearbeitet)
- `feat/workingspace` – Staging-Branch (löst automatisches Staging-Deploy aus)
- `main` – Production-Branch (löst automatisches Production-Deploy aus)

## Workflow

1. Auf `workingbranch` entwickeln und committen
2. PR erstellen: `workingbranch` → `feat/workingspace`
3. Nach Merge: Staging-Deploy läuft automatisch auf `test.btvbern-anmeldung.ch`
4. Staging testen
5. PR erstellen: `feat/workingspace` → `main`
6. Nach Merge: Production-Deploy läuft automatisch auf `btvbern-anmeldung.ch`
7. Nach Production-Deploy: GitHub Actions rebased automatisch `feat/workingspace` auf `main` und `workingbranch` auf `feat/workingspace`

## Hinweise

- Nie direkt auf `main` oder `feat/workingspace` pushen
- Falls der automatische Rebase fehlschlägt (Konflikt), muss manuell rebased werden:
  ```bash
  git checkout feat/workingspace && git rebase origin/main && git push --force-with-lease
  git checkout workingbranch && git rebase origin/feat/workingspace && git push --force-with-lease
  ```
- Protected Branches benötigen einen PAT (Secret: `GH_PAT`) statt `GITHUB_TOKEN`
