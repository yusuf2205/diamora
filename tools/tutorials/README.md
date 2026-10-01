# Обучающие видео / Training videos

## RU

Короткие ролики для каждой роли: мастерица, менеджер, админ, главный админ, покупатель. Каждый ролик есть
на узбекском и на русском языке. Ролики показываются:

- в приложении: «Профиль → O'qitish / Обучение» и «Ещё → Обучение»;
- в панели: «Обучение»;
- в магазине shop.diamoraa.uz: «Видео: как заказать»;
- в боте покупателей: «🛍 Каталог» → «🎬 Video».

Каждый видит только свои ролики, главный админ видит все.

Ролики снимаются автоматически на **демо-копии системы**: отдельная пустая база с выдуманными мастерицами и
заказами. Настоящие данные не используются. Если интерфейс изменился, ролики можно переснять (см. EN).

## EN — how to re-record

Everything runs locally on Windows. Production is never touched. Needs Node 24, the built API
(`pnpm --filter @diamoraa/api build`), the built web (`apps/web: npx next build`), the Android SDK with the
`diamoraa-demo` AVD (Pixel 6, `system-images;android-34;google_apis;x86_64`). Run `npm install` here once.

1. **Web videos** (`customer`, `admin`, `superadmin`) — Playwright, CDP screencast at 2× for sharp text:
   ```sh
   node demo.mjs                       # fresh demo DB + API on :3000 (made-up data, apps/api/src/cli/demo-server.ts)
   (cd ../../apps/web && npx next start -p 3001)
   node record.mjs customer admin superadmin
   ```
2. **App videos** (`worker`, `manager`) — the emulator, driven through adb + uiautomator, recorded by the emulator itself:
   ```sh
   DEMO_PUBLIC_URL=http://10.0.2.2:3000 node demo.mjs      # files reachable from the emulator
   emulator -avd diamoraa-demo -no-window -no-audio -gpu swiftshader_indirect -memory 2048 -no-snapshot
   # once per wiped emulator: open Chrome and finish its first-run screens
   (cd ../../apps/mobile && flutter build apk --profile --target-platform android-x64 \
     --dart-define=API_URL=http://10.0.2.2:3000 --dart-define=YANDEX_MAPKIT_KEY=...) && adb install -r <apk>
   node record-app.mjs worker manager
   ```
   Close the web server and anything heavy first: with less than ~1.5 GB free RAM the emulator's system UI stops
   responding. Host-GPU mode records black frames when headless, so use `swiftshader_indirect`.
3. **Publish**: `node manifest.mjs && sh publish.sh Joseph@100.126.164.29`. This uploads to
   `${DATA_ROOT}/downloads/tutorials/` (each file is checked by sha256, and the manifest goes last).

Scenes live in `videos/<name>.mjs`: `h.say({ uz, ru })` sets a caption, and the helpers click, type and select.
One recording gives both languages. The captions are burnt into a band under the picture (`lib.mjs`, ffmpeg + libass).
