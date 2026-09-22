# Live location & presence (D-030, D-031)

Background working location for **all four roles** (§19-26) — not just the worker GPS captured once at Telegram
registration (`WorkerProfile.latitude/longitude`, still used for M4's map filters). This is the *current* position,
kept fresh while the app runs, including in the background.

## The permission flow (§20) — never a lie

The app checks, in order, and shows a full-screen gate naming exactly what is missing until it is fixed:

1. **Location Services (GPS) on the device** — `Geolocator.isLocationServiceEnabled()`. If off: a button opens the
   system Location Settings screen. The app never claims to switch it on itself.
2. **Foreground permission** ("while using the app") — `permission_handler`'s `locationWhenInUse`. Denied → a button
   requests it (one native dialog). Denied permanently (Android "don't ask again" / iOS "Never") → the button instead
   opens the app's own Settings page, because a request would no longer show a dialog at all.
3. **Background permission** ("Always") — `locationAlways`, requested only after foreground is granted (the platforms
   require that order). Same denied/denied-forever handling.

Only once all three are satisfied does the gate show the real screen (`apps/mobile/lib/features/location/location_gate.dart`,
wrapping both the staff and the worker shell). Returning from system Settings is picked up automatically
(`WidgetsBindingObserver.didChangeAppLifecycleState` re-checks on resume) — no manual "I granted it, now what" step.

## Reporting (battery-conscious by construction, §21)

`LocationTracker` (`apps/mobile/lib/core/location/location_tracker.dart`) combines:
- a **movement-triggered stream** (`Geolocator.getPositionStream`, 25 m `distanceFilter`) — nothing is sent while the
  phone is still;
- a **5-minute heartbeat** — so a stationary phone is not silently forgotten.

Every report is `POST /v1/location { latitude, longitude, accuracy?, heading?, speed?, recordedAt, isBackground }` —
**self only**; the server takes the identity from the JWT and ignores any id in the body. A worker's report also
refreshes her classic `WorkerProfile.latitude/longitude/locationReceivedAt` (what the future Yandex map, M4, reads),
so both fields stay consistent without a second GPS system.

## Storage

`UserLiveLocation` keeps **one row per user** — the latest position, overwritten every time. No unbounded coordinate
history: this is a location "on file" for right now, not a trail (a full breadcrumb log was not requested and is not
built — brief §21's own instruction: "Не хранить бессмысленную бесконечную историю координат без бизнес-требования").

## Reading — scoped exactly like everything else

`GET /v1/locations` requires `LIVE_LOCATION_VIEW_ALL` or `LIVE_LOCATION_VIEW_ASSIGNED` and is filtered by the same
`scopeFor('LOCATION', ...)` as worker/collateral/finance data (see [RBAC.md](RBAC.md)) — a `MANAGER` gets only her own
workers' positions plus her own; nothing else. Each row also carries `phone` and live `online` presence now (M2 §14-16),
so a map marker's bottom sheet needs no second request.

### Freshness tiers (M2 §17) — never present an old point as if it were current

Thresholds live in ONE place, `packages/shared/src/basics.ts` (`LOCATION_LIVE_SECONDS = 120`, `LOCATION_RECENT_SECONDS = 600`,
`locationFreshness(ageSeconds)`), so the API, Flutter and the web panel can never disagree:

| `ageSeconds` | `freshness` | Example wording |
|---|---|---|
| < 120 | `LIVE` | «Сейчас» |
| 120–599 | `RECENT` | «Обновлено 6 мин назад» |
| ≥ 600 | `STALE` | «Последняя позиция 18 мин назад» |

The boolean `stale` field (D-030's original threshold, > 15 minutes → now 10, to match `RECENT`'s end) is kept for
backward compatibility: `stale === (freshness === 'STALE')`. `RECENT` is the new middle tier between "just now" and
"actually stale".

`apps/mobile/lib/features/team/locations_screen.dart` (plain list) and `apps/mobile/lib/features/map/map_screen.dart`
(the real Yandex map, M2) both use the same `freshness` field — see [YANDEX-MAPS.md](YANDEX-MAPS.md).

## Presence — separate from GPS (D-031)

Being "online" is not derived from GPS. `PresenceService` (`apps/api/src/presence/presence.service.ts`) tracks *live
Socket.IO connections* in memory: a user is online while at least one socket is open. `User.lastSeenAt` is written on
connect/disconnect and on the app's `presence:ping` heartbeat, so it survives an API restart. `GET /v1/presence` and
`user.presence_changed` are scoped the same way as everything else.

## Testing

`apps/api/test/location.spec.ts` (5 tests, real PostgreSQL): self-only reporting (a spoofed `userId`/`workerId` in the
body is ignored), coordinate validation, manager/`_ALL` scoping (a `WORKER` gets 403, not an empty list), staleness
flag, realtime routing to the right manager. `apps/mobile/test/location_gate_test.dart` (6 tests): every gap screen
(services off, foreground denied/denied-forever, background denied), the correct system action per screen, and that a
fully-granted state shows the real app with no gate.
