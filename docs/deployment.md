# Deployment (Docker, GHCR, Hostinger VPS)

```
GitHub push (main) ──▶ GitHub Actions ──▶ ghcr.io/<owner>/open-presenter ──▶ VPS docker compose
```

The image is immutable: the Office add-in, the web assets and the Phoenix
release are all built in `Dockerfile` by CI. The VPS only pulls.

## 1. GitHub

```bash
git remote add origin git@github.com:YOUR_USERNAME/open-presenter.git
git push -u origin main develop
```

`.github/workflows/docker.yml` runs the tests, builds the add-in and pushes
`ghcr.io/<owner>/open-presenter:latest` (plus branch and semver tags) using
the repository's own `GITHUB_TOKEN`. Make the package public in GitHub →
Packages, or log the VPS in to GHCR with a read-only PAT.

## 2. DNS

```
Type: A    Name: poll    Value: <VPS IP>
```

## 3. VPS

Option A — Hostinger **Docker Manager** (hPanel → VPS → Manage → Docker
Manager → Compose): paste `docker-compose.yml` (or `docker-compose.standalone.yml`
when no Traefik exists on the VPS) and add the variables from `.env.example`.

Option B — SSH:

```bash
ssh root@YOUR_VPS
mkdir -p /opt/open-presenter && cd /opt/open-presenter
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/open-presenter/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/open-presenter/main/.env.example
cp .env.example .env && nano .env      # BASE_URL, DOMAIN, passwords, SECRET_KEY_BASE
openssl rand -base64 64                 # -> SECRET_KEY_BASE
docker network create proxy-network     # only if it does not exist yet
docker compose pull && docker compose up -d
docker compose ps && docker compose logs -f app
```

`docker-compose.yml` attaches to an existing Traefik on `proxy-network`
(Hostinger's Docker templates) with labels for HTTPS + WebSockets.
`docker-compose.standalone.yml` brings its own Caddy (automatic Let's
Encrypt, WebSocket forwarding) and publishes 80/443.

Routes on one origin:

```
https://poll.example.com/            application
https://poll.example.com/e/ABC123    attendee join
https://poll.example.com/e/ABC123/presenter
https://poll.example.com/office/     PowerPoint add-in (+ /office/manifest.xml)
https://poll.example.com/api/office/ Office API
https://poll.example.com/health      health check
```

## 4. First login

Seeds create `admin@claper.co` / see `priv/repo/seeds.exs`. Log in, change
the password, create your account, then set `ENABLE_ACCOUNT_CREATION=false`.

## 5. Migrations

The container runs `Claper.Release.migrate` before starting. Back up first:

```bash
docker compose exec db pg_dump -U openpresenter openpresenter | gzip > backup-$(date +%F).sql.gz
```

New tables in this fork: `word_clouds`, `word_cloud_responses`, `open_ended`,
`open_ended_responses`, `open_ended_votes`, `office_tokens`.

## 6. Backups

Daily PostgreSQL dump + uploads volume, keep 7 daily and 4 weekly copies,
push them off the VPS (e.g. `rclone` to object storage):

```bash
# /etc/cron.daily/open-presenter-backup
#!/bin/sh
cd /opt/open-presenter
docker compose exec -T db pg_dump -U openpresenter openpresenter | gzip > /backup/db-$(date +%F).sql.gz
docker run --rm -v open-presenter_uploads:/u -v /backup:/b alpine tar czf /b/uploads-$(date +%F).tgz -C /u .
find /backup -name 'db-*' -mtime +7 -delete
```

## 7. Monitoring

`GET /health` → `{"status":"ok","database":"ok","version":"..."}` (503 when
the database fails). Watch container restarts (`docker compose ps`), disk,
RAM, CPU and WebSocket errors in `docker compose logs app`.

## Updates from upstream Claper

```bash
git fetch upstream
git merge upstream/dev
```

Conflicts, if any, will be in the files listed in `docs/architecture.md`.
