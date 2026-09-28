# Diamoraa — what it is and what was built

*As of 28 Sep 2026. Русская версия: [PROJECT.ru.md](PROJECT.ru.md).*

Diamoraa runs a home-based ribbon-and-bead production business. Workers (craftswomen) sew at home, staff deliver materials and collect finished work, and the owner sees everything: people, stock, money, the map.

Everything runs on the **owner's own NAS** (no cloud database), published through a Cloudflare Tunnel:

| Address | Who |
|---|---|
| **diamoraa.uz** | workers: download the app or open the web version |
| **diamoraa.uz/w** | web version for workers (iPhone, or anyone who won't install the app) |
| **admin.diamoraa.uz** | staff and owner panel |
| **@diamora1_bot** | worker registration and Telegram sign-in |

---

## Roles

| Role | Can |
|---|---|
| **Super admin** | everything: people, permissions, work, stock, money, settings, audit log; delete and cancel |
| **Admin** | nearly everything by default except role management; permissions can be granted/revoked one by one |
| **Manager** | only **their own** workers: their work, payouts, map (the server never returns others) |
| **Worker** | her own work, her own money, ordering work, receiving by QR |

Permissions are enforced by the **server**, not by hiding buttons.

---

## A working day

1. **A worker joins.** Either on her own via the Telegram bot (4 questions: name, phone, location, collateral) and waits for approval, or by **invitation**: staff enter name + phone and send a link with a QR; she opens it and is active at once.
2. **She picks work.** Catalog «Наши работы» → «Заказать эту работу» (colour, 9/18/27 m, a wish). Staff see «Заявки на работу».
3. **Staff prepare the work** from the request: materials leave the warehouse into a kit, a QR label is printed.
4. **Two-sided QR handoff.** Staff scan the QR at her door → «Начать передачу». She scans the same QR with her phone, sees exactly what she gets and **herself** taps «Подтвердить получение». Only then are the materials on her. «Есть проблема» (shortage, wrong colour…) moves nothing.
5. **Work.** She reports progress («12 of 18 m done»), then «Работа готова».
6. **Staff collect** («Забрал», by QR) and **inspect**: accepted / defective / rework. Pay is computed automatically — **one global rate per 9 m**, changed only by the super admin.
7. **Cash payout**, partial or full, with a confirmation; overpaying is impossible.
8. **Reports and summaries**: day / week / month per worker, Excel export.

---

## What was built

### For workers
- **Diamoraa Android app** (Flutter), downloaded from diamoraa.uz, **updates itself**: downloads the new version in the background and offers «Install».
- **Web version** at diamoraa.uz/w with the same features (Telegram sign-in, camera QR scanner, receiving, progress, ordering, money, notifications) and an «Add to home screen» button.
- **Password-free** sign-in through Telegram.
- Home: «Choose work» and «Scan QR» always on top; waiting work with pay and materials; her request; balance; **earnings by month**.
- **In-app notifications** (bell + Android notifications, also while the app is closed): new work, «staff are at your door», work accepted, earned, paid, request declined, deadline tomorrow/today.

### For staff
- **Overview**: quick actions in one row, «needs attention», counters (deliver, collect, inspect, to pay, overdue).
- **Workers**: registrations, approval with collateral, profile, manager, archive, **delete** (when there is no history), **add by invitation** (link + QR straight into Telegram).
- **Work**: step-by-step creation, QR handoff, inspection, payout, **cancel** (materials back to stock or written off), **change deadline**, a human-readable history.
- **Map** (Yandex) with live dots; hiding someone from the map is the super admin's call; **«Route» builds the route from the current position** in Yandex Navigator.
- **Inventory**: materials, receipts, write-offs, 9 m kit recipes, materials held by workers, «running low» alerts.
- **QR label printing** (80×60 mm) for work, workers and kits — from the app and the panel.
- **Reports** with Excel export; **audit log**: who, what, before → after.
- **Team**: add admins/managers, roles, granular permissions, passwords (typed by people only), deactivate, **delete** (when there is no history).
- Notifications: new registration, work request, work ready, handoff problem, overdue, **material running low**, **daily summary** (20:00), **weekly/monthly report**.

### Reliability and data
- Every money and stock operation is **one transaction**; replays and double taps never duplicate anything (idempotency keys, row locks, unique indexes). The database itself forbids negative stock and edits of history.
- **Backups** on the NAS: daily dump, weekly base backup with WAL, files, config; restore is verified daily in a scratch database.
- **NAS resilience**: UGREEN resets file ownership under `/volume1/docker` after every reboot; a `permfix` sidecar gives the database and Redis their files back within ~20 s; deploys check ownership first and abort without changing anything.
- Built to grow: paginated lists, aggregation in the database, indexes for reports and notifications, a 90-day position trail, a compact UI even with a large system font.

### Technology
- **Server**: NestJS 11 + PostgreSQL 17 (Prisma) + Redis + MinIO + Socket.IO; the Telegram bot is a separate process.
- **App**: Flutter 3 (Riverpod, GoRouter), Manrope font, Yandex MapKit, camera QR, PDF printing.
- **Panel and web version**: Next.js 16, React Query, Tailwind.
- **Infrastructure**: Docker Compose on the NAS, Caddy, Cloudflare Tunnel, deploy and APK publishing scripts.
- **Tests**: API 165+, app 141+, web 62+ — all run before every deploy.

---

## What is left

- **iPhone app**: needs an Apple Developer account ($99/year) and a Mac to build. Until then iPhones use the web version.
- **Instant push while the app is closed**: today it checks about every 15 minutes; instant delivery needs a free Firebase project on the owner's account.
- **Map in the app**: if it shows squares, add `uz.diamoraa.app` to the MapKit key at developer.tech.yandex.ru.
- Pilot: 1–2 days with real workers, then fixes from their feedback.
