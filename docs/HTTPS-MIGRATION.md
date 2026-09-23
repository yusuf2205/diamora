# Production HTTPS migration plan (§16, M3 round)

The architecture has been HTTPS-ready since D-025 (RBAC round): Caddy only ever speaks plain HTTP *inside* the stack
(`:8080`), and terminates nothing itself — TLS is meant to happen at a Cloudflare Tunnel in front of it. One origin,
path-routed (`/v1/*`, `/health/live`, `/socket.io/*` → API; everything else → web), so the mobile app, the web panel
and WebSocket all become `https://`/`wss://` automatically the moment the tunnel exists — **no code changes are
needed on the server side**. This doc is the exact sequence to flip it on.

## Current status: live (2026-09-23) — one hardening item left (step 5b)

`https://diamoraa.uz` is live: DNS, Tunnel, and the Public Hostname route are all up (`cloudflared tunnel healthy` in
`verify-stack.sh`), `PUBLIC_URL=https://diamoraa.uz` on the NAS, the web panel and API are on one HTTPS origin, and
the owner confirmed a real login through it. Steps 1-4 and 8 (mobile dart-define still pending an APK rebuild once
the phone reconnects) are done.

Found and fixed along the way: right after the `PUBLIC_URL` switch, the web image still had the *old* LAN
`NEXT_PUBLIC_API_URL` baked in from its previous build (it's a Next.js build-time env var, not read at runtime) —
the owner's browser, on the HTTPS page, tried to call the plain-HTTP LAN API and got blocked as mixed content
("Не удалось войти" with no specific error code). Fixed by rebuilding the web image after the `.env` change
(`docker compose up -d --build`), which re-bakes `NEXT_PUBLIC_API_URL` from the new `PUBLIC_URL`.

**Remaining (step 5b): Cloudflare "Always Use HTTPS" is off.** `curl http://diamoraa.uz/login` returns `200` instead
of a redirect to `https://` — the master prompt's HTTP→HTTPS redirect check. Not a functional blocker (everyone's
actually landing on `https://` already via the app/bookmarks), but plain-HTTP requests aren't forced to upgrade.
Owner action: Cloudflare dashboard → the `diamoraa.uz` zone → SSL/TLS → Edge Certificates → toggle **Always Use
HTTPS** on. I can re-verify the redirect once that's flipped.

Not yet explicitly checked: WebSocket (`wss://`) upgrade through the tunnel, and a file upload/download round-trip
over HTTPS (both should work automatically — same origin, same Caddy routing as before — but haven't been
exercised end-to-end since the switch).

## Steps

1. **Owner: switch `diamoraa.uz`'s nameservers to Cloudflare** (already explained step-by-step earlier in this
   conversation — add the site to a free Cloudflare account, get the two `*.ns.cloudflare.com` addresses, set them at
   the domain registrar). I'll re-check DNS once told this is done.
2. **Owner: create the Tunnel** in Cloudflare Zero Trust → Networks → Tunnels → *Create a tunnel* (Cloudflared) →
   name it `yusmus` → copy the **token** it shows → *Public hostname*: `diamoraa.uz` (or `api.diamoraa.uz` if the
   owner would rather split web/API onto two hostnames — not required, the existing path-routing already handles one
   hostname for both) → service **HTTP `caddy:8080`**.
3. **Give me the tunnel token.** I set it on the NAS as `CLOUDFLARE_TUNNEL_TOKEN` in `.env` (never in docs/git),
   set `PUBLIC_URL=https://diamoraa.uz`, and run `docker compose --profile tunnel up -d` — this starts the
   `cloudflared` sidecar already defined in `docker-compose.yml`, nothing new to build.
4. **I verify**: `curl https://diamoraa.uz/health/live` from outside the LAN (phone off Wi-Fi, or any external
   network) → expect `200`; confirm `/v1/workers` still requires auth (401, not exposed); confirm the web app loads;
   confirm a Socket.IO connection upgrades to `wss://` (the browser/Dio client do this automatically once the page
   itself loads over `https://` — no client code change, only the `API_URL` dart-define changes).
5. **CORS**: not expected to need a change — web and API share one origin behind Caddy (D-025), `CORS_ORIGINS` only
   matters for local dev against a separately-hosted panel. Verified once the tunnel is live.
6. **MinIO signed URLs**: `PUBLIC_API_URL` already drives how the API signs file URLs (`/v1/files/:id/...`) — once
   `PUBLIC_URL`/`PUBLIC_API_URL` is `https://diamoraa.uz`, signed URLs are issued under that host automatically; no
   separate MinIO-facing hostname is exposed either way (MinIO itself stays internal-only, D-025).
7. **Telegram bot**: unaffected — it's long-polling (`apps/api/src/worker.ts`), not a webhook, so it has no public
   URL dependency at all. Nothing to change here during this migration.
8. **Rebuild the mobile APK** with `--dart-define=API_URL=https://diamoraa.uz` — production build no longer needs
   the LAN cleartext exemption to function, though `network_security_config.xml` (D-042) stays in the app for local
   dev/LAN testing (§17: "не ломать LAN fallback" — it's additive, never required once HTTPS works). Version bump to
   `1.0.0-rc.2`.
9. **Full real-device pass** against the new HTTPS build (§23-24 of the master prompt) once rc.2 exists.

## What does NOT change
- PostgreSQL/Redis/MinIO: still never published to the internet (D-025) — the tunnel only ever reaches Caddy.
- The LAN fallback (`http://192.168.1.105:8088`) keeps working for home-network/Tailscale testing; it is a separate,
  already-working path, not something this migration removes.
