# Deploy SSH Key Setup

Der SSH-Key für das Kamal-Deployment muss **ohne Passphrase** generiert werden.

## Neuen Key generieren (lokal ausführen)

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/btv_deploy_key
# Bei "Enter passphrase" einfach ENTER drücken (keine Passphrase!)
```

## Public Key auf den Server kopieren

```bash
ssh-copy-id -i ~/.ssh/btv_deploy_key.pub user@dein-server.ch
```

Oder manuell den Inhalt von `~/.ssh/btv_deploy_key.pub` in `~/.ssh/authorized_keys` auf dem Server einfügen.

## Private Key als GitHub Secret hinterlegen

1. `cat ~/.ssh/btv_deploy_key` → kompletten Inhalt kopieren (inkl. `-----BEGIN...` und `-----END...`)
2. GitHub Repo → Settings → Secrets and variables → Actions
3. Secret `DEPLOY_SSH_KEY` aktualisieren oder neu anlegen
4. Inhalt einfügen → Save

---

Danach läuft `webfactory/ssh-agent@v0.9.0` im CI fehlerfrei durch.
