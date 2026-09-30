import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'chat_media.dart' show ChatFiles;
import 'chat_models.dart';

/// What actually makes the sound (swapped for a fake in tests).
abstract class ChatAudioEngine {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<void> get complete;
  Future<void> open(ChatMessage m);
  Future<void> resume();
  Future<void> pause();
  Future<void> seek(Duration d);
  Future<void> setRate(double r);
  Future<void> setVolume(double v);
  Future<void> dispose();
}

class _Players implements ChatAudioEngine {
  final _p = AudioPlayer();
  @override
  Stream<Duration> get position => _p.onPositionChanged;
  @override
  Stream<Duration> get duration => _p.onDurationChanged;
  @override
  Stream<bool> get playing => _p.onPlayerStateChanged.map((s) => s == PlayerState.playing);
  @override
  Stream<void> get complete => _p.onPlayerComplete;
  @override
  Future<void> open(ChatMessage m) async {
    // streams right away; a copy already on the phone plays from there
    final local = await ChatFiles.cached(m);
    await _p.setSource(local != null ? DeviceFileSource(local.path) : UrlSource(m.file!.url));
  }
  @override
  Future<void> resume() => _p.resume();
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> seek(Duration d) => _p.seek(d);
  @override
  Future<void> setRate(double r) => _p.setPlaybackRate(r);
  @override
  Future<void> setVolume(double v) => _p.setVolume(v);
  @override
  Future<void> dispose() => _p.dispose();
}

/// One player for the whole chat, like Telegram: one voice plays at a time, the next one starts by itself,
/// and the strip at the top ([ChatAudioBar]) controls it.
class ChatAudio extends ChangeNotifier {
  ChatAudio._();
  static final instance = ChatAudio._();
  static ChatAudioEngine Function() engineFactory = _Players.new;

  final _known = <String, ChatMessage>{};
  ChatAudioEngine? _engine;
  final _subs = <StreamSubscription<Object?>>[];

  ChatMessage? track;
  bool playing = false;
  bool loading = false;
  Duration pos = Duration.zero;
  Duration? len;
  double rate = 1;
  bool muted = false;

  /// every voice / audio bubble on screen registers itself: that is the queue for ⏮ ⏭
  /// (the same voice can be on screen twice - in the chat and in «Голосовые» of the chat's info - so it is counted:
  /// closing one of them must not drop it from ⏮ ⏭)
  final _refs = <String, int>{};
  void register(ChatMessage m) {
    _refs[m.id] = (_refs[m.id] ?? 0) + 1;
    _known[m.id] = m;
  }

  /// the same bubble got a newer copy of its message (edited, a reaction)
  void refresh(ChatMessage m) {
    if (_known.containsKey(m.id)) _known[m.id] = m;
  }

  void unregister(String id) {
    final n = (_refs[id] ?? 1) - 1;
    if (n > 0) {
      _refs[id] = n;
    } else {
      _refs.remove(id);
      _known.remove(id);
    }
  }

  Duration get total => len ?? Duration(milliseconds: track?.file?.durationMs ?? 0);
  bool isCurrent(String id) => track?.id == id;

  ChatAudioEngine _ensure() {
    final existing = _engine;
    if (existing != null) return existing;
    final e = engineFactory();
    if (muted) e.setVolume(0); // «звук выкл.» stays off for the next voice too
    _subs
      ..add(e.position.listen((d) { pos = d; notifyListeners(); }))
      ..add(e.duration.listen((d) { len = d; notifyListeners(); }))
      ..add(e.playing.listen((p) { playing = p; notifyListeners(); }))
      ..add(e.complete.listen((_) {
        final n = neighbour(1);
        if (n != null) {
          play(n);
        } else {
          playing = false;
          pos = Duration.zero;
          notifyListeners();
        }
      }));
    return _engine = e;
  }

  List<ChatMessage> _queue(String roomId) => _known.values.where((m) => m.roomId == roomId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  ChatMessage? neighbour(int d) {
    final t = track;
    if (t == null) return null;
    final q = _queue(t.roomId);
    final i = q.indexWhere((m) => m.id == t.id);
    final j = i + d;
    return i < 0 || j < 0 || j >= q.length ? null : q[j];
  }

  Future<void> play(ChatMessage m) async {
    final e = _ensure();
    if (track?.id != m.id) {
      track = m;
      pos = Duration.zero;
      len = null;
      loading = true;
      notifyListeners();
      try {
        await e.open(m);
        await e.setRate(rate);
      } catch (_) {
        // could not load it: forget it, so the next tap tries again (instead of resuming the previous voice)
        if (track?.id == m.id) {
          track = null;
          loading = false;
          notifyListeners();
        }
        return;
      }
      // another voice was tapped while this one was loading: that one wins
      if (track?.id != m.id || !identical(_engine, e)) return;
      loading = false;
      notifyListeners();
    }
    if (track?.id == m.id && identical(_engine, e)) await e.resume();
  }

  Future<void> toggle(ChatMessage m) async {
    if (isCurrent(m.id) && playing) return _engine?.pause();
    return play(m);
  }

  Future<void> seekTo(double fraction) async {
    final t = total;
    if (t.inMilliseconds <= 0) return;
    final d = Duration(milliseconds: (t.inMilliseconds * fraction.clamp(0.0, 1.0)).round());
    pos = d;
    notifyListeners();
    await _engine?.seek(d);
  }

  Future<void> step(int d) async {
    final n = neighbour(d);
    if (n != null) return play(n);
    if (d < 0) return seekTo(0);
  }

  Future<void> cycleRate() async {
    rate = rate == 1 ? 1.5 : rate == 1.5 ? 2 : 1;
    notifyListeners();
    await _engine?.setRate(rate);
  }

  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
    await _engine?.setVolume(muted ? 0 : 1);
  }

