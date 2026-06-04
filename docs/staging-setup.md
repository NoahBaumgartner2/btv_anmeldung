# Staging-Umgebung Setup

Die Staging-Umgebung läuft unter `test.btvbern-anmeldung.ch` — gleicher Code wie Production, aber eigene Datenbank und eigene Docker-Container.

## GitHub Secrets die gesetzt werden müssen

- `POSTGRES_PASSWORD_STAGING` — ein sicheres Passwort für die Staging-Datenbank (kann anders sein als Prod)

## Erstes Deployment (manuell)

Beim allerersten Mal muss das Accessory (Datenbank) initialisiert werden:

```bash
# Staging-Datenbank starten
bundle exec kamal accessory boot db -c config/deploy.staging.yml

# App deployen
bundle exec kamal deploy -c config/deploy.staging.yml

# Datenbank migrieren
bundle exec kamal app exec --interactive --reuse 'bin/rails db:migrate' -c config/deploy.staging.yml

# Optional: Seed-Daten laden
bundle exec kamal app exec --interactive --reuse 'bin/rails db:seed' -c config/deploy.staging.yml
```

## Laufendes Deployment

Ab dann deployed der CI automatisch bei jedem Push auf `staging`.

## Unterschiede zur Production

| | Production | Staging |
|---|---|---|
| Domain | btvbern-anmeldung.ch | test.btvbern-anmeldung.ch |
| Service | btv_anmeldung | btv_anmeldung_staging |
| DB Name | btv_anmeldung_production | btv_anmeldung_staging |
| DB Port | 5432 | 5433 |
| Branch | main | staging |
