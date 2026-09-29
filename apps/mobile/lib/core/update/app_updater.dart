import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../config.dart';

/// What diamoraa.uz/download/version.json says is the newest build (written by infra/scripts/publish-apk.sh).
class AppRelease {
  const AppRelease({required this.version, required this.build, required this.path, required this.sha256});
  final String version;
  final int build;
  final String path;
  final String sha256;
}

/// The Android side (MainActivity "diamoraa/updater"). An interface so tests never touch a platform channel.
abstract class UpdaterPlatform {
  Future<({int versionCode, bool is64, String dir})> info();
  Future<String?> sha256(String path);
  Future<bool> canInstall();
  Future<void> openInstallSettings();
  Future<void> install(String path);
  /// Quiet update (Android 12+ when allowed). false = not possible here, the strip stays.
  Future<bool> installSilent(String path);
}

class ChannelUpdaterPlatform implements UpdaterPlatform {
  const ChannelUpdaterPlatform();
  static const _ch = MethodChannel('diamoraa/updater');
  @override
  Future<({int versionCode, bool is64, String dir})> info() async {
    final m = (await _ch.invokeMapMethod<String, dynamic>('info'))!;
    return (versionCode: (m['versionCode'] as num).toInt(), is64: m['is64'] as bool, dir: m['dir'] as String);
  }
  @override
  Future<String?> sha256(String path) => _ch.invokeMethod<String>('sha256', {'path': path});
  @override
  Future<bool> canInstall() async => await _ch.invokeMethod<bool>('canInstall') ?? false;
  @override
  Future<void> openInstallSettings() => _ch.invokeMethod('openInstallSettings');
  @override
  Future<void> install(String path) => _ch.invokeMethod('install', {'path': path});
  @override
  Future<bool> installSilent(String path) async => await _ch.invokeMethod<bool>('installSilent', {'path': path}) ?? false;
}

enum UpdateStage { idle, downloading, ready, needsPermission }

class UpdateState {
  const UpdateState({this.stage = UpdateStage.idle, this.progress = 0, this.release, this.file});
  final UpdateStage stage;
  final double progress;
  final AppRelease? release;
  final String? file;
  UpdateState copyWith({UpdateStage? stage, double? progress, AppRelease? release, String? file}) =>
      UpdateState(stage: stage ?? this.stage, progress: progress ?? this.progress, release: release ?? this.release, file: file ?? this.file);
}

final updaterPlatformProvider = Provider<UpdaterPlatform>((_) => const ChannelUpdaterPlatform());

/// Downloads the manifest / APK. Separate from the API client: no auth, plain HTTPS to diamoraa.uz.
final updateHttpProvider = Provider<Dio>((_) => Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(minutes: 10))));

/// Self-update without the Play Store: check -> download in the background -> verify SHA-256 -> «Установить».
/// The build number is versionCode % 1000 (Flutter's split-per-abi adds 1000 × ABI).
class UpdateController extends Notifier<UpdateState> {
  DateTime? _lastCheck;
  var _busy = false;

  @override
  UpdateState build() => const UpdateState();

  static bool get supported => !kIsWeb && Platform.isAndroid && AppConfig.apiUrl.startsWith('https://');

