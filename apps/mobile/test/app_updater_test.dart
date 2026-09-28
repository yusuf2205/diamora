import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diamoraa_mobile/core/update/app_updater.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

/// Serves version.json and the APK bytes like diamoraa.uz does.
class _Server implements HttpClientAdapter {
  _Server(this.manifest, this.apk);
  Map<String, dynamic> manifest;
  List<int> apk;
  final hits = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    hits.add(o.uri.path);
    if (o.uri.path.endsWith('version.json')) {
      return ResponseBody.fromString(jsonEncode(manifest), 200, headers: {'content-type': ['application/json']});
    }
    return ResponseBody.fromBytes(apk, 200, headers: {'content-length': ['${apk.length}']});
  }
  @override
  void close({bool force = false}) {}
}

class _Platform implements UpdaterPlatform {
  _Platform(this.dir, {this.versionCode = 2016, this.allowed = true});
  final String dir;
  final int versionCode;
  bool allowed;
  String? installed;
  var openedSettings = false;
  @override
  Future<({int versionCode, bool is64, String dir})> info() async => (versionCode: versionCode, is64: true, dir: dir);
  @override
  Future<String?> sha256(String path) async {
    final f = File(path);
    return f.existsSync() ? 'sha-of-${f.readAsStringSync()}' : null; // stand-in digest: content-derived, enough for the logic
  }
  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openInstallSettings() async => openedSettings = true;
  @override
  Future<void> install(String path) async => installed = path;
}

Map<String, dynamic> manifest({int build = 17, String sha = 'sha-of-NEW'}) => {
      'version': '1.0.0-rc.$build', 'build': build, 'publishedAt': '2026-09-28T15:00:00Z',
      'files': {'arm64': {'path': '/download/diamoraa.apk', 'sha256': sha}, 'armv7': {'path': '/download/diamoraa-armv7.apk', 'sha256': 'x'}},
    };

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('upd'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container(_Server server, _Platform platform) {
    final dio = Dio()..httpClientAdapter = server;
    final c = ProviderContainer(overrides: [updaterPlatformProvider.overrideWithValue(platform), updateHttpProvider.overrideWithValue(dio)]);
    addTearDown(c.dispose);
    return c;
  }

  test('up to date: nothing is downloaded', () async {
    final server = _Server(manifest(build: 16), utf8.encode('NEW'));
    final c = container(server, _Platform(dir.path));
    await c.read(updateControllerProvider.notifier).check(force: true);
    expect(c.read(updateControllerProvider).stage, UpdateStage.idle);
    expect(server.hits.where((h) => h.endsWith('.apk')), isEmpty);
  });

  test('newer build: downloaded in the background, verified, ready to install with one tap', () async {
    final server = _Server(manifest(), utf8.encode('NEW'));
    final platform = _Platform(dir.path);
    final c = container(server, platform);
    await c.read(updateControllerProvider.notifier).check(force: true);
    final s = c.read(updateControllerProvider);
    expect(s.stage, UpdateStage.ready);
    expect(s.release!.version, '1.0.0-rc.17');
    expect(File('${dir.path}/diamoraa-17.apk').existsSync(), isTrue);
    await c.read(updateControllerProvider.notifier).install();
    expect(platform.installed, '${dir.path}/diamoraa-17.apk');

    // a later check does not download it again
    server.hits.clear();
    await c.read(updateControllerProvider.notifier).check(force: true);
    expect(server.hits, isEmpty);
  });

  test('a corrupted download is thrown away and never offered for install', () async {
    final server = _Server(manifest(sha: 'sha-of-SOMETHING-ELSE'), utf8.encode('NEW'));
    final c = container(server, _Platform(dir.path));
    await c.read(updateControllerProvider.notifier).check(force: true);
    expect(c.read(updateControllerProvider).stage, UpdateStage.idle);
    expect(File('${dir.path}/diamoraa-17.apk').existsSync(), isFalse);
  });

  test('first install ever: Android must allow Diamoraa to install -> settings open, the strip says what to do', () async {
    final server = _Server(manifest(), utf8.encode('NEW'));
    final platform = _Platform(dir.path, allowed: false);
    final c = container(server, platform);
    await c.read(updateControllerProvider.notifier).check(force: true);
    await c.read(updateControllerProvider.notifier).install();
    expect(platform.openedSettings, isTrue);
    expect(platform.installed, isNull);
    expect(c.read(updateControllerProvider).stage, UpdateStage.needsPermission);
  });

  testWidgets('the strip: «Новая версия … готова» + «Установить»', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UpdateStrip(
        state: const UpdateState(stage: UpdateStage.ready, release: AppRelease(version: '1.0.0-rc.17', build: 17, path: '/x', sha256: 's')),
        onInstall: () => tapped = true,
      )),
    ));
    expect(find.text('Новая версия 1.0.0-rc.17 готова'), findsOneWidget);
    await tester.tap(find.text('Установить'));
    expect(tapped, isTrue);
  });
}
