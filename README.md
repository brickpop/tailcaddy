# TailCaddy

**Friendly HTTPS for self-hosted services, reachable only over your tailnet.**

Put your local apps behind clean hostnames like `cloud.example.com` with valid, browser-trusted TLS certificates — without opening a single port to the public internet. Any device on your tailnet gets a green lock; to the rest of the world, the service simply doesn't answer.

## What you get

- **Real TLS certificates** from Let's Encrypt. No self-signed warnings, no `.local` workarounds.
- **No public exposure.** No port forwarding, no public IP, no Cloudflare Tunnel needed.
- **Nice hostnames.** `photos.example.com` instead of `http://192.168.1.42:2342`.
- **One proxy for everything.** Add a new service by adding a few lines to a `Caddyfile`.

## How it works

Three moving parts:

1. **Caddy** terminates TLS and reverse-proxies to your services.
2. **Cloudflare** hosts your domain's DNS. Caddy uses the Cloudflare API to solve Let's Encrypt's DNS challenge, so certificates are issued without ever needing a public HTTP listener.
3. **Tailscale** carries the actual traffic. Caddy binds its HTTPS listener to its Tailscale interface only — your tailnet devices can reach it; nothing else can.

The result: a public DNS record pointing at a private `100.x.x.x` address. The hostname resolves from anywhere, but the IP is only routable inside your tailnet.

This repo ships a small `Dockerfile` that rebuilds Caddy with the Cloudflare-DNS and Tailscale plugins, plus a `compose.yaml` and an example `Caddyfile` you copy and adapt.

## Requirements

- Docker + Docker Compose. (Podman Compose should also work.)
- A domain on Cloudflare (free plan is enough) and a Cloudflare API token scoped to **Zone → DNS → Edit** on that zone. [Create one](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/).
- A Tailscale account and an [auth key](https://tailscale.com/kb/1085/auth-keys/).

## Quick start

Set up your own Caddy reverse-proxy as a Docker service on your host, wired to your tailnet and the services behind it.

```bash
git clone https://github.com/brickpop/tailcaddy.git
cd tailcaddy
cp .env.example .env
# fill in BASE_DOMAIN, TS_AUTHKEY, CLOUDFLARE_API_TOKEN, (optional) TS_DOMAIN
```

Edit `Caddyfile` to declare a hostname for each service you want to expose (see [Connecting your services](#connecting-your-services) for examples). Then:

```bash
docker network create caddy_net   # once — the shared network your services will join
docker compose up -d
```

On first boot Caddy joins your tailnet (it will appear in the
[Tailscale admin console](https://login.tailscale.com/admin/machines)) and requests certificates as soon as DNS is pointed at it.

## Point DNS at Caddy

In Cloudflare, create a DNS record for each hostname you want to use (or a wildcard `*.example.com`), pointing at Caddy's **Tailscale IP** (`100.x.x.x`, shown in the Tailscale admin console). Set it to **DNS only** — no Cloudflare proxying.

Yes, it's a public DNS record pointing at a private IP. That's intentional: the name resolves everywhere, but the IP only routes inside your tailnet. The TLS certificate is still valid because DNS-01 doesn't require the host to be publicly reachable. From a tailnet device, HTTPS works; from anywhere else, the browser just times out.

## Connecting your services

### A service on the same Docker host

Caddy reaches your Docker services through a shared network called `caddy_net`.
Any container that joins this network is reachable by Caddy by its
`container_name`.

```yaml
# compose.yaml of your service
services:
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    networks:
      - caddy_net

networks:
  caddy_net:
    external: true
```

In `Caddyfile`:

```caddy
cloud.{$BASE_DOMAIN} {
    bind tailscale/
    tls { dns cloudflare {$CLOUDFLARE_API_TOKEN} }
    reverse_proxy http://nextcloud:80
}
```

### A service on another tailnet machine

If the backend runs on a different device on your tailnet (a NAS, a VM, another host), proxy to its Tailscale hostname:

```caddy
nas.{$BASE_DOMAIN} {
    bind tailscale/
    tls { dns cloudflare {$CLOUDFLARE_API_TOKEN} }
    reverse_proxy http://mynas.{$TS_DOMAIN}:8080
}
```

`TS_DOMAIN` is your tailnet's MagicDNS suffix (e.g. `xxx-yyy.ts.net`, shown in the Tailscale admin console).

### Enabling CORS

A reusable `(cors)` snippet ships in the `Caddyfile` for services that need to accept requests from a frontend hosted on a different origin. Import it inside a site block with the allowed origin:

```caddy
import cors https://app.{$BASE_DOMAIN}
```

After editing `Caddyfile`, reload without downtime:

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## Day 2

- **Logs:** `docker compose logs -f caddy`
- **Reload config:** `docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile`
- **Update Caddy:** `docker compose build --pull && docker compose up -d`
- **State:** certificates and the Tailscale node identity live in the `caddy_data` and `caddy_config` Docker volumes. Back them up to avoid re-auth and re-issuance.

## FAQ

**It doesn't work from outside my tailnet.** Correct — that's the whole point. Connect a device to your tailnet and try again.

**Can I use another DNS provider?** Yes. Replace `caddy-dns/cloudflare` in the `Dockerfile` with any of the [caddy-dns providers](https://github.com/caddy-dns) and adjust the `tls { dns ... }` block in the `Caddyfile`.

**Can I also expose a service publicly?** Yes, but this repo is deliberately scoped to the tailnet-only case. Drop `bind tailscale/` on a given host to listen on all interfaces — but then you own the public surface area.

**What if I don't use Cloudflare for DNS?** You need a provider whose API is supported by a `caddy-dns` plugin (most major ones are), and you need to be able to manage records via API.
