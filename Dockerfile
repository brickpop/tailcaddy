FROM caddy:2-builder AS builder

# Build Caddy with the Cloudflare DNS and the TailScale modules
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/tailscale/caddy-tailscale

# Build the base image with the custom server binary
FROM caddy:2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
