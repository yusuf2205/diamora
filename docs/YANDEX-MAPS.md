# Yandex Maps (SUPER_ADMIN / ADMIN / MANAGER app + web panel)

- Package: **`yandex_maps_mapkit_lite`** — Yandex's own Flutter package (publisher maps.yandex.ru, v4.45.0, Android + iOS; D-026). The community `yandex_mapkit` is no longer preferred. "Lite" = interactive map, markers, user location, traffic — everything the map needs. Route building (the "Full" SDK) is not needed: **Route** is a deep link into the Yandex Maps app.
- Key: `--dart-define=YANDEX_MAPKIT_KEY=...` → `init.initMapkit(apiKey: …)` in `main()`, called once before `runApp` (owner action, D-013; steps in NAS-DEPLOYMENT "Owner checklist"). Free licence: up to 25 000 monthly active users — we have a dozen.
- **The map is brought forward from M4 into M2** (owner's explicit "не откладывать", 2026-09-22) — a real screen now exists on both Flutter and web, reading the SAME `GET /v1/locations` ([LIVE-LOCATION.md](LIVE-LOCATION.md)) the earlier round already built and tested. Nothing about `pickup`/`delivery` filters is fabricated: those still need `WorkAssignment`/`Delivery` (M3/M4) and are not present.
- **Flutter** (`features/map/map_screen.dart`): `yandex_maps_mapkit_lite`'s `MapWindow`/`PlacemarkMapObject` API, imported under an `as ymk` prefix (its barrel export collides with Flutter's own `Icon`/`TextStyle`/`ImageProvider` if imported bare). Marker colour = role first, then freshness (a STALE point is always the neutral grey, whatever the role); the coloured dot is drawn straight with `dart:ui` (`PictureRecorder`/`Canvas`), no image assets needed. Tap → bottom sheet (name, role, online/offline, freshness, phone, Call/Route/Open-profile). An AppBar action switches to the existing tested list view (`locations_screen.dart`) — useful when tiles fail to load. **Honest gap:** `flutter analyze` fully type-checks this file against the real installed package (strong signal the FFI binding calls are correct), but the native rendering itself has not been run on a real device/emulator in this session (no device available) — not claimed as device-verified.
- **Web** (`app/(app)/map/page.tsx`): Yandex JS Maps API (`api-maps.yandex.ru`), loaded only if `NEXT_PUBLIC_YANDEX_MAPS_JS_KEY` is set — **a different product/key than the mobile MapKit key above**, not yet supplied by the owner. Without it the page falls back to a real, fully working card list (same fields, click → detail panel) instead of a blank or broken map — never fabricated tiles. Polls `GET /v1/locations` every 15 s (the same "auto-refresh" pattern the dashboard already uses; the web panel has no WebSocket client yet, a pre-existing gap, not new).
- Workers are markers at their live position (`UserLiveLocation`, D-030) or, until she has reported one from the app, her Telegram registration GPS (`WorkerProfile.latitude/longitude`, `locationReceivedAt`).
- **Who sees whom is the same rule as everywhere else** (§23-26, D-028): `SUPER_ADMIN`/`ADMIN` with `MAP_VIEW_ALL`/`LIVE_LOCATION_VIEW_ALL` see everyone; a `MANAGER` with the `_ASSIGNED` variants sees only her own assigned workers, enforced server-side — never a client-side filter on a full list. `GET /v1/locations` now also carries `phone` and live `online` presence, so a marker's bottom sheet needs no second request.

## Filters (no distance sorting)
`GET /v1/map/workers?filter=all|pickup|delivery`

| Filter | Shows workers with |
|---|---|
| `all` | status ACTIVE |
| `pickup` ("Есть что забрать") | an assignment `READY_FOR_PICKUP` |
| `delivery` ("Нужно доставить") | a `PENDING` delivery of type `DELIVERY_TO_WORKER` |

Marker tap → bottom sheet card:
- delivery: name, phone, model/colour, "2 × комплект 9 м", total metres, contents (ribbon, beads, thread, extras), comment, date, linked assignment → **[Позвонить] [Построить маршрут] [Доставлено]**
- pickup: name, phone, model/colour, ready metres, ready date, photos, comment → **[Позвонить] [Маршрут] [Забрал]**

## Actions
- **Call:** `tel:+998…` (`url_launcher`).
- **Route:** `yandexmaps://maps.yandex.ru/?rtext=~<lat>,<lon>&rtt=auto`, fallback `https://yandex.uz/maps/?rtext=~<lat>,<lon>&rtt=auto`. No API key needed.
- **Delivered / Picked up:** API call → transaction → COMMIT → realtime; the marker disappears from the filter on every ADMIN device.

Privacy: coordinates are shown only to ADMIN; map tiles are requested by the phone from Yandex, our data is not sent to Yandex.
