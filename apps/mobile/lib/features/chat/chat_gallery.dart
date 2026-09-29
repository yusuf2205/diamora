import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import 'chat_media.dart';
import 'chat_models.dart';

/// Photos and videos of a chat, full screen, like in Telegram: opens at once (the small preview first, the full photo
/// fades in over it), pinch to zoom, swipe left / right to the neighbours, swipe down to close. A video starts playing
/// while it is still downloading (the server answers byte ranges), and seeking fetches only that part.
class ChatGalleryScreen extends StatefulWidget {
  const ChatGalleryScreen({super.key, required this.items, required this.initial});
  /// oldest -> newest
  final List<ChatMessage> items;
  final int initial;

  static Future<void> open(BuildContext context, List<ChatMessage> items, ChatMessage tapped) {
    final media = items.where((m) => !m.deleted && m.file != null && (m.kind == 'IMAGE' || m.kind == 'VIDEO')).toList();
    final i = media.indexWhere((m) => m.id == tapped.id);
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => ChatGalleryScreen(items: media.isEmpty ? [tapped] : media, initial: i < 0 ? 0 : i),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  State<ChatGalleryScreen> createState() => _ChatGalleryScreenState();
}

class _ChatGalleryScreenState extends State<ChatGalleryScreen> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  double _drag = 0;
  bool _chrome = true;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.items[_index];
    final fade = (1 - (_drag.abs() / 400)).clamp(0.2, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: GestureDetector(
        onTap: () => setState(() => _chrome = !_chrome),
        // swipe down (or up) to close, like Telegram
        onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
        onVerticalDragEnd: (d) {
          if (_drag.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
            Navigator.of(context).pop();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Stack(children: [
          Transform.translate(
            offset: Offset(0, _drag),
            child: PageView.builder(
              key: const Key('galleryPages'),
              controller: _pages,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                return item.kind == 'VIDEO' ? _VideoPage(message: item, active: i == _index) : _PhotoPage(message: item);
              },
            ),
          ),
          if (_chrome)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Row(children: [
                  IconButton(key: const Key('galleryClose'), color: Colors.white, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.sender?.fullName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      if (widget.items.length > 1) Text('${_index + 1} / ${widget.items.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ),
          if (_chrome && (m.text ?? '').isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(14),
                  child: Text(m.text!, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A photo: the preview (already on the phone from the chat list) at once, the full photo over it when it arrives.
class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final f = message.file!;
    final thumb = f.thumbUrl;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: Center(
        child: Hero(
          tag: 'chat-media-${message.id}',
          child: CachedNetworkImage(
            imageUrl: f.url,
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (_, _) => thumb == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Stack(alignment: Alignment.center, children: [
                    CachedNetworkImage(imageUrl: thumb, fit: BoxFit.contain),
                    const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5)),
                  ]),
            errorWidget: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}

/// A video: plays while it downloads; the preview picture shows until the first frame.
class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.message, required this.active});
  final ChatMessage message;
  final bool active;
  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (widget.active && _c == null) _start();
    if (!widget.active) _c?.pause();
  }

  Future<void> _start() async {
    // an already-downloaded copy plays from the phone; otherwise straight from the server, while downloading
    final local = await ChatFiles.cached(widget.message);
    final c = local != null ? VideoPlayerController.file(local) : VideoPlayerController.networkUrl(Uri.parse(widget.message.file!.url));
    _c = c;
    c.addListener(() { if (mounted) setState(() {}); });
    try {
      await c.initialize();
      if (!mounted) return;
      if (widget.active) await c.play();
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
    final l = AppLocalizations.of(context);
    final c = _c;
    final f = widget.message.file!;
    final ready = c != null && c.value.isInitialized;
    if (_failed) return Center(child: Text(l.chatFileFailed, style: const TextStyle(color: Colors.white)));
    return Stack(alignment: Alignment.center, children: [
      if (!ready && f.thumbUrl != null) Center(child: CachedNetworkImage(imageUrl: f.thumbUrl!, fit: BoxFit.contain)),
      if (ready)
        Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: GestureDetector(onTap: () => c.value.isPlaying ? c.pause() : c.play(), child: VideoPlayer(c)),
          ),
        ),
      if (!ready || c.value.isBuffering) const CircularProgressIndicator(color: Colors.white),
      if (ready)
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // the lighter bar = already downloaded; drag anywhere, even ahead of it
              VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white38, backgroundColor: Colors.white12)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  key: const Key('videoPlayPause'),
                  iconSize: 44,
                  color: Colors.white,
                  icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                  onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
                ),
                Text('${formatDuration(c.value.position)} / ${formatDuration(c.value.duration)}', style: const TextStyle(color: Colors.white)),
              ]),
            ]),
          ),
        ),
    ]);
  }
}
