# Deploying the COSDEP website on your own server

This site is a **static export** — `npm run build` produces a folder of plain
HTML/CSS/JS with **no server process to run**. That means it costs nothing to
host beyond the server you already have, and it can't "sleep" or hit a usage
tier the way a Node app does.

You'll run it with **Docker**. One container builds the site and serves it with
[Caddy](https://caddyserver.com/), which obtains and renews a **free HTTPS
certificate automatically** from Let's Encrypt. No Render, no monthly fee.

---

## What you need

- A Linux server you can SSH into (any provider, or your own hardware).
- **Docker** with the Compose plugin installed.
- A **domain name** you can point at the server (for HTTPS).
- Ports **80** and **443** open to the internet on that server.

---

## One-time setup

### 1. Point your domain at the server

In your domain registrar's DNS settings, create **A records** pointing to your
server's public IP address:

| Type | Name  | Value              |
|------|-------|--------------------|
| A    | `@`   | `YOUR.SERVER.IP`   |
| A    | `www` | `YOUR.SERVER.IP`   |

DNS can take a few minutes to a few hours to propagate. Caddy can only issue the
HTTPS certificate **after** the domain resolves to this server, so do this first.

### 2. Install Docker (skip if already installed)

On Ubuntu / Debian:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # then log out and back in
```

Verify:

```bash
docker --version
docker compose version
```

### 3. Open the firewall (if you use `ufw`)

```bash
sudo ufw allow 80
sudo ufw allow 443
```

### 4. Get the code onto the server

```bash
git clone https://github.com/simboni/cosdep-kenya.git
cd cosdep-kenya
```

### 5. Configure your domain

```bash
cp .env.example .env
nano .env
```

Set your real domain:

```ini
SITE_ADDRESS=cosdepkenya.org www.cosdepkenya.org
```

> Testing before DNS is ready? Set `SITE_ADDRESS=:80` to serve plain HTTP on the
> server's IP, then switch to your domain later.

### 6. Build and start

```bash
docker compose up -d --build
```

The first build takes a couple of minutes (it installs dependencies and builds
the site inside the container). When it finishes, Caddy fetches your HTTPS
certificate automatically.

Open **https://cosdepkenya.org** — you should see the site with a padlock. Done. 🎉

---

## If the server already runs another site on ports 80/443

Only one program can hold ports 80 and 443 on an IP address. If the server
already runs a reverse proxy for another app, this site can't take those ports —
`docker compose up` fails with `Bind for 0.0.0.0:80 failed: port is already
allocated`.

The fix is to run this site **behind** the existing proxy. The apps stay fully
separate (own containers, own data, own deploys); they only share the front door,
which routes by domain name.

**1. Start the site with no published ports, on the proxy's network:**

```bash
echo 'PROXY_NETWORK=riziki-pos_default' >> .env       # the proxy's docker network
docker compose -f docker-compose.behind-proxy.yml up -d --build
```

**2. Add a site block to the existing proxy's config.** For Caddy:

```
cosdepkenya.org {
	reverse_proxy cosdep-website:80
	encode zstd gzip
}

www.cosdepkenya.org {
	redir https://cosdepkenya.org{uri} permanent
}
```

**3. Validate, then reload — never restart.** A reload keeps the other sites
serving and refuses to apply a broken config; a restart would take them down:

```bash
docker exec <proxy-container> caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec <proxy-container> caddy reload  --config /etc/caddy/Caddyfile
```

Caddy fetches the HTTPS certificate for the new domain automatically, as soon as
the domain's DNS points at this server.

---

## Updating the site later

Whenever the site's code changes (new content, fixes, etc.):

```bash
cd cosdep-kenya
git pull
docker compose up -d --build
```

Only a few seconds of downtime while the new container swaps in. Your HTTPS
certificate is preserved (it lives in a Docker volume, not the container).

---

## Handy commands

```bash
docker compose logs -f          # watch logs (Ctrl-C to stop watching)
docker compose ps               # is it running?
docker compose restart          # restart without rebuilding
docker compose down             # stop and remove the container
docker compose up -d --build    # rebuild and start
```

---

## Troubleshooting

**The site loads on HTTP but there's no padlock / certificate errors.**
Caddy can only issue a certificate once the domain points at this server and
ports 80 + 443 are reachable from the internet. Check:
- `dig +short cosdepkenya.org` returns your server's IP.
- The firewall/security group allows 80 and 443.
- `docker compose logs -f` — Caddy prints exactly what it's waiting on.

**"Port is already allocated" on startup.**
Another web server (e.g. an existing nginx/Apache) is using port 80/443. Stop it
(`sudo systemctl stop nginx`) or free the ports before running Compose.

**Rebuild is slow or runs out of memory on a tiny server.**
The Next.js build needs ~1 GB RAM. On a very small VPS, build the image once on a
bigger machine and `docker push`/`docker save` it, or add swap:
```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
```

**Want to serve on a subdomain** (e.g. `www` → apex redirect, or `cosdep.example.org`)?
Edit `SITE_ADDRESS` in `.env` and re-run `docker compose up -d --build`.

---

## Notes

- **Render is no longer needed.** The old `render.yaml` is left in the repo for
  reference only — nothing here uses it. You can delete it if you like.
- **No database, no secrets, no runtime env vars.** Everything is baked into the
  static files at build time, which is why hosting is so cheap and simple.
- **Backups:** the only stateful thing is the `caddy_data` Docker volume (your
  certificates). Even if you lose it, Caddy just re-issues the certificate on the
  next start.