  /// Cheap and safe to call often (app start, every return to the app): at most once per 20 min.
  Future<void> check({bool force = false}) async {
    if (_busy || state.stage == UpdateStage.ready) return;
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 20)) return;
    _lastCheck = DateTime.now();
    _busy = true;
    try {
      final platform = ref.read(updaterPlatformProvider);
      final dio = ref.read(updateHttpProvider);
      final me = await platform.info();
      final res = await dio.get<Map<String, dynamic>>('${AppConfig.root}/download/version.json', queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
      final j = res.data ?? const {};
      final build = (j['build'] as num?)?.toInt();
      final files = (j['files'] as Map?)?.cast<String, dynamic>();
      if (build == null || files == null || build <= me.versionCode % 1000) return; // up to date (or an old-format manifest)
      final f = (files[me.is64 ? 'arm64' : 'armv7'] as Map?)?.cast<String, dynamic>();
      if (f == null) return;
      final release = AppRelease(version: j['version'] as String, build: build, path: f['path'] as String, sha256: f['sha256'] as String);
      final target = '${me.dir}/diamoraa-${release.build}.apk';
      if (await platform.sha256(target) == release.sha256) {
        state = UpdateState(stage: UpdateStage.ready, progress: 1, release: release, file: target);
        return;
      }
      state = UpdateState(stage: UpdateStage.downloading, release: release);
      final part = '$target.part';
      // ?b=<build>: a fresh cache key at Cloudflare, so a just-published build is never served from the old copy
      await dio.download('${AppConfig.root}${release.path}', part, queryParameters: {'b': release.build},
          onReceiveProgress: (got, total) { if (total > 0) state = state.copyWith(progress: got / total); });
      await File(part).rename(target);
      if (await platform.sha256(target) != release.sha256) {
        await File(target).delete().catchError((_) => File(target));
        state = const UpdateState(); // broken download: try again on the next check
        return;
      }
      state = UpdateState(stage: UpdateStage.ready, progress: 1, release: release, file: target);
    } catch (_) {
      if (state.stage == UpdateStage.downloading) state = const UpdateState(); // offline etc.: silently retry later
    } finally {
      _busy = false;
    }
  }

  /// The person left the app (another app or the home screen) with an update downloaded: install it quietly now, so the
  /// next time Diamoraa opens it is already the new version. Never while she is using it.
  Future<void> installInBackground() async {
    final file = state.file;
    if (file == null || state.stage != UpdateStage.ready) return;
    try {
      await ref.read(updaterPlatformProvider).installSilent(file);
    } catch (_) {/* the strip stays: one tap next time */}
  }

  /// One tap: the system «Установить?» dialog. First time only, Android asks to allow installs from Diamoraa.
  Future<void> install() async {
    final file = state.file;
    if (file == null) return;
    final platform = ref.read(updaterPlatformProvider);
    if (!await platform.canInstall()) {
      state = state.copyWith(stage: UpdateStage.needsPermission);
      await platform.openInstallSettings();
      return;
    }
    state = state.copyWith(stage: UpdateStage.ready);
    await platform.install(file);
  }
}

final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// A thin strip at the top of every screen: silent while nothing is ready, «Обновление готово — Установить» when it is.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  AppLifecycleListener? _life;

  @override
  void initState() {
    super.initState();
    if (!UpdateController.supported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(updateControllerProvider.notifier).check());
    _life = AppLifecycleListener(
      onResume: () => ref.read(updateControllerProvider.notifier).check(),
      onHide: () => ref.read(updateControllerProvider.notifier).installInBackground(),
    );
  }

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(updateControllerProvider);
    final show = s.stage == UpdateStage.ready || s.stage == UpdateStage.needsPermission;
    return Column(children: [
      if (show) UpdateStrip(state: s, onInstall: () => ref.read(updateControllerProvider.notifier).install()),
      // the strip already took the status-bar inset: the screens below must not add it a second time
      Expanded(child: show ? MediaQuery.removePadding(context: context, removeTop: true, child: widget.child) : widget.child),
    ]);
  }
}

class UpdateStrip extends StatelessWidget {
  const UpdateStrip({super.key, required this.state, required this.onInstall});
  final UpdateState state;
  final VoidCallback onInstall;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(children: [
            Icon(Icons.system_update_rounded, color: scheme.onPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.stage == UpdateStage.needsPermission ? l.updateAllowInstall : l.updateReady(state.release?.version ?? ''),
                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton(
              // the app theme makes buttons full-width; inside this row that squeezed the text to one letter per line
              style: FilledButton.styleFrom(backgroundColor: scheme.onPrimary, foregroundColor: scheme.primary, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: onInstall,
              child: Text(l.updateInstall),
            ),
          ]),
        ),
      ),
    );
  }
}
