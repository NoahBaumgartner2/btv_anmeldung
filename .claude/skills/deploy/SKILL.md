---
name: deploy
description: Projektspezifischer Deploy-Ablauf für btv_anmeldung. Verwenden, wenn der User "deploy", "deployen", "ausrollen", "nach staging/main bringen" oder Ähnliches sagt. Promotet Arbeit von workingbranch → staging (Auto-Deploy test.btvbern-anmeldung.ch) → main per PR (Auto-Deploy btvbern-anmeldung.ch).
---

# Deploy-Workflow (btv_anmeldung)

Quelle der Wahrheit ist **`workingbranch`**. Deploys laufen über GitHub Actions
(`.github/workflows/ci.yml`): Push auf `staging` → Auto-Deploy nach
**test.btvbern-anmeldung.ch**, Merge auf `main` → Auto-Deploy nach
**btvbern-anmeldung.ch**. Es sind KEINE "trigger staging deploy"-Commits nötig.

Branch-Protection: `main` akzeptiert nur PRs (kein Direktpush). `staging` erlaubt
Direktpush. `gh` muss eingeloggt sein (`gh auth status`); sonst den User bitten,
`! gh auth login` zu tippen.

## Ablauf

### 1. workingbranch: committen + pushen
Nur committen/pushen, wenn es offene Änderungen gibt bzw. der User es will.
```bash
git checkout workingbranch
git commit -am "<aussagekräftige Nachricht>"   # Co-Authored-By-Trailer nicht vergessen
git push origin workingbranch
```
Push auf `workingbranch` löst KEINEN Deploy aus (nur staging/main deployen).

### 2. staging auf den workingbranch-Stand bringen
```bash
git checkout staging
git pull --ff-only origin staging
git rebase workingbranch        # staging-Unikate auf die workingbranch-Spitze setzen
git push origin staging         # -> Auto-Deploy nach test.btvbern-anmeldung.ch
```
- Bei Rebase-Konflikten NICHT raten: anhalten und dem User den Konflikt zeigen.
- `workingbranch` enthält historisch viele leere "trigger staging deploy"-Commits.
  Wenn die nicht mitsollen, stattdessen die relevanten Commits gezielt auf einen
  von `origin/staging` abgezweigten Branch `git cherry-pick`en (siehe Hinweis unten).

### 3. CI auf staging prüfen
Vor dem Schritt nach main sicherstellen, dass die staging-CI grün ist:
```bash
gh run list --branch staging -L 1 --json databaseId,status,conclusion
```
Deploy-Gate sind `scan_ruby` (brakeman), `lint`, `test`. `gem_audit` (bundler-audit)
ist bewusst KEIN Gate — ein rotes `gem_audit` ist nur ein sichtbarer Hinweis und
darf den Deploy/Merge nicht blockieren.

### 4. PR nach main erstellen
```bash
gh pr create --base main --head staging \
  --title "<knapper Titel>" \
  --body "<Zusammenfassung der enthaltenen Commits + lokal/CI-verifizierte Checks>"
```
PR-Body mit `🤖 Generated with [Claude Code](https://claude.com/claude-code)` abschließen.

### 5. Auf grüne CI warten, DANN mergen
```bash
# pollen bis mergeStateStatus == CLEAN und keine Checks mehr pending
gh pr checks <PR-NR>
gh pr view <PR-NR> --json mergeable,mergeStateStatus
gh pr merge <PR-NR> --merge       # -> Auto-Deploy nach btvbern-anmeldung.ch (PRODUKTION)
```
- **Niemals einen PR mergen, dessen Pflicht-Checks noch pending oder rot sind.**
- `--merge` verwenden (Merge-Commit, wie bisher), NICHT squash/rebase-merge.
- `staging` und `main` sind Dauerbranches — **niemals löschen** (kein `--delete-branch`).

### 6. Prod-Deploy verifizieren
```bash
RUNID=$(gh run list --branch main -L 1 --json databaseId -q '.[0].databaseId')
gh run view "$RUNID" --json jobs -q '.jobs[] | "\(.name): \(.status)/\(.conclusion // "-")"'
```
Auf `deploy: completed/success` warten und dem User das Ergebnis melden.

## Sicherheits-Leitplanken
- Schritt 5 (Merge nach main) ist ein **Produktiv-Deploy** — er ist bewusst der
  letzte Schritt. Nur ausführen, wenn der User "deploy nach main/Produktion" bzw.
  den vollen Ablauf will. Bei "deploy nach staging" o. Ä. nach Schritt 3 stoppen.
- Wenn `gh` nicht eingeloggt ist, anhalten und den User `! gh auth login` tippen lassen.
- Hard-to-reverse: vor dem main-Merge im Zweifel kurz rückversichern.

## Hinweis: workingbranch ist "verschmutzt"
`workingbranch` trägt viele alte leere "trigger staging deploy"-Commits. Solange das
so ist, kann der Rebase in Schritt 2 unübersichtlich werden. Saubere Alternative,
wenn nur einzelne echte Commits nach staging sollen:
```bash
git checkout staging && git reset --hard origin/staging
git cherry-pick <commit-sha(s) der echten Änderung>
git push origin staging
```
Bei Gelegenheit lohnt es sich, `workingbranch` neu von `main` aufzusetzen.
