import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../config.dart';
import '../providers.dart' show realtimeEventsProvider;

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

  /// Cheap and safe to call often (app start, every return to the app, every 10 min while open, and at once when the server announces a new build): at most once a minute.
  Future<void> check({bool force = false}) async {
    if (_busy || (state.stage == UpdateStage.ready && !force)) return; // forced: an even newer build may have been announced
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 1)) return;
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
      if (state.stage == UpdateStage.ready && (state.release?.build ?? 0) >= build) return; // already downloaded
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
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (!UpdateController.supported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(updateControllerProvider.notifier).check());
    // a phone that stays open all day still hears about a new version
    _tick = Timer.periodic(const Duration(minutes: 10), (_) { if (mounted) ref.read(updateControllerProvider.notifier).check(); });
    _life = AppLifecycleListener(
      onResume: () => ref.read(updateControllerProvider.notifier).check(),
      onHide: () => ref.read(updateControllerProvider.notifier).installInBackground(),
    );
  }

  @override
  void dispose() {
    _life?.dispose();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // the server announces a freshly published build (a realtime hint; a push reaches closed apps): check right now
    if (UpdateController.supported) {
      ref.listen(realtimeEventsProvider, (_, next) {
        if (next.value?.type == 'app.release') ref.read(updateControllerProvider.notifier).check(force: true);
      });
    }
    final s = ref.watch(updateControllerProvider);
    final show = s.stage == UpdateStage.ready || s.stage == UpdateStage.needsPermission;
    final downloading = s.stage == UpdateStage.downloading && s.release != null;
    return Column(children: [
      // the new version is on its way: a quiet line with the percent (the app keeps working)
      if (downloading) UpdateProgress(state: s),
      if (show) UpdateStrip(state: s, onInstall: () => ref.read(updateControllerProvider.notifier).install()),
      // the strip already took the status-bar inset: the screens below must not add it a second time
      Expanded(child: show || downloading ? MediaQuery.removePadding(context: context, removeTop: true, child: widget.child) : widget.child),
    ]);
  }
}

class UpdateProgress extends StatelessWidget {
  const UpdateProgress({super.key, required this.state});
  final UpdateState state;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pct = (state.progress * 100).clamp(0, 100).round();
    return Material(
      key: const Key('updateProgress'),
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(children: [
              Icon(Icons.downloading_rounded, size: 20, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(child: Text(l.updateDownloading(state.release?.version ?? '', pct), style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          LinearProgressIndicator(value: state.progress > 0 ? state.progress : null, minHeight: 2),
        ]),
      ),
    );
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


/// Profile: «Версия приложения 1.0.0-rc.40» + «Проверить обновление» - a way to update right now, without waiting.
class UpdateTile extends ConsumerStatefulWidget {
  const UpdateTile({super.key});
  @override
  ConsumerState<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<UpdateTile> {
  bool _checking = false;

  Future<void> _check() async {
    final l = AppLocalizations.of(context);
    setState(() => _checking = true);
    final c = ref.read(updateControllerProvider.notifier);
    await c.check(force: true);
    if (!mounted) return;
    setState(() => _checking = false);
    final s = ref.read(updateControllerProvider);
    if (s.stage == UpdateStage.idle) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.updateLatest)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(updateControllerProvider);
    final supported = UpdateController.supported;
    final Widget? trailing = !supported
        ? null
        : switch (s.stage) {
            UpdateStage.downloading => Text('${(s.progress * 100).round()}%', style: Theme.of(context).textTheme.titleMedium),
            UpdateStage.ready || UpdateStage.needsPermission => FilledButton(
                key: const Key('updateInstallNow'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => ref.read(updateControllerProvider.notifier).install(),
                child: Text(l.updateInstall),
              ),
            _ => _checking
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : OutlinedButton(key: const Key('updateCheck'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _check, child: Text(l.updateCheck)),
          };
    return Card(
      child: ListTile(
        key: const Key('updateTile'),
        leading: const Icon(Icons.system_update_rounded),
        title: Text(l.updateAppVersion),
        subtitle: Text(switch (s.stage) {
          UpdateStage.downloading => l.updateDownloading(s.release?.version ?? '', (s.progress * 100).round()),
          UpdateStage.ready => l.updateReady(s.release?.version ?? ''),
          _ => AppConfig.appVersion,
        }),
        trailing: trailing,
      ),
    );
  }
}
