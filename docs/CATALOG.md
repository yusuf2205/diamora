# Catalog — "Наши работы" (D-029)

The WORKER app's **default screen** (§10, §18). A beautiful, informational catalog of finished work. It is **never** a shop:
no price anywhere in the data model, no cart, no checkout, no payment.

## Data model

- `ProductModel` gained `status` (`DRAFT` → `PUBLISHED` ⇄ `HIDDEN`), `availability` (`AVAILABLE` / `ON_REQUEST` / `UNAVAILABLE`), `isNew`, `sortOrder`, `publishedAt`.
- `ProductVariant` gained `label` (e.g. "long") and `sortOrder`; colour comes from the existing `Color` model.
- `ProductMedia`: ordered photos and videos, one photo flagged `isMain` (the cover). Stored in MinIO on the NAS (bucket `products`); photos go through the same real-image validation as collateral photos, videos are sniffed by magic bytes (no client-declared MIME trusted) and stored as-is (no thumbnail/transcode).
- `CompanyContactSettings`: **one row** — phone + Telegram username. Never hard-coded in Flutter or the web panel; both read it live and refresh on `company_contact.changed`.

## API

| Route | Who | What |
|---|---|---|
| `GET /v1/catalog` | `WORKER` | Published items only: id, name, cover photo, colours, `isNew`, availability. No status, no code, no price. |
| `GET /v1/catalog/:id` | `WORKER` | Published item detail: description, full media gallery, variants. 404 if not published (a draft does not leak by id). |
| `GET /v1/admin/catalog` | `CATALOG_VIEW` or `CATALOG_MANAGE` | Every status, for staff. |
| `GET /v1/admin/catalog/:id` | same | Full detail. |
| `POST /v1/admin/catalog` | `CATALOG_MANAGE` | Create (`DRAFT`); a `PRD-####` code is generated. |
| `PATCH /v1/admin/catalog/:id` | `CATALOG_MANAGE` | name / description / availability / `isNew`. |
| `POST /v1/admin/catalog/:id/publish` \| `/hide` | `CATALOG_MANAGE` | Publishing without at least one photo is rejected (409). |
| `DELETE /v1/admin/catalog/:id` | `CATALOG_MANAGE` | Refused (409) if a real assignment or sale already references it — hide it instead. |
| `POST /v1/admin/catalog/:id/variants` \| `PATCH .../variants/:id` | `CATALOG_MANAGE` | Colour + label. |
| `POST /v1/admin/catalog/:id/media` (multipart) | `CATALOG_MANAGE` | `kind=PHOTO\|VIDEO`, optional `caption`/`variantId`. The first photo becomes `isMain` automatically. |
| `POST /v1/admin/catalog/media/:id/main` \| `DELETE .../media/:id` | `CATALOG_MANAGE` | Change the cover photo / remove a photo or video. |
| `PUT /v1/admin/catalog/order` \| `.../:id/media/order` | `CATALOG_MANAGE` | Reorder cards / a gallery (`{ ids: [...] }`, plain `sortOrder`, independent of which photo is main). |
| `GET /v1/settings/company-contact` | any signed-in role | phone / Telegram for the "Позвонить"/"Написать в Telegram" buttons. |
| `PUT /v1/settings/company-contact` | `SETTINGS_MANAGE` | Update it. |

## Realtime

`catalog.item.created/updated/published/hidden/deleted` and `catalog.order.changed` — staff with `CATALOG_VIEW` get all of them; **every connected WORKER** additionally gets `published`/`hidden`/`deleted`/`order.changed` (so her catalog updates live, no pull-to-refresh needed). `company_contact.changed` reaches staff and every worker the same way.

## Flutter

- `apps/mobile/lib/features/catalog/worker_catalog_screen.dart` — grid of cards (cover photo, name, colours, "Новинка" badge), detail screen (gallery, description, availability, colour chips, Call/Telegram buttons that only render when the company has configured that channel).
- `apps/mobile/lib/features/catalog/admin_catalog_screen.dart` — staff list + create dialog + detail screen (photo upload via `image_picker`, publish/hide, mark "Новинка").
- WORKER's bottom navigation: **Каталог** is the first tab (§18); "Моя работа"/"Заработок" tabs are not added yet — they need assignments (M3) and the ledger screen (M5), which do not exist. Adding a fabricated tab for unbuilt data was rejected (brief §63: no mocks).

## Testing

`apps/api/test/catalog.spec.ts` (8 tests, real PostgreSQL + MinIO-compatible memory storage in tests): empty-until-published, publish requires a photo, no price field anywhere in either payload, variants/video upload/main-photo/reorder/dedupe, delete-blocked-when-used, permission boundaries (`CATALOG_VIEW` read-only vs `CATALOG_MANAGE`, WORKER excluded from `/admin/catalog`), realtime to both a worker and staff. `apps/mobile/test/catalog_test.dart` (5 tests): default screen, empty state, detail with/without configured contact, admin create flow.