  Future<void> close() async {
    final e = _engine;
    final subs = [..._subs];
    _engine = null;
    _subs.clear();
    track = null;
    playing = false;
    loading = false;
    pos = Duration.zero;
    len = null;
    notifyListeners();
    for (final s in subs) {
      await s.cancel();
    }
    await e?.pause().catchError((_) {});
    await e?.dispose().catchError((_) {});
  }
}

String chatAudioTime(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

/// «сегодня в 10:01» / «вчера в 10:01» / «29.09 в 10:01»
String chatAudioWhen(AppLocalizations l, DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(t.hour)}:${two(t.minute)}';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return l.chatTodayAt(time);
  if (day == today.subtract(const Duration(days: 1))) return l.chatYesterdayAt(time);
  return l.chatDateAt('${two(t.day)}.${two(t.month)}', time);
}

/// The strip under the chat's top bar while a voice / audio plays (Telegram-like):
/// ⏮ ▶ ⏭, who and when, time, speed 1X / 1.5X / 2X, sound on / off, ✕, and a thin progress line (tap / drag to seek).
class ChatAudioBar extends StatelessWidget {
  const ChatAudioBar({super.key});

  @override
  Widget build(BuildContext context) {
    final a = ChatAudio.instance;
    return ListenableBuilder(
      listenable: a,
      builder: (context, _) {
        final t = a.track;
        if (t == null) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final wide = MediaQuery.sizeOf(context).width >= 600; // tablets: a roomier strip, the date on the same line
        final title = t.kind == 'AUDIO' && t.file?.name != null ? t.file!.name! : (t.sender?.fullName ?? l.chatVoice);
        final total = a.total;
        final progress = total.inMilliseconds > 0 ? (a.pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0) : 0.0;
        final when = chatAudioWhen(l, t.createdAt);
        final ctrl = IconButton.styleFrom(foregroundColor: scheme.primary, disabledForegroundColor: scheme.primary.withValues(alpha: 0.35));
        final dense = wide ? VisualDensity.standard : VisualDensity.compact;
        return Material(
          key: const Key('audioBar'),
          color: scheme.surfaceContainerLow,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 4, vertical: wide ? 4 : 0),
              child: Row(children: [
                IconButton(key: const Key('audioPrev'), tooltip: l.chatAudioPrev, visualDensity: dense, style: ctrl, icon: const Icon(Icons.skip_previous_rounded), onPressed: () => a.step(-1)),
                IconButton(
                  key: const Key('audioPlay'),
                  tooltip: a.playing ? l.chatAudioPause : l.chatAudioPlay,
                  visualDensity: dense,
                  style: ctrl,
                  icon: a.loading
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                      : Icon(a.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                  onPressed: a.loading ? null : () => a.toggle(t),
                ),
                IconButton(key: const Key('audioNext'), tooltip: l.chatAudioNext, visualDensity: dense, style: ctrl, icon: const Icon(Icons.skip_next_rounded), onPressed: a.neighbour(1) == null ? null : () => a.step(1)),
                const SizedBox(width: 4),
                Expanded(
                  child: wide
                      ? Text.rich(
                          TextSpan(children: [
                            TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: '  $when', style: TextStyle(color: scheme.outline)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('$when · ${chatAudioTime(a.pos)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.outline)),
                        ]),
                ),
                if (wide) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(chatAudioTime(a.pos), style: TextStyle(color: scheme.outline, fontFeatures: const [FontFeature.tabularFigures()]))),
                if (wide) IconButton(key: const Key('audioMute'), tooltip: l.chatAudioMute, style: ctrl, icon: Icon(a.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded), onPressed: a.toggleMute),
                InkWell(
                  key: const Key('audioSpeed'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: a.cycleRate,
                  child: Tooltip(
                    message: l.chatAudioSpeed,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(border: Border.all(color: a.rate == 1 ? scheme.outline : scheme.primary, width: 1.6), borderRadius: BorderRadius.circular(5)),
                      child: Text('${a.rate == a.rate.roundToDouble() ? a.rate.toInt() : a.rate}X', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: a.rate == 1 ? scheme.outline : scheme.primary)),
                    ),
                  ),
                ),
                IconButton(key: const Key('audioClose'), tooltip: l.chatAudioClose, visualDensity: dense, icon: Icon(Icons.close_rounded, color: scheme.outline), onPressed: a.close),
              ]),
            ),
            // the thin progress line; tap or drag it to seek
            LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => a.seekTo(d.localPosition.dx / box.maxWidth),
                onHorizontalDragUpdate: (d) => a.seekTo(d.localPosition.dx / box.maxWidth),
                child: SizedBox(
                  height: 8,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: LinearProgressIndicator(value: progress, minHeight: 2, color: scheme.primary, backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
