# Yandex Maps (SUPER_ADMIN / ADMIN / MANAGER app)

- Package: **`yandex_maps_mapkit_lite`** — Yandex's own Flutter package (publisher maps.yandex.ru, v4.45.0, Android + iOS; D-026). The community `yandex_mapkit` is no longer preferred. "Lite" = interactive map, markers, user location, traffic — everything the map needs. Route building (the "Full" SDK) is not needed: **Route** is a deep link into the Yandex Maps app.
- Key: `--dart-define=YANDEX_MAPKIT_KEY=...` → `init.initMapkit(apiKey: …)` in `main()` (owner action, D-013; steps in NAS-DEPLOYMENT "Owner checklist"). Free licence: up to 25 000 monthly active users — we have a dozen. **The map screen itself is still M4** — not built in this round. What already exists and is tested: the live-location data source it will read (`GET /v1/locations`, [LIVE-LOCATION.md](LIVE-LOCATION.md)) and a plain-list screen (`locations_screen.dart`) showing exactly the fields a marker will need.
- Workers are markers at their live position (`UserLiveLocation`, D-030) or, until she has reported one from the app, her Telegram registration GPS (`WorkerProfile.latitude/longitude`, `locationReceivedAt`).
- **Who sees whom is the same rule as everywhere else** (§23-26, D-028): `SUPER_ADMIN`/`ADMIN` with `MAP_VIEW_ALL`/`LIVE_LOCATION_VIEW_ALL` see everyone; a `MANAGER` with the `_ASSIGNED` variants sees only her own assigned workers, enforced server-side — never a client-side filter on a full list.

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
