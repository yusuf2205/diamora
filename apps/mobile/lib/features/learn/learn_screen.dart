import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/config.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../profile/locale_controller.dart';

/// One training video (download/tutorials/tutorials.json, written by tools/tutorials/publish.sh).
class Tutorial {
  const Tutorial({required this.id, required this.roles, required this.title, required this.files, this.poster, this.seconds});
  final String id;
  final List<String> roles;
  final Map<String, String> title; // uz, ru
  final Map<String, String> files; // uz, ru -> path under the site
  final String? poster;
  final int? seconds;

  factory Tutorial.fromJson(Map<String, dynamic> j) => Tutorial(
        id: j['id'] as String,
        roles: [for (final r in (j['roles'] as List? ?? const [])) r as String],
        title: {for (final e in ((j['title'] as Map?) ?? const {}).entries) e.key as String: e.value as String},
        files: {for (final e in ((j['files'] as Map?) ?? const {}).entries) e.key as String: e.value as String},
        poster: j['poster'] as String?,
        seconds: (j['seconds'] as num?)?.toInt(),
      );

  String titleFor(String lang) => title[lang] ?? title['ru'] ?? title.values.first;
  String fileFor(String lang) => files[lang] ?? files['ru'] ?? files.values.first;
}

String _url(String path) => path.startsWith('http') ? path : '${AppConfig.root}$path';

/// the manifest from the server (no account needed; the same file the panel and the shop read)
final tutorialsProvider = FutureProvider.autoDispose<List<Tutorial>>((ref) async {
  final res = await Dio().get<Map<String, dynamic>>(_url('/download/tutorials/tutorials.json'));
  return [for (final t in (res.data?['items'] as List? ?? const [])) Tutorial.fromJson(t as Map<String, dynamic>)];
});

/// «Обучение»: the short videos for this person's role (SUPER_ADMIN sees them all), in Uzbek or Russian.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});
  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  String? _lang;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final role = ref.watch(authControllerProvider).value?.role ?? 'WORKER';
    final lang = _lang ?? (ref.watch(localeControllerProvider).languageCode == 'ru' ? 'ru' : 'uz');
    final async = ref.watch(tutorialsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.learnTitle)),
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => EmptyState(icon: Icons.ondemand_video_rounded, title: l.learnNone),
        data: (all) {
          final mine = role == 'SUPER_ADMIN' ? all.where((t) => !t.roles.contains('CUSTOMER')).toList() : all.where((t) => t.roles.contains(role)).toList();
          if (mine.isEmpty) return EmptyState(icon: Icons.ondemand_video_rounded, title: l.learnNone);
          return ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'uz', label: Text("O'zbekcha")), ButtonSegment(value: 'ru', label: Text('Русский'))],
              selected: {lang},
              onSelectionChanged: (s) => setState(() => _lang = s.first),
            ),
            const SizedBox(height: 12),
            for (final t in mine)
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TutorialPlayer(title: t.titleFor(lang), url: _url(t.fileFor(lang))))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (t.poster != null)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(fit: StackFit.expand, children: [
                          Image.network(_url(t.poster!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12)),
                          const Center(child: CircleAvatar(radius: 30, backgroundColor: Colors.black54, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40))),
                        ]),
                      ),
                    ListTile(
                      leading: t.poster == null ? const Icon(Icons.play_circle_fill_rounded, size: 40) : null,
                      title: Text(t.titleFor(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: t.seconds == null ? null : Text(l.learnMinutes((t.seconds! / 60).ceil())),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Full-screen player: tap to pause / play, a progress bar to jump.
class TutorialPlayer extends StatefulWidget {
  const TutorialPlayer({super.key, required this.title, required this.url});
  final String title;
  final String url;
  @override
  State<TutorialPlayer> createState() => _TutorialPlayerState();
}

class _TutorialPlayerState extends State<TutorialPlayer> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  Object? _error;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (mounted) setState(() {});
      _c.play();
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
    _c.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.title, maxLines: 2)),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.learnNone, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)))
          : !_c.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
                      child: Center(
                        child: Stack(alignment: Alignment.center, children: [
                          AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
                          if (!_c.value.isPlaying) const CircleAvatar(radius: 34, backgroundColor: Colors.black54, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 46)),
                        ]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: VideoProgressIndicator(_c, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 12), colors: const VideoProgressColors(playedColor: Color(0xFFA3324F))),
                  ),
                ]),
    );
  }
}
