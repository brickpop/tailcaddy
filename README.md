Caddy internal TLS
---

This repo builds a custom Caddy server image that can be used to:
- Expose internal services, only accessible via TailScale
- Get valid TLS certificates with CloudFlare's API (verifying domains via DNS)

## Getting started

### Starting Caddy

- Ensure that you have Docker installed.
- Run `cp .env.example .env`
- Parameterize `.env` with the appropriate settings
- Edit `Caddyfile` to set up a reverse proxy for your desired services
- Start Caddy: `docker compose up -d`

Requests will not work until you start the services where Caddy should reverse proxy to.

### Start your services

Start your desired Docker services
- Add them to the `internal_net` network
- Ensure that `internal_net` is declared as `external`, so that Caddy can reach them

```yaml
# compose.yaml
services:
  my-service:
    image: nginx:latest
    container_name: my-service
    restart: unless-stopped
    networks:
      - internal_net

networks:
  internal_net:
    external: true
```

- Start your service with `docker compose up -d`.
- Create a DNS record on Cloudflare and make it point to the IP address that TailScale assigned to Caddy
- Navigate to `<host>.yourdomain.com`
