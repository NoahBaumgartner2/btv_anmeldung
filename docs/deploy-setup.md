# Deploy Setup — Einmalige Server-Einrichtung

## Persistentes Storage-Verzeichnis (ActiveStorage)

Das Logo und andere hochgeladene Dateien werden in `/rails/storage` im Container gespeichert.
Damit diese Dateien Deploys überleben, wird dieses Verzeichnis auf ein Host-Verzeichnis gemountet.

### Production-Server (btvbern-anmeldung.ch)

```bash
sudo mkdir -p /var/lib/btv_anmeldung/storage
sudo chown ubuntu:ubuntu /var/lib/btv_anmeldung/storage
```

### Staging-Server (test.btvbern-anmeldung.ch)

```bash
sudo mkdir -p /var/lib/btv_anmeldung_staging/storage
sudo chown ubuntu:ubuntu /var/lib/btv_anmeldung_staging/storage
```

> Diese Befehle müssen nur einmalig auf dem jeweiligen Server ausgeführt werden.
> Das Volume-Mapping ist in `config/deploy.yml` bzw. `config/deploy.staging.yml` unter `servers.web.volumes` konfiguriert.
