# Docker Compose Sample App

A minimal 3-tier app demonstrating Docker Compose:

- **nginx** — web server / reverse proxy, exposed on `localhost:8080`
- **web** — Flask app (served via Gunicorn), not exposed directly; only nginx talks to it
- **db** — PostgreSQL database with a persistent named volume

```
Browser → nginx (port 8080) → web (Flask/Gunicorn, port 5000) → db (Postgres, port 5432)
```

## Project layout

```
sample-app/
├── docker-compose.yml
├── .env.example
├── db-init/
│   └── 01-init.sql        # optional table bootstrap, runs on first DB init
├── nginx/
│   ├── Dockerfile
│   └── default.conf       # reverse proxy config
└── web/
    ├── Dockerfile
    ├── app.py              # Flask app
    ├── requirements.txt
    └── templates/index.html
```

## Run it

1. (Optional) copy the env template and adjust credentials:
   ```bash
   cp .env.example .env
   ```
2. Build and start everything:
   ```bash
   docker compose up --build
   ```
3. Open **http://localhost:8080** — submit a message and it's stored in Postgres, then listed on the page.
4. Health check: **http://localhost:8080/health** returns JSON with app and DB status.

## Stop / clean up

```bash
docker compose down        # stop containers, keep DB data
docker compose down -v     # stop containers AND delete the DB volume
```

## How it fits together

- `docker-compose.yml` defines three services on a shared `backend` bridge network, so they can reach each other by service name (`db`, `web`, `nginx`).
- Only `nginx` publishes a port to the host (`8080:80`); `web` and `db` stay internal, which is the usual pattern for a reverse-proxied app.
- `web` waits for `db`'s healthcheck (`pg_isready`) before starting, and also retries its own DB connection on startup as a second safety net.
- Postgres data persists in the named volume `db_data` across `docker compose down` / `up` cycles (but not `down -v`).

## Extending this

- Swap Flask for another framework — keep the same "app listens on 5000, nginx proxies to it" shape.
- Add a `.env` with real secrets for anything beyond local dev; don't commit real credentials.
- Add TLS termination in nginx, or put nginx behind a load balancer, for anything production-facing.