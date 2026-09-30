import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import 'chat_audio.dart';
import 'chat_models.dart';
import 'chat_profile.dart' show Waveform, barsFor;

/// Files of messages are fetched once into the app's cache (signed links expire; the file is still there next time).
class ChatFiles {
  ChatFiles._();
  static final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(minutes: 5)));
  static final _inFlight = <String, Future<File>>{};

  static String _ext(ChatMessage m) {
    final n = m.file?.name ?? '';
    final dot = n.lastIndexOf('.');
    if (dot > 0 && n.length - dot <= 9) return n.substring(dot);
    return switch (m.file?.mimeType) {
      'audio/mp4' => '.m4a',
      'audio/mpeg' => '.mp3',
      'audio/ogg' => '.ogg',
      'video/quicktime' => '.mov',
      'video/webm' => '.webm',
      'video/mp4' => '.mp4',
      'image/jpeg' => '.jpg',
      _ => '',
    };
  }

  static Future<File> _target(ChatMessage m) async {
    final dir = Directory('${(await getApplicationCacheDirectory()).path}/chat');
    await dir.create(recursive: true);
    return File('${dir.path}/${m.id}${_ext(m)}');
  }

  /// The local copy, if it was already downloaded.
  static Future<File?> cached(ChatMessage m) async {
    final f = await _target(m);
    return await f.exists() ? f : null;
  }

  static Future<File> get(ChatMessage m, {void Function(double)? onProgress}) => _inFlight.putIfAbsent(m.id, () async {
        try {
          final f = await _target(m);
          if (await f.exists()) return f;
          final part = File('${f.path}.part');
          await _dio.download(m.file!.url, part.path, onReceiveProgress: (got, total) { if (total > 0) onProgress?.call(got / total); });
          return await part.rename(f.path);
        } finally {
          unawaited(Future<void>.delayed(Duration.zero, () => _inFlight.remove(m.id)));
        }
      });

  /// Opens a document with whatever app the phone has for it (PDF viewer, Excel, …).
  static Future<void> open(BuildContext context, ChatMessage m) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l.chatDownloading), duration: const Duration(seconds: 1)));
    try {
      final f = await get(m);
      final r = await OpenFilex.open(f.path);
      if (r.type != ResultType.done) messenger.showSnackBar(SnackBar(content: Text(r.message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatFileFailed)));
    }
  }
}

String formatBytes(int? b) {
  if (b == null) return '';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

String formatDuration(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// A photo full screen: pinch to zoom.
class ChatImageScreen extends StatelessWidget {
  const ChatImageScreen({super.key, required this.url, this.caption});
  final String url;
  final String? caption;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Column(children: [
          Expanded(child: InteractiveViewer(maxScale: 5, child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)))),
          if (caption != null && caption!.isNotEmpty) SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: Text(caption!, style: const TextStyle(color: Colors.white)))),
        ]),
      );
}

/// A video full screen: downloaded first (the whole file, so seeking works everywhere), then played.
class ChatVideoScreen extends StatefulWidget {
  const ChatVideoScreen({super.key, required this.message});
  final ChatMessage message;
  @override
  State<ChatVideoScreen> createState() => _ChatVideoScreenState();
}

class _ChatVideoScreenState extends State<ChatVideoScreen> {
  VideoPlayerController? _c;
  final double _progress = 0; // streams now: no whole-file download to wait for
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // plays while downloading (the server answers byte ranges); a copy already on the phone plays from there
      final local = await ChatFiles.cached(widget.message);
      final c = local != null ? VideoPlayerController.file(local) : VideoPlayerController.networkUrl(Uri.parse(widget.message.file!.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(() { if (mounted) setState(() {}); });
      setState(() => _c = c);
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _failed
            ? Text(l.chatFileFailed, style: const TextStyle(color: Colors.white))
            : c == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(value: _progress > 0 ? _progress : null),
                    const SizedBox(height: 12),
                    Text(l.chatDownloading, style: const TextStyle(color: Colors.white70)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: GestureDetector(onTap: () => c.value.isPlaying ? c.pause() : c.play(), child: VideoPlayer(c)))),
                    VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.all(12)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                        iconSize: 40,
                        color: Colors.white,
                        icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                        onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
                      ),
                      Text('${formatDuration(c.value.position)} / ${formatDuration(c.value.duration)}', style: const TextStyle(color: Colors.white)),
                    ]),
                  ]),
      ),
    );
  }
}

/// Voice notes and audio files: play / pause, position, length.
class ChatAudioBubble extends StatefulWidget {
  const ChatAudioBubble({super.key, required this.message, required this.color});
  final ChatMessage message;
  final Color color;
  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble> {
  // the sound itself lives in the shared ChatAudio (one at a time, the next starts by itself, the strip on top controls it)
  final _audio = ChatAudio.instance;

  @override
  void initState() {
    super.initState();
    _audio.register(widget.message);
  }

  @override
  void didUpdateWidget(ChatAudioBubble old) {
    super.didUpdateWidget(old);
    if (old.message.id != widget.message.id) {
      _audio.unregister(old.message.id);
      _audio.register(widget.message);
    } else {
      _audio.refresh(widget.message);
    }
  }

  @override
  void dispose() {
    _audio.unregister(widget.message.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final size = widget.message.file?.size;
    return ListenableBuilder(
      listenable: _audio,
      builder: (context, _) {
        final current = _audio.isCurrent(widget.message.id);
        final playing = current && _audio.playing;
        final loading = current && _audio.loading;
        final pos = current ? _audio.pos : Duration.zero;
        final total = current ? _audio.total : Duration(milliseconds: widget.message.file?.durationMs ?? 0);
        final value = total.inMilliseconds > 0 ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0) : 0.0;
        final shown = playing || pos > Duration.zero ? pos : total;
        final rate = current && _audio.rate != 1 ? ' · ${_audio.rate}x' : '';
        // like Telegram: a round ▶, the waveform (played part filled; tap to seek), «00:02, 8.8 KB»
        return SizedBox(
          width: 250,
          child: Row(children: [
            GestureDetector(
              key: Key('play-${widget.message.id}'),
              onTap: loading ? null : () => _audio.toggle(widget.message),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: accent,
                child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Waveform(
                  bars: barsFor(widget.message.waveform, widget.message.id),
                  progress: current ? value : 0,
                  color: accent,
                  onSeek: (f) async {
                    if (!current) await _audio.play(widget.message);
                    await _audio.seekTo(f);
                  },
                ),
                const SizedBox(height: 2),
                Text('${chatAudioTime(shown)}${size != null ? ', ${formatBytes(size)}' : ''}$rate', style: TextStyle(fontSize: 12, color: widget.color.withValues(alpha: 0.75))),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
