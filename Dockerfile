# syntax=docker/dockerfile:1
#
# Self-hosting image for the COSDEP website.
# Stage 1 builds the static export; stage 2 serves it with Caddy (automatic HTTPS).
# Nothing from Node runs at runtime — the final image is just Caddy + static files.

# ---------- Build stage: produce the static export (./out) ----------
FROM node:22-alpine AS build
WORKDIR /app

# Install dependencies from the committed lockfile for reproducible builds.
COPY package.json package-lock.json ./
RUN npm ci

# Build the static site. `output: "export"` in next.config.ts writes ./out.
COPY . .
RUN npm run build

# ---------- Serve stage: Caddy serves ./out over HTTP/HTTPS ----------
FROM caddy:2-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/out /srv

# 80 = HTTP (redirects to HTTPS), 443 = HTTPS, 443/udp = HTTP/3.
EXPOSE 80 443
